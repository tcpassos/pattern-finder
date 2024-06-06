# frozen_string_literal: true

# Collection of methods to create subpatterns
#
# This module provides a set of methods to create and add various types of subpatterns to a pattern.
# These methods allow for flexible pattern matching based on different criteria.
module SubPatternFactory
  # ===============================================================================================
  private_class_method def self.def_optional_subpatterns(*method_names)
    def_subpatterns_with_prefix('optional', *method_names, optional: true)
  end

  private_class_method def self.def_zero_or_more_subpatterbs(*method_names)
    def_subpatterns_with_prefix('zero_or_more', *method_names, repeat: true, optional: true)
  end

  private_class_method def self.def_least_one_subpatterns(*method_names)
    def_subpatterns_with_prefix('least_one', *method_names, repeat: true, optional: false)
  end

  private_class_method def self.def_subpatterns_with_prefix(prefix, *method_names, **options)
    method_names.each do |method_name|
      name = if method_name.start_with?('value_')
               method_name.to_s.gsub('value_', "#{prefix}_").to_sym
             else
               "#{prefix}_#{method_name}".to_sym
             end
      define_method(name) do |*args, **kwargs, &block|
        send(method_name, *args, **kwargs.merge(options), &block)
      end
    end
  end

  def_optional_subpatterns :any, :value_eq, :value_neq, :value_in, :value_of
  def_zero_or_more_subpatterbs :value_eq, :value_neq, :value_in, :value_of, :present, :absent
  def_least_one_subpatterns :value_eq, :value_neq, :value_in, :value_of, :present, :absent
  # ===============================================================================================


  # Add a subpattern that matches any value, with an optional evaluator
  #
  # @param options [Hash] Options to configure the subpattern
  # @param additional_evaluator [Proc] An optional block to further evaluate the value
  # @return [self] Returns the pattern for method chaining
  def any(**options, &additional_evaluator)
    evaluator = ->(v) { additional_evaluator.nil? || additional_evaluator.call(v) }
    add_subpattern(SubPattern.new(evaluator, **options))
    self
  end

  # Add a subpattern that matches a specific value
  #
  # @param value [Object] The value to match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_eq(value, **options)
    add_subpattern(SubPattern.new(->(v) { v == value }, **options))
    self
  end

  # Add a subpattern that matches any value except a specific one
  #
  # @param value [Object] The value to not match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_neq(value, **options)
    add_subpattern(SubPattern.new(->(v) { v != value }, **options))
    self
  end

  # Add a subpattern that matches any value within a specified range
  #
  # @param range [Range] The range of values to match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_in(range, **options)
    add_subpattern(SubPattern.new(->(v) { range.include?(v) }, **options))
    self
  end

  # Add a subpattern that matches any value of a specified type
  #
  # @param type [Class] The class type to match
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def value_of(type, **options)
    add_subpattern(SubPattern.new(->(v) { v.is_a?(type) }, **options))
    self
  end

  # Add a subpattern that matches any non-nil and non-empty value
  #
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def present(**options)
    add_subpattern(SubPattern.new(->(v) { !v.nil? && v != '' }, **options))
    self
  end

  # Add a subpattern that matches any nil or empty value
  #
  # @param options [Hash] Options to configure the subpattern
  # @return [self] Returns the pattern for method chaining
  def absent(**options)
    add_subpattern(SubPattern.new(->(v) { v.nil? || v == '' }, **options))
    self
  end
end
