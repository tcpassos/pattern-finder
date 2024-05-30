# frozen_string_literal: true

# Sub-pattern representation
class SubPattern
  attr_reader :evaluator, :optional, :repeat

  # Constructor
  # @param [Proc] evaluator The evaluator for the subpattern
  # @param [Boolean] optional Whether the subpattern is optional
  # @param [Boolean] repeat Whether the subpattern can repeat
  def initialize(evaluator, optional: false, repeat: false)
    @evaluator = evaluator
    @optional = optional
    @repeat = repeat
    @matched = {}
  end

  # Combine this subpattern with another using logical AND
  # @param [SubPattern] other The other subpattern to combine with
  # @return [SubPattern] A new subpattern that matches if both subpatterns match
  def and(other)
    raise ArgumentError, 'Other must be a SubPattern' unless other.is_a?(SubPattern)

    combined_evaluator = lambda do |value, *args|
      self_match = match?(value, *args)
      other_match = other.match?(value, *args)
      self_match && other_match
    end

    SubPattern.new(combined_evaluator, optional: optional && other.optional, repeat: repeat && other.repeat)
  end

  # Combine this subpattern with another using logical OR
  # @param [SubPattern] other The other subpattern to combine with
  # @return [SubPattern] A new subpattern that matches if either subpattern matches
  def or(other)
    raise ArgumentError, 'Other must be a SubPattern' unless other.is_a?(SubPattern)

    combined_evaluator = lambda do |value, *args|
      self_match = match?(value, *args)
      other_match = other.match?(value, *args)
      self_match || other_match
    end

    SubPattern.new(combined_evaluator, optional: optional || other.optional, repeat: repeat || other.repeat)
  end

  # Create a negative lookahead pattern
  def not
    negated_evaluator = lambda do |value, *args|
      !match?(value, *args)
    end

    SubPattern.new(negated_evaluator, optional: optional, repeat: repeat)
  end

  # Check if the subpattern matches a value
  # @param [Object] value The value to match
  # @param [Array] matched_so_far The values that have been matched so far
  # @return [Boolean] Whether the subpattern matches the value
  def match?(value, matched_so_far = [])
    key = [value, matched_so_far].hash
    return @matched[key] if @matched.key?(key)

    match = @evaluator.arity == 1 ? @evaluator.call(value) : @evaluator.call(value, matched_so_far)
    @matched[key] = match
    match
  end
end
