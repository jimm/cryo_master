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
  #   FUNCTION_KEY_SYMBOLS["f#{i+1}"] = Crt::Key::F1 + i
  #   FUNCTION_KEY_SYMBOLS["F#{i+1}"] = Crt::Key::F1 + i
  # end

  def initialize(@cm : CM)
  end

  def run
    @cm.start
    begin
      config_curses
      create_windows

      loop do
        begin
          refresh_all
          ch = getch
          message("ch = #{ch}") if @debug # FIXME
          case ch
          when 'j', Key::DOWN, ' '
            @cm.next_patch
          when 'k', Key::UP
            @cm.prev_patch
          when 'n', Key::RIGHT
            @cm.next_song
          when 'p', Key::LEFT
            @cm.prev_song
          when 'g'
            name = PromptWindow.new("Go To Song", "Go to song:").gets
            @cm.goto_song(name) if name.length > 0
          when 't'
            name = PromptWindow.new("Go To Song List", "Go to Song List:").gets
            @cm.goto_song_list(name) if name.length > 0
          when 'e'
            close_screen
            file = @cm.loaded_file || PromptWindow.new("Edit", "Edit file:").gets
            edit(file) if file.length > 0
          when 'r'
            load(@cm.loaded_file) if @cm.loaded_file && @cm.loaded_file.length > 0
          when 'h', '?'
            help
          when 27        # "\e" doesn't work here
            # Twice in a row sends individual note-off commands
            message("Sending panic note off messages...")
            @cm.panic(@prev_cmd == 27)
            message("Panic sent")
          when 'l'
            file = PromptWindow.new("Load", "Load file:").gets
            if file.length > 0
              begin
                load(file)
                message("Loaded #{file}")
              rescue ex
                message(ex.to_s)
              end
            end
          when 's'
            file = PromptWindow.new("Save", "Save into file:").gets
            if file.length > 0
              begin
                save(file)
                message("Saved #{file}")
              rescue ex
                message(ex.to_s)
              end
            end
          when 'q'
            break
          when Key::RESIZE
            resize_windows
          end
          @prev_cmd = ch
        rescue ex
          message(ex.to_s)
          @cm.debug caller.join("\n")
        end

        msg_name = @cm.message_bindings[ch]
        @cm.send_message(msg_name) if msg_name
        code_key = @cm.code_bindings[ch]
        code_key.run if code_key
      end
    ensure
      clear
      refresh
      # close_screen
      @cm.stop
      @cm.close_debug_file
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
    @message_win = Window.new(*g.message_rect)
    @trigger_win = TriggerWindow.new(*g.trigger_rect)
    @info_win = InfoWindow.new(*g.info_rect)

    @message_win.scrollok(false)
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
    @message_win.move(r[2], r[3])
    @message_win.resize(r[0], r[1])
  end

  def load(file)
    @cm.load(file)
  end

  def save(file)
    @cm.save(file)
  end

  # Opens the most recently loaded/saved file name in an editor. After
  # editing, the file is re-loaded.
  def edit(file)
    editor_command = find_editor
    unless editor_command
      message("Can not find $VISUAL, $EDITOR, vim, or vi on your path")
      return
    end

    cmd = "#{editor_command} #{file}"
    @cm.debug(cmd)
    system(cmd)
    load(file)
  end

  # Return the first legit command from $VISUAL, $EDITOR, vim, vi, and
  # notepad.exe.
  def find_editor
    @editor ||= [ENV["VISUAL"], ENV["EDITOR"], "vim", "vi", "notepad.exe"].compact.detect do |cmd|
      system("which", cmd) || File.exist?(cmd)
    end
  end

  def help
    g = Geometry.new
    win = HelpWindow.new(*g.help_rect)
    win.draw
    win.refresh
    getch                       # wait for key and eat it
  end

  def message(str)
    if @message_win
      @message_win.clear
      @message_win.addstr(str)
      @message_win.refresh
    else
      STDERR.puts str
    end
    @cm.debug "#{Time.now} #{str}"
  end

  # Public method callable by triggers
  def refresh
    refresh_all
  end

  def refresh_all
    set_window_data
    wins = [@song_lists_win, @song_list_win, @song_win, @patch_win, @info_win, @trigger_win]
    wins.map(&:draw)
    ([stdscr] + wins).map(&:noutrefresh)
    Curses.doupdate
  end

  def set_window_data
    @song_lists_win.set_contents("Song Lists", @cm.song_lists, :song_list)

    song_list = @cm.song_list
    @song_list_win.set_contents(song_list.name, song_list.songs, :song)

    song = @cm.song
    if song
      @song_win.set_contents(song.name, song.patches, :patch)
      @info_win.text = song.notes
      patch = @cm.patch
      @patch_win.patch = patch
    else
      @song_win.set_contents(nil, nil, :patch)
      @info_win.text = nil
      @patch_win.patch = nil
    end
  end
end
