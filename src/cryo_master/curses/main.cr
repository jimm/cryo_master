require "crt"
require "./list_window"
require "./patch_window"
require "./info_window"
require "./trigger_window"
require "./prompt_window"
require "./help_window"
require "./geometry"

class Main
  # TODO
  # FUNCTION_KEY_SYMBOLS = Hash(String, Char)
  # 12.times do |i|
  #   FUNCTION_KEY_SYMBOLS["f#{i+1}"] = (265 + i).chr # Key::F1
  #   FUNCTION_KEY_SYMBOLS["F#{i+1}"] = (265 + i).chr # Key::F1
  # end

  def initialize
    Crt.init
    Crt.start_color

    @song_lists_win = uninitialized ListWindow
    @song_list_win = uninitialized ListWindow
    @song_win = uninitialized ListWindow
    @patch_win = uninitialized PatchWindow
    @message_win = uninitialized Crt::Window
    @trigger_win = uninitialized TriggerWindow
    @info_win = uninitialized InfoWindow
    @prev_cmd = 0
  end

  def run
    begin
      config_curses
      create_windows

      loop do
        begin
          refresh_all unless @prev_cmd == -1
          Fiber.yield
          ch = LibNcursesw.getch
          case ch
          when 'j', 258.chr, ' ' # Key::DOWN
            CM.instance.next_patch
          when 'k', 259.chr # Key::UP
            CM.instance.prev_patch
          when 'n', 261.chr # Key::RIGHT
            CM.instance.next_song
          when 'p', 260.chr # Key::LEFT
            CM.instance.prev_song
          when 'g'
            name = PromptWindow.new("Go To Song", "Go to song:").gets
            CM.instance.goto_song(Regex.new(name)) if name.size > 0
          when 't'
            name = PromptWindow.new("Go To Song List", "Go to Song List:").gets
            CM.instance.goto_song_list(Regex.new(name)) if name.size > 0
          when 'e'
            # FIXME
            # close_screen
            file = CM.instance.loaded_from_file || PromptWindow.new("Edit", "Edit file:").gets
            edit(file) if file.size > 0
          when 'r'
            load(CM.instance.loaded_from_file.as(String)) if (CM.instance.loaded_from_file.try(&.size) || 0) > 0
          when 'h', '?'
            help
          when 27 # "\e" doesn't work here
            # Twice in a row sends individual note-off commands
            message("Sending panic note off messages...")
            CM.instance.panic(@prev_cmd == 27)
            message("Panic sent")
          when 'l'
            file = PromptWindow.new("Load", "Load file:").gets
            if file.size > 0
              begin
                load(file)
                message("Loaded #{file}")
              rescue ex
                message(ex.to_s)
              end
            end
          when 'q'
            break
          when 410.chr # Key::RESIZE
            resize_windows
          end
          @prev_cmd = ch
        rescue ex
          message(ex.to_s)
          CM.debug caller.join("\n")
        end

        # TODO
        # msg_name = CM.instance.message_bindings[ch]
        # CM.instance.send_message(msg_name) if msg_name

        # TODO
        # code_key = CM.instance.code_bindings[ch]
        # code_key.run if code_key
      end
    ensure
      clear
      refresh
      # close_screen
      CM.instance.stop
      CM.close_debug_file
    end
  end

  def config_curses
    # TODO delete this method?

    # init_screen
    # cbreak                      # unbuffered input
    # noecho                      # do not show typed keys
    # stdscr.keypad(true)         # enable arrow keys
    # curs_set(0)                 # cursor: 0 = invisible, 1 = normal
  end

  def create_windows
    g = Geometry.new

    @song_lists_win = ListWindow.new(*g.song_lists_rect, nil)
    @song_list_win = ListWindow.new(*g.song_list_rect, "Song List")
    @song_win = ListWindow.new(*g.song_rect, "Song")
    @patch_win = PatchWindow.new(*g.patch_rect, "Patch")
    @message_win = Crt::Window.new(*g.message_rect)
    @trigger_win = TriggerWindow.new(*g.trigger_rect)
    @info_win = InfoWindow.new(*g.info_rect)
  end

  def resize_windows
    g = Geometry.new

    @song_lists_win.move_and_resize(g.song_lists_rect)
    @song_list_win.move_and_resize(g.song_list_rect)
    @song_win.move_and_resize(g.song_rect)
    @patch_win.move_and_resize(g.patch_rect)
    @trigger_win.move_and_resize(g.trigger_rect)
    @info_win.move_and_resize(g.info_rect)

    r = g.message_rect
    # Crt does not implement resize
    @message_win = Crt::Window.new(*r)
  end

  def load(file)
    CM.instance.load(file)
  end

  # Opens the most recently loaded/saved file name in an editor. After
  # editing, the file is re-loaded.
  def edit(file)
    editor_command = find_editor()
    unless editor_command
      message("Can not find $VISUAL, $EDITOR, vim, or vi on your path")
      return
    end

    cmd = "#{editor_command} #{file}"
    CM.debug(cmd)
    system(cmd)
    load(file)
  end

  # Return the first legit command from $VISUAL, $EDITOR, vim, vi, and
  # notepad.exe.
  def find_editor
    [ENV["VISUAL"], ENV["EDITOR"], "vim", "vi", "notepad.exe"].compact.find("vi") do |cmd|
      system("which", [cmd]) || File.exists?(cmd)
    end
  end

  def help
    g = Geometry.new
    win = HelpWindow.new(*g.help_rect)
    win.draw
    win.refresh
    LibNcursesw.getch # wait for key and eat it
  end

  def message(str)
    if @message_win
      @message_win.clear
      @message_win.print(str)
      @message_win.refresh
    else
      STDERR.puts str
    end
    CM.debug "#{Time.now} #{str}"
  end

  def clear
    wins = [@song_lists_win, @song_list_win, @song_win, @patch_win, @info_win, @trigger_win]
    wins.map(&.clear)
  end

  # Public method callable by triggers
  def refresh
    refresh_all
  end

  def refresh_all
    set_window_data
    wins = [@song_lists_win, @song_list_win, @song_win, @patch_win, @info_win, @trigger_win]
    wins.map(&.draw)
    wins.map(&.win).map(&.refresh)
  end

  def set_window_data
    cursor = CM.instance.cursor
    @song_lists_win.set_contents("Song Lists", CM.instance.song_lists.map { |sl| sl.as(Nameable) }, cursor.song_list)

    song_list = cursor.song_list
    @song_list_win.set_contents(cursor.song_list.name, song_list.songs.map { |s| s.as(Nameable) }, cursor.song)

    maybe_song = cursor.song
    if maybe_song
      song = maybe_song.as(Song)
      @song_win.set_contents(song.name, song.patches.map { |p| p.as(Nameable) }, cursor.patch)
      @info_win.text = song.notes
      @patch_win.patch = cursor.patch
    end
  end
end
