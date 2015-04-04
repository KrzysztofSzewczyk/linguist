require_relative "./helper"

class TestColorThreshold < Minitest::Test
  include Linguist

  def cut_hash(color)
    color[1..-1]
  end

  def test_color_threshold
    langs_with_colors = Language.all.reject { |language| language.color.nil? }
    cp = ColorProximity.new(0.02, langs_with_colors.map { |lang| cut_hash(lang.color) })
    failing_threshold = langs_with_colors.map do |lang|
      state = cp.past_threshold?(cut_hash(lang.color))
      if !state.first && lang.color != "##{state.last.first}"
        "- #{lang} (#{lang.color}) is too close to #{state.last}"
      end
    end.compact
    message = "The following languages have failing color thresholds. Please modify the hex color.\n#{failing_threshold.join("\n")}"

    assert failing_threshold.empty?, message
  end
end
