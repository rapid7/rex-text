require 'spec_helper'


describe Rex::Text::Table do
  let(:formatter) do
    Formatter = Class.new do
      def format(str)
        "IHAVEBEENFORMATTED#{str}"
      end
    end

    Formatter.new
  end

  let(:styler) do
    Styler = Class.new do
      def style(str)
        "IHAVEBEENSTYLED#{str}"
      end
    end

    Styler.new
  end

  describe '.wrap_table?' do
    let(:default_table_options) { [{ }] }
    let(:enable_wrapped_table_options) { [{ 'WordWrap' => true }] }
    let(:disable_wrapped_table_options) { [{ 'WordWrap' => false }] }
    let(:feature_enabled) { false }

    before(:each) do
      allow(described_class).to receive(:wrapped_tables?).and_return(feature_enabled)
    end

    context 'when the feature is enabled' do
      let(:feature_enabled) { true }

      it "defaults to true" do
        expect(described_class.wrap_table?(default_table_options)).to be true
      end

      it "returns the user preference when set to true" do
        expect(described_class.wrap_table?(enable_wrapped_table_options)).to be true
      end

      it "returns the user preference when set to false" do
        expect(described_class.wrap_table?(disable_wrapped_table_options)).to be false
      end
    end

    context 'when the feature is disabled' do
      let(:feature_enabled) { false }

      it "defaults to false" do
        expect(described_class.wrap_table?(default_table_options)).to be false
      end

      it "ignores the user preference when set to true" do
        expect(described_class.wrap_table?(enable_wrapped_table_options)).to be false
      end

      it "ignores the user preference when set to false" do
        expect(described_class.wrap_table?(disable_wrapped_table_options)).to be false
      end      
    end
  end

  it 'should space columns correctly' do
    col_1_field = "A" * 5
    col_2_field = "B" * 50
    col_3_field = "C" * 15

    options = {
      'Header' => 'Header',
      'SearchTerm' => ['jim', 'bob'],
      'Columns' => [
        'Column 1',
        'Column 2',
        'Column 3'
      ]
    }

    tbl = Rex::Text::Table.new(options)

    tbl << [
      col_1_field,
      col_2_field,
      col_3_field
    ]

    expect(tbl.to_s).to eql <<~TABLE
      Header
      ======

      Column 1  Column 2                                            Column 3
      --------  --------                                            --------
      AAAAA     BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  CCCCCCCCCCCCCCC
    TABLE
  end

  it 'should apply field formatters correctly and increase column length' do
    col_1_field = "A" * 5
    col_2_field = "B" * 50
    col_3_field = "C" * 15

    options = {
      'Header' => 'Header',
      'SearchTerm' => ['jim', 'bob'],
      'Columns' => [
        'Column 1',
        'Column 2',
        'Column 3'
      ],
      'ColProps' => {
        'Column 2' => {
          'Formatters' => [formatter]
        }
      }
    }

    tbl = Rex::Text::Table.new(options)

    tbl << [
      col_1_field,
      col_2_field,
      col_3_field
    ]

    expect(tbl.to_s).to eql <<~TABLE
      Header
      ======

      Column 1  Column 2                                                              Column 3
      --------  --------                                                              --------
      AAAAA     IHAVEBEENFORMATTEDBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  CCCCCCCCCCCCCCC
    TABLE
  end


  it 'should apply field stylers correctly and NOT increase column length' do
    col_1_field = "A" * 5
    col_2_field = "B" * 50
    col_3_field = "C" * 15

    options = {
      'Header' => 'Header',
      'SearchTerm' => ['jim', 'bob'],
      'Columns' => [
        'Column 1',
        'Column 2',
        'Column 3'
      ],
      'ColProps' => {
        'Column 2' => {
          'Stylers' => [styler]
        }
      }
    }

    tbl = Rex::Text::Table.new(options)

    tbl << [
      col_1_field,
      col_2_field,
      col_3_field
    ]

    expect(tbl.to_s).to eql <<~TABLE
      Header
      ======

      Column 1  Column 2                                            Column 3
      --------  --------                                            --------
      AAAAA     IHAVEBEENSTYLEDBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  CCCCCCCCCCCCCCC
    TABLE
  end

end

