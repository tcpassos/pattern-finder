# frozen_string_literal: true

require_relative 'pattern_finder/subpattern'
require_relative 'pattern_finder/subpattern_factory'
require_relative 'pattern_finder/subpattern_node'
require_relative 'pattern_finder/pattern'
require_relative 'pattern_finder/scanner'

p = Pattern.new
p.value_eq(1, repeat: true, optional: true)
 .any(repeat: true)
 .value_eq(3)

v = [1, 1, 2, 3]

puts p.match(v).inspect
