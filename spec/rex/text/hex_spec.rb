# -*- coding: binary -*-
require 'spec_helper'

RSpec.describe Rex::Text do
  context "Class Hex methods" do
    context ".hexify" do
      let(:wrap) { 60 }
      it 'should wrap at the specified columns' do
        lines = described_class.hexify("A" * 100, wrap).split("\n")
        expect(lines.any? { |line| line.rstrip.length > wrap }).to be_falsey
      end

      it 'should wrap at the specified columns when a line start and end are specified' do
        lines = described_class.hexify("A" * 100, wrap, '"', '"').split("\n")
        expect(lines.any? { |line| line.rstrip.length > wrap }).to be_falsey
      end

      it 'should convert the buffer to hex' do
        expect(described_class.hexify(Random.bytes(8))).to match(/(\\x[a-fA-F0-9]{2}){8}/)
      end
    end
  end
end
