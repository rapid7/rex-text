require 'spec_helper'


describe Rex::Text do

  describe '#xor' do

    let(:hello_world_str) {
      'hello world'
    }

    let(:xor_hello_world_str) {
      "\x67\x6a\x63\x63\x60\x2f\x78\x60\x7d\x63\x6b"
    }

    it 'XORs with an integer type key' do
      xor_key = 0x0f
      expect(Rex::Text.xor(xor_key, hello_world_str)).to eq(xor_hello_world_str)
    end

    it 'XORs with a string type key' do
      xor_key = "0x0f"
      expect(Rex::Text.xor(xor_key, hello_world_str)).to eq(xor_hello_world_str)
    end

    it 'raises an ArgumentError due to an out of range key' do
      bad_key = 0x1024
      expect { Rex::Text.xor(bad_key, hello_world_str) }.to raise_error(ArgumentError)
    end

  end
end