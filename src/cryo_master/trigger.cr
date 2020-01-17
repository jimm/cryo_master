class Trigger
  enum Action
    NEXT_SONG
    PREV_SONG
    NEXT_PATCH
    PREV_PATCH
    MESSAGE
  end

  getter trigger_msg : UInt32
  getter action : Action
  getter output_message : Message?

  def initialize(@trigger_msg, @action, @output_message)
  end
end
