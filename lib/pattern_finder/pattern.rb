# frozen_string_literal: true

require 'forwardable'
require_relative 'subpattern'
require_relative 'subpattern_factory'

# Represents a pattern to match against a list of values
class Pattern
  include SubPatternFactory
  attr_reader :root, :subpatterns, :global_options

  # Constructor
  # @param block [Proc] The block to evaluate
  def initialize(&block)
    @global_options = {}
    @subpatterns = []
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
    @subpatterns.push(node)
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

    matched = match_all(values, [{ node: @root }])
    subpattern_names = @subpatterns.map(&:name)

    # Sort matches by the size of each subarray in descending order
    matched.sort_by! { |match| match[:matched].map { |subarray| -subarray.size } }

    matched.each do |match|
      next unless match_complete?(match[:matched])

      clean_match = remove_non_capture_groups(match[:matched])
      pattern_match = PatternMatch.new(clean_match, subpattern_names)
      return [pattern_match, match[:next_pos]]
    end

    return [PatternMatch.new(Array.new(@subpatterns.size) { [] }, subpattern_names), 0] if @subpatterns.all?(&:optional)

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
  # @param stack [Array] Array containing the nodes to match and their state
  # @param acc_matched [Array] The matched elements so far containing the matched elements and the next position
  # @return [Array] The matched elements and the next position
  def match_all(values, stack = [{}], acc_matched = [])
    until stack.empty?
      current_state = stack.shift
      current_node = current_state[:node] || @root
      last_node = current_state[:last_node] || current_node
      current_pos = current_state[:pos] || 0
      current_matched = current_state[:matched] || [[]]
      current_matched_flat = current_state[:matched_flat]&.dup || []
      next if current_pos >= values.size

      current_value = values[current_pos]
      has_matched_node = current_node.match_evaluator?(current_value, current_matched_flat, values, current_pos)

      # If the current node is optional, add the children to the pending list without advancing the position
      if current_node.optional
        stack += current_node.children.map do |child|
          {
            node: child,
            last_node: current_node,
            pos: current_pos,
            matched: current_node == last_node ? current_matched.map(&:dup) : current_matched.map(&:dup).push([]),
            matched_flat: current_matched_flat
          }
        end
      end

      # If the current node has matched, advance validating the children with the next position
      if has_matched_node
        current_matched = current_matched.map(&:dup)
        current_matched.last.push(current_value) if current_node == last_node
        current_matched.push([current_value]) unless current_node == last_node
        current_matched_flat.push(current_value)

        next_nodes = current_node.children.dup
        next_nodes.unshift(current_node) if current_node.repeat && current_pos < values.size - 1

        stack += next_nodes.map do |node|
          {
            node: node,
            last_node: current_node,
            pos: current_pos + 1,
            matched: current_matched,
            matched_flat: current_matched_flat
          }
        end
      end

      # If the current node has children, add empty arrays for each child
      if current_pos == values.size - 1 && !current_node.children.empty?
        current_matched += Array.new(count_child_levels(current_node)) { [] }
      end

      # End of the pattern, add the current match to the accumulator
      if current_pos == values.size - 1 || current_node.children.empty?
        next_pos = current_pos + (has_matched_node ? 1 : 0)
        acc_matched << { matched: current_matched, next_pos: next_pos } if has_matched_node || current_node.optional
      end
    end

    acc_matched
  end

  # (private) Count the levels of children
  # @param node [SubPattern] The node to count the levels
  # @return [Integer] The number of levels of children
  def count_child_levels(node)
    return 0 if node.children.empty?

    1 + count_child_levels(node.children.first)
  end

  # (private) Remove non-capture groups from the matched elements
  # @param matched [Array] The matched elements
  # @return [Array] The matched elements without non-capture groups
  def remove_non_capture_groups(matched)
    @subpatterns.zip(matched).each_with_object([]) do |(subpattern, match), result|
      result << match if subpattern.capture
    end
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
