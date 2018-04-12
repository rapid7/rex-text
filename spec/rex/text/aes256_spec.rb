require 'spec_helper'
require 'securerandom'
require 'openssl'


describe Rex::Text do

    let(:iv) {
      SecureRandom.random_bytes(16)
    }

    let(:key) {
      SecureRandom.random_bytes(32)
    }

    let(:value) {
      'Hello World'
    }

  describe '#encrypt_aes256' do
    it 'raises a CipherError exception due to a short IV' do
      iv = SecureRandom.random_bytes(1)
      expect { Rex::Text.encrypt_aes256(iv, key, value) }.to raise_error(OpenSSL::Cipher::CipherError)
    end

    it 'raises a CipherError exception due to a short key' do
      key = SecureRandom.random_bytes(1)
      expect { Rex::Text.encrypt_aes256(iv, key, value) }.to raise_error(OpenSSL::Cipher::CipherError)
    end

    it 'encrypts the string Hello World' do
      encrypted_str = Rex::Text.encrypt_aes256(iv, key, value)
      expect(encrypted_str).not_to eq(value)
    end
  end

  describe '#decrypt_aes256' do
    it 'raises a CipherError exception due to a short IV' do
      iv = SecureRandom.random_bytes(1)
      expect { Rex::Text.decrypt_aes256(iv, key, value) }.to raise_error(OpenSSL::Cipher::CipherError)
    end

    it 'raises a CipherError exception due to a short key' do
      key = SecureRandom.random_bytes(1)
      expect { Rex::Text.decrypt_aes256(iv, key, value) }.to raise_error(OpenSSL::Cipher::CipherError)
    end

    it 'decrypts the value to Hello World' do
      encrypted_str = Rex::Text.encrypt_aes256(iv, key, value)
      decrypted_str = Rex::Text.decrypt_aes256(iv, key, encrypted_str)
      expect(decrypted_str).to eq(value)
    end
  end

end