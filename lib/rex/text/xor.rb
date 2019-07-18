# -*- coding: binary -*-

module Rex::Text
  # XOR a string against a variable-length key
  #
  # @param key [String] XOR key
  # @param value [String] String to XOR
  # @return [String] XOR'd string
  def self.xor(key, value)
    # Check for nil
    unless key && value
      raise ArgumentError, 'XOR key and value must be supplied'
    end

    xor_key =
      begin
        # Support integer strings
        Integer(key)
      rescue ArgumentError
        key
      end

    if xor_key.is_a?(Integer)
      unless xor_key.between?(0, 255)
        raise ArgumentError, 'XOR key must be between 0x00 and 0xff'
      end

      # Convert integer to string
      xor_key = [xor_key].pack('C')
    end

    # Check for empty strings
    if xor_key.empty? || value.empty?
      raise ArgumentError, 'XOR key and value must not be empty'
    end

    # Get byte arrays for key and value
    xor_key   = xor_key.bytes
    xor_value = value.bytes

    # XOR value against cycled key
    xor_value.zip(xor_key.cycle).map { |v, k| v ^ k }.pack('C*')
  end
end
