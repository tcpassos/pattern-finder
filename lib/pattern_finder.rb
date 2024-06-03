# frozen_string_literal: true

require_relative 'pattern_finder/subpattern'
require_relative 'pattern_finder/subpattern_factory'
require_relative 'pattern_finder/pattern'
require_relative 'pattern_finder/scanner'

p = Pattern.new do
  value_eq_opt(:set_flag, repeat: true, allow_gaps: true, stop_condition: ->(v) { %i[move_input perform].include?(v) })
  value_eq(:move_input)
  value_eq_opt(:set_flag, repeat: true)
end

v = %i[
  set_flag
  outra_coisa
  set_flag
  move_input
  set_flag
  outra_coisa
  perform
  outra_coisa
  move_output
  move_output
  outra_coisa
  set_flag
  move_input
  perform
  move_output
]

s = Scanner.new(v)

until s.eov?
  m = s.scan_until(p)
  break unless m

  puts
  puts 'Matched:'
  m.each_with_index do |e, i|
    puts "#{i}: #{e}"
  end
end
