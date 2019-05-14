require "../nameable"
require "./cr_window"

class ListWindow < CrWindow
  getter list : Array(Nameable)?

  def initialize(rows, cols, row, col, title_prefix)
    super
    @offset = 0
    @list = [] of Nameable
  end

  # +curr_item_method_sym+ is a method symbol that is sent to
  # `CM.instance` to obtain the current item so we can highlight it.
  def set_contents(title : String?, list : Array(Nameable)?, curr_item : Nameable?)
    @title, @list, @curr_item = title, list, curr_item
    draw
  end

  def draw
    super
    return unless @list
    return unless @curr_item

    curr_index = @list.not_nil!.index(@curr_item).not_nil!
    if curr_index < @offset
      @offset = curr_index
    elsif curr_index >= @offset + visible_height
      @offset = curr_index - visible_height + 1
    end

    @list.not_nil![@offset, visible_height].each_with_index do |thing, i|
      @win.attribute_on(Crt::Attribute::Reverse) if thing == @curr_item
      @win.print(i + 1, 1, make_fit(" #{thing.name} "))
      @win.attribute_off(Crt::Attribute::Reverse) if thing == @curr_item
    end
  end
end
