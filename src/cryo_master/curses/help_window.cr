require "crt"

class HelpWindow < CrWindow
  CONTENTS = File.join(File.dirname(__FILE__), "info_window_contents.txt")

  getter text : String

  def initialize(rows, cols, row, col)
    super(rows, cols, row, col, nil)
    @text = File.read(CONTENTS)
    @title = "PatchMaster Help"
  end

  def draw
    super
    i = 0
    @text.each_line do |line|
      @win.print(i + 2, 3, make_fit(line.chomp))
      i += 1
    end
  end
end
