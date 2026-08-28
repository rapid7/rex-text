# -*- coding: binary -*-

module Rex
module Text

###
#
# Renders rows with parent/child relationships as a table.
#
# Rows can form a hierarchy directly through {#add_row} and {Row#add_child}, or
# they can describe relationships with keys and parent keys. Key-based relationships
# are resolved only when the table is rendered, so rows may be added in any order.
#
# @example Building a relational hierarchy
#   table = Rex::Text::HierarchyTable.new(
#     columns: ['Id', 'Type', 'Information'],
#     header: 'Sessions'
#   )
#
#   table.add_row(['2', 'shell', 'via pivot'], key: 2, parent_keys: [1])
#   table.add_row(['1', 'meterpreter', 'DESKTOP-A'], key: 1)
#
#   puts table.render(mode: :tree)
#
###
class HierarchyTable
  MODE_TREE = :tree
  MODE_GROUPED = :grouped
  MODES = [MODE_TREE, MODE_GROUPED].freeze
  DEFAULT_MODE = MODE_TREE

  GLYPH_SETS = {
    ascii: {
      last: '\\- ',
      mid: '+- ',
      carry: '|  ',
      clear: '   '
    }.freeze,
    unicode: {
      last: "\u2514\u2500 ",
      mid: "\u251c\u2500 ",
      carry: "\u2502  ",
      clear: '   '
    }.freeze
  }.freeze

  DEFAULT_HIERARCHY_STYLE = :ascii
  DEFAULT_REFERENCE_SUFFIX = ' (see above)'
  TRUNCATION_MARKER = '...'

  # Distinguishes an omitted render override from an explicit value.
  RENDER_OPTION_UNSPECIFIED = Object.new.freeze
  private_constant :RENDER_OPTION_UNSPECIFIED

  # A transient grouping row used to build a presentation without changing the
  # source rows.
  RenderNode = Struct.new(:fields, :children)
  private_constant :RenderNode

  # A row and the rows nested directly beneath it.
  class Row
    # @return [Array<String>] The immutable values stored in this row.
    attr_reader :fields

    # @return [Object, nil] The identity used to resolve relationships.
    attr_reader :key

    # @return [Array<Object>] Identities of this row's parents.
    attr_reader :parent_keys

    # @param column_count [Integer] The required number of fields.
    # @param fields [Array] The values stored in this row.
    # @param key [Object, nil] Optional identity used to resolve relationships.
    # @param parent_keys [Array<Object>] Identities of this row's parents.
    def initialize(column_count, fields, key: nil, parent_keys: [])
      unless fields.is_a?(Array) && fields.length == column_count
        actual = fields.respond_to?(:length) ? fields.length : 0
        raise ArgumentError, "Expected #{column_count} fields, got #{actual}"
      end
      raise ArgumentError, 'parent_keys must be an Array' unless parent_keys.is_a?(Array)
      if key.nil? && !parent_keys.empty?
        raise ArgumentError, 'A row with parent keys must have a key'
      end

      @column_count = column_count
      @fields = fields.map { |field| field.to_s.strip.freeze }.freeze
      @key = key
      @parent_keys = parent_keys.compact.uniq.freeze
      @children = []
    end

    # @return [Boolean] Whether this row participates in key-based relationships.
    def relational?
      !key.nil?
    end

    # Adds a row directly beneath this row.
    #
    # @param fields [Array] The values stored in the child row.
    # @return [Row] The child row.
    def add_child(fields)
      child = self.class.new(@column_count, fields)
      @children << child
      child
    end

    # @return [Array<Row>] The child rows in insertion order.
    def children
      @children.dup
    end
  end

  # @return [Array<Symbol>] The supported rendering modes.
  def self.modes
    MODES.dup
  end

  # @return [Array<Symbol>] The supported connector styles.
  def self.hierarchy_styles
    GLYPH_SETS.keys
  end

  # @return [Array<String>] The table's immutable column names.
  attr_reader :columns

  # @return [String, nil] The heading printed above the table.
  attr_reader :header

  # @return [Integer] The column on which hierarchy connectors are drawn.
  attr_reader :hierarchy_column_index

  # @return [Symbol] The rendering mode used by {#to_s}.
  attr_reader :mode

  # @return [Symbol] The connector style used to draw the hierarchy.
  attr_reader :hierarchy_style

  # @param columns [Array<String>] The table's source column names.
  # @param header [String, nil] An optional heading printed above the table.
  # @param hierarchy_column [String, Integer] The column on which connectors are drawn.
  # @param mode [Symbol] Either `:tree` or `:grouped`. When omitted, non-empty group columns select grouped mode.
  # @param hierarchy_style [Symbol] Either `:ascii` or `:unicode`.
  # @param max_chars [Hash{String,Integer=>Integer}] Optional character limits by source column.
  # @param group_columns [Array<String, Integer>] Source columns promoted to hierarchy levels in grouped mode.
  # @param reference_suffix [String] Text appended when a relational row is referenced more than once.
  def initialize(columns:, header: nil, hierarchy_column: 0, mode: RENDER_OPTION_UNSPECIFIED, hierarchy_style: DEFAULT_HIERARCHY_STYLE, max_chars: {}, group_columns: [], reference_suffix: DEFAULT_REFERENCE_SUFFIX)
    unless columns.is_a?(Array) && !columns.empty?
      raise ArgumentError, 'Columns must be a non-empty Array'
    end

    @columns = columns.map { |column| column.to_s.dup.freeze }.freeze
    @header = header.nil? ? nil : header.to_s.dup.freeze
    @hierarchy_column_index = resolve_column(hierarchy_column, 'hierarchy column')
    @group_column_indices = resolve_group_columns(group_columns).freeze
    @mode = mode.equal?(RENDER_OPTION_UNSPECIFIED) ? inferred_mode(@group_column_indices) : resolve_mode(mode)
    validate_mode(@mode, @group_column_indices)
    @hierarchy_style = resolve_hierarchy_style(hierarchy_style)
    @glyphs = GLYPH_SETS.fetch(@hierarchy_style)
    @max_chars = resolve_max_chars(max_chars).freeze
    @reference_suffix = reference_suffix.to_s.dup.freeze
    @rows = []
    @rows_by_key = {}
  end

  # Adds a row. Keyed rows have their relationships resolved when rendered;
  # unkeyed rows are roots and can still be nested directly with {Row#add_child}.
  # Re-adding an identical keyed row returns the previously added row, while a
  # conflicting definition for the same key is rejected.
  #
  # @param fields [Array] The values stored in the row.
  # @param key [Object, nil] Optional identity used to resolve relationships.
  # @param parent_keys [Array<Object>] Identities of this row's parents.
  # @return [Row] The added or previously added identical row.
  def add_row(fields, key: nil, parent_keys: [])
    row = Row.new(columns.length, fields, key: key, parent_keys: parent_keys)

    unless key.nil?
      existing_row = @rows_by_key[key]
      if existing_row
        same_parent_keys = existing_row.parent_keys.length == row.parent_keys.length && (existing_row.parent_keys - row.parent_keys).empty?
        return existing_row if existing_row.fields == row.fields && same_parent_keys

        raise ArgumentError, "Duplicate row key #{key.inspect} has conflicting row data"
      end
    end

    @rows << row
    @rows_by_key[key] = row unless key.nil?
    row
  end

  # @return [Array<Row>] The root rows in insertion order.
  def rows
    @rows.dup
  end

  # Renders the hierarchy using the constructor-provided mode.
  #
  # @return [String] The rendered table.
  def to_s
    render
  end

  # Renders the hierarchy as an aligned table.
  #
  # An explicit mode overrides the constructor-provided mode for this rendering only.
  #
  # @param mode [Symbol] Either `:tree` or `:grouped`.
  # @return [String] The rendered table.
  def render(mode: RENDER_OPTION_UNSPECIFIED)
    render_mode = mode.equal?(RENDER_OPTION_UNSPECIFIED) ? @mode : resolve_mode(mode)
    validate_mode(render_mode, @group_column_indices)
    group_column_indices = render_mode == MODE_GROUPED ? @group_column_indices : []
    visible_column_indices = columns.each_index.reject { |index| group_column_indices.include?(index) }
    visible_hierarchy_column_index = visible_column_indices.index(hierarchy_column_index)
    display_columns = rendered_columns(group_column_indices, visible_column_indices, visible_hierarchy_column_index)
    display_rows = rendered_rows(group_column_indices).map do |row|
      visible_column_indices.map { |index| row[index] }
    end
    widths = column_widths(display_columns, display_rows)
    lines = []

    unless header.nil?
      lines << header
      lines << ('=' * character_length(header))
      lines << ''
    end

    lines << format_row(display_columns, widths)
    lines << format_row(display_columns.map { |column| '-' * character_length(column) }, widths)
    display_rows.each { |row| lines << format_row(row, widths) }

    lines.join("\n") + "\n"
  end

  private

  # Resolves key-based parent relationships into presentation nodes without
  # changing source rows. Missing parents promote a row to a root. Shared rows and
  # cycles are expanded once and represented by a suffixed reference thereafter.
  #
  # @return [Array<(Row, RenderNode)>] Root nodes ready for tree rendering.
  def relationship_presentation_rows
    return @rows if @rows_by_key.empty?

    children_by_key = Hash.new { |hash, key| hash[key] = [] }

    @rows_by_key.each_value do |row|
      row.parent_keys.each do |parent_key|
        children_by_key[parent_key] << row if @rows_by_key.key?(parent_key)
      end
    end

    roots = @rows.reject do |row|
      row.relational? && row.parent_keys.any? { |parent_key| @rows_by_key.key?(parent_key) }
    end
    rendered_keys = {}
    rendered = roots.map { |row| relationship_node(row, children_by_key, rendered_keys) }

    # A graph made entirely of cycles has no root. Start each still-unrendered
    # component at its first-added row so no source row is lost.
    @rows_by_key.each_value do |row|
      next if rendered_keys.key?(row.key)

      rendered << relationship_node(row, children_by_key, rendered_keys)
    end

    rendered
  end

  # @param row [Row] The source row to project.
  # @param children_by_key [Hash{Object=>Array<Row>}] Relational children by key.
  # @param rendered_keys [Hash] Keys expanded during this rendering.
  # @return [Row, RenderNode] A source row or transient relational node.
  def relationship_node(row, children_by_key, rendered_keys)
    return row unless row.relational?

    if rendered_keys.key?(row.key)
      fields = row.fields.dup
      fields[hierarchy_column_index] = fields[hierarchy_column_index] + @reference_suffix
      return RenderNode.new(fields, [])
    end

    rendered_keys[row.key] = true
    projected_children = (row.children + children_by_key[row.key]).map do |child|
      relationship_node(child, children_by_key, rendered_keys)
    end
    RenderNode.new(row.fields, projected_children)
  end

  # @param group_column_indices [Array<Integer>] Group columns for this rendering.
  # @param visible_column_indices [Array<Integer>] Source columns visible in this rendering.
  # @param visible_hierarchy_column_index [Integer] The hierarchy column's rendered position.
  # @return [Array<String>] Column headings after presentation-only grouping.
  def rendered_columns(group_column_indices, visible_column_indices, visible_hierarchy_column_index)
    rendered = visible_column_indices.map { |index| columns[index] }
    return rendered if group_column_indices.empty?

    grouped_heading = (group_column_indices + [hierarchy_column_index]).map { |index| columns[index] }.join(' / ')
    rendered[visible_hierarchy_column_index] = grouped_heading
    rendered
  end

  # @param group_column_indices [Array<Integer>] Group columns for this rendering.
  # @return [Array<(Row, RenderNode)>] Rows used for this rendering.
  def presentation_rows(group_column_indices)
    rows = relationship_presentation_rows
    return rows if group_column_indices.empty?

    grouped_presentation_rows(rows, 0, group_column_indices)
  end

  # @param rows [Array<Row>] Source rows sharing the preceding group path.
  # @param depth [Integer] The group column currently being projected.
  # @param group_column_indices [Array<Integer>] Group columns for this rendering.
  # @param group_values [Array<String>] Values projected by preceding group levels.
  # @return [Array<RenderNode>] Group nodes in first-seen order.
  def grouped_presentation_rows(rows, depth, group_column_indices, group_values = [])
    group_column_index = group_column_indices[depth]

    rows.group_by { |row| row.fields[group_column_index] }.map do |value, members|
      current_group_values = group_values + [value]
      if depth == group_column_indices.length - 1
        final_group_node(value, members, group_column_indices, current_group_values)
      else
        RenderNode.new(
          group_fields(value),
          grouped_presentation_rows(members, depth + 1, group_column_indices, current_group_values)
        )
      end
    end
  end

  # @param value [String] The final group value.
  # @param rows [Array<Row>] Source rows with the same complete group path.
  # @param group_column_indices [Array<Integer>] Group columns for this rendering.
  # @param group_values [Array<String>] The complete group path represented by this node.
  # @return [RenderNode] The final group node, optionally populated by a matching row.
  def final_group_node(value, rows, group_column_indices, group_values)
    collapsed = rows.find { |row| row.fields[hierarchy_column_index] == value }
    children = rows.flat_map do |row|
      if row.equal?(collapsed)
        projected_children(row.children, group_column_indices, group_values)
      else
        [projected_row(row, group_column_indices, group_values)]
      end
    end

    RenderNode.new(
      collapsed ? collapsed.fields : group_fields(value),
      children
    )
  end

  # Projects a source row while preserving endpoint changes in its descendants.
  #
  # @param row [Row] The source row.
  # @param group_column_indices [Array<Integer>] Group columns for this rendering.
  # @param group_values [Array<String>] The group path containing the row.
  # @return [RenderNode] A presentation copy of the source row.
  def projected_row(row, group_column_indices, group_values)
    RenderNode.new(
      row.fields,
      projected_children(row.children, group_column_indices, group_values)
    )
  end

  # Projects child rows, adding new group levels when their group path differs
  # from their parent's path. Children sharing a changed path share its synthetic
  # group levels while direct children retain insertion order.
  #
  # @param rows [Array<Row>] Source child rows.
  # @param group_column_indices [Array<Integer>] Group columns for this rendering.
  # @param parent_group_values [Array<String>] The parent row's group path.
  # @return [Array<RenderNode>] Projected child rows and group nodes.
  def projected_children(rows, group_column_indices, parent_group_values)
    entries = []
    grouped_entry_indices = {}

    rows.each do |row|
      group_values = group_column_indices.map { |index| row.fields[index] }
      if group_values == parent_group_values
        entries << [:direct, [row]]
      elsif grouped_entry_indices.key?(group_values)
        entries[grouped_entry_indices[group_values]][1] << row
      else
        grouped_entry_indices[group_values] = entries.length
        entries << [:grouped, [row]]
      end
    end

    entries.flat_map do |type, members|
      if type == :direct
        members.map { |row| projected_row(row, group_column_indices, parent_group_values) }
      else
        [changed_group_node(members, group_column_indices, parent_group_values)]
      end
    end
  end

  # Builds only the changed suffix of a child row's group path.
  #
  # @param rows [Array<Row>] Source rows sharing the changed group path.
  # @param group_column_indices [Array<Integer>] Group columns for this rendering.
  # @param parent_group_values [Array<String>] The parent row's group path.
  # @return [RenderNode] The first synthetic node in the changed path.
  def changed_group_node(rows, group_column_indices, parent_group_values)
    group_values = group_column_indices.map { |index| rows.first.fields[index] }
    first_changed_depth = group_values.each_index.find { |depth| group_values[depth] != parent_group_values[depth] }
    last_depth = group_column_indices.length - 1
    node = final_group_node(
      group_values[last_depth],
      rows,
      group_column_indices,
      group_values
    )

    (last_depth - 1).downto(first_changed_depth) do |depth|
      node = RenderNode.new(group_fields(group_values[depth]), [node])
    end

    node
  end

  # @param value [String] The value displayed by a synthetic group row.
  # @return [Array<String>] Source-shaped fields with only the hierarchy field populated.
  def group_fields(value)
    fields = Array.new(columns.length, '')
    fields[hierarchy_column_index] = value
    fields
  end

  # @param group_column_indices [Array<Integer>] Group columns for this rendering.
  # @return [Array<Array<String>>] Rows with truncation and hierarchy prefixes applied.
  def rendered_rows(group_column_indices)
    rendered = []
    append_rendered_rows(presentation_rows(group_column_indices), rendered, nil)
    rendered
  end

  # @param rows [Array<(Row, RenderNode)>] Sibling rows at the current depth.
  # @param rendered [Array<Array<String>>] The output rows accumulated so far.
  # @param carried [String, nil] Connectors carried from ancestor rows, or nil for roots.
  # @return [void]
  def append_rendered_rows(rows, rendered, carried)
    root_level = carried.nil?

    rows.each_with_index do |row, index|
      last = index == rows.length - 1
      prefix = root_level ? '' : carried + (last ? @glyphs[:last] : @glyphs[:mid])
      fields = truncate_fields(row.fields)
      fields[hierarchy_column_index] = prefix + fields[hierarchy_column_index]
      rendered << fields

      next if row.children.empty?

      child_carry = root_level ? '' : carried + (last ? @glyphs[:clear] : @glyphs[:carry])
      append_rendered_rows(row.children, rendered, child_carry)
    end
  end

  # @param fields [Array<String>] The stored source-shaped fields.
  # @return [Array<String>] Truncated copies of the fields.
  def truncate_fields(fields)
    fields.each_with_index.map do |value, index|
      limit = @max_chars[index]
      limit.nil? ? value : truncate_value(value, limit)
    end
  end

  # @param value [String] The value to truncate.
  # @param limit [Integer] Its maximum character count.
  # @return [String] The value truncated to the requested length.
  def truncate_value(value, limit)
    return value if character_length(value) <= limit

    marker = limit > TRUNCATION_MARKER.length ? TRUNCATION_MARKER : ''
    string = utf8_string(value) || value
    string[0, limit - marker.length] + marker
  end

  # @param display_columns [Array<String>] The rendered column headings.
  # @param rows [Array<Array<String>>] The rows that will be rendered.
  # @return [Array<Integer>] The display width of each column.
  def column_widths(display_columns, rows)
    display_columns.each_index.map do |index|
      ([character_length(display_columns[index])] + rows.map { |row| character_length(row[index]) }).max
    end
  end

  # @param fields [Array<String>] The row to format.
  # @param widths [Array<Integer>] The display width of each column.
  # @return [String] The aligned row without trailing whitespace.
  def format_row(fields, widths)
    fields.each_with_index.map do |field, index|
      index == fields.length - 1 ? field : pad(field, widths[index])
    end.join('  ').rstrip
  end

  # @param value [String] The value to pad.
  # @param width [Integer] The target display width.
  # @return [String] The padded value.
  def pad(value, width)
    value + (' ' * [width - character_length(value), 0].max)
  end

  # @param value [Object] The value to measure.
  # @return [Integer] The number of characters in the value.
  def character_length(value)
    string = utf8_string(value)
    string ? string.length : value.to_s.length
  end

  # @param value [Object] The value to encode as UTF-8.
  # @return [String, nil] A valid UTF-8 string, or nil when conversion is unsafe.
  def utf8_string(value)
    string = value.to_s.dup.force_encoding('UTF-8')
    string.valid_encoding? ? string : nil
  end

  # @param column [String, Integer] A column name or index.
  # @param description [String] The option being resolved, for error messages.
  # @return [Integer] The resolved column index.
  def resolve_column(column, description)
    if column.is_a?(Integer)
      unless column.between?(0, columns.length - 1)
        raise ArgumentError, "Invalid #{description} index #{column}"
      end

      return column
    end

    index = columns.index(column.to_s)
    raise ArgumentError, "Invalid #{description} name #{column.inspect}" if index.nil?

    index
  end

  # @param group_columns [Array<String, Integer>] Requested presentation group columns.
  # @return [Array<Integer>] Resolved source column indexes.
  def resolve_group_columns(group_columns)
    raise ArgumentError, 'group_columns must be an Array' unless group_columns.is_a?(Array)

    resolved = group_columns.map { |column| resolve_column(column, 'group column') }
    if resolved.uniq.length != resolved.length
      raise ArgumentError, 'Duplicate group column'
    end
    if resolved.include?(hierarchy_column_index)
      raise ArgumentError, 'The hierarchy column cannot also be a group column'
    end

    resolved
  end

  # @param group_column_indices [Array<Integer>] The configured grouping columns.
  # @return [Symbol] Grouped mode when columns are configured, otherwise tree mode.
  def inferred_mode(group_column_indices)
    group_column_indices.empty? ? DEFAULT_MODE : MODE_GROUPED
  end

  # @param mode [Symbol, String] The requested rendering mode.
  # @return [Symbol] The normalized mode.
  def resolve_mode(mode)
    mode = mode.to_sym if mode.respond_to?(:to_sym)
    return mode if MODES.include?(mode)

    expected = MODES.map { |supported_mode| ":#{supported_mode}" }.join(' or ')
    raise ArgumentError, "Unknown hierarchy mode #{mode.inspect}; expected #{expected}"
  end

  # @param mode [Symbol] The resolved rendering mode.
  # @param group_column_indices [Array<Integer>] The configured grouping columns.
  # @return [void]
  def validate_mode(mode, group_column_indices)
    return unless mode == MODE_GROUPED && group_column_indices.empty?

    raise ArgumentError, 'Grouped hierarchy mode requires at least one group column'
  end

  # @param style [Symbol, String] The requested connector style.
  # @return [Symbol] The normalized style.
  def resolve_hierarchy_style(style)
    style = style.to_sym if style.respond_to?(:to_sym)
    return style if GLYPH_SETS.key?(style)

    expected = self.class.hierarchy_styles.map { |supported_style| ":#{supported_style}" }.join(' or ')
    raise ArgumentError, "Unknown hierarchy style #{style.inspect}; expected #{expected}"
  end

  # @param max_chars [Hash] Maximum character counts keyed by column name or index.
  # @return [Hash{Integer=>Integer}] Maximum character counts keyed by column index.
  def resolve_max_chars(max_chars)
    raise ArgumentError, 'max_chars must be a Hash' unless max_chars.is_a?(Hash)

    max_chars.each_with_object({}) do |(column, limit), resolved|
      index = resolve_column(column, 'max_chars column')
      limit = Integer(limit)
      raise ArgumentError, 'Maximum character counts must be greater than zero' unless limit > 0

      resolved[index] = limit
    end
  end
end

end
end
