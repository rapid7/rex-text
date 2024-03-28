# -*- coding: binary -*-
require 'spec_helper'
require 'timeout'

RSpec.describe Rex::Text do

  LANGUAGES = %w[ bash c csharp golang masm nim rust perl python ruby zig ]

  describe "languages match expected output" do
    let(:expected_bash) do
      "export buf=\\\n$'\\x41\\x41\\x41\\x41\\x41\\x41'\\\n$'\\x41\\x41\\x41\\x41'\n"
    end

    let(:expected_c) do
      "unsigned char buf[] = \n\"\\x41\\x41\\x41\\x41\\x41\\x41\\x41\"\n\"\\x41\\x41\\x41\";\n"
    end

    let(:expected_csharp) do
      "byte[] buf = new byte[10] {\n0x41,0x41,0x41,0x41,0x41,0x41,\n0x41,0x41,0x41,0x41};\n"
    end

    let(:expected_golang) do
      "buf :=  []byte{0x41,0x41,0x41,\n0x41,0x41,0x41,0x41,0x41,0x41,\n0x41};\n"
    end

    let(:expected_nim) do
      "var buf: array[10, byte] = [\nbyte 0x41,0x41,0x41,0x41,0x41,\n0x41,0x41,0x41,0x41,0x41]\n"
    end

    let(:expected_rust) do
      "let buf: [u8; 10] = [0x41,\n0x41,0x41,0x41,0x41,0x41,0x41,\n0x41,0x41,0x41];\n"
    end

    let(:expected_perl) do
      "my $buf = \n\"\\x41\\x41\\x41\\x41\\x41\\x41\" .\n\"\\x41\\x41\\x41\\x41\";\n"
    end

    let(:expected_python) do
      "buf =  b\"\"\nbuf += b\"\\x41\\x41\\x41\\x41\\x41\"\nbuf += b\"\\x41\\x41\\x41\\x41\\x41\"\n"
    end

    let(:expected_ruby) do
      "buf = \n\"\\x41\\x41\\x41\\x41\\x41\\x41\" +\n\"\\x41\\x41\\x41\\x41\"\n"
    end

    let(:expected_zig) do
      "\nconst buf: []const u8 = &.{\n0x41,0x41,0x41,0x41,0x41,0x41,\n0x41,0x41,0x41,0x41};\n"
    end

    it "bash is as expected" do
      output = described_class.to_bash('A' * 10, 30)
      expect(output).to eq(expected_bash)
    end

    it "c is as expected" do
      output = described_class.to_c('A' * 10, 30)
      expect(output).to eq(expected_c)
    end

    it "csharp is as expected" do
      output = described_class.to_csharp('A' * 10, 30)
      expect(output).to eq(expected_csharp)
    end

    it "golang is as expected" do
      output = described_class.to_golang('A' * 10, 30)
      expect(output).to eq(expected_golang)
    end

    describe '#to_masm' do
      [
        {
          args: ['A' * 10, 80],
          expected: "buf DB 41h,41h,41h,41h,41h,41h,41h,41h,41h,41h\n"
        },
        {
          args: ['A' * 10, 30],
          expected: "buf DB 41h,41h,41h,41h,41h\n    DB 41h,41h,41h,41h,41h\n"
        },
        {
          args: [(0..24).to_a.pack("C*"), 50],
          expected: "buf DB 00h,01h,02h,03h,04h,05h,06h,07h,08h,09h\n    DB 0ah,0bh,0ch,0dh,0eh,0fh,10h,11h,12h,13h\n    DB 14h,15h,16h,17h,18h\n"
        },
        {
          args: [('A'..'Z').to_a.join, 50],
          expected: "buf DB 41h,42h,43h,44h,45h,46h,47h,48h,49h,4ah\n    DB 4bh,4ch,4dh,4eh,4fh,50h,51h,52h,53h,54h\n    DB 55h,56h,57h,58h,59h,5ah\n"
        }
      ].each do |test|
        it "formats #{test} as expected" do
          output = described_class.to_masm(*test[:args])
          expect(output).to eq(test[:expected])
        end
      end
    end

    it "nim is as expected" do
      output = described_class.to_nim('A' * 10, 30)
      expect(output).to eq(expected_nim)
    end

    it "rust is as expected" do
      output = described_class.to_rust('A' * 10, 30)
      expect(output).to eq(expected_rust)
    end

    it "perl is as expected" do
      output = described_class.to_perl('A' * 10, 30)
      expect(output).to eq(expected_perl)
    end

    it "python is as expected" do
      output = described_class.to_python('A' * 10, 30)
      expect(output).to eq(expected_python)
    end

    it "ruby is as expected" do
      output = described_class.to_ruby('A' * 10, 30)
      expect(output).to eq(expected_ruby)
    end

    it "zig is as expected" do
      output = described_class.to_zig('A' * 10, 30)
      expect(output).to eq(expected_zig)
    end
  end


  context "to language methods should wrap at the specified columns" do
    LANGUAGES.each do |lang|
      describe ".to_#{lang}" do
        it "should wrap to 60" do
          wrap = 60
          lines = described_class.send("to_#{lang}", "A" * 100, wrap).split("\n")
          expect(lines).to all(have_maximum_width(wrap))
        end
      end
    end

    LANGUAGES.each do |lang|
      describe ".to_#{lang}" do
        it "should wrap to the provided random value" do
          wrap = rand(100)+40
          lines = described_class.send("to_#{lang}", "A" * 1000, wrap).split("\n")
          expect(lines).to all(have_maximum_width(wrap))
        end
      end
    end
  end

  context "to language methods should complete almost instantaneously" do
    LANGUAGES.each do |lang|
      describe ".to_#{lang}" do
        it "should not time out" do
          wrap = 60
          Timeout::timeout(5) do
            described_class.send("to_#{lang}", "A" * 100000, wrap)
          end
        end
      end
    end
  end
end
