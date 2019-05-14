require "crt"

class InfoWindow < CrWindow
  CONTENTS = File.join(File.dirname(__FILE__), "info_window_contents.txt")

  @info_text : Array(String)
  getter text : Array(String)

  def initialize(rows, cols, row, col)
    super(rows, cols, row, col, nil)
    @info_text = File.read(CONTENTS).split("\n")
    @text = [] of String
  end

  def text=(str : Array(String)?)
    if str
      @text = str.not_nil!
      @title = "Song Notes"
    else
      @text = @info_text
      @title = "PatchMaster Help"
    end
  end

  def draw
    super
    i = 1
    @text.each do |line|
      break if i >= @win.row - 2
      @win.print(i + 1, 1, make_fit(" #{line.chomp}"))
      i += 1
    end
  end
end
