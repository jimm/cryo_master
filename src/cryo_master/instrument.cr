require "port_midi"
require "./nameable"
require "./trigger"

class Instrument < Nameable
  MIDI_BUFSIZ = 128

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

  def initialize(sym, name, port_num)
    if Instrument.real_port?(port_num)
      LibPortMIDI.open_input(out port, port_num, nil, MIDI_BUFSIZ, nil, nil)
    else
      port = nil
    end
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

  def connections_for_message(msg)
    # TODO
    @connections
  end

  def read_thread
    buf = Array(LibPortMIDI::Event).new(MIDI_BUFSIZ)
    while @running
      if Input.real_port?(@port_num) && LibPortMIDI.poll(@port.not_nil!) == 1
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
