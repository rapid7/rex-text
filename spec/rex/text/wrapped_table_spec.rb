# -*- coding: binary -*-

require 'spec_helper'
require 'rex/text/wrapped_table'

describe Rex::Text::Table do
  let(:formatter) do
    clazz = Class.new do
      def format(str)
        "IHAVEBEENFORMATTED#{str}"
      end
    end

    clazz.new
  end

  let(:styler) do
    clazz = Class.new do
      def style(str)
        "IHAVEBEENSTYLED#{str}"
      end
    end

    clazz.new
  end

  let(:mock_window_size_rows) { 30 }
  let(:mock_window_size_columns) { 180 }
  let(:mock_window_size) { [mock_window_size_rows, mock_window_size_columns] }
  let(:mock_io_console) { double(:console, winsize: mock_window_size) }

  before(:each) do
    allow(::IO).to receive(:console).and_return(mock_io_console)
    allow(Rex::Text::Table).to receive(:wrap_table?).with(anything).and_return(true)
  end

  describe "#to_csv" do
    it "handles strings in different encodings" do
      options = {
        'Header' => 'Header',
        'Indent' => 2,
        'Width' => 80,
        'Columns' => [
          'Name',
          'Value'
        ]
      }

      tbl = Rex::Text::Table.new(options)
      tbl << [
        "hello world".force_encoding("ASCII-8BIT"),
        "hello world".force_encoding("ASCII-8BIT")
      ]
      tbl << [
        "Administratör".force_encoding("UTF-8"),
        "Administratör".force_encoding("UTF-8")
      ]
       # "Administrator’s Shares".encode("UTF-16LE")
       tbl << [
        "\x41\x00\x64\x00\x6d\x00\x69\x00\x6e\x00\x69\x00\x73\x00\x74\x00" \
        "\x72\x00\x61\x00\x74\x00\x6f\x00\x72\x00\x19\x20\x73\x00\x20\x00" \
        "\x53\x00\x68\x00\x61\x00\x72\x00\x65\x00\x73\x00".force_encoding("UTF-16LE")
      ] * 2

      tbl << [
        "这是中文这是中文这是中文这是中文".force_encoding("UTF-8"),
        "这是中文这是中文这是中文这是中文".force_encoding("UTF-8")
      ]

      tbl << [
        # Contains invalid UTF-8 bytes
        "\x85\x5f\x9c\xbc\x10\x7f\x11\x4e\x8e\x8e\xeb\x3a\x54\x33\x41\xb0".force_encoding('UTF-8'),
        # 四Ⅰ
        "\xe5\x9b\x9b\xe2\x85\xa0".force_encoding("UTF-8")
      ]

      tbl << [
        '👍👍👍👍👍👍'.force_encoding('UTF-8'),
        # Hello 日本
        "hello \x93\xfa\x96\x7b".force_encoding("SHIFT_JIS")
      ]

      expect(tbl.to_csv).to eql <<~TABLE.force_encoding("UTF-8")
        Name,Value
        "hello world","hello world"
        "Administratör","Administratör"
        "Administrator’s Shares","Administrator’s Shares"
        "这是中文这是中文这是中文这是中文","这是中文这是中文这是中文这是中文"
        "�_��\u0010\u007F\u0011N���:T3A�","四Ⅰ"
        "👍👍👍👍👍👍","hello 日本"
      TABLE
      expect(tbl.to_s.lines).to all(have_maximum_width(80))
    end
  end

  describe "#to_s" do
    describe 'width calculation' do
      let(:default_options) do
        {
          'Header' => 'Header',
          'Columns' => [
            'Column 1',
            'Column 2',
            'Column 3'
          ]
        }
      end
      let(:table) { Rex::Text::Table.new(options) }

      context 'when a width is specified' do
        let(:options) { default_options.merge({ 'Width' =>  100 }) }
        it { expect(table.width).to eql 100 }
      end

      context 'when a width is not specified' do
        let(:options) { default_options }
        it { expect(table.width).to eql 180 }
      end

      context 'when the IO.console API is not available' do
        let(:options) { default_options }
        let(:mock_io_console) { nil }
        it { expect(table.width).to eql BigDecimal::INFINITY }
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

      expect(tbl).to match_table <<~TABLE
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

      expect(tbl).to match_table <<~TABLE
        Header
        ======

        Column 1  Column 2                                                              Column 3
        --------  --------                                                              --------
        AAAAA     IHAVEBEENFORMATTEDBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  CCCCCCCCCCCCCCC
      TABLE
    end

    it 'should apply field stylers correctly and NOT increase column length' do
      skip(
        "Functionality not implemented. Currently if there are colors present in a cell, the colors will break " \
          "when word wrapping occurs. This is a regression in functionality with a normal Rex Table."
      )

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

      expect(tbl).to match_table <<~TABLE
        Header
        ======

        Column 1  Column 2                                            Column 3
        --------  --------                                            --------
        AAAAA     IHAVEBEENSTYLEDBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB  CCCCCCCCCCCCCCC
      TABLE
    end

    it 'handles multiple columns gracefully' do
      options = {
        'Header' => 'Hosts',
        'Indent' => 0,
        'Width' => 120,
        'Columns' => [
          'address',
          'mac',
          'name',
          'os_name',
          'os_flavor',
          'os_sp',
          'purpose',
          'info',
          'comments'
        ]
      }

      tbl = Rex::Text::Table.new(options)

      tbl << [
        "127.0.0.1",
        "",
        "192.168.1.10",
        "macOS Mojave (macOS 10.14.6)",
        "",
        "",
        "device",
        "",
        ""
      ]

      expect(tbl).to match_table <<~TABLE
        Hosts
        =====

        address    mac  name          os_name                       os_flavor  os_sp  purpose  info  comments
        -------    ---  ----          -------                       ---------  -----  -------  ----  --------
        127.0.0.1       192.168.1.10  macOS Mojave (macOS 10.14.6)                    device
      TABLE
      expect(tbl.to_s.lines).to all(have_maximum_width(120))
    end

    it 'makes use of all available space' do
      options = {
        'Header' => 'Hosts',
        'Indent' => 0,
        'Width' => 80,
        'Columns' => [
          'address',
          'mac',
          'name',
          'os_name',
          'os_flavor',
          'os_sp',
          'purpose',
          'info',
          'comments'
        ]
      }

      tbl = Rex::Text::Table.new(options)

      tbl << [
        "127.0.0.1",
        "",
        "192.168.1.10",
        "macOS Mojave (macOS 10.14.6)",
        "",
        "",
        "device",
        "",
        ""
      ]

      expect(tbl).to match_table <<~TABLE
        Hosts
        =====

        address   mac  name        os_name     os_flav  os_sp  purpose  info  comments
                                               or
        -------   ---  ----        -------     -------  -----  -------  ----  --------
        127.0.0.       192.168.1.  macOS Moja                  device
        1              10          ve (macOS
                                   10.14.6)
      TABLE
      expect(tbl.to_s.lines).to all(have_maximum_width(80))
    end

    context 'when word wrapping occurs' do
      it "Evenly distributes all data" do
        options = {
          'Header' => 'Header',
          'Width' => 80,
          'Columns' => [
            'id',
            'Column 2',
            'Column 3',
          ]
        }

        tbl = Rex::Text::Table.new(options)
        tbl << [
          '1',
          'Lorem ipsum dolor sit amet, consectetur adipiscing elite',
          'Pellentesque ac tellus lobortis, volutpat nibh sit amet'
        ]

        expect(tbl).to match_table <<~TABLE
          Header
          ======

          id  Column 2                              Column 3
          --  --------                              --------
          1   Lorem ipsum dolor sit amet, consecte  Pellentesque ac tellus lobortis, vol
              tur adipiscing elite                  utpat nibh sit amet
        TABLE
        expect(tbl.to_s.lines).to all(have_maximum_width(80))
      end

      it "Evenly allows columns to have specified widths" do
        options = {
          'Header' => 'Header',
          'Width' => 80,
          'Columns' => [
            'name',
            'Column 2',
            'Column 3',
          ],
          'ColProps' => {
            'Column 2' => {
              'MaxChar' => 30
            }
          }
        }

        tbl = Rex::Text::Table.new(options)
        tbl << [
          '1',
          'Lorem ipsum dolor sit amet, consectetur adipiscing elite ' * 2,
          'Pellentesque ac tellus lobortis, volutpat nibh sit amet'
        ]

        expect(tbl).to match_table <<~TABLE
          Header
          ======

          name  Column 2                             Column 3
          ----  --------                             --------
          1     Lorem ipsum dolor sit amet, consect  Pellentesque ac tellus lobortis, vo
                etur adipiscing elite Lorem ipsum d  lutpat nibh sit amet
                olor sit amet, consectetur adipisci
                ng elite
        TABLE
        expect(tbl.to_s.lines).to all(have_maximum_width(80))
      end

      it "handles multiple columns and rows" do
        options = {
          'Header' => 'Header',
          'Indent' => 2,
          'Width' => 80,
          'Columns' => [
            'Name',
            'Current Setting',
            'Required',
            'Description'
          ]
        }

        tbl = Rex::Text::Table.new(options)
        tbl << [
          "DESCRIPTION",
          "{PROCESS_NAME} needs your permissions to start. Please enter user credentials",
          "yes",
          "Message shown in the loginprompt"
        ]
        tbl << [
          "PROCESS",
          "",
          "no",
          "Prompt if a specific process is started by the target. (e.g. calc.exe or specify * for all processes)"
        ]
        tbl << [
          "SESSION",
          "",
          "yes",
          "The session to run this module on."
        ]

        expect(tbl).to match_table <<~TABLE
          Header
          ======

            Name         Current Setting      Required  Description
            ----         ---------------      --------  -----------
            DESCRIPTION  {PROCESS_NAME} need  yes       Message shown in the loginprompt
                         s your permissions
                         to start. Please en
                         ter user credential
                         s
            PROCESS                           no        Prompt if a specific process is
                                                        started by the target. (e.g. cal
                                                        c.exe or specify * for all proce
                                                        sses)
            SESSION                           yes       The session to run this module o
                                                        n.
        TABLE
        expect(tbl.to_s.lines).to all(have_maximum_width(80))
      end

      it "handles strings in different encodings" do
        options = {
          'Header' => 'Header',
          'Indent' => 2,
          'Width' => 80,
          'Columns' => [
            'Name',
            'Value'
          ]
        }

        tbl = Rex::Text::Table.new(options)
        tbl << ["hello world".force_encoding("ASCII-8BIT")] * 2
        tbl << ["Administratör".force_encoding("UTF-8")] * 2

        # "Administrator’s Shares".encode("UTF-16LE")
        tbl << [
          "\x41\x00\x64\x00\x6d\x00\x69\x00\x6e\x00\x69\x00\x73\x00\x74\x00" \
          "\x72\x00\x61\x00\x74\x00\x6f\x00\x72\x00\x19\x20\x73\x00\x20\x00" \
          "\x53\x00\x68\x00\x61\x00\x72\x00\x65\x00\x73\x00".force_encoding("UTF-16LE")
        ] * 2

        tbl << [
          "администраторадминистраторадминистратор".force_encoding('UTF-8'),
          "домен".force_encoding('UTF-8')
        ]

        tbl << ["这是中文这是中文这是中文这是中文".force_encoding("UTF-8")] * 2
        tbl << ["お好み焼き".force_encoding("UTF-8")] * 2

        tbl << [
          # Contains invalid UTF-8 bytes
          "\x85\x5f\x9c\xbc\x10\x7f\x11\x4e\x8e\x8e\xeb\x3a\x54\x33\x41\xb0".force_encoding('UTF-8'),
          # 四Ⅰ
          "\xe5\x9b\x9b\xe2\x85\xa0".force_encoding("UTF-8")
        ]

        tbl << [
          '👍👍👍👍👍👍'.force_encoding('UTF-8'),
          # Hello 日本
          "hello \x93\xfa\x96\x7b".force_encoding("SHIFT_JIS")
        ]

        tbl << [
          "N",
          # Contains invalid bytes
          "VMware \xce\xef\xc0\xed\xb4\xc5\xc5\xcc\xd6\xfa\xca\xd6\xb7\xfe\xce\xf1".force_encoding("ASCII-8BIT")
        ]

        expect(tbl).to match_table <<~TABLE.force_encoding("UTF-8")
          Header
          ======

            Name                                     Value
            ----                                     -----
            Administrator’s Shares                   Administrator’s Shares
            Administratör                            Administratör
            N                                        VMware ����������������
            hello world                              hello world
            администраторадминистраторадминистратор  домен
            お好み焼き                                    お好み焼き
            这是中文这是中文这是中文这是中文                         这是中文这是中文这是中文这是中文
            �_��\u0010\u007F\u0011N���:T3A�                         四Ⅰ
            👍👍👍👍👍👍                                   hello 日本
        TABLE
        expect(tbl.to_s.lines).to all(have_maximum_width(80))
      end

      it "Wraps columns as well as values" do
        options = {
          'Header' => 'Header',
          'Indent' => 2,
          'Width' => 80,
          'Columns' => [
            'A' * 80,
            'B' * 40
          ]
        }

        tbl = Rex::Text::Table.new(options)
        tbl << [
          'Foo',
          'Bar'
        ]
        tbl << [
          'Foo',
          'Bar'
        ]

        expect(tbl).to match_table <<~TABLE
          Header
          ======

            AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA  BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
            AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA  BBB
            AAAAAA
            -------------------------------------  -------------------------------------
            Foo                                    Bar
            Foo                                    Bar
        TABLE
        expect(tbl.to_s.lines).to all(have_maximum_width(80))
      end

      it "safely wordwraps cells that have colors present" do
        skip(
          "Functionality not implemented. Currently if there are colors present in a cell, the colors will break " \
          "when word wrapping occurs"
        )

        options = {
          'Header' => 'Header',
          'Indent' => 2,
          'Width' => 80,
          'Columns' => [
            'Blue Column',
            'Red Column'
          ]
        }

        tbl = Rex::Text::Table.new(options)
        tbl << [
          "%blu#{'A' * 100}%clr",
          "%red#{'A' * 100}%clr",
        ]
        expect(tbl).to match_table <<~TABLE
          Header
          ======

          Blue Column                            Red Column
          -----------                            ----------
          %bluAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%clr  %redAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%clr
          %bluAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%clr  %redAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%clr
          %bluAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%clr     %redAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%clr
        TABLE
        expect(tbl.to_s.lines).to all(have_maximum_width(80))
      end

      it "ensures specific columns can disable wordwrapping" do
        skip(
          "Functionality not implemented. Allowing certain columns to disable wordwrapping would allow the values to be " \
          "copy/pasted easily, i.e. password fields."
        )

        options = {
          'Header' => 'Header',
          'Indent' => 2,
          'Width' => 80,
          'Columns' => [
            '#',
            'Name',
            'Disclosure Date',
            'Rank',
            'Check',
            'Description'
          ],
          'ColProps' => {
            'Name' => {
              'WordWrap' => false
            }
          }
        }

        tbl = Rex::Text::Table.new(options)
        tbl << ['0', 'auxiliary/admin/2wire/xslt_password_reset', '2007-08-15', 'normal', 'No', '2Wire Cross-Site Request Forgery Password Reset Vulnerability']
        tbl << ['1', 'auxiliary/admin/android/google_play_store_uxss_xframe_rce', '', 'normal', 'No', 'Android Browser RCE Through Google Play Store XFO']
        tbl << ['2', 'auxiliary/admin/appletv/appletv_display_image', '', 'normal', 'No', 'Apple TV Image Remote Control']

        expect(tbl).to match_table <<~TABLE
          ...
        TABLE
        expect(tbl.to_s.lines).to all(have_maximum_width(80))
      end

      it "continues to work when it's not possible to fit all of the columns into the available width" do
        options = {
          'Header' => 'Header',
          'Indent' => 2,
          'Width' => 10,
          'Columns' => [
            'Name',
            'Value',
            'Required',
            'Description'
          ]
        }

        tbl = Rex::Text::Table.new(options)
        tbl << [
          "ABCD",
          "ABCD",
          "Yes",
          "ABCD"
        ]

        # If it's not possible to fit all of the required data into the given space, we can either:
        #
        # 1. Ensure that all columns are allocated at least one character
        # 2. Show the left most column(s) that fit, truncate the rightmost columns, and attempt to add affordance.
        #
        # Example:
        #
        #  Header
        #  ======
        #
        #    Name  ...
        #    ----  ---
        #    Foo   ...
        #    Bar   ...
        #
        # For simplicity the first option is chosen, as in either scenario the user will have to resize their terminal.
        expect(tbl).to match_table <<~TABLE
         Header
         ======

           N  V  R  D
           a  a  e  e
           m  l  q  s
           e  u  u  c
              e  i  r
                 r  i
                 e  p
                 d  t
                    i
                    o
                    n
           -  -  -  -
           A  A  Y  A
           B  B  e  B
           C  C  s  C
           D  D     D
        TABLE
      end
    end
  end
end
