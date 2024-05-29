# frozen_string_literal: true

# Collection of default subpatterns
module DefaultSubPatterns
  def any(optional: false, repeat: false)
    new(->(_) { true }, optional: optional, repeat: repeat)
  end

  def any_required(repeat: false)
    new(->(_) { true }, optional: false, repeat: repeat)
  end

  def any_optional(repeat: false)
    new(->(_) { true }, optional: true, repeat: repeat)
  end
end
