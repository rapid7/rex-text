# -*- coding: binary -*-

module Rex
  module Text

    def self.xor(key, value)
      buf = ''

      value.each_byte do |byte|
        xor_byte = byte ^ key
        xor_byte = [xor_byte].pack('c').first
        buf << xor_byte
      end

      buf
    end

  end
end