require "crt"

# Defines positions and sizes of windows. Rects contain [height, width, top,
# left], which is the order used by Curses::Window.new.
class Geometry

  @top_height : Int32
  @bot_height : Int32
  @top_width : Int32
  @sls_height : Int32
  @sl_height : Int32
  @info_width : Int32
  @info_left : Int32

  def initialize
    @top_height = (Crt.y - 1) * 2 / 3
    @bot_height = (Crt.y - 1) - @top_height
    @top_width = Crt.x / 3

    @sls_height = @top_height / 3
    @sl_height = @top_height - @sls_height

    @info_width = Crt.x - (@top_width * 2)
    @info_left = @top_width * 2
  end

  def song_list_rect
    {@sl_height, @top_width, 0, 0}
  end

  def song_rect
    {@sl_height, @top_width, 0, @top_width}
  end

  def song_lists_rect
    {@sls_height, @top_width, @sl_height, 0}
  end

  def trigger_rect
    {@sls_height, @top_width, @sl_height, @top_width}
  end

  def patch_rect
    {@bot_height, Crt.x, @top_height, 0}
  end

  def message_rect
    {1, Crt.x, Crt.y-1, 0}
  end

  def info_rect
    {@top_height, @info_width, 0, @info_left}
  end

  def help_rect
    {Crt.y - 6, Crt.x - 6, 3, 3}
  end
end
