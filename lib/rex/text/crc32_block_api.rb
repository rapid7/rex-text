# -*- coding: binary -*-
require 'crc'

module Rex
    module Text
      # We are re-opening the module to add these module methods.
      # Breaking them up this way allows us to maintain a little higher
      # degree of organisation and make it easier to find what you're looking for
      # without hanging the underlying calls that we historically rely upon.
  
      #
      # Calculate the CRC32 block API checksum for the given module/function
      #
      # @param mod [String] The name of the module containing the target function.
      # @param fun [String] The name of the function.
      #
      # @return [String] The checksum of the mod/fun pair in string format
      def self.crc32_block_api_checksum(mod, func)
        crc32c = CRC.new(32, 0x11EDC6F41, initial_crc = 0, refin = true, refout = true, xor_output = 0)
        unicode_mod = (mod.upcase + "\x00").unpack('C*').pack('v*')
        "0x#{(crc32c[unicode_mod+func+"\x00"]).to_s(16)}"
      end
    end
  end
  