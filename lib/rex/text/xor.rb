# -*- coding: binary -*-

module Rex::Text
  # XOR a string against a variable-length key
  #
  # @param key [String] XOR key
  # @param value [String] String to XOR
  # @return [String] XOR'd string
  def self.xor(key, value)
    unless key && value
      raise ArgumentError, 'XOR key and value must be supplied'
    end

    xor_key =
      case key
      when String
        if key.empty?
          raise ArgumentError, 'XOR key must not be empty'
        end

        key
      when Integer
        unless key.between?(0x00, 0xff)
          raise ArgumentError, 'XOR key must be between 0x00 and 0xff'
        end

        # Convert integer to string
        [key].pack('C')
      end

    # Get byte arrays for key and value
    xor_key   = xor_key.bytes
    xor_value = value.bytes

    # XOR value against cycled key
    xor_value.zip(xor_key.cycle).map { |v, k| v ^ k }.pack('C*')
  end
end
