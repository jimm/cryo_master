class Controller
  IGNORE = 128_u8

  include Consts

  property cc_num : UInt8
  property translated_cc_num : UInt8 = IGNORE # IGNORE means no translation
  property min : UInt8 = 0_u8
  property max : UInt8 = 127_u8
  property? filtered = false

  def initialize(@cc_num)
    @translated_cc_num = @cc_num
  end

  # Returns true if this controller will modify the original by filtering,
  # translating, or clamping.
  def will_modify?
    filtered? || @translated_cc_num != @cc_num || @min != 0_u8 || @max != 127_u8
  end

  # Returns bytes if there's something to send, else nil
  def process(bytes : Array(UInt8), output_channel : UInt8) : Array(UInt8)?
    return nil if filtered?

    processed = [CONTROLLER, @translated_cc_num, clamp(bytes[2]), 0_u8]
    if output_channel != IGNORE
      processed[0] = (processed[0] & 0xf0) + output_channel
    end
    processed
  end

  def clamp(val : UInt8) : UInt8
    if val < min
      min
    elsif val > max
      max
    else
      val
    end
  end
end
