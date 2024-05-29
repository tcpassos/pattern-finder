# frozen_string_literal: true

require_relative 'default_subpatterns'
require_relative 'subpattern_node'

# Sub-pattern representation
class SubPattern
  extend DefaultSubPatterns
  attr_reader :evaluator, :optional, :repeat

  def initialize(evaluator, optional: false, repeat: false)
    @evaluator = evaluator
    @optional = optional
    @repeat = repeat
  end

  def match?(value, matched_so_far)
    @evaluator.arity == 1 ? @evaluator.call(value) : @evaluator.call(value, matched_so_far)
  end
end
