# -*- coding: binary -*-
require 'spec_helper'
require 'timeout'

RSpec.describe Rex::Text do
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
