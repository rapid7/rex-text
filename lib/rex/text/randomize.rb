# -*- coding: binary -*-
module Rex
  module Text
    # We are re-opening the module to add these module methods.
    # Breaking them up this way allows us to maintain a little higher
    # degree of organisation and make it easier to find what you're looking for
    # without hanging the underlying calls that we historically rely upon.

    #
    # Converts a string to random case
    #
    # @example
    #   Rex::Text.to_rand_case("asdf") # => "asDf"
    #
    # @param str [String] The string to randomize
    # @return [String]
    # @see permute_case
    # @see to_mixed_case_array
    def self.to_rand_case(str)
      buf = str.dup
      0.upto(str.length) do |i|
        buf[i,1] = rand(2) == 0 ? str[i,1].upcase : str[i,1].downcase
      end
      return buf
    end

    #
    # Takes a string, and returns an array of all mixed case versions.
    #
    # @example
    #   >> Rex::Text.to_mixed_case_array "abc1"
    #   => ["abc1", "abC1", "aBc1", "aBC1", "Abc1", "AbC1", "ABc1", "ABC1"]
    #
    # @param str [String] The string to randomize
    # @return [Array<String>]
    # @see permute_case
    def self.to_mixed_case_array(str)
      letters = []
      str.scan(/./).each { |l| letters << [l.downcase, l.upcase] }
      coords = []
      (1 << str.size).times { |i| coords << ("%0#{str.size}b" % i) }
      mixed = []
      coords.each do |coord|
        c = coord.scan(/./).map {|x| x.to_i}
        this_str = ""
        c.each_with_index { |d,i| this_str << letters[i][d] }
        mixed << this_str
      end
      return mixed.uniq
    end

    #
    # Randomize the whitespace in a string
    #
    def self.randomize_space(str)
      set = ["\x09", "\x20", "\x0d", "\x0a"]
      str.gsub(/\s+/) { |s|
        len = rand(50)+2
        buf = ''
        while (buf.length < len)
          buf << set.sample
        end

        buf
      }
    end

    #
    # Shuffles a byte stream
    #
    # @param str [String]
    # @return [String] The shuffled result
    # @see shuffle_a
    def self.shuffle_s(str)
      shuffle_a(str.unpack("C*")).pack("C*")
    end

    #
    # Performs a Fisher-Yates shuffle on an array
    #
    # Modifies +arr+ in place
    #
    # @param arr [Array] The array to be shuffled
    # @return [Array]
    def self.shuffle_a(arr)
      len = arr.length
      max = len - 1
      cyc = [* (0..max) ]
      for d in cyc
        e = rand(d+1)
        next if e == d
        f = arr[d];
        g = arr[e];
        arr[d] = g;
        arr[e] = f;
      end
      return arr
    end

    # Permute the case of a word
    def self.permute_case(word, idx=0)
      res = []

      if( (UpperAlpha+LowerAlpha).index(word[idx,1]))

        word_ucase = word.dup
        word_ucase[idx, 1] = word[idx, 1].upcase

        word_lcase = word.dup
        word_lcase[idx, 1] = word[idx, 1].downcase

        if (idx == word.length)
          return [word]
        else
          res << permute_case(word_ucase, idx+1)
          res << permute_case(word_lcase, idx+1)
        end
      else
        res << permute_case(word, idx+1)
      end

      res.flatten
    end
  end
end
