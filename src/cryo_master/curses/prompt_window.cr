require "crt"

class PromptWindow
  MAX_WIDTH = 30

  def initialize(title : String, prompt : String)
    @title, @prompt = title, prompt
    width = Crt.x // 2
    width = MAX_WIDTH if width > MAX_WIDTH
    @win = Crt::Window.new(4, width, Crt.y // 3, (Crt.x - width) // 2)
  end

  def gets
    draw
    read_string
  end

  def draw
    @win.border

    @win.attribute_on(Crt::Attribute::Reverse)
    @win.print(0, 1, " #@title ")
    @win.attribute_off(Crt::Attribute::Reverse)

    @win.print(1, 1, @prompt)

    @win.attribute_on(Crt::Attribute::Reverse)
    @win.print(2, 1, " " * (@win.col - 2))
    @win.attribute_off(Crt::Attribute::Reverse)

    @win.move(2, 1)
    @win.refresh
  end

  def read_string
    LibNcursesw.nocbreak
    LibNcursesw.echo
    LibNcursesw.curs_set(1)
    @win.attribute_on(Crt::Attribute::Reverse)

    bytes = Pointer(UInt8).malloc(1024)
    LibNcursesw.getnstr(bytes, 1024)
    str = String.new(bytes)

    @win.attribute_off(Crt::Attribute::Reverse)
    LibNcursesw.curs_set(0)
    LibNcursesw.noecho
    LibNcursesw.cbreak
    str
  end
end
