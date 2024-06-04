# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/pattern_finder'

# Test the Pattern class
class TestPattern < Minitest::Test
  def test_match_next_position_optional_and_repeated_subpatterns
    pattern = Pattern.new
    pattern.value_eq(1)
    pattern.optional_eq(2)
    pattern.optional_eq(3, repeat: true)
    pattern.value_eq(4, repeat: true)

    result, position = pattern.match_next_position([1, 2, 3, 4, 4, 4, 4, 5])
    assert_equal([[1], [2], [3], [4, 4, 4, 4]], result.matched)
    assert_equal(7, position)

    result, position = pattern.match_next_position([1, 3, 4, 4, 4, 4])
    assert_equal([[1], [], [3], [4, 4, 4, 4]], result.matched)
    assert_equal(6, position)

    assert_nil pattern.match_next_position([1, 2, 2, 3, 4, 4, 4, 4])

    result, position = pattern.match_next_position([1, 3, 3, 4, 4, 4, 4])
    assert_equal([[1], [], [3, 3], [4, 4, 4, 4]], result.matched)
    assert_equal(7, position)

    result, position = pattern.match_next_position([1, 3, 4, 4, 4, 4, 4])
    assert_equal([[1], [], [3], [4, 4, 4, 4, 4]], result.matched)
    assert_equal(7, position)

    result, position = pattern.match_next_position([1, 4])
    assert_equal([[1], [], [], [4]], result.matched)
    assert_equal(2, position)

    result, position = pattern.match_next_position([1, 4, 4])
    assert_equal([[1], [], [], [4, 4]], result.matched)
    assert_equal(3, position)

    result, position = pattern.match_next_position([1, 4, 4, 4])
    assert_equal([[1], [], [], [4, 4, 4]], result.matched)
    assert_equal(4, position)

    assert_nil pattern.match_next_position([1, 2])
    assert_nil pattern.match_next_position([1, 3])
    assert_nil pattern.match_next_position([2, 3, 4])

    result, position = pattern.match_next_position([1, 2, 3, 4, 5])
    assert_equal([[1], [2], [3], [4]], result.matched)
    assert_equal(4, position)
  end

  def test_match_next_position_any_optional_repeat_subpattern
    pattern = Pattern.new
    pattern.value_eq('a')
    pattern.any(repeat: true)
    pattern.value_eq('d')

    result, position = pattern.match_next_position(['a', 'b', 'c', 'd'])
    assert_equal([['a'], ['b', 'c'], ['d']], result.matched)
    assert_equal(4, position)

    result, position = pattern.match_next_position(['a', 'b', 'c', 'd', 'e', 'f', 'g'])
    assert_equal([['a'], ['b', 'c'], ['d']], result.matched)
    assert_equal(4, position)

    result, position = pattern.match_next_position(['a', 'b', 'c', 'd', 'e', 'd'])
    assert_equal([['a'], ['b', 'c', 'd', 'e'], ['d']], result.matched)
    assert_equal(6, position)
  end

  def test_match_next_position_mixed_types
    pattern = Pattern.new
    pattern.value_of(Integer)
    pattern.optional_of(String, repeat: true)
    pattern.value_of(Float)

    result, position = pattern.match_next_position([1, 'a', 'b', 'c', 1.1])
    assert_equal([[1], ['a', 'b', 'c'], [1.1]], result.matched)
    assert_equal(5, position)

    assert_nil pattern.match_next_position(['a', 1, 'b', 'c', 1.1])

    result, position = pattern.match_next_position([2, 3.0])
    assert_equal([[2], [], [3.0]], result.matched)
    assert_equal(2, position)
  end

  def test_match_next_position_non_matching_values
    pattern = Pattern.new
    pattern.value_eq('x')
    pattern.optional_eq('y')
    pattern.value_eq('z', repeat: true)

    assert_nil pattern.match_next_position(['x', 'y', 'y', 'y'])
    assert_nil pattern.match_next_position(['a', 'b', 'c'])

    result, position = pattern.match_next_position(['x', 'z', 'z', 'a'])
    assert_equal([['x'], [], ['z', 'z']], result.matched)
    assert_equal(3, position)
  end

  def test_match_next_position_complex_evaluators
    pattern = Pattern.new
    pattern.any(&:even?)
    pattern.optional_any(repeat: true, &:odd?)
    pattern.any { |value| value > 10 }

    result, position = pattern.match_next_position([2, 1, 3, 5, 11])
    assert_equal([[2], [1, 3, 5], [11]], result.matched)
    assert_equal(5, position)

    assert_nil pattern.match_next_position([1, 2, 3, 4, 5])

    result, position = pattern.match_next_position([4, 12])
    assert_equal([[4], [], [12]], result.matched)
    assert_equal(2, position)
  end

  def test_match_next_position_all_optional_subpatterns
    pattern = Pattern.new
    pattern.optional_eq(1)
    pattern.optional_eq(2)
    pattern.optional_eq(3)

    result, position = pattern.match_next_position([1, 2, 3])
    assert_equal([[1], [2], [3]], result.matched)
    assert_equal(3, position)

    result, position = pattern.match_next_position([4, 5, 6])
    assert_equal([[], [], []], result.matched)
    assert_equal(0, position)

    result, position = pattern.match_next_position([1, 3])
    assert_equal([[1], [], [3]], result.matched)
    assert_equal(2, position)
  end

  def test_match_next_position_no_optional_subpatterns
    pattern = Pattern.new
    pattern.value_eq('x')
    pattern.value_eq('y')
    pattern.value_eq('z')

    result, position = pattern.match_next_position(['x', 'y', 'z'])
    assert_equal([['x'], ['y'], ['z']], result.matched)
    assert_equal(3, position)

    assert_nil pattern.match_next_position(['x', 'z', 'y'])
    assert_nil pattern.match_next_position(['x', 'y'])

    pattern = Pattern.new
    pattern.any
    result, position = pattern.match_next_position([1, 2])
    assert_equal([[1]], result.matched)
    assert_equal(1, position)
  end

  def test_match_next_position_optional_and_mandatory_subpatterns
    pattern = Pattern.new
    pattern.optional_eq('a')
    pattern.value_eq('b')
    pattern.optional_eq('c')
    pattern.value_eq('d')

    result, position = pattern.match_next_position(['a', 'b', 'c', 'd'])
    assert_equal([['a'], ['b'], ['c'], ['d']], result.matched)
    assert_equal(4, position)

    result, position = pattern.match_next_position(['b', 'd'])
    assert_equal([[], ['b'], [], ['d']], result.matched)
    assert_equal(2, position)

    assert_nil pattern.match_next_position(['a', 'c'])

    pattern = Pattern.new
    pattern.optional_eq(1)
    pattern.optional_eq(2)

    result, position = pattern.match_next_position([1])
    assert_equal([[1], []], result.matched)
  end

  def test_match_next_position_repeated_optional_subpatterns
    pattern = Pattern.new
    pattern.optional_eq('a', repeat: true)
    pattern.value_eq('b')

    result, position = pattern.match_next_position(['a', 'a', 'b'])
    assert_equal([['a', 'a'], ['b']], result.matched)
    assert_equal(3, position)

    result, position = pattern.match_next_position(['b'])
    assert_equal([[], ['b']], result.matched)
    assert_equal(1, position)

    assert_nil pattern.match_next_position(['a', 'a'])
  end

  def test_match_next_position_empty_input
    pattern = Pattern.new
    pattern.value_eq(1)
    pattern.value_eq(2)

    assert_nil pattern.match_next_position([])
  end

  def test_match_next_position_repeated_values
    pattern = Pattern.new
    pattern.optional_eq(1, repeat: true)
    pattern.any(repeat: true)
    pattern.optional_eq(3)

    result, position = pattern.match_next_position([1, 1, 2, 3])
    assert_equal([[1, 1], [2, 3], []], result.matched)
    assert_equal(4, position)
  end

  def test_match_next_position_non_capturing_and_mandatory_subpattern
    pattern = Pattern.new
    pattern.value_eq(1)
    pattern.value_eq(2, repeat: true, capture: false)
    pattern.value_eq(3)

    result, position = pattern.match_next_position([1, 2, 3])
    assert_equal([[1], [3]], result.matched)
    assert_equal(3, position)

    assert_nil pattern.match_next_position([1, 4, 3]) # Should fail because 2 is mandatory

    result, position = pattern.match_next_position([1, 2, 2, 3])
    assert_equal([[1], [3]], result.matched)
    assert_equal(4, position)

    pattern = Pattern.new
    pattern.value_of(String, repeat: true, capture: false)
    pattern.value_of(Integer)

    result, position = pattern.match_next_position(['a', 'b', 1])
    assert_equal([[1]], result.matched)
    assert_equal(3, position)

    assert_nil pattern.match_next_position(['a', 'b', 'c']) # Should fail because Integer is mandatory
  end
end

# Run the tests
Minitest.run
