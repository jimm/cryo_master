require "./consts"
require "./instrument"
require "./controller"

class Connection
  include Consts

  IGNORE = 128_u8

  property input : InputInstrument
  property input_chan : Int32
  property output : OutputInstrument
  property output_chan : Int32
  property filter : String?     # TODO
  property bank_msb : UInt8     # may be IGNORE
  property bank_lsb : UInt8     # ditto
  property pc_prog : UInt8      # ditto
  property zone : Range(UInt8, UInt8)
  property xpose : Int32
  property cc_maps = Hash(UInt8, Controller).new

  NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

  def initialize(@input, @input_chan, @output, @output_chan, @filter = nil,
                 @bank_msb = IGNORE, @bank_lsb = IGNORE, @pc_prog = IGNORE,
                 @zone = (0_u8..127_u8), @xpose = 0)
  end

  def start(start_messages : Array(LibPortMidi::Message))
    messages = [] of LibPortMidi::Message
    messages += start_messages if start_messages
    messages << PortMidi.message(CONTROLLER + @output_chan,
                                 CC_BANK_SELECT_MSB,
                                 @bank_msb) unless @bank_msb == IGNORE
    messages << PortMidi.message(CONTROLLER + @output_chan,
                                 CC_BANK_SELECT_LSB,
                                 @bank_msb) if @bank_lsb != IGNORE
    messages << PortMidi.message(PROGRAM_CHANGE + @output_chan,
                                 @pc_prog, 0) if @pc_prog != IGNORE
    @output.midi_out(messages) unless messages.empty?
    @input.add_connection(self)
  end

  def stop(stop_bytes)
    @output.midi_out(stop_bytes) if stop_bytes
    @input.remove_connection(self)
  end

  def accept_from_input?(msg)
    return true if @input_chan == nil
    status = PortMidi.message_status(msg)
    return true unless status < 0xf0_u8
    (status & 0xff) == @input_chan
  end

  # Returns true if the +@zone+ is nil (allowing all notes throught) or if
  # +@zone+ is a Range and +note+ is inside +@zone+.
  def inside_zone?(note)
    @zone == nil || @zone.includes?(note)
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

    bytes_duped = false

    bytes = PortMidi.message_to_bytes(msg)
    high_nibble = bytes[0] & 0xF0_u8
    case high_nibble
    when NOTE_ON, NOTE_OFF, POLY_PRESSURE
      return unless inside_zone?(bytes[1])

      if bytes[0] != high_nibble + @output_chan || (@xpose && @xpose != 0)
        duped_bytes = bytes.dup
        bytes = duped_bytes
        bytes_duped = true
      end

      bytes[0] = high_nibble + @output_chan
      bytes[1] = ((bytes[1] + @xpose) & 0xff) if @xpose
    when CONTROLLER, PROGRAM_CHANGE, CHANNEL_PRESSURE, PITCH_BEND
      if bytes[0] != high_nibble + @output_chan
        bytes = bytes.dup
        bytes_duped = true
        bytes[0] = high_nibble + @output_chan
      end
    end

    # We can't tell if a filter will modify the bytes, so we have to assume
    # they will be. If we didn't, we'd have to rely on the filter duping the
    # bytes and returning the dupe.
    if @filter
      if !bytes_duped
        bytes = bytes.dup
        bytes_duped = true
      end
      # TODO
      # bytes = @filter.not_nil!.call(self, bytes)
    end

    if bytes && bytes.size > 0
      @output.midi_out([PortMidi.message(bytes[0], bytes[1], bytes[2])])
    end
  end

  def pc?
    @pc_prog != nil
  end

  def note_num_to_name(n)
    oct = (n / 12) - 1
    note = NOTE_NAMES[n % 12]
    "#{note}#{oct}"
  end

  def to_s
    str = "#{@input.name} ch #{@input_chan ? @input_chan+1 : "all"} -> #{@output.name} ch #{@output_chan+1}"
    str << "; pc #@pc_prog" if pc?
    str << "; xpose #@xpose" if @xpose
    str << "; zone #{note_num_to_name(@zone.begin)}..#{note_num_to_name(@zone.end)}" if @zone
    str
  end
end
