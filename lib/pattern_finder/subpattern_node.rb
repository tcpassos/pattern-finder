# frozen_string_literal: true

# Node containing a subpattern and its children
class SubPatternNode
  attr_reader :subpattern, :subpatterns, :children

  # Constructor
  # @param [SubPattern] subpattern The subpattern of the node
  def initialize(subpattern)
    @subpattern = subpattern
    @subpatterns = [subpattern]
    @children = []
  end

  # Match the node against a list of values
  # @param [Array] values The values to match against
  # @return [Array, nil] The matched elements or nil if the node doesn't match
  def match(values)
    matches, final_position = match_recursively(values, [])
    # Sort matches by the size of each subarray in descending order
    matches.sort_by { |match| match.map { |subarray| -subarray.size } }.each do |match|
      return [remove_non_capture_groups(match), final_position] if match_complete?(match)
    end
    return [Array.new(@subpatterns.size) { [] }, values.size] if @subpatterns.all?(&:optional)

    [nil, final_position]
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

  # (protected) Match the node against a list of values recursively
  # This method returns every possible match, even if it's incomplete
  # @param [Array] values The values to match against
  # @param [Array] matched_so_far The matched elements so far
  # @return [Array, Integer] The matched elements and the final position
  def match_recursively(values, matched_so_far)
    return [[], 0] if values.empty?

    # If node is optional, match all the values for the children
    matched = []
    matched += match_nodes(@children, values, matched_so_far).first if @subpattern.optional
    final_position = matched_so_far.size

    if @subpattern.match?(values.first, matched_so_far)
      next_value, *remaining_values = values
      nodes_to_match = @children.dup
      nodes_to_match.unshift(self) if @subpattern.repeat

      new_matches, final_pos = match_nodes(nodes_to_match, remaining_values, matched_so_far, [next_value])

      matched.concat(new_matches)
      final_position = final_pos + 1
      matched << [[next_value]] if new_matches.empty?
    end

    [matched, final_position]
  end

  # (protected) Check if the node has a subpattern that is not optional ahead
  # @return [Boolean] Whether the node has a mandatory subpattern ahead
  def mandatory_ahead?
    @children.any? { |child| !child.subpattern.optional || child.mandatory_ahead? }
  end

  private

  # (private) Match the nodes against a list of values
  # @param [Array] nodes The nodes to match against
  # @param [Array] values The values to match against
  # @param [Array] matched_so_far The matched elements so far
  # @param [Array] new_value The new value matched
  # @return [Array, Integer] The matched elements and the final position
  def match_nodes(nodes, values, matched_so_far, new_value = [])
    matches = []
    final_position = matched_so_far.size
    nodes.each do |node|
      node_matches, node_final_pos = node.match_recursively(values, matched_so_far + new_value)
      node_matches.each do |match|
        if node == self
          # Ensure we are working with a duplicate of the match to avoid shared references
          match = match.map(&:dup)
          # [v1, new_value] [v2] [v3]
          #      ^^^^^^^^^ Adds the new value together with the same group of this node
          match.first.unshift(new_value.first)
        else
          # [new_value] [v2] [v3]
          # ^^^^^^^^^^^ Adds the new value as a new group representing this node
          match.unshift(new_value)
        end
        matches << match
      end
      final_position = node_final_pos + new_value.size
    end
    [matches, final_position]
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
