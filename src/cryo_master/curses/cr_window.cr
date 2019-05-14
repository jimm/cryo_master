require "crt"

class CrWindow
  getter win : Crt::Window
  getter title_prefix : String?
  property title : String?
  @rows : Int32
  @cols : Int32
  @row : Int32
  @col : Int32

  forward_missing_to(@win)

  # If title is nil then list's name will be used
  def initialize(@rows, @cols, @row, @col, @title_prefix)
    @win = Crt::Window.new(rows, cols, row, col)
    @title_prefix = title_prefix
    @max_contents_len = 0
    set_max_contents_len(cols)
    @title = ""
  end

  def move_and_resize(rect)
    @win.move(rect[2], rect[3])
    @win.resize(rect[0], rect[1])
    set_max_contents_len(rect[1])
  end

  def draw
    @win.clear
    @win.border
    return unless @title_prefix || @title

    @win.move(0, 1)
    @win.attribute_on(Crt::Attribute::Reverse)
    @win.print(" ")
    @win.print("#{@title_prefix}: ") if @title_prefix
    @win.print(@title.not_nil!) if @title
    @win.print(" ")
    @win.attribute_off(Crt::Attribute::Reverse)
  end

  # Visible height is height of window minus 2 for the borders.
  def visible_height
    @win.row - 2
  end

  def set_max_contents_len(cols)
    @max_contents_len = cols - 3 # 2 for borders
  end

  def make_fit(str)
    str = str[0..@max_contents_len] if str.size > @max_contents_len
    str
  end
end
