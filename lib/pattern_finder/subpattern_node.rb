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
    # Sort by the number of matched elements and return the first complete match
    match_recursively(values, []).sort_by { |match| match.flatten.size }.reverse.each do |match|
      return match if match_complete?(match)
    end
    # Will return nil if no match is found
    # but if all subpatterns are optional, must return an array of empty arrays
    return Array.new(@subpatterns.size) { [] } if @subpatterns.all?(&:optional)

    nil
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
  # @return [Array] The matched elements
  def match_recursively(values, matched_so_far)
    return [] if values.empty?

    # Match all values with children if the subpattern is optional
    matched = @subpattern.optional ? match_nodes(@children, values, matched_so_far) : []

    # If the first value matches the subpattern, continue matching with the remaining values
    if @subpattern.match?(values.first, matched_so_far)
      next_value, *remaining_values = values
      nodes_to_match = @children.dup.unshift(self) if subpattern.repeat

      # Match the children with the remaining values
      new_matches = match_nodes(nodes_to_match || @children, remaining_values, matched_so_far, [next_value])
      matched.concat(new_matches)
      # If no match was added, this is a leaf node, add [[next_value]]
      matched << [[next_value]] if new_matches.empty?
    end

    # Return the matched elements
    matched
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
  # @return [Array] The matched elements
  def match_nodes(nodes, values, matched_so_far, new_value = [])
    nodes.flat_map do |node|
      #                      | Update matched_so_far with the last matched value
      #                      v                          v
      node.match_recursively(values, (matched_so_far + new_value)).map do |match|
        if node == self
          # [v1, new_value] [v2] [v3]
          #      ^^^^^^^^^ Adds the new value togheter with the same group of this node
          match.first.unshift(new_value.first)
        else
          # [new_value] [v2] [v3]
          # ^^^^^^^^^^^ Adds the new value as a new group representing this node
          match.unshift(new_value)
        end
        match
      end
    end
  end

  # (private) Check if all elements matched
  # Validates for optional and repeatable subpatterns
  # @param [Array] matched_elements The matched elements
  # @return [Boolean] Whether all elements matched
  def match_complete?(matched_elements)
    @subpatterns.zip(matched_elements).all? do |subpattern, matched|
      (subpattern.optional || matched&.any?) && (subpattern.repeat || matched&.size.to_i <= 1)
    end
  end
end
