# frozen_string_literal: true

require 'forwardable'
require_relative 'subpattern'
require_relative 'subpattern_factory'

# Represents a pattern to match against a list of values
class Pattern
  include SubPatternFactory
  attr_reader :root, :global_options

  # Constructor
  # @param [Proc] block The block to evaluate
  def initialize(&block)
    @global_options = {}
    instance_eval(&block) if block
  end

  # Set global options for the pattern
  # @param [Hash] options The options to set globally
  def set_options(options = {})
    @global_options.merge!(options)
    self
  end

  # Begin a block with a new set of options
  # @param [Hash] options The options to set for the block
  # @param [Proc] block The block to evaluate
  def begin_block(options = {}, &block)
    previous_options = @global_options.dup
    set_options(options)
    instance_eval(&block)
    @global_options = previous_options
  end

  # Add a node to the pattern
  # @param [SubPattern] node The node to add
  def add_node(node)
    node.set_options(@global_options)
    if @root
      @root.push_node(node)
    else
      @root = node
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
