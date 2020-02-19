require "./nameable"

class Patch < Nameable
  property start_messages : Array(UInt32)
  property stop_messages : Array(UInt32)
  property connections = Array(Connection).new

  def initialize(name = "Default Patch",
                 @start_messages = [] of UInt32,
                 @stop_messages = [] of UInt32)
    super(name)
    @running = false
  end

  def add_connection(conn)
    @connections << conn
  end

  def inputs
    @connections.map(&.input).uniq
  end

  def start
    return if @running

    send_messages_to_outputs(@start_messages)
    @connections.each(&.start)
    @running = true
  end

  def running?
    @running
  end

  def stop
    return if !@running

    @connections.each(&.stop)
    send_messages_to_outputs(@stop_messages)
    @running = false
  end

  def send_messages_to_outputs(messages : Array(UInt32))
    outputs = [] of OutputInstrument
    @connections.each do |conn|
      outputs << conn.output
    end

    outputs.to_set.each { |out| out.midi_out(messages) }
  end
end
