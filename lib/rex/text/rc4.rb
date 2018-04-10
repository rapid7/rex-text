# -*- coding: binary -*-

module Rex
  module Text

    def self.encrypt_rc4(key, value)
      rc4 = RC4.new(key)
      rc4.encrypt(value)
    end

  end
end