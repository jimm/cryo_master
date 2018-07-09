class Trigger
  enum Action
    NEXT_SONG
    PREV_SONG
    NEXT_PATCH
    PREV_PATCH
    MESSAGE
  end

  def initialize(@trigger_msg : LibPortMidi::Message,
                 @action : Action,
                 @output_msg : Message?)
    @trigger_msg = trigger_msg
    @action = action
    @output_msg = output_msg
  end
end
