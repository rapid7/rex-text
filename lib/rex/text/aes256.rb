# -*- coding: binary -*-

module Rex
  module Text

    def self.encrypt_aes256(iv, key, value)
      aes = OpenSSL::Cipher::AES256.new(:CBC)
      aes.encrypt
      aes.iv = iv
      aes.key = key
      aes.update(value) + aes.final
    end

    def self.decrypt_aes256(iv, key, value)
      aes = OpenSSL::Cipher::AES256.new(:CBC)
      aes.decrypt
      aes.iv = iv
      aes.key = key
      aes.update(value) + aes.final
    end

  end
end