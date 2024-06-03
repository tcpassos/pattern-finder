# frozen_string_literal: true

# Sub-pattern representation
class SubPattern
  attr_reader :evaluator, :children, :subpatterns, :matched_cache,
              :name, :optional, :repeat, :capture,
              :allow_gaps, :gap_break_condition

  # Constructor
  # @param evaluator [Proc] The evaluator for the subpattern
  # @param options [Hash] The options for the subpattern
  def initialize(evaluator, options = {})
    raise ArgumentError, 'Evaluator must be a Proc' unless evaluator.is_a?(Proc)

    @evaluator = evaluator
    @children = []
    @subpatterns = [self]
    @matched_cache = {}

    @name = options.fetch(:name, nil)
    @optional = options.fetch(:optional, false)
    @repeat = options.fetch(:repeat, false)
    @capture = options.fetch(:capture, true)
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

  # Push a node to the tree
  # @param node [SubPattern] The node to push
  def push_node(node)
    return if node == self

    # Propagate the allow_gaps flag to the children if it's not set
    node.set_options(allow_gaps: @allow_gaps) if node.allow_gaps.nil?
    node.set_options(gap_break_condition: @gap_break_condition) if node.gap_break_condition.nil?

    @subpatterns += node.subpatterns
    @children << node unless mandatory_ahead?
    @children.each { |child| child.push_node(node) }
  end

  # Match the node against a list of values
  # @param values [Array] The values to match against
  # @return [Array, nil] The matched elements or nil if the node doesn't match
  def match(values)
    matches, next_positions = match_recursively(values, 0)
    # Sort matches by the size of each subarray in descending order
    matches_with_positions = matches.zip(next_positions).sort_by { |match, _| match.map { |subarray| -subarray.size } }

    matches_with_positions.each do |match, position|
      return [remove_non_capture_groups(match), position] if match_complete?(match)
    end
    return [Array.new(@subpatterns.size) { [] }, 0] if @subpatterns.all?(&:optional)

    [nil, 0]
  end

  protected

  # (protected) Propagate options to children
  def propagate_options
    @children.each do |child|
      child.set_options(allow_gaps: @allow_gaps, gap_break_condition: @gap_break_condition)
      child.propagate_options
    end
  end

  # (protected) Check if the node has a child that is not optional ahead
  # @return [Boolean] Whether the node has a mandatory subpattern ahead
  def mandatory_ahead?
    @children.any? { |child| !child.optional || child.mandatory_ahead? }
  end

  # (protected) Match the node against a list of values recursively
  # This method returns every possible match, even if it's incomplete
  # @param values [Array] The values to match against
  # @param position [Integer] The current position in the values array
  # @param matched_so_far [Array] The matched elements so far
  # @return [Array, Array<Integer>] The matched elements and the next positions
  def match_recursively(values, position, matched_so_far = [])
    return [[], [position]] if position >= values.size

    next_position = position + 1
    current_value = values[position]
    matched, positions = @optional ? match_nodes(@children, values, matched_so_far, position) : [[], []]

    if match_evaluator?(current_value, matched_so_far, values, position)
      value_matched = [current_value]
      nodes_to_match = @children.dup
      nodes_to_match.unshift(self) if @repeat

      new_matches, new_positions = match_nodes(nodes_to_match, values, matched_so_far, next_position, value_matched)

      matched.concat(new_matches.empty? ? [[[current_value]] + Array.new(@children.size) { [] }] : new_matches)
      positions.concat(new_positions.empty? ? [next_position] : new_positions)
    elsif @allow_gaps && !@gap_break_condition&.call(current_valuem, matched_so_far, values, position)
      new_matches, new_positions = match_recursively(values, next_position, matched_so_far)
      matched.concat(new_matches)
      positions.concat(new_positions)
    end

    [matched, positions]
  end

  private

  # (private) Check if the subpattern matches a value
  # @param value [Object] The value to match
  # @param matched_so_far [Array] The values that have been matched so far
  # @param all_values [Array] All the values that are being matched
  # @param position [Integer] The current position in the values array
  # @return [Boolean] Whether the subpattern matches the value
  def match_evaluator?(value, matched_so_far = [], all_values = [], position = 0)
    key = [value, matched_so_far, position].hash
    return @matched_cache[key] if @matched_cache.key?(key)

    args = Array.new([@evaluator.arity, 4].min) { |i| [value, matched_so_far, all_values, position][i] }
    match = @evaluator.call(*args)
    @matched_cache[key] = match
    match
  end

  # (private) Match the nodes against a list of values
  # @param nodes [Array] The nodes to match against
  # @param values [Array] The values to match against
  # @param matched_so_far [Array] The matched elements so far
  # @param position [Integer] The current position in the values array
  # @param new_value [Array] The new value matched
  # @return [Array, Array<Integer>] The matched elements and the next positions
  def match_nodes(nodes, values, matched_so_far, position, new_value = [])
    matches = []
    next_positions = []
    nodes.each do |node|
      node_matches, node_positions = node.match_recursively(values, position, matched_so_far + new_value)
      node_matches.zip(node_positions).each do |match, node_position|
        match = match.map(&:dup) # Deep copy the match to avoid shared references
        if node == self
          #      vvvvvvvvv Adds the new value together with the same group of this node
          # [v1, new_value] [v2] [v3]
          match.first.unshift(new_value.first)
        else
          # vvvvvvvvvvv Adds the new value as a new group representing this node
          # [new_value] [v2] [v3]
          match.unshift(new_value)
        end
        matches << match
        next_positions << node_position
      end
    end
    [matches, next_positions]
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
