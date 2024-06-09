# frozen_string_literal: true

# Module to match a pattern against a set of values
module PatternMatcher
  # Find a match for the pattern
  # @param state [Hash] The current state of the pattern matching
  # @param queue [Array] Array containing the subpatterns to match and their state
  # @param values [Array] The values to match against
  # @param acc_matched [Array] The matched elements so far containing and the next position
  # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/MethodLength
  def find_match(state, queue, values, acc_matched)
    value_pos = state[:value_pos]

    # Skip the current subpattern if the position is out of bounds
    return if value_pos >= values.size

    # Get current state properties
    subpattern_pos, current_matched, current_matched_flat = state.values_at(:subpattern_pos, :matched, :matched_flat)
    subpattern = @subpatterns[subpattern_pos]
    value = values[value_pos]
    has_matched_subpattern = subpattern.match_evaluator?(value, current_matched_flat, values, value_pos)
    has_matched_break_condition = subpattern.match_break_condition?(value, current_matched_flat, values, value_pos)
    is_last_subpattern = subpattern_pos == @subpatterns.size - 1
    allow_gaps = subpattern.allow_gaps && !has_matched_break_condition

    # Get previous state properties
    previous_subpattern, previous_matched = state.values_at(:previous_subpattern, :previous_matched)
    previous_self = previous_subpattern == subpattern || previous_subpattern.nil?
    previous_has_matched_break_condition = previous_subpattern&.match_break_condition?(value, current_matched_flat,
                                                                                       values, value_pos)
    previous_allow_gaps = previous_subpattern&.allow_gaps && !previous_has_matched_break_condition

    # ==================================
    # ADD the value to the current match
    # ==================================
    if has_matched_subpattern
      # Duplicate the last match to avoid modifying the previous one
      current_matched = current_matched.dup.tap { |cm| cm[-1] = cm.last.dup }
      previous_self ? current_matched.last << value : current_matched << [value]
      state.update(matched: current_matched, matched_flat: current_matched_flat + [value])
    end

    # If the current subpattern can repeat has matched and can repeat, procceed to the next value
    # ...with the same subpattern
    advance_value(queue, state, subpattern) if has_matched_subpattern && subpattern.repeat

    # If allow gaps between the current and the previous subpattern and the current subpattern han't matched,
    # ...advance the value with the previous subpattern
    advance_value(queue, state, previous_subpattern) if !has_matched_subpattern && (allow_gaps || previous_allow_gaps)

    # If has matched the current subpattern or allow gaps, procceed to the next value with the next subpattern
    advance_subpattern_and_value(queue, state, subpattern) if (has_matched_subpattern || allow_gaps) &&
                                                              # Cannot advance the subpattern if it's the last one
                                                              !is_last_subpattern &&
                                                              # Optionals that didn't match are dealt with later
                                                              !(subpattern.optional && !has_matched_subpattern)

    # If the current subpattern is optional, adds a case to advance the subpattern without matching the current value
    advance_subpattern(queue, state, subpattern, previous_self) if subpattern.optional && !is_last_subpattern &&
                                                                   !(previous_self && previous_matched)

    # To add the current match to the accumulator, the following conditions must be met:
    # - The current subpattern matches
    # - The current subpattern is the last one or the current value is the last one
    # - The current match accumulated less than the previous one
    # - The current pattern don't have any mandatory subpatterns left
    return unless should_match?(subpattern_pos, value_pos, acc_matched, current_matched, has_matched_subpattern)

    # If the current subpattern is the last one, add empty arrays to the current match until the end of the pattern
    final_matched = current_matched + Array.new(@subpatterns.size - subpattern_pos - 1) { [] }

    # End of the pattern, add the current match to the accumulator
    acc_matched.update(matched: final_matched, next_pos: value_pos + 1)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity, Metrics/MethodLength

  private

  # (private) Adds a new state to the queue with the next value
  # @param queue [Array] Array containing the subpatterns to match and their state
  # @param current_state [Hash] The current state of the pattern matching
  # @param previous_subpattern [SubPattern] The previous subpattern
  def advance_value(queue, current_state, previous_subpattern)
    queue << {
      subpattern_pos: current_state[:subpattern_pos],
      value_pos: current_state[:value_pos] + 1,
      matched: current_state[:matched],
      matched_flat: current_state[:matched_flat],
      previous_matched: true,
      previous_subpattern: previous_subpattern
    }
  end

  # (private) Adds a new state to the queue with the next subpattern
  # @param queue [Array] Array containing the subpatterns to match and their state
  # @param current_state [Hash] The current state of the pattern matching
  # @param previous_subpattern [SubPattern] The previous subpattern
  # @param previous_self [Boolean] Whether the previous subpattern is the same as the current one
  def advance_subpattern(queue, current_state, previous_subpattern, previous_self)
    queue << {
      subpattern_pos: current_state[:subpattern_pos] + 1,
      value_pos: current_state[:value_pos],
      matched: previous_self ? current_state[:matched] : current_state[:matched] + [[]],
      matched_flat: current_state[:matched_flat],
      previous_matched: false,
      previous_subpattern: previous_subpattern
    }
  end

  # (private) Adds a new state to the queue with the next subpattern and value
  # @param queue [Array] Array containing the subpatterns to match and their state
  # @param current_state [Hash] The current state of the pattern matching
  # @param previous_subpattern [SubPattern] The previous subpattern
  def advance_subpattern_and_value(queue, current_state, previous_subpattern)
    queue << {
      subpattern_pos: current_state[:subpattern_pos] + 1,
      value_pos: current_state[:value_pos] + 1,
      matched: current_state[:matched],
      matched_flat: current_state[:matched_flat],
      previous_matched: true,
      previous_subpattern: previous_subpattern
    }
  end

  # (private) Check if the pattern should match the current value
  # @param subpattern_pos [Integer] The index of the current subpattern
  # @param value_pos [Integer] The index of the current value
  # @param acc_matched [Array] The matched elements so far containing and the next position
  # @param current_matched [Array] The current matched elements
  # @param has_matched_subpattern [Boolean] Whether the current subpattern matches the current value
  # @return [Boolean] Whether the pattern should match the current value
  def should_match?(subpattern_pos, value_pos, acc_matched, current_matched, has_matched_subpattern)
    return false unless has_matched_subpattern
    return false if subpattern_pos < @last_mandatory_index
    return false unless value_pos >= acc_matched[:next_pos]
    return false if acc_matched[:next_pos].positive? && current_matched.sum(&:size) < acc_matched[:matched].sum(&:size)

    true
  end
end
