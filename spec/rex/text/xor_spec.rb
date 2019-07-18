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

    it 'XORs with a variable-length key' do
      xor_key = "\x00\x00\x00\x00\x00\x0c"
      expect(Rex::Text.xor(xor_key, hello_world_str)).to eq('hello,world')
    end

    it 'XORs with itself' do
      xor_key = hello_world_str
      expect(Rex::Text.xor(xor_key, hello_world_str)).to eq("\x00" * hello_world_str.length)
    end

    it 'raises an ArgumentError due to a nil key' do
      bad_key = nil
      expect { Rex::Text.xor(bad_key, hello_world_str) }.to raise_error(ArgumentError)
    end

    it 'raises an ArgumentError due to an empty key' do
      bad_key = ''
      expect { Rex::Text.xor(bad_key, hello_world_str) }.to raise_error(ArgumentError)
    end

    it 'raises an ArgumentError due to an out of range key' do
      bad_key = 0x1024
      expect { Rex::Text.xor(bad_key, hello_world_str) }.to raise_error(ArgumentError)
    end

  end
end
