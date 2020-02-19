require "./consts"
require "./instrument"
require "./controller"

macro is_status(b)
  (({{b}}) & 0x80) == 0x80
end

macro is_realtime(b)
  (({{b}}) >= 0xf8)
end

class Program
  IGNORE = 128_u8

  property bank_msb : UInt8
  property bank_lsb : UInt8
  property prog : UInt8

  def initialize(@bank_msb = IGNORE, @bank_lsb = IGNORE, @prog = IGNORE)
  end
end

class Connection
  include Consts

  IGNORE = 128_u8

  property input : InputInstrument
  property input_chan : UInt8
  property output : OutputInstrument
  property output_chan : UInt8
  property filter : String? # TODO
  property prog : Program
  property zone : Range(UInt8, UInt8)
  property xpose : Int32
  property cc_maps = Hash(UInt8, Controller).new

  NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

  def initialize(@input, @input_chan, @output, @output_chan, @filter = nil,
                 @prog = Program.new, @zone = (0_u8..127_u8), @xpose = 0)
    @pass_through_sysex = false
    @processing_sysex = false
  end

  def start
    if (@output_chan != IGNORE)
      if @prog
        prog = @prog.not_nil!
        messages = [] of UInt32
        messages << PortMIDI.message(CONTROLLER + output_chan,
          CC_BANK_SELECT_MSB,
          prog.bank_msb) unless prog.bank_msb == IGNORE
        messages << PortMIDI.message(CONTROLLER + output_chan,
          CC_BANK_SELECT_LSB,
          prog.bank_msb) if prog.bank_lsb != IGNORE
        messages << PortMIDI.message(PROGRAM_CHANGE + output_chan,
          prog.prog, 0) if prog.prog != IGNORE
        @output.midi_out(messages) unless messages.empty?
      end
    end
    @processing_sysex = false
    @input.add_connection(self)
  end

  def stop
    @input.remove_connection(self)
  end

  # The workhorse. Ignore bytes that aren't from our input, or are outside
  # the zone. Change to output channel. Filter.
  #
  # Note that running bytes are not handled, but unimidi doesn't seem to use
  # them anyway.
  #
  # Finally, we go through gyrations to avoid duping bytes unless they are
  # actually modified in some way.
  def midi_in(msg)
    return unless accept_from_input?(msg)

    bytes = PortMIDI.bytes(msg)
    status, data1, data2, data3 = bytes
    high_nibble = status & Consts::SYSEX

    @processing_sysex = true if status == Consts::SYSEX

    # If this is a sysex message, we may or may not filter it out. In any
    # case we pass through any realtime bytes in the sysex message.
    if @processing_sysex
      # If any byte is an EOX or if the first byte is a non-realtime status
      # byte, this is the end of the sysex message.
      if bytes.includes?(Consts::EOX) || (is_status(status) && !is_realtime(status))
        (is_status(status) && status < 0xf8 && status != Consts::SYSEX)
        @processing_sysex = false
      end

      if @pass_through_sysex
        @output.midi_out([msg])
        return
      end

      # If any of the bytes are realtime bytes AND if we are filtering out
      # sysex, send them.
      realtime_messages = bytes
        .select { |b| is_realtime(b) }
        .map { |b| PortMIDI.message(b, 0, 0) }
      @output.midi_out(realtime_messages) unless realtime_messages.empty?
      return
    end

    case high_nibble
    when NOTE_ON, NOTE_OFF, POLY_PRESSURE
      return unless @zone.includes?(data1)
      bytes[0] = high_nibble + @output_chan if @output_chan != IGNORE
      bytes[1] += xpose
    when CONTROLLER
      controller = @cc_maps[data1]?
      if controller
        bytes = controller.not_nil!.process(bytes, @output_chan)
      else
        if @output_chan != IGNORE
          bytes[0] = high_nibble + @output_chan if @output_chan != IGNORE
        end
      end
    when PROGRAM_CHANGE, CHANNEL_PRESSURE, PITCH_BEND
      bytes[0] = high_nibble + @output_chan if @output_chan != IGNORE
    end

    if bytes && bytes.size > 0
      @output.midi_out([PortMIDI.message(bytes[0], bytes[1], bytes[2])])
    else
    end
  end

  def add_controller(controller : Controller)
    cc_maps[controller.cc_num] = controller
  end

  # Returns `true` if any one of the following are true:
  # - we accept any input channel
  # - it's a system message, not a channel message
  # - the input channel matches our selected `input_chan`
  def accept_from_input?(msg)
    return true if @input_chan == IGNORE || @processing_sysex
    status = PortMIDI.status(msg)
    status >= Consts::SYSEX || (status & 0x0f) == @input_chan
  end

  def pc?
    @prog != nil
  end

  def note_num_to_name(n)
    oct = (n / 12) - 1
    note = NOTE_NAMES[n % 12]
    "#{note}#{oct}"
  end

  def to_s
    str = "#{@input.name} ch #{@input_chan ? @input_chan + 1 : "all"} -> #{@output.name} ch #{@output_chan + 1}"
    str << "; pc #@prog" if pc?
    str << "; xpose #@xpose" if @xpose
    str << "; zone #{note_num_to_name(@zone.begin)}..#{note_num_to_name(@zone.end)}" if @zone
    str
  end
end
