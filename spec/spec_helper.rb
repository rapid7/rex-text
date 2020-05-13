$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'rex/text'

RSpec.configure do |config|
  if ENV['CI']
    config.before(:example, :focus) { raise "Should not commit focused specs" }
  else
    config.filter_run focus: true
    config.run_all_when_everything_filtered = true
  end
end
