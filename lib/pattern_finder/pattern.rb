# frozen_string_literal: true

require 'forwardable'
require_relative 'subpattern'
require_relative 'subpattern_factory'

# Represents a pattern to match against a list of values
class Pattern
  include SubPatternFactory
  attr_reader :root, :global_options

  # Constructor
  # @param block [Proc] The block to evaluate
  def initialize(&block)
    @global_options = {}
    instance_eval(&block) if block
  end

  # Get a subpattern by index or name
  # @param identifier [Integer, Symbol] The index or name of the subpattern
  # @return [SubPattern, nil] The subpattern or nil if not found
  def [](identifier)
    index = case identifier
            when Integer
              identifier
            when Symbol
              subpatterns.find_index { |sp| sp.name == identifier }
            end
    subpatterns[index] if index
  end

  # Set global options for the pattern
  # @param options [Hash] The options to set globally
  # @return [Pattern] The pattern
  def set_options(options = {})
    @global_options.merge!(options)
    self
  end

  # Set options for specific subpatterns
  # @param identifiers [Array<Integer, Symbol>, Range] The identifiers of the subpatterns to set the options
  # @param options [Hash] The options to set
  def set_options_for(identifiers, options)
    subpatterns_to_update = case identifiers
                            when Range
                              subpatterns[identifiers]
                            when Array
                              if identifiers.first.is_a?(Symbol)
                                identifiers.map { |name| subpatterns.find { |sp| sp.name == name } }
                              else
                                subpatterns.values_at(*identifiers)
                              end
                            end
    subpatterns_to_update.compact.each { |subpattern| subpattern.set_options(options) }
  end

  # Set global options for the pattern within a block
  # @param options [Hash] The options to set globally
  # @param block [Proc] The block to evaluate
  def with_options(options = {}, &block)
    previous_options = @global_options.dup
    set_options(options)
    instance_eval(&block)
    @global_options = previous_options
  end

  # Add a node to the pattern
  # @param node [SubPattern] The node to add
  def add_node(node)
    node.set_options(@global_options)
    if @root
      @root.push_node(node)
    else
      @root = node
    end
  end

  # Match the pattern against a list of values
  # @param values [Array] The values to match against
  # @return [Array, nil] The matched elements or nil if the pattern doesn't match
  def match(values)
    match_next_position(values)&.first
  end

  # Matches the pattern against the values and returns the matched elements and the final position.
  # @param values [Array] The values to match against
  # @return [[Array, Integer], nil] The matched elements and the next position, or nil if no match
  def match_next_position(values)
    raise ArgumentError, 'Values must be an array' unless values.is_a?(Array)
    return unless @root

    matched_elements, next_position = @root.match(values)
    [PatternMatch.new(matched_elements, @root.subpatterns.map(&:name)), next_position] if matched_elements
  end

  # Check if the pattern matches a list of values
  # @param values [Array] The values to match against
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

  def_delegators :@matched_flattened, :each, :first, :last

  # Constructor
  # @param matched [Array] List of matched values
  # @param group_names [Array] List of names for the matched values
  def initialize(matched, group_names = [])
    @matched = matched
    @matched_flattened = matched.flatten
    @name_indices = {}
    group_names.each_with_index { |name, index| @name_indices[name] = index if name }
  end

  # Get the matched value by index or group name
  # @param index [Integer, Symbol] The index or group name
  # @return [Object, nil] The matched value or nil if not found
  def [](index)
    index = @name_indices[index] if index.is_a?(Symbol)
    @matched[index]
  end

  # Convert the matched values to a string
  def to_s
    @matched.inspect
  end
end
