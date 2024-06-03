# frozen_string_literal: true

# Collection of methods to create subpatterns
#
# This module provides a set of methods to create and add various types of subpatterns to a pattern.
# These methods allow for flexible pattern matching based on different criteria.
module SubPatternFactory
  # Add a subpattern that matches any value, with an optional evaluator
  #
  # @param options [Hash] Options to configure the subpattern
  # @param additional_evaluator [Proc] An optional block to further evaluate the value
  # @return [self] Returns the pattern for method chaining
  def any(**options, &additional_evaluator)
    evaluator = ->(v) { additional_evaluator.nil? || additional_evaluator.call(v) }
    add_node(SubPattern.new(evaluator, **options))
    self
  end

  # Add an optional subpattern that matches any value, with an optional evaluator
  #
  # @param options [Hash] Options to configure the subpattern
  # @param additional_evaluator [Proc] An optional block to further evaluate the value
  # @return [self] Returns the pattern for method chaining
  def any_opt(**options, &additional_evaluator)
    evaluator = ->(v) { additional_evaluator.nil? || additional_evaluator.call(v) }
    add_node(SubPattern.new(evaluator, optional: true, **options))
    self
  end

  # Add a subpattern that matches any value except those that satisfy the evaluator
  #
  # @param options [Hash] Options to configure the subpattern
  # @param additional_evaluator [Proc] An optional block to evaluate the value
  # @return [self] Returns the pattern for method chaining
  def none(**options, &additional_evaluator)
    evaluator = ->(v) { additional_evaluator.nil? || !additional_evaluator.call(v) }
    add_node(SubPattern.new(evaluator, **options))
    self
  end

  # Add a subpattern that matches a specific value
  #
  # @param value [Object] The value to match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_eq(value, **options)
    add_node(SubPattern.new(->(v) { v == value }, **options))
    self
  end

  # Add an optional subpattern that matches a specific value
  #
  # @param value [Object] The value to match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_eq_opt(value, **options)
    add_node(SubPattern.new(->(v) { v == value }, optional: true, **options))
    self
  end

  # Add a subpattern that matches any value except a specific one
  #
  # @param value [Object] The value to not match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_neq(value, **options)
    add_node(SubPattern.new(->(v) { v != value }, **options))
    self
  end

  # Add an optional subpattern that matches any value except a specific one
  #
  # @param value [Object] The value to not match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_neq_opt(value, **options)
    add_node(SubPattern.new(->(v) { v != value }, optional: true, **options))
    self
  end

  # Add a subpattern that matches any value within a specified range
  #
  # @param range [Range] The range of values to match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_in(range, **options)
    add_node(SubPattern.new(->(v) { range.include?(v) }, **options))
    self
  end

  # Add an optional subpattern that matches any value within a specified range
  #
  # @param range [Range] The range of values to match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_in_opt(range, **options)
    add_node(SubPattern.new(->(v) { range.include?(v) }, optional: true, **options))
    self
  end

  # Add a subpattern that matches any value of a specified type
  #
  # @param type [Class] The class type to match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_is_a(type, **options)
    add_node(SubPattern.new(->(v) { v.is_a?(type) }, **options))
    self
  end

  # Add an optional subpattern that matches any value of a specified type
  #
  # @param type [Class] The class type to match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_is_a_opt(type, **options)
    add_node(SubPattern.new(->(v) { v.is_a?(type) }, optional: true, **options))
    self
  end

  # Add a subpattern that matches any non-nil and non-empty value
  #
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def present(**options)
    add_node(SubPattern.new(->(v) { !v.nil? && v != '' }, **options))
    self
  end

  # Add a subpattern that matches any nil or empty value
  #
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def absent(**options)
    add_node(SubPattern.new(->(v) { v.nil? || v == '' }, **options))
    self
  end
end
