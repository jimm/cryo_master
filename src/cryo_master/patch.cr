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
    unless @running
      @connections.each { |conn| conn.start(@start_messages) }
      @running = true
    end
  end

  def running?
    @running
  end

  def stop
    if @running
      @running = false
      @connections.each { |conn| conn.stop(@stop_messages) }
    end
  end
end
