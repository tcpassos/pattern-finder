# frozen_string_literal: true

require_relative 'pattern_finder/subpattern'
require_relative 'pattern_finder/subpattern_factory'
require_relative 'pattern_finder/pattern'
require_relative 'pattern_finder/scanner'

p1 = Pattern.new
p1.value_eq(1)
p1.root.instance_variable_set(:@allow_gaps, true)
p1.value_eq(4)

puts p1.match([1, 2, 3, 4]).inspect