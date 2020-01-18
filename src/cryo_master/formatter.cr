module Formatter
  NOTE_NAMES   = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
  NOTE_OFFSETS = [9, 11, 0, 2, 4, 5, 7]

  def note_num_to_name(num : UInt8)
    oct = (num.to_i // 12) - 1
    note = NOTE_NAMES[num.to_i % 12]
    "#{note}#{oct}"
  end

  def note_name_to_num(str : String) : UInt8
    ch = str[0].downcase
    return str.to_u8 if ch >= '0' && ch <= '9' # what happened to Char.digit?
    return 0_u8 unless ch >= 'a' && ch <= 'g'

    from_c = NOTE_OFFSETS[ch.ord - 'a'.ord]
    accidental = 0
    num_start = str[1..].downcase
    case num_start[0]
    when 's', '#'
      accidental = 1
      num_start = num_start[1..]
    when 'f', 'b'
      accidental = -1
      num_start = num_start[1..]
    end

    octave = (num_start.to_i + 1) * 12
    ((octave + from_c + accidental) & 0xff).to_u8
  end

  # TODO for GUI
  def format_program
  end

  # TODO for GUI
  def format_program_no_spaces
  end
end
