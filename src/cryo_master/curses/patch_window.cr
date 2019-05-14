class PatchWindow < CrWindow
  getter patch : Patch?

  def patch=(@patch)
    @title = @patch.try(&.name) || "Untitled"
    draw
  end

  def draw
    super
    @win.move(1, 1)
    draw_headers
    return unless @patch

    @patch.not_nil!.connections[0, visible_height].each_with_index do |connection, i|
      @win.move(i + 2, 1)
      draw_connection(connection)
    end
  end

  def draw_headers
    @win.attribute_on(Crt::Attribute::Reverse)
    str = " Input          Chan | Output         Chan | Prog | Zone      | Xpose | Filter"
    str += " " * (@win.col - 2 - str.size)
    @win.print(str)
    @win.attribute_off(Crt::Attribute::Reverse)
  end

  def draw_connection(connection)
    str = String.build do |io|
      io << " #{"%16s" % connection.input.name}"
      io << " #{connection.input_chan ? ("%2d" % (connection.input_chan + 1)) : "  "} |"
      io << " #{"%16s" % connection.output.name}"
      io << " #{"%2d" % (connection.output_chan + 1)} |"
      io << if connection.pc?
        "  #{"%3d" % connection.pc_prog} |"
      else
        "      |"
      end
      io << if connection.zone
        " #{"%3s" % connection.note_num_to_name(connection.zone.begin)}" +
        " - #{"%3s" % connection.note_num_to_name(connection.zone.end)} |"
      else
        "           |"
      end
      io << if connection.xpose && connection.xpose != 0
        "   #{connection.xpose < 0 ? "" : " "}#{"%2d" % connection.xpose.to_i} |"
      else
        "       |"
      end
      io << " #{filter_string(connection.filter)}"
    end
    @win.print(make_fit(str))
  end

  def filter_string(filter)
    filter.to_s.gsub(/\s*#.*/, "").gsub(/\n\s*/, "; ")
  end
end
