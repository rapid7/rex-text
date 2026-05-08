# -*- coding: binary -*-
require 'spec_helper'
require 'timeout'

RSpec.describe Rex::Text do
  describe ".to_hex_cstring" do
    it 'should return just a null terminator for an empty string' do
      expect(described_class.to_hex_cstring("")).to eq("0x00")
    end

    it 'should return hex bytes with a null terminator for a non-empty string' do
      expect(described_class.to_hex_cstring("AB")).to eq("0x41, 0x42, 0x00")
    end

    it 'should handle nil by treating it as an empty string' do
      expect(described_class.to_hex_cstring(nil)).to eq("0x00")
    end

    it 'should handle binary data' do
      expect(described_class.to_hex_cstring("\xff\x00\x01")).to eq("0xff, 0x00, 0x01, 0x00")
    end

    context 'with nullbyte: false' do
      it 'should return an empty string for an empty input' do
        expect(described_class.to_hex_cstring("", nullbyte: false)).to eq("")
      end

      it 'should return hex bytes without a null terminator' do
        expect(described_class.to_hex_cstring("AB", nullbyte: false)).to eq("0x41, 0x42")
      end
    end
  end

  describe ".hexify" do
    let(:wrap) { 60 }
    it 'should wrap at the specified columns' do
      lines = described_class.hexify("A" * 100, wrap).split("\n")
      expect(lines.any? { |line| line.rstrip.length > wrap }).to be_falsey
    end

    it 'should wrap at the specified columns when a line start and end are specified' do
      lines = described_class.hexify("A" * 100, wrap, '"', '"').split("\n")
      expect(lines).to all(have_maximum_width(wrap))
    end

    it 'should convert the buffer to hex' do
      expect(described_class.hexify(Random.bytes(8))).to match(/(\\x[a-fA-F0-9]{2}){8}/)
    end

    it 'should finish instantaneously' do
      Timeout::timeout(5) do
        described_class.hexify(Random.bytes(800000))
      end
    end
  end
end
