# -*- coding: binary -*-
module Rex
  module Text
    # We are re-opening the module to add these module methods.
    # Breaking them up this way allows us to maintain a little higher
    # degree of organisation and make it easier to find what you're looking for
    # without hanging the underlying calls that we historically rely upon.


    TLDs = ['com', 'net', 'org', 'gov', 'biz', 'edu']
    States = ["AK", "AL", "AR", "AZ", "CA", "CO", "CT", "DE", "FL", "GA", "HI",
              "IA", "ID", "IL", "IN", "KS", "KY", "LA", "MA", "MD", "ME", "MI", "MN",
              "MO", "MS", "MT", "NC", "ND", "NE", "NH", "NJ", "NM", "NV", "NY", "OH",
              "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VA", "VT", "WA",
              "WI", "WV", "WY"]
    #
    # Most 100 common surnames, male/female names in the U.S. (http://names.mongabay.com/)
    #

    Surnames = [
      "adams", "alexander", "allen", "anderson", "bailey", "baker", "barnes",
      "bell", "bennett", "brooks", "brown", "bryant", "butler", "campbell",
      "carter", "clark", "coleman", "collins", "cook", "cooper", "cox",
      "davis", "diaz", "edwards", "evans", "flores", "foster", "garcia",
      "gonzales", "gonzalez", "gray", "green", "griffin", "hall", "harris",
      "hayes", "henderson", "hernandez", "hill", "howard", "hughes", "jackson",
      "james", "jenkins", "johnson", "jones", "kelly", "king", "lee", "lewis",
      "long", "lopez", "martin", "martinez", "miller", "mitchell", "moore",
      "morgan", "morris", "murphy", "nelson", "parker", "patterson", "perez",
      "perry", "peterson", "phillips", "powell", "price", "ramirez", "reed",
      "richardson", "rivera", "roberts", "robinson", "rodriguez", "rogers",
      "ross", "russell", "sanchez", "sanders", "scott", "simmons", "smith",
      "stewart", "taylor", "thomas", "thompson", "torres", "turner", "walker",
      "ward", "washington", "watson", "white", "williams", "wilson", "wood",
      "wright", "young"
    ]

    Names_Male = [
      "aaron", "adam", "alan", "albert", "andrew", "anthony", "antonio",
      "arthur", "benjamin", "billy", "bobby", "brandon", "brian", "bruce",
      "carl", "carlos", "charles", "chris", "christopher", "clarence", "craig",
      "daniel", "david", "dennis", "donald", "douglas", "earl", "edward",
      "eric", "ernest", "eugene", "frank", "fred", "gary", "george", "gerald",
      "gregory", "harold", "harry", "henry", "howard", "jack", "james", "jason",
      "jeffrey", "jeremy", "jerry", "jesse", "jimmy", "joe", "john", "johnny",
      "jonathan", "jose", "joseph", "joshua", "juan", "justin", "keith",
      "kenneth", "kevin", "larry", "lawrence", "louis", "mark", "martin",
      "matthew", "michael", "nicholas", "patrick", "paul", "peter", "philip",
      "phillip", "ralph", "randy", "raymond", "richard", "robert", "roger",
      "ronald", "roy", "russell", "ryan", "samuel", "scott", "sean", "shawn",
      "stephen", "steve", "steven", "terry", "thomas", "timothy", "todd",
      "victor", "walter", "wayne", "william", "willie"
    ]

    Names_Female = [
      "alice", "amanda", "amy", "andrea", "angela", "ann", "anna", "anne",
      "annie", "ashley", "barbara", "betty", "beverly", "bonnie", "brenda",
      "carol", "carolyn", "catherine", "cheryl", "christina", "christine",
      "cynthia", "deborah", "debra", "denise", "diana", "diane", "donna",
      "doris", "dorothy", "elizabeth", "emily", "evelyn", "frances", "gloria",
      "heather", "helen", "irene", "jacqueline", "jane", "janet", "janice",
      "jean", "jennifer", "jessica", "joan", "joyce", "judith", "judy", "julia",
      "julie", "karen", "katherine", "kathleen", "kathryn", "kathy", "kelly",
      "kimberly", "laura", "lillian", "linda", "lisa", "lois", "lori", "louise",
      "margaret", "maria", "marie", "marilyn", "martha", "mary", "melissa",
      "michelle", "mildred", "nancy", "nicole", "norma", "pamela", "patricia",
      "paula", "phyllis", "rachel", "rebecca", "robin", "rose", "ruby", "ruth",
      "sandra", "sara", "sarah", "sharon", "shirley", "stephanie", "susan",
      "tammy", "teresa", "theresa", "tina", "virginia", "wanda"
    ]


    # Generates a random character.
    def self.rand_char(bad, chars = AllChars)
      rand_text(1, bad, chars)
    end

    # Base text generator method
    def self.rand_base(len, bad, *foo)
      cset = (foo.join.unpack("C*") - bad.to_s.unpack("C*")).uniq
      return "" if cset.length == 0
      outp = []
      len.times { outp << cset[rand(cset.length)] }
      outp.pack("C*")
    end

    # Generate random bytes of data
    def self.rand_text(len, bad='', chars = AllChars)
      foo = chars.split('')
      rand_base(len, bad, *foo)
    end

    # Generate random bytes of alpha data
    def self.rand_text_alpha(len, bad='')
      foo = []
      foo += ('A' .. 'Z').to_a
      foo += ('a' .. 'z').to_a
      rand_base(len, bad, *foo )
    end

    # Generate random bytes of lowercase alpha data
    def self.rand_text_alpha_lower(len, bad='')
      rand_base(len, bad, *('a' .. 'z').to_a)
    end

    # Generate random bytes of uppercase alpha data
    def self.rand_text_alpha_upper(len, bad='')
      rand_base(len, bad, *('A' .. 'Z').to_a)
    end

    # Generate random bytes of alphanumeric data
    def self.rand_text_alphanumeric(len, bad='')
      foo = []
      foo += ('A' .. 'Z').to_a
      foo += ('a' .. 'z').to_a
      foo += ('0' .. '9').to_a
      rand_base(len, bad, *foo )
    end

    # Generate random bytes of alphanumeric hex.
    def self.rand_text_hex(len, bad='')
      foo = []
      foo += ('0' .. '9').to_a
      foo += ('a' .. 'f').to_a
      rand_base(len, bad, *foo)
    end

    # Generate random bytes of numeric data
    def self.rand_text_numeric(len, bad='')
      foo = ('0' .. '9').to_a
      rand_base(len, bad, *foo )
    end

    # Generate random bytes of english-like data
    def self.rand_text_english(len, bad='')
      foo = []
      foo += (0x21 .. 0x7e).map{ |c| c.chr }
      rand_base(len, bad, *foo )
    end

    # Generate random bytes of high ascii data
    def self.rand_text_highascii(len, bad='')
      foo = []
      foo += (0x80 .. 0xff).map{ |c| c.chr }
      rand_base(len, bad, *foo )
    end

    # Generate random bytes of base64 data
    def self.rand_text_base64(len, bad='')
      foo = Base64.unpack('C*').map{ |c| c.chr }
      rand_base(len, bad, *foo )
    end

    # Generate random bytes of base64url data
    def self.rand_text_base64url(len, bad='')
      foo = Base64Url.unpack('C*').map{ |c| c.chr }
      rand_base(len, bad, *foo )
    end

    # Generate a random GUID
    #
    # @example
    #   Rex::Text.rand_guid # => "{ca776ced-4ab8-2ed6-6510-aa71e5e2508e}"
    #
    # @return [String]
    def self.rand_guid
      "{#{[8,4,4,4,12].map {|a| rand_text_hex(a) }.join("-")}}"
    end

    #
    # Generate a valid random 4 byte UTF-8 character
    # valid codepoints for 4byte UTF-8 chars: U+010000 - U+10FFFF
    #
    # @example
    #   Rex::Text.rand_4byte_utf8 # => "\u{108CF3}"
    #
    # @return [String]
    def self.rand_4byte_utf8
      [rand(0x10000..0x10ffff)].pack('U*')
    end

    # Generate a random hostname
    #
    # @return [String] A random string conforming to the rules of FQDNs
    def self.rand_hostname
      host = []
      (rand(5) + 1).times {
        host.push(Rex::Text.rand_text_alphanumeric(rand(10) + 1))
      }
      host.push(TLDs.sample)
      host.join('.').downcase
    end

    # Generate a state
    def self.rand_state()
      States.sample
    end

    # Generate a surname
    def self.rand_surname
      Surnames.sample
    end

    # Generate a name
    def self.rand_name
      if rand(10) % 2 == 0
        Names_Male.sample
      else
        Names_Female.sample
      end
    end

    # Generate a male name
    def self.rand_name_male
      Names_Male.sample
    end

    # Generate a female name
    def self.rand_name_female
      Names_Female.sample
    end

    # Generate a random mail address
    def self.rand_mail_address
      mail_address = ''
      mail_address << Rex::Text.rand_name
      mail_address << '.'
      mail_address << Rex::Text.rand_surname
      mail_address << '@'
      mail_address << Rex::Text.rand_hostname
    end
  end
end