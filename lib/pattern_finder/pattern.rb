# frozen_string_literal: true

require 'forwardable'
require_relative 'subpattern'
require_relative 'subpattern_factory'

# Represents a pattern to match against a list of values
class Pattern
  include SubPatternFactory
  attr_reader :subpatterns, :global_options

  # Constructor
  # @param block [Proc] The block to evaluate
  def initialize(&block)
    @global_options = {}
    @subpatterns = []
    @subpattern_names = []
    @last_mandatory_index = 0
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

  # Add a subpattern to the pattern
  # @param subpattern [SubPattern] The subpattern to add
  def add_subpattern(subpattern)
    subpattern.set_options(@global_options)
    @subpatterns << subpattern
    @subpattern_names << subpattern.name
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

    # Find all possible matches
    all_matches = match_all(values)

    # Select the best complete match
    best_match = all_matches.lazy
                            .select { |match| match_complete?(match[:matched]) }
                            .max_by { |match| calculate_weight(match) }

    # If a complete and valid match is found, return it
    if best_match
      pattern_match = PatternMatch.new(best_match[:matched], @subpattern_names)
      return [pattern_match, best_match[:next_pos]]
    end

    # If all subpatterns are optional, return an empty match
    if @subpatterns.all?(&:optional)
      empty_match = Array.new(@subpatterns.size) { [] }
      return [PatternMatch.new(empty_match, @subpattern_names), 0]
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

  # ====================================================================================================================
  # Private methods
  # ====================================================================================================================
  private

  # (private) Match the specified values against the pattern
  # This method returns every possible match, even if it's invalid
  # @param values [Array] The values to match against
  # @param queue [Array] Array containing the subpatterns to match and their state
  # @param acc_matched [Array] The matched elements so far containing the matched elements and the next position
  # @return [Array] The matched elements and the next position
  def match_all(values, queue = Queue.new, acc_matched = [])
    # First state
    queue << ({ subpattern_pos: 0, value_pos: 0, matched: [[]], matched_flat: [],
                previous_self: nil, previous_matched: nil })

    # Process all states in the queue
    until queue.empty?
      state = queue.pop
      process_state(state, queue, values, acc_matched)
    end

    # Return the matched elements
    acc_matched
  end

  # (private) Process the current state of the pattern matching
  # @param state [Hash] The current state of the pattern matching
  # @param queue [Array] Array containing the subpatterns to match and their state
  # @param values [Array] The values to match against
  # @param acc_matched [Array] The matched elements so far containing the matched elements and the next position
  # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/MethodLength
  def process_state(state, queue, values, acc_matched)
    value_pos = state[:value_pos]

    # Skip the current subpattern if the position is out of bounds
    return if value_pos >= values.size

    # Get the current properties
    subpattern_pos = state[:subpattern_pos]
    subpattern = @subpatterns[subpattern_pos]
    value = values[value_pos]
    current_matched = state[:matched]
    current_matched_flat = state[:matched_flat]
    has_matched_subpattern = subpattern.match_evaluator?(value, current_matched_flat, values, value_pos)
    previous_self = state[:previous_self].nil? || state[:previous_self]
    previous_matched = state[:previous_matched]

    # If the current subpattern is optional, add an empty array to the current match and continue
    if subpattern.optional && !(previous_self && previous_matched) && subpattern_pos < @subpatterns.size - 1
      queue << {
        subpattern_pos: subpattern_pos + 1,
        value_pos: value_pos,
        matched: previous_self ? current_matched : current_matched + [[]],
        matched_flat: current_matched_flat,
        previous_self: false,
        previous_matched: false
      }
    end

    # ==================================
    # ADD the value to the current match
    # ==================================
    if has_matched_subpattern
      # Duplicate the last match to avoid modifying the previous one
      current_matched = current_matched.dup.tap { |cm| cm[-1] = cm.last.dup }
      previous_self ? current_matched.last << value : current_matched << [value]
    end

    # If the current subpattern is repeatable, add the current subpattern to match the next value
    if (has_matched_subpattern && subpattern.repeat) ||
       (!has_matched_subpattern && subpattern.allow_gaps &&
        !subpattern.match_break_condition?(value, current_matched_flat, values, value_pos))
      queue << {
        subpattern_pos: subpattern_pos,
        value_pos: value_pos + 1,
        matched: current_matched,
        matched_flat: Array.new(current_matched.size, value),
        previous_self: has_matched_subpattern && subpattern.repeat,
        previous_matched: true
      }
    end

    # Add the next subpattern to the queue to match the next value
    if has_matched_subpattern && subpattern_pos < @subpatterns.size - 1
      queue << {
        subpattern_pos: subpattern_pos + 1,
        value_pos: value_pos + 1,
        matched: current_matched,
        matched_flat: Array.new(current_matched.size, value),
        previous_self: false,
        previous_matched: true
      }
    end

    # To add the current match to the accumulator, the following conditions must be met:
    # - The current subpattern matches
    # - The current subpattern is the last one or the current value is the last one
    # - The current pattern don't have any mandatory subpatterns left
    return unless has_matched_subpattern
    return unless subpattern_pos < @subpatterns.size || value_pos == values.size - 1
    return if subpattern_pos < @last_mandatory_index

    # If the current subpattern is the last one, add empty arrays to the current match until the end of the pattern
    final_matched = current_matched + Array.new(@subpatterns.size - subpattern_pos - 1) { [] }

    # End of the pattern, add the current match to the accumulator
    acc_matched << { matched: final_matched, next_pos: value_pos + 1 }
  end
  # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/MethodLength

  # (private) Calculate the weight of a match
  # The weight is the sum of the sizes of the matched subarrays sorted in descending order
  # @param match [Hash] The match to calculate the weight for
  def calculate_weight(match)
    match[:matched].map(&:size).sum
  end

  # (private) Check if all elements matched
  # Validates for optional and repeatable subpatterns
  # @param matched_elements [Array] The matched elements
  # @return [Boolean] Whether all elements matched
  def match_complete?(matched_elements)
    return false if matched_elements.size != @subpatterns.size

    @subpatterns.zip(matched_elements).all? do |subpattern, matched|
      (subpattern.optional || matched&.any?) && (subpattern.repeat || matched&.size.to_i <= 1)
    end
  end
end

# =====================================================================================================================
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
