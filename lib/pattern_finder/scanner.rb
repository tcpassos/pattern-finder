# frozen_string_literal: true

require_relative 'pattern'

# A pattern finder that matches a pattern against a list of values
class Scanner
  attr_reader :values, :matched
  attr_accessor :pos

  # Constructor
  # @param [Array] values The values to scan
  def initialize(values)
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

  # Tries to match with pattern at the current position.
  # If there's a match, the scanner advances the “scan pointer” and returns the matched values.
  # Otherwise, the scanner returns nil.
  # @param [Pattern] pattern The pattern to match
  # @return [Array, nil] The matched values or nil if the pattern doesn't match
  def scan(pattern)
    result, next_pos = pattern.match_next_position(@values[@pos..])
    @pos += next_pos unless result.nil?
    result.matched_flattened
  end

  # Scans the values until the pattern is matched.
  # Returns the matched values up to and including the end of the match, advancing the scan pointer to that location.
  # If there is no match, nil is returned.
  # @param [Pattern] pattern The pattern to match
  # @return [Array, nil] The matched values or nil if the pattern doesn't match
  def scan_until(pattern)
    initial_pos = @pos
    until initial_pos >= @values.size
      result, next_pos = pattern.match_next_position(@values[initial_pos..])
      if result
        @pos = initial_pos + next_pos
        return result.matched_flattened
      end
      initial_pos += 1
    end
    nil
  end
end
