require "./nameable"

class Message < Nameable
  property messages = [] of LibPortMidi::Message
end
