# frozen_string_literal: true

require_relative 'pattern'

# A pattern finder that matches a pattern against a list of values
class PatternScanner
  attr_reader :values
  attr_accessor :pos

  # Constructor
  # @param values [Enumerable] The values to match
  def initialize(values)
    @values = values.is_a?(Enumerable) ? values.to_enum : values
    @pos = 0
  end

  # Returns true if the scan pointer is at the end of the values.
  # For infinite streams, this will always return false.
  # @return [Boolean] Whether the scan pointer is at the end of the values
  def eov?
    @values.peek
    false
  rescue StopIteration
    true
  end

  # Reset the scan pointer (index 0) and clear matching data.
  def reset
    @values.rewind if @values.respond_to?(:rewind)
    @pos = 0
  end

  # Tries to match with pattern at the current position.
  # If there's a match, the scanner advances the “scan pointer” and returns the matched values.
  # Otherwise, the scanner returns nil.
  # @param pattern [Pattern] The pattern to match
  # @return [Array, nil] The matched values or nil if the pattern doesn't match
  def scan(pattern)
    result, next_pos = pattern.match_next_position(enum_from_pos)
    @pos += next_pos if next_pos&.nonzero?
    result
  end

  # Scans the values until the pattern is matched.
  # Returns the matched values up to and including the end of the match, advancing the scan pointer to that location.
  # If there is no match, nil is returned.
  # @param pattern [Pattern] The pattern to match
  # @return [Array, nil] The matched values or nil if the pattern doesn't match
  def scan_until(pattern)
    initial_pos = @pos
    until eov?
      result, next_pos = pattern.match_next_position(enum_from_pos(initial_pos))
      if next_pos&.nonzero?
        @pos = initial_pos + next_pos
        return result
      end
      initial_pos += 1
    end
    nil
  end

  private

  # Creates an enumerator from the current position.
  # @param start_pos [Integer] The starting position for the enumerator
  # @return [Enumerator] The enumerator starting from the given position
  def enum_from_pos(start_pos = @pos, &block)
    return to_enum(:each_from_pos, start_pos) unless block_given?

    each_from_pos(start_pos, &block)
  end

  # Enumerates values starting from a given position.
  # @param start_pos [Integer] The starting position
  # @yield [Object] Yields each value from the given position
  def each_from_pos(start_pos)
    @values.rewind if @values.respond_to?(:rewind)
    current_pos = 0
    loop do
      value = @values.next
      yield value if current_pos >= start_pos
      current_pos += 1
    end
  end
end

# A module that adds scan and scan_for methods to an Enumerable object.
module PatternScannerMethods
  # Scans the values for a pattern and yields the matched values.
  # @param pattern [Pattern] The pattern to match
  # @yield [PatternMatch] The matched values
  # @return [Array] The matched values if no block is given
  def scan(pattern)
    scanner = PatternScanner.new(to_a)

    return to_enum(:scan, pattern) unless block_given?

    loop do
      match = scanner.scan_until(pattern)
      break unless match

      yield match if block_given?
    end
  end
end
