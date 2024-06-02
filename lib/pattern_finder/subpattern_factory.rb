# frozen_string_literal: true

# Collection of methods to create subpatterns
module SubPatternFactory
  def any(**options, &additional_evaluator)
    evaluator = ->(v) { additional_evaluator.nil? || additional_evaluator.call(v) }
    add_subpattern(SubPattern.new(evaluator, **options))
    self
  end

  def any_opt(**options, &additional_evaluator)
    evaluator = ->(v) { additional_evaluator.nil? || additional_evaluator.call(v) }
    add_subpattern(SubPattern.new(evaluator, optional: true, **options))
    self
  end

  def value_eq(value, **options)
    add_subpattern(SubPattern.new(->(v) { v == value }, **options))
    self
  end

  def value_eq_opt(value, **options)
    add_subpattern(SubPattern.new(->(v) { v == value }, optional: true, **options))
    self
  end

  def value_neq(value, **options)
    add_subpattern(SubPattern.new(->(v) { v != value }, **options))
    self
  end

  def value_neq_opt(value, **options)
    add_subpattern(SubPattern.new(->(v) { v != value }, optional: true, **options))
    self
  end

  def value_in(range, **options)
    add_subpattern(SubPattern.new(->(v) { range.include?(v) }, **options))
    self
  end

  def value_in_opt(range, **options)
    add_subpattern(SubPattern.new(->(v) { range.include?(v) }, optional: true, **options))
    self
  end

  def value_is_a(type, **options)
    add_subpattern(SubPattern.new(->(v) { v.is_a?(type) }, **options))
    self
  end

  def value_is_a_opt(type, **options)
    add_subpattern(SubPattern.new(->(v) { v.is_a?(type) }, optional: true, **options))
    self
  end

  def present(**options)
    add_subpattern(SubPattern.new(->(v) { !v.nil? && v != '' }, **options))
    self
  end

  def absent(**options)
    add_subpattern(SubPattern.new(->(v) { v.nil? || v == '' }, **options))
    self
  end
end
