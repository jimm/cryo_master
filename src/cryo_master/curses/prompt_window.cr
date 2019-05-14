require "crt"

class PromptWindow
  MAX_WIDTH = 30

  def initialize(title, prompt)
    @title, @prompt = title, prompt
    width = cols() / 2
    width = MAX_WIDTH if width > MAX_WIDTH
    @win = Crt::Window.new(4, width, lines() / 3, (cols() - width) / 2)
  end

  def gets
    draw
    str = read_string
    cleanup
    str
  end

  def draw
    @win.border

    @win.attribute_on(Crt::Attribute::Reverse)
    @win.print(0, 1, " #@title ")
    @win.attribute_off(Crt::Attribute::Reverse)

    @win.print(1, 1, @prompt)

    @win.attribute_on(Crt::Attribute::Reverse)
    @win.print(2, 1, ' ' * (@win.col - 2))
    @win.attribute_off(Crt::Attribute::Reverse)

    @win.move(2, 1)
    @win.refresh
  end

  def read_string
    nocbreak
    echo
    curs_set(1)
    str = nil
    @win.attron(A_REVERSE) {
      str = @win.getstr
    }
    curs_set(0)
    noecho
    cbreak
    str
  end

  def cleanup
    @win.close
  end
end
