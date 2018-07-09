class Controller
  IGNORE = 128_u8

  include Consts

  property cc_num : UInt8 = IGNORE
  property translated_cc_num : UInt8 = IGNORE # IGNORE means no translation
  property min : UInt8 = 0_u8
  property max : UInt8 = 127_u8
  property? filtered = false

  # Returns true if this controller will modify the original by filtering,
  # translating, or clamping.
  def will_modify?
    filtered || translated_cc_num != IGNORE || min != 0 || max != IGNORE
  end

  # Returns a message if there's something to send, else nil
  def process(msg : LibPortMidi::Message, output_channel : UInt8) : LibPortMidi::Message?
    return nil if filtered

    status = CONTROLLER
    data1 = message_data1(msg)
    data2 = message_data2(msg)

    if output_chan != IGNORE
      status += output_chan
    else
      status += data1 & 0x0f
    end

    if translated_cc_num != IGNORE
      data1 = translated_cc_num
    end

    message(status, data, clamp(data2))
  end

  def clamp(val : UInt8)
    if val < min
      min
    elsif val > max
      max
    else
      val
    end
  end
end
