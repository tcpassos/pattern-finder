# frozen_string_literal: true

# Node containing a subpattern and its children
class SubPatternNode
  attr_reader :subpattern, :subpatterns, :children

  # Constructor
  # @param [SubPattern] subpattern The subpattern of the node
  def initialize(subpattern)
    raise ArgumentError, 'Subpattern must be a SubPattern instance' unless subpattern.is_a?(SubPattern)

    @subpattern = subpattern
    @subpatterns = [subpattern]
    @children = []
  end

  # Match the node against a list of values
  # @param [Array] values The values to match against
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

  # Push a node to the tree
  # @param [Node] node The node to push
  def push_node(node)
    unless node == self
      @subpatterns << node.subpattern
      @children << node unless mandatory_ahead?
    end
    @children.each { |child| child.push_node(node) }
  end

  protected

  # (protected) Check if the node has a subpattern that is not optional ahead
  # @return [Boolean] Whether the node has a mandatory subpattern ahead
  def mandatory_ahead?
    @children.any? { |child| !child.subpattern.optional || child.mandatory_ahead? }
  end

  # (protected) Match the node against a list of values recursively
  # This method returns every possible match, even if it's incomplete
  # @param [Array] values The values to match against
  # @param [Integer] position The current position in the values array
  # @param [Array] matched_so_far The matched elements so far
  # @return [Array, Array<Integer>] The matched elements and the next positions
  def match_recursively(values, position, matched_so_far = [])
    return [[], [position]] if position >= values.size

    matched, positions = @subpattern.optional ? match_nodes(@children, values, matched_so_far, position) : [[], []]

    if @subpattern.match?(values[position], matched_so_far, values, position)
      next_position = position + 1
      nodes_to_match = @children.dup
      nodes_to_match.unshift(self) if @subpattern.repeat

      new_matches, new_positions = match_nodes(nodes_to_match, values, matched_so_far,
                                               next_position, [values[position]])
      matched.concat(new_matches.empty? ? [[[values[position]]]] : new_matches)
      positions.concat(new_positions.empty? ? [next_position] : new_positions)
    end

    [matched, positions]
  end

  private

  # (private) Match the nodes against a list of values
  # @param [Array] nodes The nodes to match against
  # @param [Array] values The values to match against
  # @param [Array] matched_so_far The matched elements so far
  # @param [Integer] position The current position in the values array
  # @param [Array] new_value The new value matched
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
  # @param [Array] matched The matched elements
  # @return [Array] The matched elements without non-capture groups
  def remove_non_capture_groups(matched)
    @subpatterns.zip(matched).each_with_object([]) do |(subpattern, match), result|
      result << match if subpattern.capture
    end
  end

  # (private) Check if all elements matched
  # Validates for optional and repeatable subpatterns
  # @param [Array] matched_elements The matched elements
  # @return [Boolean] Whether all elements matched
  def match_complete?(matched_elements)
    return false if matched_elements.size != @subpatterns.size

    @subpatterns.zip(matched_elements).all? do |subpattern, matched|
      (subpattern.optional || matched&.any?) && (subpattern.repeat || matched&.size.to_i <= 1)
    end
  end
end
