# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/pattern_finder'

# Test the Pattern class
# rubocop:disable Metrics/ClassLength
class TestPattern < Minitest::Test
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/AbcSize
  def test_pattern_with_optional_and_repeated_subpatterns
    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(value) { value == 1 })
    pattern.add_subpattern_from_evaluator(->(value) { value == 2 }, optional: true)
    pattern.add_subpattern_from_evaluator(->(value) { value == 3 }, repeat: true, optional: true)
    pattern.add_subpattern_from_evaluator(->(value) { value == 4 }, repeat: true)

    assert_equal([[1], [2], [3], [4, 4, 4, 4]], pattern.match([1, 2, 3, 4, 4, 4, 4, 5])&.matched)
    assert_equal([[1], [], [3], [4, 4, 4, 4]], pattern.match([1, 3, 4, 4, 4, 4])&.matched)
    assert_nil pattern.match([1, 2, 2, 3, 4, 4, 4, 4])
    assert_equal([[1], [], [3, 3], [4, 4, 4, 4]], pattern.match([1, 3, 3, 4, 4, 4, 4])&.matched)
    assert_equal([[1], [], [3], [4, 4, 4, 4, 4]], pattern.match([1, 3, 4, 4, 4, 4, 4])&.matched)
    assert_equal([[1], [], [], [4]], pattern.match([1, 4])&.matched)
    assert_equal([[1], [], [], [4, 4]], pattern.match([1, 4, 4])&.matched)
    assert_equal([[1], [], [], [4, 4, 4]], pattern.match([1, 4, 4, 4])&.matched)
    assert_nil pattern.match([1, 2])
    assert_nil pattern.match([1, 3])
    assert_nil pattern.match([2, 3, 4])
    assert_equal([[1], [2], [3], [4]], pattern.match([1, 2, 3, 4, 5])&.matched)

    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(_) { true }, repeat: true)
    pattern.add_subpattern_from_evaluator(->(value) { value == 3 })
    pattern.add_subpattern_from_evaluator(->(value) { value == 4 })
    assert_equal([[1, 2, 2], [3], [4]], pattern.match([1, 2, 2, 3, 4])&.matched)
  end
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/AbcSize

  def test_pattern_with_any_optional_repeat_subpattern
    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(value) { value == 'a' })
    pattern.add_subpattern_from_evaluator(->(_) { true }, repeat: true)
    pattern.add_subpattern_from_evaluator(->(value) { value == 'd' })

    assert_equal([['a'], %w[b c], ['d']], pattern.match(%w[a b c d])&.matched)
    assert_equal([['a'], %w[b c], ['d']], pattern.match(%w[a b c d e f g])&.matched)
    assert_equal([['a'], %w[b c d e], ['d']], pattern.match(%w[a b c d e d])&.matched)
  end

  def test_pattern_with_mixed_types
    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(value) { value.is_a?(Integer) })
    pattern.add_subpattern_from_evaluator(->(value) { value.is_a?(String) }, repeat: true, optional: true)
    pattern.add_subpattern_from_evaluator(->(value) { value.is_a?(Float) })

    assert_equal([[1], %w[a b c], [1.1]], pattern.match([1, 'a', 'b', 'c', 1.1])&.matched)
    assert_nil pattern.match(['a', 1, 'b', 'c', 1.1])
    assert_equal([[2], [], [3.0]], pattern.match([2, 3.0])&.matched)
  end

  def test_pattern_with_non_matching_values
    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(value) { value == 'x' })
    pattern.add_subpattern_from_evaluator(->(value) { value == 'y' }, optional: true)
    pattern.add_subpattern_from_evaluator(->(value) { value == 'z' }, repeat: true)

    assert_nil pattern.match(%w[x y y y])
    assert_nil pattern.match(%w[a b c])
    assert_equal([['x'], [], %w[z z]], pattern.match(%w[x z z a])&.matched)
  end

  def test_pattern_with_complex_evaluators
    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(value) { value.even? })
    pattern.add_subpattern_from_evaluator(->(value) { value.odd? }, repeat: true, optional: true)
    pattern.add_subpattern_from_evaluator(->(value) { value > 10 })

    assert_equal([[2], [1, 3, 5], [11]], pattern.match([2, 1, 3, 5, 11])&.matched)
    assert_nil pattern.match([1, 2, 3, 4, 5])
    assert_equal([[4], [], [12]], pattern.match([4, 12])&.matched)
  end

  def test_pattern_with_all_optional_subpatterns
    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(value) { value == 1 }, optional: true)
    pattern.add_subpattern_from_evaluator(->(value) { value == 2 }, optional: true)
    pattern.add_subpattern_from_evaluator(->(value) { value == 3 }, optional: true)

    assert_equal([[1], [2], [3]], pattern.match([1, 2, 3])&.matched)
    assert_equal([[], [], []], pattern.match([4, 5, 6])&.matched)
    assert_equal([[1], [], [3]], pattern.match([1, 3])&.matched)
  end

  def test_pattern_with_no_optional_subpatterns
    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(value) { value == 'x' })
    pattern.add_subpattern_from_evaluator(->(value) { value == 'y' })
    pattern.add_subpattern_from_evaluator(->(value) { value == 'z' })

    assert_equal([['x'], ['y'], ['z']], pattern.match(%w[x y z])&.matched)
    assert_nil pattern.match(%w[x z y])
    assert_nil pattern.match(%w[x y])

    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(_) { true })
    assert_equal([[1]], pattern.match([1, 2])&.matched)
  end

  def test_pattern_with_optional_and_mandatory_subpatterns
    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(value) { value == 'a' }, optional: true)
    pattern.add_subpattern_from_evaluator(->(value) { value == 'b' })
    pattern.add_subpattern_from_evaluator(->(value) { value == 'c' }, optional: true)
    pattern.add_subpattern_from_evaluator(->(value) { value == 'd' })

    assert_equal([['a'], ['b'], ['c'], ['d']], pattern.match(%w[a b c d])&.matched)
    assert_equal([[], ['b'], [], ['d']], pattern.match(%w[b d])&.matched)
    assert_nil pattern.match(%w[a c])
  end

  def test_pattern_with_repeated_optional_subpatterns
    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(value) { value == 'a' }, optional: true, repeat: true)
    pattern.add_subpattern_from_evaluator(->(value) { value == 'b' })

    assert_equal([%w[a a], ['b']], pattern.match(%w[a a b])&.matched)
    assert_equal([[], ['b']], pattern.match(%w[b])&.matched)
    assert_nil pattern.match(%w[a a])
  end

  def test_pattern_with_empty_input
    pattern = Pattern.new
    pattern.add_subpattern_from_evaluator(->(value) { value == 1 })
    pattern.add_subpattern_from_evaluator(->(value) { value == 2 })

    assert_nil pattern.match([])
  end
end
# rubocop:enable Metrics/ClassLength

# Run the tests
Minitest.run
