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
    end
  end
end
