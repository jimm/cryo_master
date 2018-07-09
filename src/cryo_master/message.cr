class Message
  property name : String
  property messages = [] of LibPortMidi::Message

  def initialize(@name)
  end
end
