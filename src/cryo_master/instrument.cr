require "port_midi"
require "./nameable"
require "./trigger"
require "./consts"

class Instrument < Nameable
  MIDI_BUFSIZ = 128

  include Consts

  property sym : String
  property port_num : Int32
  property port : LibPortMIDI::Stream?
  property io_messages : Array(UInt32)

  def self.real_port?(num)
    num >= 0
  end

  def initialize(@sym, name, @port_num, @port)
    super(name)
    @io_messages = [] of UInt32
  end
end

class InputInstrument < Instrument
  SLEEP_TIMESPAN = Time::Span.new(nanoseconds: 2e6.to_i64) # 2 milliseconds

  property connections = Array(Connection).new
  property triggers = Array(Trigger).new
  getter note_off_conns : Array(Array(Array(Connection)?))
  getter sustain_off_conns : Array(Array(Connection)?)

  def initialize(sym, name, port_num)
    if Instrument.real_port?(port_num)
      LibPortMIDI.open_input(out port, port_num, nil, MIDI_BUFSIZ, nil, nil)
    else
      port = nil
    end
    @note_off_conns = (0...MIDI_CHANNELS).map do |chan|
      Array(Array(Connection)?).new(NOTES_PER_CHANNEL, nil)
    end
    @sustain_off_conns = Array(Array(Connection)?).new(MIDI_CHANNELS, nil)
    super(sym, name, port_num, port)
  end

  def add_connection(conn)
    @connections << conn
  end

  def remove_connection(conn)
    @connections.delete(conn)
  end

  def start
    @running = true
    spawn { read_thread() }
  end

  def stop
    @running = false
  end

  def read(buf, len)
    # TODO triggers
    (0...len).each do |i|
      msg = buf[i].message

      # TODO triggers

      # When testing, remember the messages we've seen. This could be made
      # more efficient by doing a bulk copy before or after this for loop,
      # making sure not to copy over the end of received_messages.
      @io_messages << msg if !Instrument.real_port?(@port_num)

      remember_program_change_messages(msg)
      connections_for_message(msg).each(&.midi_in(msg))
    end
  end

  def remember_program_change_messages(msg)
    status = PortMIDI.status(msg)
    high_nibble = status & 0xf0
    chan = status & 0x0f
    data1 = PortMIDI.data1(msg)

    # TODO
  end

  # Return the connections to use for *msg*. Normally it's the same as our
  # list of connections. However for every note on we store those
  # connections so we can use them later for the corresponding note off.
  # Same for sustain controller messages.
  def connections_for_message(msg) : Array(Connection)
    status = PortMIDI.status(msg)
    high_nibble = status & 0xf0
    chan = status & 0x0f
    data1 = PortMIDI.data1(msg)

    # Note off messages must be sent to their original connections, so for
    # incoming note on messages we store the current connections in
    # note_off_conns.
    case high_nibble
    when NOTE_OFF
      return @note_off_conns[chan][data1].not_nil!
    when NOTE_ON
      # Velocity 0 means we should use the note-off connections.
      return @note_off_conns[chan][data1].not_nil! if PortMIDI.data2(msg) == 0
      @note_off_conns[chan][data1] = @connections.dup
      return @connections
    when CONTROLLER
      if data1 == CC_SUSTAIN
        return @sustain_off_conns[chan].not_nil! if PortMIDI.data2(msg) == 0
        @sustain_off_conns[chan] = @connections.dup
      end
      return @connections
    else
      return @connections
    end
  end

  def read_thread
    buf = Array(LibPortMIDI::Event).new(MIDI_BUFSIZ)
    while @running
      if Instrument.real_port?(@port_num) && LibPortMIDI.poll(@port.not_nil!) == 1
        n = LibPortMIDI.midi_read(@port.not_nil!, pointerof(buf).as(Pointer(LibPortMIDI::Event)), MIDI_BUFSIZ)
        read(buf, n)
      else
        sleep(SLEEP_TIMESPAN)
      end
    end
  end
end

class OutputInstrument < Instrument
  def initialize(sym, name, port_num)
    if Instrument.real_port?(port_num)
      LibPortMIDI.open_output(out port, port_num, nil, MIDI_BUFSIZ, nil, nil, 0)
    else
      port = nil
    end
    super(sym, name, port_num, port)
  end

  # def midi_out(bytes : Array(UInt8))
  #   LibPortMIDI.midi_write(@port, pointerof(bytes), bytes.size)
  # end

  def midi_out(messages : Array(UInt32))
    if Instrument.real_port?(@port_num)
      messages.each { |msg| LibPortMIDI.midi_write_short(@port.not_nil!, 0, msg) }
    else
      @io_messages += messages
    end
  end

  def midi_out(events : Array(LibPortMIDI::Event))
    midi_out(events.map(&.message))
  end
end
