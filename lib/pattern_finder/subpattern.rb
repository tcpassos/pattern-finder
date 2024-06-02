# frozen_string_literal: true

# Sub-pattern representation
class SubPattern
  attr_reader :evaluator, :optional, :repeat, :capture, :matched_cache

  # Constructor
  # @param [Proc] evaluator The evaluator for the subpattern
  # @param [Boolean] optional Whether the subpattern is optional
  # @param [Boolean] repeat Whether the subpattern can repeat
  # @param [Boolean] capture Whether the subpattern should be captured in the match results
  def initialize(evaluator, optional: false, repeat: false, capture: true)
    raise ArgumentError, 'Evaluator must be a Proc' unless evaluator.is_a?(Proc)

    @evaluator = evaluator
    @optional = optional
    @repeat = repeat
    @capture = capture
    @matched_cache = {}
  end

  # Check if the subpattern matches a value
  # @param [Object] value The value to match
  # @param [Array] matched_so_far The values that have been matched so far
  # @param [Array] all_values All the values that are being matched
  # @param [Integer] position The current position in the values array
  # @return [Boolean] Whether the subpattern matches the value
  def match?(value, matched_so_far = [], all_values = [], position = 0)
    key = [value, matched_so_far, position].hash
    return @matched_cache[key] if @matched_cache.key?(key)

    args = [@evaluator.arity, 4].min.times.map { |i| [value, matched_so_far, all_values, position][i] }
    match = @evaluator.call(*args)
    @matched_cache[key] = match
    match
  end
end
