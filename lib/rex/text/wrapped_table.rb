# -*- coding: binary -*-
require 'ipaddr'
require 'io/console'
require 'bigdecimal'

module Rex
module Text

###
#
# Prints text in a tablized format.  Pretty lame at the moment, but
# whatever.
#
###
# private_constant
class WrappedTable

  #
  # Initializes a text table instance using the supplied properties.  The
  # Table class supports the following hash attributes:
  #
  # Header
  #
  #	The string to display as a heading above the table.  If none is
  #	specified, no header will be displayed.
  #
  # HeaderIndent
  #
  # 	The amount of space to indent the header.  The default is zero.
  #
  # Columns
  #
  # 	The array of columns that will exist within the table.
  #
  # Rows
  #
  # 	The array of rows that will exist.
  #
  # Width
  #
  # 	The maximum width of the table in characters.
  #
  # Indent
  #
  # 	The number of characters to indent the table.
  #
  # CellPad
  #
  # 	The number of characters to put between each horizontal cell.
  #
  # Prefix
  #
  # 	The text to prefix before the table.
  #
  # Postfix
  #
  # 	The text to affix to the end of the table.
  #
  # SortIndex
  #
  #	The column to sort the table on, -1 disables sorting.
  #
  # ColProps
  #
  # A hash specifying column Width, Stylers, and Formatters.
  #
  def initialize(opts = {})
    self.header   = opts['Header']
    self.headeri  = opts['HeaderIndent'] || 0
    self.columns  = opts['Columns'] || []
    # updated below if we got a "Rows" option
    self.rows     = []

    self.width    = opts['Width']   || ::IO.console&.winsize&.[](1) || ::BigDecimal::INFINITY
    self.indent   = opts['Indent']  || 0
    self.cellpad  = opts['CellPad'] || 2
    self.prefix   = opts['Prefix']  || ''
    self.postfix  = opts['Postfix'] || ''
    self.colprops = []
    self.scterm   = /#{opts['SearchTerm']}/mi if opts['SearchTerm']

    self.sort_index  = opts['SortIndex'] || 0
    self.sort_order  = opts['SortOrder'] || :forward

    # Default column properties
    self.columns.length.times { |idx|
      self.colprops[idx] = {}
      self.colprops[idx]['Width'] = nil
      self.colprops[idx]['WordWrap'] = true
      self.colprops[idx]['Stylers'] = []
      self.colprops[idx]['Formatters'] = []
      self.colprops[idx]['ColumnStylers'] = []
    }

    # ensure all our internal state gets updated with the given rows by
    # using add_row instead of just adding them to self.rows.  See #3825.
    opts['Rows'].each { |row| add_row(row) } if opts['Rows']

    # Merge in options
    if (opts['ColProps'])
      opts['ColProps'].each_key { |col|
        idx = self.columns.index(col)

        if (idx)
          self.colprops[idx].merge!(opts['ColProps'][col])
        end
      }
    end

  end

  #
  # Converts table contents to a string.
  #
  def to_s
    sort_rows

    # Loop over and style columns
    styled_columns = columns.map.with_index { |col, idx| style_table_column_headers(col, idx) }
    # Loop over and style rows that are visible to the user
    styled_rows = rows.select { |row| row_visible(row) }
                      .map! { |row| row.map.with_index { |cell, index| style_table_field(cell, index) } }

    optimal_widths = calculate_optimal_widths(styled_columns, styled_rows)

    str  = prefix.dup
    str << header_to_s || ''
    str << columns_to_s(styled_columns, optimal_widths) || ''
    str << hr_to_s || ''

    styled_rows.each { |row|
      if is_hr(row)
        str << hr_to_s
      else
        str << row_to_s(row, optimal_widths)
      end
    }
    str << postfix

    return str
  end

  #
  # Converts table contents to a csv
  #
  def to_csv
    sort_rows

    str = ''
    str << ( columns.join(",") + "\n" )
    rows.each { |row|
      next if is_hr(row) || !row_visible(row)
      str << ( row.map{|x|
        x = x.to_s
        x.gsub(/[\r\n]/, ' ').gsub(/\s+/, ' ').gsub('"', '""')
      }.map{|x| "\"#{x}\"" }.join(",") + "\n" )
    }
    str
  end

  #
  #
  # Returns the header string.
  #
  def header_to_s # :nodoc:
    if (header)
      pad = " " * headeri

      return pad + header + "\n" + pad + "=" * header.length + "\n\n"
    end

    return ''
  end

  #
  # Prints the contents of the table.
  #
  def print
    puts to_s
  end

  #
  # Adds a row using the supplied fields.
  #
  def <<(fields)
    add_row(fields)
  end

  #
  # Adds a row with the supplied fields.
  #
  def add_row(fields = [])
    if fields.length != self.columns.length
      raise RuntimeError, 'Invalid number of columns!'
    end
    formatted_fields = fields.map.with_index { |field, idx|
      field = format_table_field(field, idx)

      field
    }

    rows << formatted_fields
  end

  def ip_cmp(a, b)
    begin
      a = IPAddr.new(a.to_s)
      b = IPAddr.new(b.to_s)
      return 1  if a.ipv6? && b.ipv4?
      return -1 if a.ipv4? && b.ipv6?
      a <=> b
    rescue IPAddr::Error
      nil
    end
  end

  #
  # Sorts the rows based on the supplied index of sub-arrays
  # If the supplied index is an IPv4 address, handle it differently, but
  # avoid actually resolving domain names.
  #
  def sort_rows(index = sort_index, order = sort_order)
    return if index == -1
    return unless rows
    rows.sort! do |a,b|
      if a[index].nil?
        cmp = -1
      elsif b[index].nil?
        cmp = 1
      elsif a[index] =~ /^[0-9]+$/ and b[index] =~ /^[0-9]+$/
        cmp = a[index].to_i <=> b[index].to_i
      elsif (cmp = ip_cmp(a[index], b[index])) != nil
      else
        cmp = a[index] <=> b[index] # assumes otherwise comparable.
      end
      cmp ||= 0
      order == :forward ? cmp : -cmp
    end
  end

  #
  # Adds a horizontal line.
  #
  def add_hr
    rows << '__hr__'
  end

  #
  # Returns new sub-table with headers and rows maching column names submitted
  #
  #
  # Flips table 90 degrees left
  #
  def drop_left
    tbl = self.class.new(
      'Columns' => Array.new(self.rows.count+1,'  '),
      'Header' => self.header,
      'Indent' => self.indent)
    (self.columns.count+1).times do |ti|
      row = self.rows.map {|r| r[ti]}.unshift(self.columns[ti]).flatten
      # insert our col|row break. kind of hackish
      row[1] = "| #{row[1]}" unless row.all? {|e| e.nil? || e.empty?}
      tbl << row
    end
    return tbl
  end

  def valid_ip?(value)
    begin
      IPAddr.new value
      true
    rescue IPAddr::Error
      false
    end
  end

  #
  # Build table from CSV dump
  #
  def self.new_from_csv(csv)
    # Read in or keep data, get CSV or die
    if csv.is_a?(String)
      csv = File.file?(csv) ? CSV.read(csv) : CSV.parse(csv)
    end
    # Adjust for skew
    if csv.first == ["Keys", "Values"]
      csv.shift # drop marker
      cols = []
      rows = []
      csv.each do |row|
        cols << row.shift
        rows << row
      end
      tbl = self.new('Columns' => cols)
      rows.in_groups_of(cols.count) {|r| tbl << r.flatten}
    else
      tbl = self.new('Columns' => csv.shift)
      while !csv.empty? do
        tbl << csv.shift
      end
    end
    return tbl
  end

  def [](*col_names)
    tbl = self.class.new('Indent' => self.indent,
                         'Header' => self.header,
                         'Columns' => col_names)
    indexes = []

    col_names.each do |col_name|
      index = self.columns.index(col_name)
      raise RuntimeError, "Invalid column name #{col_name}" if index.nil?
      indexes << index
    end

    self.rows.each do |old_row|
      new_row = []
      indexes.map {|i| new_row << old_row[i]}
      tbl << new_row
    end

    return tbl
  end


  alias p print

  attr_accessor :header, :headeri # :nodoc:
  attr_accessor :columns, :rows, :colprops # :nodoc:
  attr_accessor :width, :indent, :cellpad # :nodoc:
  attr_accessor :prefix, :postfix # :nodoc:
  attr_accessor :sort_index, :sort_order, :scterm # :nodoc:

