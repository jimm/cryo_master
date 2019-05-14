require "./connection"
require "./formatter"

class Loader
  include Formatter

  enum InstrumentDirection
    INPUT
    OUTPUT
  end

  enum Section
    IGNORE
    INSTRUMENTS
    MESSAGES
    TRIGGERS
    SONGS
    SET_LISTS
  end

  enum NoteState
    OUTSIDE
    SKIPPING_BLANK_LINES
    COLLECTING
  end

  enum StartStopState
    UNSTARTED
    START_MESSAGES
    STOP_MESSAGES
  end

  struct Markup
    property header_char : Char
    property list_chars : String
    property block_marker_prefix : String

    def initialize(@header_char, @list_chars, @block_marker_prefix)
    end
  end

  ORG_MODE_MARKUP      = Markup.new('*', "-*+", "#+")
  MARKDOWN_MODE_MARKUP = Markup.new('#', "-*+", "```")

  WHITESPACE = / \t/

  TRIGGER_ACTIONS = {
    "next song"      => Trigger::Action::NEXT_SONG,
    "prev song"      => Trigger::Action::PREV_SONG,
    "previous song"  => Trigger::Action::PREV_SONG,
    "next patch"     => Trigger::Action::NEXT_PATCH,
    "prev patch"     => Trigger::Action::PREV_PATCH,
    "previous patch" => Trigger::Action::PREV_PATCH,
    "message"        => Trigger::Action::MESSAGE,
  }

  @cm = CM.new
  @song = Song.new
  @patch = Patch.new
  @conn : Connection?
  @message = Message.new("dummy")
  @error_str = ""
  @markup = ORG_MODE_MARKUP
  @notes = [] of String

  def initialize
    clear
  end

  def load(path : String, testing : Bool)
    retval = 0
    error_str = ""

    old_cm = CM.instance
    @cm = CM.new # side-effect: CM static instance set
    File.open(path, "r") do |f|
      determine_markup(path)
      @cm.loaded_from_file = path
      @cm.testing = testing
      clear
      while !error? && (line = f.gets(true)) != nil
        parse_line(line) if line
      end
      ensure_song_has_patch
    end
    @cm
  end

  def error?
    @error_str != ""
  end

  def error
    @error_str
  end

  def clear
    ensure_song_has_patch

    @section = Section::IGNORE
    @notes_state = NoteState::OUTSIDE
    @song_list = nil : SongList
    @song = Song.new
    @patch = Patch.new
    @conn = nil
    @message = Message.new("dummy")
    @notes = Array(String).new
  end

  def enter_section(sec)
    clear()
    @section = sec
  end

  def parse_line(line : String)
    start = 0
    if @notes_state == NoteState::OUTSIDE
      return if line.strip.empty? || markup_block_command?(line)
    end

    # Header lines must start at beginning of the line, so don't skip past
    # whitespace quite yet.

    if header_level?(line, 1)
      if header?(line, "Instruments", 1)
        enter_section(Section::INSTRUMENTS)
        return
      end
      if header?(line, "Messages", 1)
        enter_section(Section::MESSAGES)
        return
      end
      if header?(line, "Triggers", 1)
        enter_section(Section::TRIGGERS)
        return
      end
      if header?(line, "Songs", 1)
        enter_section(Section::SONGS)
        return
      end
      if header?(line, "Set Lists", 1)
        enter_section(Section::SET_LISTS)
        return
      end
      enter_section(Section::IGNORE)
      return
    end

    # Now we can strip leading whitespace.
    line = line.strip

    case @section
    when Section::INSTRUMENTS
      parse_instrument_line(line)
    when Section::MESSAGES
      parse_message_line(line)
    when Section::TRIGGERS
      parse_trigger_line(line)
    when Section::SONGS
      parse_song_line(line)
    when Section::SET_LISTS
      parse_set_list_line(line)
    end
  end

  def parse_instrument_line(line)
    return unless table_row?(line)

    cols = table_columns(line)
    case cols[0]
    when "in"
      load_instrument(cols, InstrumentDirection::INPUT)
    when "out"
      load_instrument(cols, InstrumentDirection::OUTPUT)
    end
  end

  def parse_message_line(line)
    if header_level?(line, 2)
      @message = Message.new(line[3..-1])
      @message.messages << message_from_bytes(line)
      @cm.messages << @message
      return
    end
  end

  def parse_trigger_line(line)
    return unless table_row?(line)

    cols = table_columns(line)
    cols[0].downcase
    input = @cm.inputs.find { |i| i.sym.downcase == cols[0] }
    return unless input # might be table header, not an error

    trigger_msg = message_from_bytes(cols[1])
    output_msg = nil : UInt32
    action = TRIGGER_ACTIONS[cols[2]]
    if action == Trigger::Action::MESSAGE
      output_msg = @cm.messages.find { |m| m.name.downcase == cols[3].downcase }
      if output_msg == nil
        error_str = "trigger can not find message named #{cols[3]}"
        return
      end
    end

    input.triggers << Trigger.new(trigger_msg, action, output_msg)
  end

  def message_from_bytes(str : String)
    bytes = str.split(/[, ]/).map { |word| word.strip.to_u8(prefix: true) }
    PortMIDI.message(bytes[0], bytes[1], bytes[2])
  end

  def parse_song_line(line : String)
    if (header_level?(line, 2))
      load_song(line[3..-1])
    elsif (header_level?(line, 3))
      load_patch(line[4..-1])
    elsif (header_level?(line, 4))
      load_connection(line[5..-1])
    elsif (@notes_state != NoteState::OUTSIDE)
      save_notes_line(line)
    elsif list_item?(line) && @conn != nil
      line = line[2..-1]
      case line[0]
      when 'b'
        load_bank(line)
      when 'p'
        load_prog(line)
      when 'x'
        load_xpose(line)
      when 'z'
        load_zone(line)
      when 'c'
        load_controller(line)
      end
    end
  end

  def parse_set_list_line(line : String)
    if header_level?(line, 2)
      load_song_list(line[3..-1])
    elsif list_item?(line)
      load_song_list_song(line[2..-1])
    end
  end

  def load_instrument(cols : Array(String), type : InstrumentDirection)
    devid : Int32 = find_device(cols[1], type)

    if devid == LibPortMIDI::PmError::InvalidDeviceId && !@cm.testing?
      @error_str = "MIDI port #{cols[1]} not found"
      return
    end

    sym = cols[0]
    name = cols[3]
    case type
    when InstrumentDirection::INPUT
      @cm.inputs << InputInstrument.new(sym, name, devid)
    when InstrumentDirection::OUTPUT
      @cm.outputs << OutputInstrument.new(sym, name, devid)
    end
  end

  def load_message(line : String)
    # TODO
  end

  def load_song(line : String)
    ensure_song_has_patch if @song

    s = Song.new(line)
    @cm.all_songs.songs << s
    puts "added song #{s.name} to all_songs, size = #{@cm.all_songs.songs.size}" # DEBUG
    @song = s
    @patch = Patch.new
    @conn = nil : Connection
    start_collecting_notes
  end

  def save_notes_line(line : String)
    if @notes_state == NoteState::SKIPPING_BLANK_LINES
      return unless line.starts_with?(WHITESPACE)
    end

    @notes_state = NoteState::COLLECTING
    @notes << line
  end

  def start_collecting_notes
    @notes_state = NoteState::SKIPPING_BLANK_LINES
    @notes.clear
  end

  def stop_collecting_notes
    # remove trailing blank lines
    while !@notes.empty? && @notes.last == ""
      @notes.pop
    end
    @notes_state = NoteState::OUTSIDE
  end

  def load_patch(line : String)
    stop_collecting_notes
    if !@notes.empty?
      @song.notes = @notes
      @notes.clear # do not dealloc
    end

    p = Patch.new(line)
    @song.patches << p
    @patch = p
    @conn = nil

    start_collecting_notes
  end

  def load_connection(line : String)
    stop_collecting_notes
    if !@notes.empty? && @conn == nil # first conn, interpret start/stop in notes
      start_and_stop_messages_from_notes
    end

    args = comma_sep_args(line, false)
    input = @cm.inputs.find { |i| i.sym.downcase == args[0].downcase }
    unless input
      instrument_not_found("input", args[0])
      return
    end
    in_chan = chan_from_word(args[1])
    output = @cm.outputs.find { |i| i.sym.downcase == args[2].downcase }
    unless output
      instrument_not_found("output", args[2])
      return
    end
    out_chan = chan_from_word(args[3])

    @conn = Connection.new(input, in_chan, output, out_chan)
    @patch.connections << @conn.not_nil!
  end

  def start_and_stop_messages_from_notes
    state = StartStopState::UNSTARTED
    @notes.each do |note|
      str = note.strip
      next if str.empty?

      case str.downcase
      when "start"
        state = StartStopState::START_MESSAGES
      when "stop"
        state = StartStopState::STOP_MESSAGES
      else
        case state
        when StartStopState::START_MESSAGES
          @patch.start_messages << message_from_bytes(str)
        when StartStopState::STOP_MESSAGES
          @patch.stop_messages << message_from_bytes(str)
        when StartStopState::UNSTARTED
          break
        end
      end
    end
    @notes.clear
  end

  def instrument_not_found(type_name : String, sym : String)
    error_str = "song #{@song.name}, patch #{@patch.name}: #{type_name} #{sym} not found"
  end

  def load_prog(line : String)
    @conn.not_nil!.pc_prog = line.split(WHITESPACE)[1].to_u8
  end

  def load_bank(line : String)
    args = comma_sep_args(line, true)
    @conn.not_nil!.bank_msb = args[0].to_u8
    @conn.not_nil!.bank_lsb = args[1].to_u8
  end

  def load_xpose(line : String)
    @conn.not_nil!.xpose = line.split(WHITESPACE)[1].to_i
  end

  def load_zone(line : String)
    args = comma_sep_args(line, true)
    @conn.not_nil!.zone = (note_name_to_num(args[0])..note_name_to_num(args[1]))
  end

  def load_controller(line : String)
    args = whitespace_sep_args(line)
    cc = @conn.not_nil!.cc_maps[args[0].to_i]
    args = whitespace_sep_args(line)
    skip = 0
    args.each_with_index do |args, i|
      if skip > 0
        skip -= 1
        next
      end
      case args[0]
      when 'f' # filter
        cc.filtered = true
      when 'm' # map
        cc.translated_cc_num = args[i + 1].to_u8
        skip = 1
      when 'l' # limit
        cc.min = args[i + 1].to_u8
        cc.max = args[i + 2].to_u8
        skip = 2
      end
    end
  end

  def load_song_list(line : String)
    @song_list = SongList.new(line)
    @cm.song_lists << @song_list.not_nil!
  end

  def load_song_list_song(line : String)
    line = line.downcase
    s = @cm.all_songs.songs.find { |s| s.name.downcase == line }
    unless s
      error_str = "set list #{@song_list.try(&.name)} can not find song named #{line}"
      return
    end

    @song_list.not_nil!.songs << s
  end

  def ensure_song_has_patch
    return if @song == nil || !@song.patches.empty?

    p = Patch.new
    @song.patches << p

    @cm.inputs.each do |input|
      s = input.sym.downcase
      output = @cm.outputs.find { |i| i.sym.downcase == s }
      if output
        conn = Connection.new(input, -1, output, -1)
        p.connections << conn
      end
    end
  end

  # Splits line on whitespace and returns all words except first
  # the list as a list of strings. The contents should NOT be freed, since
  # they are a destructive mutation of `line`.
  def whitespace_sep_args(line : String)
    words = line.split(WHITESPACE)
    words.shift
    words
  end

  # Skips first word on line, splits rest of line on commas, and returns the
  # list as a list of strings. The contents should NOT be freed, since they
  # are a destructive mutation of `line`.
  def comma_sep_args(line : String, skip_word)
    words = line.split(",")
    words.shift if skip_word
    words
  end

  def table_columns(line : String)
    line.strip.split("|")[1..-2].map { |s| s.strip }
  end

  def chan_from_word(word)
    return -1 if word == "all"
    word.to_i - 1
  end

  def find_device(name, device_type : InstrumentDirection) : Int32
    name = name.downcase

    # TODO
    # return if @cm.testing?
    #   return LibPortMIDI::NO_DEVICE

    num_devices = LibPortMIDI.count_devices
    (0...num_devices).each do |i|
      device = LibPortMIDI.get_device_info(i).value
      if device_type == InstrumentDirection::INPUT && device.input && name == String.new(device.name).downcase
        return i
      elsif device_type == InstrumentDirection::OUTPUT && device.output && name == String.new(device.name).downcase
        return i
      end
    end
    return LibPortMIDI::PmError::InvalidDeviceId.value
  end

  def header?(const line : String, header : String, level : Int32)
    return false unless header_level?(line, level)
    line.downcase.includes?(header.downcase)
  end

  def header_level?(const line : String, int level) : Bool
    leader = (@markup.header_char.to_s * level) + " "
    line.starts_with?(leader)
  end

  def list_item?(line : String)
    @markup.list_chars.includes?(line[0]) && line[1] == ' '
  end

  def table_row?(const line : String)
    line = line.strip
    line[0] == '|' && line[1] != '-'
  end

  def markup_block_command?(const line : String)
    line.downcase.starts_with?(@markup.block_marker_prefix)
  end

  def determine_markup(path : String)
    @markup = case File.extname(path)
              when "markdown", "md"
                MARKDOWN_MODE_MARKUP
              else
                ORG_MODE_MARKUP
              end
  end
end
