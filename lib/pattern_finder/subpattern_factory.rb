# frozen_string_literal: true

# Collection of methods to create subpatterns
module SubPatternFactory
  def any(optional: false, repeat: false)
    add_subpattern(SubPattern.new(->(_) { true }, optional: optional, repeat: repeat))
    self
  end

  def any_opt(repeat: false)
    add_subpattern(SubPattern.new(->(_) { true }, optional: true, repeat: repeat))
    self
  end

  def contains(substring, optional: false, repeat: false)
    add_subpattern(SubPattern.new(->(v) { v.to_s.include?(substring) }, optional: optional, repeat: repeat))
    self
  end

  def value_eq(value, optional: false, repeat: false)
    add_subpattern(SubPattern.new(->(v) { v == value }, optional: optional, repeat: repeat))
    self
  end

  def value_in_range(range, optional: false, repeat: false)
    add_subpattern(SubPattern.new(->(v) { range.include?(v) }, optional: optional, repeat: repeat))
    self
  end

  def value_of_type(type, optional: false, repeat: false)
    add_subpattern(SubPattern.new(->(v) { v.is_a?(type) }, optional: optional, repeat: repeat))
    self
  end

  def match_regexp(regexp, optional: false, repeat: false)
    add_subpattern(SubPattern.new(->(v) { v =~ regexp }, optional: optional, repeat: repeat))
    self
  end

  def present(optional: false, repeat: false)
    add_subpattern(SubPattern.new(->(v) { !v.nil? && v != '' }, optional: optional, repeat: repeat))
    self
  end
end
