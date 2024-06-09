# frozen_string_literal: true

require 'forwardable'
require_relative 'pattern_match'
require_relative 'pattern_matcher'
require_relative 'subpattern_factory'

# Represents a pattern to match against a list of values
class Pattern
  include SubPatternFactory
  include PatternMatcher
  private :find_match
  attr_reader :subpatterns, :global_options

  # Constructor
  # @param block [Proc] The block to evaluate
  def initialize(&block)
    @global_options = {}
    @subpatterns = []
    @subpattern_map = {}
    @last_mandatory_index = 0
    instance_eval(&block) if block
  end

  # Get a subpattern by index or name
  # @param identifier [Integer, Symbol] The index or name of the subpattern
  # @return [SubPattern, nil] The subpattern or nil if not found
  def [](identifier)
    case identifier
    when Integer
      subpatterns[identifier]
    when Symbol
      @subpattern_map[identifier]
    end
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
                              identifiers.map do |id|
                                id.is_a?(Symbol) ? subpatterns.find { |sp| sp.name == id } : subpatterns[id]
                              end
                            end
    subpatterns_to_update.compact.each { |subpattern| subpattern.set_options(options) }
  end

  # Set global options for the pattern within a block
  # @param options [Hash] The options to set globally
  # @param block [Proc] The block to evaluate
  def with_options(options = {}, &block)
    raise ArgumentError, 'Block must be given to set options' unless block

    previous_options = @global_options.dup
    set_options(options)
    instance_eval(&block)
    @global_options = previous_options
  end

  # Add a subpattern to the pattern
  # @param subpattern [SubPattern] The subpattern to add
  def add_subpattern(subpattern)
    subpattern.set_options(@global_options)
    @subpatterns << subpattern
    if subpattern.name
      raise ArgumentError, "Subpattern name '#{subpattern.name}' is already in use" if @subpattern_map[subpattern.name]

      @subpattern_map[subpattern.name] = subpattern
    end
    @last_mandatory_index = @subpatterns.size - 1 unless subpattern.optional
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
    return unless @subpatterns.any?

    # Initialize the queue and the match object
    queue = Queue.new
    queue << { subpattern_pos: 0, value_pos: 0, matched: [[]], matched_flat: [], previous_self: true }
    match = { next_pos: 0 }

    # Process all states in the queue
    until queue.empty?
      state = queue.pop
      find_match(state, queue, values, match)
    end

    # Return the matched elements and the next position if a valid match is found
    return [PatternMatch.new(match[:matched], @subpatterns.map(&:name)), match[:next_pos]] unless match[:next_pos].zero?

    # If all subpatterns are optional, return an empty match
    if @subpatterns.all?(&:optional)
      empty_match = Array.new(@subpatterns.size) { [] }
      return [PatternMatch.new(empty_match, @subpatterns.map(&:name)), 0]
    end

    # Return nil if no complete and valid match is found
    nil
  end

  # Check if the pattern matches a list of values
  # @param values [Array] The values to match against
  # @return [Boolean] Whether the pattern matches the values
  def match?(values)
    !match(values).nil?
  end
end
