# -*- coding: binary -*-
require 'spec_helper'
require 'timeout'

RSpec.describe Rex::Text do

  LANGUAGES = %w[ bash c csharp golang masm nim rust perl python ruby ]

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
