# frozen_string_literal: true

# Collection of methods to create subpatterns
module SubPatternFactory
  def any(optional: false, repeat: false, capture: true, &additional_evaluator)
    evaluator = ->(v) { additional_evaluator.nil? || additional_evaluator.call(v) }
    add_subpattern(SubPattern.new(evaluator, optional: optional, repeat: repeat, capture: capture))
    self
  end

  def any_opt(repeat: false, capture: true, &additional_evaluator)
    evaluator = ->(v) { additional_evaluator.nil? || additional_evaluator.call(v) }
    add_subpattern(SubPattern.new(evaluator, optional: true, repeat: repeat, capture: capture))
    self
  end

  def value_eq(value, optional: false, repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(v) { v == value }, optional: optional, repeat: repeat, capture: capture))
    self
  end

  def value_neq(value, optional: false, repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(v) { v != value }, optional: optional, repeat: repeat, capture: capture))
    self
  end

  def value_in(range, optional: false, repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(v) { range.include?(v) }, optional: optional, repeat: repeat, capture: capture))
    self
  end

  def value_is_a(type, optional: false, repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(v) { v.is_a?(type) }, optional: optional, repeat: repeat, capture: capture))
    self
  end

  def present(optional: false, repeat: false, capture: true)
    add_subpattern(SimpleSubPattern.new(->(v) { !v.nil? && v != '' }, optional: optional, repeat: repeat,
                                                                      capture: capture))
    self
  end

  def absent(optional: false, repeat: false, capture: true)
    add_subpattern(SimpleSubPattern.new(->(v) { v.nil? || v == '' }, optional: optional, repeat: repeat,
                                                                     capture: capture))
    self
  end
end
