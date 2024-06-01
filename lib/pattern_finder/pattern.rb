# frozen_string_literal: true

require 'forwardable'
require_relative 'subpattern'
require_relative 'subpattern_factory'

# Represents a pattern to match against a list of values
class Pattern
  include SubPatternFactory
  attr_reader :root

  # Constructor
  # @param [Proc] block The block to evaluate
  def initialize(&block)
    instance_eval(&block) if block
  end

  # Add a subpattern to the pattern with a custom evaluator
  # @param [Proc] evaluator The evaluator to test the subpattern
  # @param [Boolean] optional Whether the subpattern is optional
  # @param [Boolean] repeat Whether the subpattern can be repeated
  # @param [Boolean] capture Whether the subpattern should be captured in the match results
  def add_subpattern_from_evaluator(evaluator, optional: false, repeat: false, capture: true)
    raise ArgumentError, 'Evaluator must be a Proc' unless evaluator.is_a?(Proc)

    subpattern = SubPattern.new(evaluator, optional: optional, repeat: repeat, capture: capture)
    add_subpattern(subpattern)
  end

  # Add a subpattern to the pattern
  # @param [SubPattern] subpattern The subpattern to add
  def add_subpattern(subpattern)
    raise ArgumentError, 'Subpattern must be a SubPattern instance' unless subpattern.is_a?(SubPattern)

    if @root
      @root.push_node(SubPatternNode.new(subpattern))
    else
      @root = SubPatternNode.new(subpattern)
    end
  end

  # Match the pattern against a list of values
  # @param [Array] values The values to match against
  # @return [Array, nil] The matched elements or nil if the pattern doesn't match
  def match(values)
    match_next_position(values)&.first
  end

  # Matches the pattern against the values and returns the matched elements and the final position.
  # @param [Array] values The values to match against
  # @return [[Array, Integer], nil] The matched elements and the next position, or nil if no match
  def match_next_position(values)
    raise ArgumentError, 'Values must be an array' unless values.is_a?(Array)
    return unless @root

    matched_elements, next_position = @root.match(values)
    [PatternMatch.new(matched_elements), next_position] if matched_elements
  end

  # Check if the pattern matches a list of values
  # @param [Array] values The values to match against
  # @return [Boolean] Whether the pattern matches the values
  def match?(values)
    !match(values).nil?
  end

  # Get the subpatterns of the pattern
  # @return [Array<SubPattern>] The subpatterns of the pattern
  def subpatterns
    @root&.subpatterns || []
  end
end

# Pattern match
class PatternMatch
  extend Forwardable
  include Enumerable
  attr_reader :matched, :matched_flattened

  def_delegators :@matched, :[]
  def_delegators :@matched_flattened, :each, :first, :last

  # Constructor
  # @param matched [Array] List of matched values
  def initialize(matched)
    @matched = matched
    @matched_flattened = matched.flatten
  end

  # Convert the matched values to a string
  def to_s
    @matched.inspect
  end
end
