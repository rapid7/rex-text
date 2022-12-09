# -*- coding: binary -*-
require 'spec_helper'
require 'timeout'

RSpec.describe Rex::Text do

  LANGUAGES = %w[ bash c csharp golang nim rust perl python ruby ]

  context "to language methods should wrap at the specified columns" do
    LANGUAGES.each do |lang|
      describe ".to_#{lang}" do
        it "should raise on non-convertable characters" do
          wrap = 60
          lines = described_class.send("to_#{lang}", "A" * 100, wrap).split("\n")
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
