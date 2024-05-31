# frozen_string_literal: true

# Collection of methods to create subpatterns
module SubPatternFactory
  def any(optional: false, repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(_) { true }, optional: optional, repeat: repeat, capture: capture))
    self
  end

  def any_opt(repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(_) { true }, optional: true, repeat: repeat, capture: capture))
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

  def value_in_range(range, optional: false, repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(v) { range.include?(v) }, optional: optional, repeat: repeat, capture: capture))
    self
  end

  def value_of_type(type, optional: false, repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(v) { v.is_a?(type) }, optional: optional, repeat: repeat, capture: capture))
    self
  end

  def match_regexp(regexp, optional: false, repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(v) { v =~ regexp }, optional: optional, repeat: repeat, capture: capture))
    self
  end

  def present(optional: false, repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(v) { !v.nil? && v != '' }, optional: optional, repeat: repeat, capture: capture))
    self
  end

  def absent(optional: false, repeat: false, capture: true)
    add_subpattern(SubPattern.new(->(v) { v.nil? || v == '' }, optional: optional, repeat: repeat, capture: capture))
    self
  end
end
