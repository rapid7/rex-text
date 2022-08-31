# -*- coding: binary -*-
require 'spec_helper'

RSpec.describe Rex::Text do
  context "Class Language methods" do

    LANGUAGES = %w[ bash c csharp golang perl python ruby ]

    context "to language methods should wrap at the specified columns" do
      LANGUAGES.each do |lang|
        context ".to_#{lang}" do
          it "should raise on non-convertable characters" do
            wrap = 60
            lines = described_class.send("to_#{lang}", "A" * 100, wrap).split("\n")
            expect(lines.any? { |line| line.rstrip.length > wrap }).to be_falsey
          end
        end
      end
    end
  end
end
