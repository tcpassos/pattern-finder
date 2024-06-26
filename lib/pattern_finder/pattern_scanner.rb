# frozen_string_literal: true

require_relative 'pattern'

# A pattern finder that matches a pattern against a list of values
class PatternScanner
  attr_reader :values
  attr_accessor :pos

  # Constructor
  # @param values [Array] The values to scan
  def initialize(values)
    raise ArgumentError, 'values must be an array' unless values.is_a?(Array)

    @values = values
    @pos = 0
  end

  # Returns true if the scan pointer is at the end of the values.
  # @return [Boolean] Whether the scan pointer is at the end of the values
  def eov?
    @pos >= @values.size
  end

  # Reset the scan pointer (index 0) and clear matching data.
  def reset
    @pos = 0
  end

  def scan(pattern)
    result, next_pos = pattern.match_next_position(@values[@pos..])
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
    until initial_pos >= @values.size
      result, next_pos = pattern.match_next_position(@values[initial_pos..])
      if next_pos&.nonzero?
        @pos = initial_pos + next_pos
        return result
      end
      initial_pos += 1
    end
    nil
  end
end

# A module that adds scan and scan_for methods to an Enumerable object.
module PatternScannerMethods
  # Scans the values for a pattern and yields the matched values.
  # @param pattern [Pattern] The pattern to match
  # @yield [PatternMatch] The matched values
  # @return [Array] The matched values if no block is given
  def scan(pattern)
    return to_enum(:scan, pattern) unless block_given?

    scanner = PatternScanner.new(self)
    loop do
      match = scanner.scan_until(pattern)
      break unless match

      yield match if block_given?
    end
  end
end
