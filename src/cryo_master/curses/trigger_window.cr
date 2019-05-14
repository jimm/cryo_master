require "crt"

class TriggerWindow < CrWindow
  def initialize(rows, cols, row, col)
    super(rows, cols, row, col, nil)
    @title = "Triggers "
  end

  def draw
    super
    i = 0
    CM.instance.inputs.each do |instrument|
      instrument.triggers.each do |trigger|
        if i < visible_height
          @win.print(i + 1, 1, make_fit(":#{instrument.sym} #{trigger.to_s}"))
        end
        i += 1
      end
    end
  end
end
