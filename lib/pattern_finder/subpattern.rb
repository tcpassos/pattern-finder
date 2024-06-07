# frozen_string_literal: true

# Sub-pattern representation
class SubPattern
  attr_reader :evaluator, :name, :optional, :repeat, :allow_gaps, :gap_break_condition

  # Constructor
  # @param evaluator [Proc] The evaluator for the subpattern
  # @param options [Hash] The options for the subpattern
  def initialize(evaluator, options = {})
    raise ArgumentError, 'Evaluator must be a Proc' unless evaluator.is_a?(Proc)

    @evaluator = evaluator
    @name = options.fetch(:name, nil)
    @optional = options.fetch(:optional, false)
    @repeat = options.fetch(:repeat, false)
    @allow_gaps = options.fetch(:allow_gaps, nil)
    @gap_break_condition = options.fetch(:gap_break_condition, nil)
  end

  # Set options for the subpattern
  # @param options [Hash] The options to set
  def set_options(options = {})
    options.each_key do |key|
      instance_variable_set("@#{key}", options.fetch(key, instance_variable_get("@#{key}")))
    end
  end

  # Check if the subpattern matches a value
  # @param value [Object] The value to match
  # @param matched_so_far [Array] The values that have been matched so far
  # @param all_values [Array] All the values that are being matched
  # @param position [Integer] The current position in the values array
  # @return [Boolean] Whether the subpattern matches the value
  def match_evaluator?(value, matched_so_far = [], all_values = [], position = 0)
    args = Array.new([@evaluator.arity, 4].min) { |i| [value, matched_so_far, all_values, position][i] }
    @evaluator.call(*args)
  end

  # Check if the break condition is met
  # @param value [Object] The value to match
  # @param matched_so_far [Array] The values that have been matched so far
  # @param all_values [Array] All the values that are being matched
  # @param position [Integer] The current position in the values array
  # @return [Boolean] Whether the break condition is met
  def match_break_condition?(value, matched_so_far = [], all_values = [], position = 0)
    return true unless @allow_gaps
    return false unless @gap_break_condition

    args = Array.new([@gap_break_condition.arity, 4].min) { |i| [value, matched_so_far, all_values, position][i] }
    @gap_break_condition.call(*args)
  end
end
