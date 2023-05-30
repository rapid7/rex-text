require 'spec_helper'

describe Rex::Text do
  describe '.to_dword' do
    [
      { input: '', expected: "\r\n" },
      { input: 'a', expected: "0x00000061\r\n" },
      { input: 'ab', expected: "0x00006261\r\n" },
      { input: 'abc', expected: "0x00636261\r\n" },
      { input: 'abcd', expected: "0x64636261\r\n" },
      { input: 'abcde', expected: "0x64636261, 0x00000065\r\n" },
      { input: 'abcdef', expected: "0x64636261, 0x00006665\r\n" },
      { input: 'abcdefg', expected: "0x64636261, 0x00676665\r\n" },
      { input: 'abcdefgh', expected: "0x64636261, 0x68676665\r\n" },
      { input: 'abcdefghi', expected: "0x64636261, 0x68676665, 0x00000069\r\n" },
      { input: ('a'..'z').to_a.join, expected:  "0x64636261, 0x68676665, 0x6c6b6a69, 0x706f6e6d, 0x74737271, 0x78777675, 0x00007a79\r\n" },
      { input: "这是中文".force_encoding("UTF-8"), expected: "0xe699bfe8, 0xb8e4af98, 0x8796e6ad\r\n" }
    ].each do |test|
      it "returns the expected output when the input is #{test[:input]}" do
        expect(described_class.to_dword(test[:input])).to eq test[:expected]
      end
    end
  end
end
