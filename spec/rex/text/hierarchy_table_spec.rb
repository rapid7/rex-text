# The box drawing connectors in the expectations below need to compare equal to the
# UTF-8 strings the table produces, so this file deliberately is not `coding: binary`.

require 'spec_helper'
require 'rex/text/hierarchy_table'

RSpec.describe Rex::Text::HierarchyTable do
  let(:options) do
    {
      columns: %w[Name Value],
      mode: :tree,
      hierarchy_style: :ascii
    }
  end

  subject(:table) { described_class.new(**options) }

  describe '.new' do
    it 'creates a standalone hierarchy table' do
      expect(table).to be_a described_class
      expect(table).to_not be_a Rex::Text::Table
    end

    it 'exposes the supported modes and connector styles' do
      expect(described_class.modes).to eql %i[tree grouped]
      expect(described_class.hierarchy_styles).to eql %i[ascii unicode]
    end

    it 'does not expose its mode registry for mutation' do
      described_class.modes.clear

      expect(described_class.modes).to eql %i[tree grouped]
    end

    it 'requires at least one column' do
      expect { described_class.new(columns: []) }.to raise_error ArgumentError, /Columns/
    end

    it 'rejects an unknown hierarchy mode' do
      options[:mode] = :sparkles

      expect { table }.to raise_error ArgumentError, /Unknown hierarchy mode/
    end

    it 'infers grouped mode from configured group columns for compatibility' do
      options.delete(:mode)
      options[:group_columns] = ['Value']

      expect(table.mode).to eql :grouped
    end

    it 'requires group columns in grouped mode' do
      options[:mode] = :grouped

      expect { table }.to raise_error ArgumentError, /requires at least one group column/
    end

    it 'rejects an unknown hierarchy style' do
      options[:hierarchy_style] = :sparkles

      expect { table }.to raise_error ArgumentError, /Unknown hierarchy style/
    end

    it 'rejects an unknown hierarchy column' do
      options[:hierarchy_column] = 'Nope'

      expect { table }.to raise_error ArgumentError, /Invalid hierarchy column/
    end

    it 'rejects an out-of-range hierarchy column index' do
      options[:hierarchy_column] = 5

      expect { table }.to raise_error ArgumentError, /Invalid hierarchy column/
    end

    it 'rejects an unknown max_chars column' do
      options[:max_chars] = { 'Nope' => 10 }

      expect { table }.to raise_error ArgumentError, /Invalid max_chars column/
    end
  end

  describe '#add_row' do
    it 'returns a root row containing normalized fields' do
      row = table.add_row([' root ', 1])

      expect(row).to be_a described_class::Row
      expect(row.fields).to eql %w[root 1]
      expect(table.rows).to eql [row]
    end

    it 'keeps root rows in insertion order' do
      first = table.add_row(%w[first 1])
      second = table.add_row(%w[second 2])

      expect(table.rows).to eql [first, second]
    end

    it 'does not expose its mutable root collection' do
      table.add_row(%w[root 1])

      table.rows.clear

      expect(table.rows.length).to eql 1
    end

    it 'requires one field per column' do
      expect { table.add_row(%w[too many fields]) }
        .to raise_error ArgumentError, /Expected 2 fields, got 3/
    end
  end

  describe 'Row' do
    it 'adds children beneath their parent' do
      root = table.add_row(%w[root 1])
      child = root.add_child(%w[child 2])
      grandchild = child.add_child(%w[grandchild 3])

      expect(root.children).to eql [child]
      expect(child.children).to eql [grandchild]
      expect(grandchild.children).to be_empty
    end

    it 'keeps children in insertion order' do
      root = table.add_row(%w[root 1])
      first = root.add_child(%w[first 2])
      second = root.add_child(%w[second 3])

      expect(root.children).to eql [first, second]
    end

    it 'does not expose its mutable child collection' do
      root = table.add_row(%w[root 1])
      root.add_child(%w[child 2])

      root.children.clear

      expect(root.children.length).to eql 1
    end

    it 'keeps stored fields immutable' do
      row = table.add_row(%w[root 1])

      expect(row.fields).to be_frozen
      expect(row.fields).to all(be_frozen)
      expect { row.fields << 'extra' }.to raise_error RuntimeError
      expect { row.fields.first << 'changed' }.to raise_error RuntimeError
    end
  end

  describe 'relational rows' do
    it 'resolves parents regardless of insertion order' do
      table.add_row(%w[child 2], key: :child, parent_keys: [:root])
      table.add_row(%w[root 1], key: :root)

      expect(table.to_s).to eql <<~'TABLE'
        Name      Value
        ----      -----
        root      1
        \- child  2
      TABLE
    end

    it 'promotes rows with missing parents to roots' do
      table.add_row(%w[orphan 1], key: :orphan, parent_keys: [:missing])

      expect(table.to_s).to include "orphan  1\n"
    end

    it 'expands a shared row under the first-added root and marks later references' do
      table.add_row(%w[root_b 2], key: :root_b)
      table.add_row(%w[root_a 1], key: :root_a)
      table.add_row(%w[shared 3], key: :shared, parent_keys: %i[root_a root_b])

      expect(table.to_s).to eql <<~'TABLE'
        Name                   Value
        ----                   -----
        root_b                 2
        \- shared              3
        root_a                 1
        \- shared (see above)  3
      TABLE
    end

    it 'starts a rootless cycle at the first-added row' do
      table.add_row(%w[b 2], key: :b, parent_keys: [:a])
      table.add_row(%w[a 1], key: :a, parent_keys: [:b])

      expect(table.to_s).to eql <<~'TABLE'
        Name                 Value
        ----                 -----
        b                    2
        \- a                 1
           \- b (see above)  2
      TABLE
    end

    it 'preserves insertion order for relational roots and siblings' do
      table.add_row(%w[second 2], key: :second)
      table.add_row(%w[parent 1], key: :parent)
      table.add_row(%w[z_child 3], key: :z_child, parent_keys: [:parent])
      table.add_row(%w[a_child 4], key: :a_child, parent_keys: [:parent])

      expect(table.to_s).to eql <<~'TABLE'
        Name        Value
        ----        -----
        second      2
        parent      1
        +- z_child  3
        \- a_child  4
      TABLE
    end

    it 'returns the existing row when an identical key is added again' do
      first = table.add_row(%w[first 1], key: :duplicate, parent_keys: %i[parent_a parent_b])

      duplicate = table.add_row(%w[first 1], key: :duplicate, parent_keys: %i[parent_b parent_a])

      expect(duplicate).to equal first
      expect(table.rows).to contain_exactly(first)
    end

    it 'rejects conflicting duplicate keys' do
      table.add_row(%w[first 1], key: :duplicate)

      expect { table.add_row(%w[second 2], key: :duplicate) }
        .to raise_error ArgumentError, /Duplicate row key/
    end

    it 'requires keyed rows when parent keys are supplied' do
      expect { table.add_row(%w[child 1], parent_keys: [:root]) }
        .to raise_error ArgumentError, /must have a key/
    end
  end

  describe '#to_s' do
    it 'renders roots followed recursively by their children' do
      root = table.add_row(%w[root 1])
      child = root.add_child(%w[child 2])
      child.add_child(%w[grandchild 3])
      table.add_row(%w[other 4])

      expect(table.to_s).to eql <<~'TABLE'
        Name              Value
        ----              -----
        root              1
        \- child          2
           \- grandchild  3
        other             4
      TABLE
    end

    it 'draws sibling and continuation connectors' do
      root = table.add_row(%w[root 1])
      branch = root.add_child(%w[branch 2])
      branch.add_child(%w[branch_child_a 3])
      branch.add_child(%w[branch_child_b 4])
      root.add_child(%w[last 5])

      expect(table.to_s).to eql <<~'TABLE'
        Name                  Value
        ----                  -----
        root                  1
        +- branch             2
        |  +- branch_child_a  3
        |  \- branch_child_b  4
        \- last               5
      TABLE
    end

    it 'supports unicode connectors' do
      options[:hierarchy_style] = :unicode
      root = table.add_row(%w[root 1])
      root.add_child(%w[first 2])
      root.add_child(%w[last 3])

      expect(table.to_s).to eql <<~TABLE
        Name      Value
        ----      -----
        root      1
        ├─ first  2
        └─ last   3
      TABLE
    end

    it 'draws the hierarchy on the selected column' do
      options[:hierarchy_column] = 'Value'
      root = table.add_row(%w[root 1])
      root.add_child(%w[child 2])

      expect(table.to_s).to eql <<~'TABLE'
        Name   Value
        ----   -----
        root   1
        child  \- 2
      TABLE
    end

    it 'renders an optional heading' do
      options[:header] = 'Example'
      table.add_row(%w[root 1])

      expect(table.to_s).to eql <<~TABLE
        Example
        =======

        Name  Value
        ----  -----
        root  1
      TABLE
    end

    it 'truncates configured columns without changing stored fields' do
      options[:columns] = %w[Name Info]
      options[:max_chars] = { 'Info' => 10 }
      row = table.add_row(['root', 'x' * 20])

      expect(table.to_s).to eql <<~TABLE
        Name  Info
        ----  ----
        root  xxxxxxx...
      TABLE
      expect(row.fields).to eql ['root', 'x' * 20]
    end

    it 'keeps connectors outside the hierarchy column limit' do
      options[:max_chars] = { 'Name' => 8 }
      root = table.add_row(%w[root info])
      root.add_child(['a_very_long_child_name', 'more'])

      expect(table.to_s).to eql <<~'TABLE'
        Name         Value
        ----         -----
        root         info
        \- a_ver...  more
      TABLE
    end

    it 'cuts without a marker when the limit cannot hold it' do
      options[:max_chars] = { 'Value' => 3 }
      table.add_row(%w[root abcdef])

      expect(table.to_s).to eql <<~TABLE
        Name  Value
        ----  -----
        root  abc
      TABLE
    end

    it 'renders grouped mode as hierarchy levels' do
      options[:columns] = %w[Host Port Proto Name]
      options[:hierarchy_column] = 'Name'
      options[:mode] = :grouped
      options[:group_columns] = %w[Host Port Proto]
      transport = table.add_row(['192.0.2.1', '53', 'udp', 'udp'])
      transport.add_child(['192.0.2.1', '53', 'udp', 'dns'])

      expect(table.to_s).to eql <<~'TABLE'
        Host / Port / Proto / Name
        --------------------------
        192.0.2.1
        \- 53
           \- udp
              \- dns
      TABLE
    end

    it 'shows changed group values on descendants instead of hiding them' do
      options[:columns] = %w[Host Port Proto Name]
      options[:hierarchy_column] = 'Name'
      options[:mode] = :grouped
      options[:group_columns] = %w[Host Port Proto]
      root = table.add_row(['192.0.2.1', '53', 'udp', 'dns'])
      root.add_child(['192.0.2.1', '8080', 'tcp', 'http'])
      root.add_child(['192.0.2.1', '8080', 'tcp', 'admin'])

      expect(table.to_s).to eql <<~'TABLE'
        Host / Port / Proto / Name
        --------------------------
        192.0.2.1
        \- 53
           \- udp
              \- dns
                 \- 8080
                    \- tcp
                       +- http
                       \- admin
      TABLE
    end

    it 'renders the same output without mutating rows' do
      root = table.add_row(%w[root 1])
      child = root.add_child(%w[child 2])
      fields = [root.fields, child.fields].map(&:dup)

      expect(table.to_s).to eql table.to_s
      expect([root.fields, child.fields]).to eql fields
    end
  end

  describe '#render' do
    it 'can override the configured mode for one rendering' do
      options[:group_columns] = ['Value']
      root = table.add_row(%w[root 1])
      root.add_child(%w[child 1])

      expect(table.render(mode: :grouped)).to eql <<~'TABLE'
        Value / Name
        ------------
        1
        \- root
           \- child
      TABLE
      expect(table.to_s).to eql <<~'TABLE'
        Name      Value
        ----      -----
        root      1
        \- child  1
      TABLE
    end

    it 'rejects grouped mode without configured group columns' do
      expect { table.render(mode: :grouped) }
        .to raise_error ArgumentError, /requires at least one group column/
    end
  end
end
