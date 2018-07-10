require "./patch"
require "./song"
require "./song_list"
require "./sorted_song_list"
require "./message"

class CM
  DEBUG_FILE = "/tmp/pm_debug.txt"

  property? running = false
  property? testing = false
  property inputs = [] of InputInstrument
  property outputs = [] of OutputInstrument
  property song_lists = [] of SongList
  property all_songs : SortedSongList
  property loaded_from_file = ""
  property messages = [] of Message # TODO hash
  @song_list : SongList
  @song : Song?
  @patch : Patch?

  class_getter(instance) { CM.new }

  def initialize()
    @all_songs = SortedSongList.new("All Songs")
    @song_lists << @all_songs
    @song_list = @song_lists.first
    @song = nil
    @patch = nil

    # @gui = nil
    # @message_bindings = {}
    # @code_bindings = {}
    init_data
  end

  # def load(file)
  # end

  # def bind_message(name, key)
  # end

  # def bind_code(code_key)
  # end

  def init_data
    @inputs = [] of InputInstrument
    @outputs = [] of OutputInstrument
    @song_lists = [] of SongList
    @all_songs = SortedSongList.new("All Songs")
    @song_lists << @all_songs
    @messages = [] of Message   # TODO hash

    clear_cursor
  end

  def clear_cursor
    # Clear cursor
    @song_list = @song_lists.first
    @song = @song_list.songs.first unless @song_list.songs.empty?
    patches = @song.try(&.patches)
    @patch = patches.try(&.first) unless patches.try(&.empty?)
    # Do not erase names saved by #mark.
  end

  def start(init_cursor = true)
    clear_cursor if init_cursor
    @running = true
    start_patch(@patch)
    @inputs.each(&.start)
  end

  def stop
    stop_patch(@patch)
    @inputs.map(&.stop)
    @running = false
    close_debug_file
  end

  def send_message(name)
    # TODO
  end

  def panic(individual_notes = false)
    # TODO
  end

  # def debug=(b : Bool)
  #   @debug = b
  # end

  # def debug(str : String)
  #   return unless @debug
  #   @debug_file ||= File.open(DEBUG_FILE, "a")
  #   @debug_file.puts str
  #   @debug_file.flush
  # end

  # def close_debug_file
  #   return unless @debug && @debug_file
  #   @debug_file.close
  # end

  # ================ cursor ================

  def next_song
    next_song(@song_list)
  end

  def next_song(sl : Nil)
  end

  def next_song(sl : SongList)
    return if @song_list.songs.last == @song

    stop_patch(@patch)
    @song = sl.songs[sl.songs.index(@song) + 1]
    @patch = @song.patches.first
    start_patch(@patch)
  end

  def prev_song
    prev_song(@song_list)
  end

  def prev_song(sl : Nil)
  end

  def prev_song(sl : SongList)
    stop_patch(@patch)
    @song = sl.songs[sl.songs.index(@song) - 1]
    @patch = @song.patches.first
    start_patch(@patch)
  end

  def next_patch
    next_patch(@song)
  end

  def next_patch(song : Nil)
  end

  def next_patch(song : SongList)
    if song.patches.last == @patch
      next_song
    elsif @patch
      stop_patch(@patch)
      @patch = song.patches[song.patches.index(@patch) + 1]
      start_patch(@patch)
    end
  end

  def prev_patch
    prev_patch(@song)
  end

  def prev_patch(song : Nil)
  end

  def prev_patch(song : Song)
    if @song.patches.first == @patch
      prev_song
    elsif @patch
      stop_patch(@patch)
      @patch = @song.patches[@song.patches.index(@patch) - 1]
      start_patch(@patch)
    end
  end

  def goto_song(name_regex)
    new_song_list = new_song = new_patch = nil
    new_song = @song_list.find(name_regex) if @song_list
    new_song = @@cm.all_songs.find(name_regex) unless new_song
    new_patch = new_song ? new_song.patches.first : nil

    if (new_song && new_song != @song) || # moved to new song
        (new_song == @song && @patch != new_patch) # same song but not at same first patch

      stop_patch(@patch) if @patch

      if @song_list.songs.include?(new_song)
        new_song_list = @song_list
      else
        # Not found in current song list. Switch to @cm.all_songs list.
        new_song_list = @@cm.all_songs
      end

      @song_list = new_song_list
      @song = new_song
      @patch = new_patch
      start_patch(@patch)
    end
  end

  def goto_song_list(name_regex)
    name_regex = Regexp.new(name_regex.to_s, true) # make case-insensitive
    new_song_list = @cm.song_lists.find { |song_list| song_list.name =~ name_regex }
    return unless new_song_list

    @song_list = new_song_list

    new_song = @song_list.songs.first
    new_patch = new_song ? new_song.patches.first : nil

    if new_patch != @patch
      stop_patch(@patch) if @patch
      new_patch.start if new_patch
    end
    @song = new_song
    @patch = new_patch
  end

  # Attempt to go to the same song list, song, and patch that old cursor `c`
  # points to. Called when (re)loading a file.
  def attempt_goto(c : Cursor)
    # TODO

  #   init

  #   if c->song_list
  #     @song_list_index =
  #     find_nearest_match_index(reinterpret_cast<vector<Named *> *>(&pm->song_lists),
  #                              c->song_list()->name);

  # if (c->song() == 0)
  #   return;

  # song_index =
  #   find_nearest_match_index(reinterpret_cast<vector<Named *> *>(&pm->all_songs->songs),
  #                            c->song()->name);
  # if (c->patch() != 0)
  #   patch_index =
  #     find_nearest_match_index(reinterpret_cast<vector<Named *> *>(&song()->patches),
  #                              c->patch()->name);
  # else
  #   patch_index = 0;
  end

  # Remembers the names of the current song list, song, and patch.
  # Used by #restore.
  def mark
    @song_list_name = if @song_list
                        @song_list.name
                      else
                        nil : String
                      end
    @song_name = if @song
                   @song.name
                 else
                   nil : String
                 end
    @patch_name = if @patch
                    @patch.name
                  else
                    nil : String
                  end
  end

  # Using the names saved by #save, try to find them now.
  #
  # Since names can change we use Damerau-Levenshtein distance on lowercase
  # versions of all strings.
  def restore
    return unless @song_list_name   # will be nil on initial load

    @song_list = find_nearest_match(@cm.song_lists, @song_list_name) || @cm.all_songs
    @song = find_nearest_match(@song_list.songs, @song_name) || @song_list.songs.first
    if @song
      @patch = find_nearest_match(@song.patches, @patch_name) || @song.patches.first
    else
      @patch = nil : Patch
    end
  end

  # List must contain objects that respond to #name. If +str+ is nil or
  # +list+ is +nil+ or empty then +nil+ is returned.
  def find_nearest_match(list, str)
    return nil unless str && list && !list.empty?

    str = str.downcase
    distances = list.collect { |item| Levenshtein.distance(str, item.name.downcase) }
    list[distances.index(distances.min)]
  end

  def start_patch(patch : Nil)
    puts "we have no patch, nothing to do" # DEBUG
  end

  def start_patch(patch : Patch)
    puts "we have a non-nil patch, starting" # DEBUG
    patch.start
  end

  def stop_patch(patch : Nil)
  end

  def stop_patch(patch : Patch)
    patch.stop
  end

  # DEBUG
  def dump
    pp self
  end
end
