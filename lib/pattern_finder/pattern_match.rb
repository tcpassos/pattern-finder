# frozen_string_literal: true

require 'forwardable'

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
    @matched[index] if index
  end

  # Convert the matched values to a string
  def to_s
    @matched.inspect
  end
end
