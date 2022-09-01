RSpec::Matchers.define :have_maximum_width do |expected|
  match do |actual|
    actual.length <= expected
  end

  failure_message do |actual|
    "expected '#{actual}' to have a length than or equal to #{expected}, instead got #{actual.length}"
  end
end
