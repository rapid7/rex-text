# -*- coding: binary -*-

module Rex
  module Text

    def self.xor(key, value)
      if key.length != 1
        raise RuntimeError, 'The key for XOR should be one byte'
      end

      buf = ''

      value.each do |byte|
        buf << byte ^ key
      end

      buf
    end

  end
end