protected

  #
  # Returns if a row should be visible or not
  #
  def row_visible(row)
    return true if self.scterm.nil?
    row.join(' ').match(self.scterm)
  end

  #
  # Defaults cell widths and alignments.
  #
  def defaults # :nodoc:
    self.columns.length.times { |idx|
    }
  end

  #
  # Checks to see if the row is an hr.
  #
  def is_hr(row) # :nodoc:
    return ((row.kind_of?(String)) && (row == '__hr__'))
  end

  #
  # Converts the columns to a string.
  #
  def columns_to_s(columns, optimal_widths) # :nodoc:
    values_as_chunks = chunk_values(columns, optimal_widths)
    result = chunks_to_s(values_as_chunks, optimal_widths)

    barline = ""
    columns.each.with_index do |_column, idx|
      bar_width = display_width(values_as_chunks[idx].first)
      column_width = optimal_widths[idx]

      if idx == 0
        barline << ' ' * indent
      end

      barline << '-' * bar_width
      is_last_column = (idx + 1) == columns.length
      unless is_last_column
        barline << ' ' * (column_width - bar_width)
        barline << ' ' * cellpad
      end
    end

    result + barline
  end

  #
  # Converts an hr to a string.
  #
  def hr_to_s # :nodoc:
    return "\n"
  end

  #
  # Converts a row to a string.
  #
  def row_to_s(row, optimal_widths) # :nodoc:
    values_as_chunks = chunk_values(row, optimal_widths)
    chunks_to_s(values_as_chunks, optimal_widths)
  end

  #
  # Placeholder function that aims to calculate the display width of the given string.
  # In the future this will be aware of East Asian characters having different display
  # widths. For now it simply returns the string's length.
  #
  def display_width(str)
    Rex::Text.display_width(str)
  end

  #
  # Returns a string of color/formatting codes made up of the previously stored color_state
  # e.g. if a `%blu` color code spans multiple lines this will return a string of `%blu` to be appended to
  # the beginning of each row
  #
  # @param [Hash<String, String>] color_state tracks current color/formatting codes within table row
  # @returns [String] Color code string such as `%blu%grn'
  def color_code_string_for(color_state)
    result = ''.dup
    color_state.each do |_format, value|
      if value.is_a?(Array)
        result << value.uniq.join
      else
        result << value
      end
    end
    result
  end

  # @returns [Hash<String, String>] The supported color codes from {Rex::Text::Color} grouped into sections
  def color_code_groups
    return @color_code_groups if @color_code_groups

    @color_code_groups = {
      foreground: %w[
        %cya %red %grn %blu %yel %whi %mag %blk
        %dred %dgrn %dblu %dyel %dcya %dwhi %dmag
      ],
      background: %w[
        %bgblu %bgyel %bggrn %bgmag %bgblk %bgred %bgcyn %bgwhi
      ],
      decoration: %w[
        %und %bld
      ],
      clear: %w[
        %clr
      ]
    }

    # Developer exception raised to ensure all color codes are accounted for. Verified via tests.
    missing_color_codes = (Rex::Text::Color::SUPPORTED_FORMAT_CODES - @color_code_groups.values.flatten)
    raise "Unsupported color codes #{missing_color_codes.join(', ')}" if missing_color_codes.any?

    @color_code_groups
  end

  # Find the preceding color type and value of a given string
  # @param [String] string A string such as '%bgyel etc'
  # @returns [Array,nil] A tuple with the color type and value, or nil
  def find_color_type_and_value(string)
    color_code_groups.each do |color_type, color_values|
      color_value = color_values.find { |color_value| string.start_with?(color_value) }
      if color_value
        return [color_type, color_value]
      end
    end

    nil
  end

  #
  # Takes an array of row values and an integer of optimal column width, loops over array and parses
  # each string to gather color/formatting tags and handles those appropriately while not increasing the column width
  #
  # e.g. if a formatting "%blu" spans across multiple lines it needs to be added to the beginning off every following
  # line, and each line will have a "%clr" added to the end of each row
  #
  # @param [Array<String>] values
  # @param [Integer] optimal_widths
  def chunk_values(values, optimal_widths)
    # First split long strings into an array of chunks, where each chunk size is the calculated column width
    values_as_chunks = values.each_with_index.map do |value, idx|
      color_state = {}
      column_width = optimal_widths[idx]
      chunks = []
      current_chunk = nil
      chars = value.chars
      char_index = 0

      # Check if any color code(s) from previous the string need appended
      while char_index < chars.length do
        # If a new chunk has started, start the chunk with any previous color codes
        if current_chunk.nil? && color_state.any?
          current_chunk = color_code_string_for(color_state)
        end
        current_chunk ||= ''.dup

        # Check if the remaining chars start with a color code such as %blu
        color_type_and_value = chars[char_index] == '%' ? find_color_type_and_value(chars[char_index..].join) : nil
        if color_type_and_value.nil?
          current_chunk << chars[char_index]
          char_index += 1
        else
          color_type, color_code = color_type_and_value

          if color_type == :clear
            color_state.clear
          elsif color_type == :decoration
            # Multiple decorations can be enabled
            color_state[:decoration] ||= []
            color_state[:decoration] << color_code
          else
            # There can only be one foreground or background color
            color_state[color_type] = color_code
          end

          current_chunk << color_code
          char_index += color_code.length
        end

        # If we've reached the final character of the string, or need to word wrap
        # it's time to push the current chunk, and start a new row. Also discard
        # any values that are purely colors and have no display_width
        is_final_character = char_index >= chars.length
        display_width = display_width(current_chunk)
        if (is_final_character && display_width != 0) || display_width == column_width
          if color_state.any? && !current_chunk.end_with?('%clr')
            current_chunk << '%clr'
          end
          chunks.push(current_chunk)
          current_chunk = nil
        end
      end

      chunks
    end

    values_as_chunks
  end

  def chunks_to_s(values_as_chunks, optimal_widths)
    result = ''

    interleave(values_as_chunks).each do |row_chunks|
      line = ""
      row_chunks.each_with_index do |chunk, idx|
        column_width = optimal_widths[idx]
        chunk_length_with_padding = column_width + (chunk.to_s.length - display_width(chunk.to_s))

        if idx == 0
          line << ' ' * indent
        end

        line << chunk.to_s.ljust(chunk_length_with_padding)
        line << ' ' * cellpad
      end

      result << line.rstrip << "\n"
    end

    result
  end

  def interleave(arrays)
    max_length = arrays.map(&:size).max
    padding = [nil] * max_length
    with_left_extra_column = padding.zip(*arrays)
    without_extra_column = with_left_extra_column.map { |columns| columns.drop(1) }

    without_extra_column
  end

  def calculate_optimal_widths(styled_columns, styled_rows)
    total_columns = self.colprops.length
    # Calculate the display width metadata, i.e. the size of the longest strings in the table
    display_width_metadata = Array.new(total_columns) { {} }
    [[styled_columns], styled_rows].each do |group|
      group.each do |row|
        row.each.with_index do |cell, column_index|
          metadata = display_width_metadata[column_index]
          cell_display_width = display_width(cell)
          if cell_display_width > (metadata[:max_display_width] || 0)
            metadata[:max_display_width] = cell_display_width
          end
        end
      end
    end

    # Calculate the sizes set by the user
    user_influenced_column_widths = colprops.map do |colprop|
      if colprop['Width']
        colprop['Width']
      else
        nil
      end
    end

    required_padding = indent + (colprops.length) * cellpad
    available_space = self.width - user_influenced_column_widths.sum(&:to_i) - required_padding
    remaining_column_calculations = user_influenced_column_widths.select(&:nil?).count

    # Calculate the initial widths, which will need an additional refinement to reallocate surplus space
    naive_optimal_width_calculations = display_width_metadata.map.with_index do |display_size, index|
      shared_column_width = available_space / [remaining_column_calculations, 1].max
      remaining_column_calculations -= 1

      # Preference the user defined widths first
      if user_influenced_column_widths[index]
        { width: user_influenced_column_widths[index], wrapped: false }
      elsif display_size[:max_display_width] < shared_column_width
        available_space -= display_size[:max_display_width]
        { width: display_size[:max_display_width], wrapped: false }
      else
        available_space -= shared_column_width
        { width: shared_column_width, wrapped: true }
      end
    end

    # Naively redistribute any surplus space to columns that were wrapped, and try to fit the cell on one line still
    current_width = naive_optimal_width_calculations.sum { |width| width[:width] }
    surplus_width = self.width - current_width - required_padding
    # revisit all columns that were wrapped and add add additional characters
    revisiting_column_counts = naive_optimal_width_calculations.count { |width| width[:wrapped] }
    optimal_widths = naive_optimal_width_calculations.map.with_index do |naive_width, index|
      additional_column_width = surplus_width / [revisiting_column_counts, 1].max
      revisiting_column_counts -= 1

      if naive_width[:wrapped]
        max_width = display_width_metadata[index][:max_display_width]
        if max_width < (naive_width[:width] + additional_column_width)
          surplus_width -= max_width - naive_width[:width]
          max_width
        else
          surplus_width -= additional_column_width
          naive_width[:width] + additional_column_width
        end
      else
        naive_width[:width]
      end
    end

    # In certain scenarios columns can be allocated 0 widths if it's completely impossible to fit the columns into the
    # given space. There's different ways to handle that, for instance truncating data in the table to the initial
    # columns that can fit. For now, we just ensure every width is at least 1 or more character wide, and in the future
    # it may have to truncate columns entirely.
    optimal_widths.map { |width| [1, width].max }
  end

  def format_table_field(str, idx)
    str_cp = str.to_s.encode('UTF-8', invalid: :replace, undef: :replace).strip

    colprops[idx]['Formatters'].each do |f|
      str_cp = f.format(str_cp)
    end

    str_cp
  end

  def style_table_column_headers(str, idx)
    str_cp = str.dup

    colprops[idx]['ColumnStylers'].each do |s|
      str_cp = s.style(str_cp)
    end

    str_cp
  end

  def style_table_field(str, idx)
    str_cp = str.dup

    colprops[idx]['Stylers'].each do |s|
      str_cp = s.style(str_cp)
    end

    str_cp
  end

end

end
end
