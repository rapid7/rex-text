$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rex/text'

Dir['./spec/support/**/*.rb'].each do |f|
  require f.sub(%r{\./spec/}, '')
end

RSpec.configure do |config|
  if ENV['CI']
    config.before(:example, :focus) { raise "Should not commit focused specs" }
  else
    config.filter_run focus: true
    config.run_all_when_everything_filtered = true
  end

  config.raise_on_warning = true
end
