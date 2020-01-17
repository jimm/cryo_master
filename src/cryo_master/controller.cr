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
    filtered? || translated_cc_num != IGNORE || min != 0 || max != IGNORE
  end

  # Returns a message if there's something to send, else nil
  def process(bytes, output_channel : UInt8) : UInt32?
    return nil if filtered?

    status = CONTROLLER
    data1 = bytes[1]
    data2 = bytes[2]

    if output_channel != IGNORE
      status += output_channel
    else
      status += bytes[0] & 0x0f
    end

    if translated_cc_num != IGNORE
      data1 = translated_cc_num
    end

    PortMIDI.message(status, data1, clamp(data2))
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
