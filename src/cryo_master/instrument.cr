class Instrument
  MIDI_BUFSIZ = 128

  property sym : String
  property name : String
  property port_num : Int32
  property port : LibPortMidi::Stream

  def initialize(@sym, @name, @port_num, @port)
  end
end

class InputInstrument < Instrument
  SLEEP_TIMESPAN = Time::Span.new(nanoseconds: 1e7.to_i64) # 10 milliseconds

  property connections = Array(Connection).new
  property triggers = Array(Trigger).new

  def initialize(sym, name, port_num)
    LibPortMidi.open_input(out port, port_num, nil, MIDI_BUFSIZ, nil, nil)
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
    channel = Channel(Array(UInt8)).new
    # FIXME
    spawn generate(channel)
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
    status = PortMidi.message_status(msg)
    high_nibble = status & 0xf0
    chan = status & 0x0f
    data1 = PortMidi.message_data1(msg)

    # TODO
  end

  def connections_for_message(msg)
    # TODO
    @connections
  end

  # FIXME
  def generate(chan)
    buf = Array(LibPortMidi::Event).new(MIDI_BUFSIZ)
    while @running
      if LibPortMidi.poll(@port) == 1
        n = LibPortMidi.midi_read(@port, pointerof(buf).as(Pointer(Void*)), MIDI_BUFSIZ)
        read(buf, n)
      else
        sleep(SLEEP_TIMESPAN)
      end
    end
  end
end

class OutputInstrument < Instrument
  def initialize(sym, name, port_num)
    LibPortMidi.open_output(out port, port_num, nil, MIDI_BUFSIZ, nil, nil, 0)
    super(sym, name, port_num, port)
  end

  # def midi_out(bytes : Array(UInt8))
  #   LibPortMidi.midi_write(@port, pointerof(bytes), bytes.size)
  # end

  def midi_out(messages : Array(LibPortMidi::Message))
    messages.each { |msg| LibPortMidi.midi_write_short(@port, 0, msg) }
  end

  def midi_out(events : Array(LibPortMidi::Event))
    midi_out(events.map(&.message))
  end
end
