# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rex/text/version'

Gem::Specification.new do |spec|
  spec.name          = "rex-text"
  spec.version       = Rex::Text::VERSION
  spec.authors       = ['Metasploit Hackers']
  spec.email         = ['msfdev@metasploit.com']

  spec.summary       = %q{Provides Text Manipulation Methods for Exploitation}
  spec.description   = %q{This Gem contains all of the Ruby Exploitation(Rex) methods for text manipulation and generation}
  spec.homepage      = "https://github.com/rapid7/rex-text"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.4.0'

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"

  # bigdecimal is not part of the default gems starting from Ruby 3.4.0: https://www.ruby-lang.org/en/news/2023/12/25/ruby-3-3-0-released/
  spec.add_runtime_dependency 'bigdecimal'
end
