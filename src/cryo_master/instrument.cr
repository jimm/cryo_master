require "./nameable"
require "./trigger"

class Instrument < Nameable
  MIDI_BUFSIZ = 128

  property sym : String
  property port_num : Int32
  property port : LibPortMIDI::Stream

  def initialize(@sym, name, @port_num, @port)
    super(name)
  end
end

class InputInstrument < Instrument
  SLEEP_TIMESPAN = Time::Span.new(nanoseconds: 2e6.to_i64) # 2 milliseconds

  property connections = Array(Connection).new
  property triggers = Array(Trigger).new

  def initialize(sym, name, port_num)
    LibPortMIDI.open_input(out port, port_num, nil, MIDI_BUFSIZ, nil, nil)
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

  def midi_in(bytes)
  end

  def read(buf, len)
    # TODO triggers
    (0...len).each do |i|
      msg = buf[i].message
      # TODO when testing, remember messages
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

  def connections_for_message(msg)
    # TODO
    @connections
  end

  def read_thread
    buf = Array(LibPortMIDI::Event).new(MIDI_BUFSIZ)
    while @running
      if LibPortMIDI.poll(@port) == 1
        n = LibPortMIDI.midi_read(@port, pointerof(buf).as(Pointer(LibPortMIDI::Event)), MIDI_BUFSIZ)
        read(buf, n)
      else
        sleep(SLEEP_TIMESPAN)
      end
    end
  end
end

class OutputInstrument < Instrument
  def initialize(sym, name, port_num)
    LibPortMIDI.open_output(out port, port_num, nil, MIDI_BUFSIZ, nil, nil, 0)
    super(sym, name, port_num, port)
  end

  # def midi_out(bytes : Array(UInt8))
  #   LibPortMIDI.midi_write(@port, pointerof(bytes), bytes.size)
  # end

  def midi_out(messages : Array(UInt32))
    messages.each { |msg| LibPortMIDI.midi_write_short(@port, 0, msg) }
  end

  def midi_out(events : Array(LibPortMIDI::Event))
    midi_out(events.map(&.message))
  end
end
