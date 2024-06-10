# frozen_string_literal: true

require_relative 'pattern_finder/subpattern'
require_relative 'pattern_finder/subpattern_factory'
require_relative 'pattern_finder/pattern'
require_relative 'pattern_finder/pattern_match'
require_relative 'pattern_finder/pattern_scanner'

class Array
  include PatternScannerMethods
end
