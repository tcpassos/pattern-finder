# frozen_string_literal: true

# ===============================================================================
# Collection of default subpatterns
module DefaultSubPatterns
  def any(optional: false, repeat: false)
    new(->(_) { true }, optional: optional, repeat: repeat)
  end

  def any_required(repeat: false)
    new(->(_) { true }, optional: false, repeat: repeat)
  end

  def any_optional(repeat: false)
    new(->(_) { true }, optional: true, repeat: repeat)
  end
end

# ===============================================================================
# Sub-pattern representation
class SubPattern
  extend DefaultSubPatterns
  attr_reader :evaluator, :optional, :repeat

  def initialize(evaluator, optional: false, repeat: false)
    @evaluator = evaluator
    @optional = optional
    @repeat = repeat
  end

  def match?(value)
    @evaluator.call(value)
  end
end

# ===============================================================================
# Node containing a subpattern and its children
class SubPatternNode
  attr_reader :subpattern, :subpatterns, :children

  # Constructor
  # @param [SubPattern] subpattern The subpattern of the node
  def initialize(subpattern)
    @subpattern = subpattern
    @subpatterns = [subpattern]
    @children = []
    @matched_values = {}
  end

  # Match the node against a list of values
  # @param [Array] values The values to match against
  # @return [Array, nil] The matched elements or nil if the node doesn't match
  def match(values)
    # Sort by the number of matched elements and return the first complete match
    match_incomplete(values).sort_by { |match| match.flatten.size }.reverse_each do |match|
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

  # Match the node against a list of values
  # This method returns every possible match, even if it's incomplete
  # @param [Array] values The values to match against
  # @return [Array] The matched elements
  def match_incomplete(values)
    matched = []
    return matched if values.empty?

    # Match all values with children if the subpattern is optional
    add_child_matches(matched, values, []) if @subpattern.optional
    # If the first value matches the subpattern, continue matching with the remaining values
    process_first_value(matched, values) if match_with_node_subpattern?(values.first)
    # Return the matched elements
    matched
  end

  # Check if the node has a subpattern that is not optional ahead
  # @return [Boolean] Whether the node has a mandatory subpattern ahead
  def mandatory_ahead?
    @children.any? { |child| !child.subpattern.optional || child.mandatory_ahead? }
  end

  private

  # Match the children of the node against a list of values
  # @param [Array] matched The matched elements
  # @param [Array] values The values to match against
  # @param [Array] first_value The first value of the match
  def add_child_matches(matched, values, first_value)
    @children.each do |child|
      child.match_incomplete(values).each do |match|
        matched << [first_value] + match
      end
    end
  end

  # Process the first value of the node
  # @param [Array] matched The matched elements so far
  # @param [Array] values The values to match against
  def process_first_value(matched, values)
    remaining_values = values[1..]
    first_value = values.first
    # If the subpattern is repeatable, add the repeated matches
    # Otherwise, add an array with the first value and empty arrays for the children
    if @subpattern.repeat
      add_repeated_matches(matched, remaining_values, first_value)
    else
      matched << [[first_value] + Array.new(@children.size) { [] }]
    end
    # Match the children with the remaining values
    add_child_matches(matched, remaining_values, [first_value])
  end

  # Add repeated matches to the matched elements
  # @param [Array] matched The matched elements so far
  # @param [Array] remaining_values The remaining values to match against
  # @param [Object] first_value The first value of the match
  def add_repeated_matches(matched, remaining_values, first_value)
    match_remaining = match_incomplete(remaining_values)

    if match_remaining.empty?
      matched << [[first_value] + Array.new(@children.size) { [] }]
    else
      add_remaining_matches(matched, match_remaining, first_value)
    end
  end

  # Add remaining matches to the matched elements
  # @param [Array] matched The matched elements so far
  # @param [Array] match_remaining The remaining matches to add
  # @param [Object] first_value The first value of the match
  def add_remaining_matches(matched, match_remaining, first_value)
    match_remaining.select! { |match| match.first.empty? || @subpattern.repeat }

    matched.concat(match_remaining.map do |match|
      match_copy = match.map(&:dup) # Deep copy to avoid mutating original match
      match_copy.first.unshift(first_value)
      match_copy
    end)
  end

  # Match a value with the current subpattern of the node
  # @param [Object] value The value to match
  # @return [Array, nil] The matched value and the index of the subpattern or nil if it doesn't match
  def match_with_node_subpattern?(value)
    @matched_values[value] = @subpattern.match?(value) unless @matched_values.key?(value)
    @matched_values[value]
  end

  # Check if all elements matched
  # Validates for optional and repeatable subpatterns
  # @param [Array] matched_elements The matched elements
  # @return [Boolean] Whether all elements matched
  def match_complete?(matched_elements)
    @subpatterns.zip(matched_elements).all? do |subpattern, matched|
      (subpattern.optional || matched&.any?) && (subpattern.repeat || matched&.size.to_i <= 1)
    end
  end
end
