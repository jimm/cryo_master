require "./patch"
require "./song"
require "./song_list"
require "./sorted_song_list"
require "./message"
require "./cursor"

class CM
  DEBUG_FILE = "/tmp/cryo_master_debug.txt"

  property? running = false
  property? testing = false
  property inputs = [] of InputInstrument
  property outputs = [] of OutputInstrument
  property song_lists = [] of SongList
  property all_songs : SortedSongList
  property loaded_from_file = ""
  property messages = [] of Message # TODO hash
  getter cursor : Cursor

  @@cm_instance = uninitialized CM
  @@debug = false
  @@debug_file : File? = nil

  def self.debug=(b : Bool)
    @@debug = b
  end

  def self.debug(str : String)
    return unless @@debug
    @@debug_file ||= File.open(DEBUG_FILE, "a")
    @@debug_file.as(File).puts str
    @@debug_file.as(File).flush
  end

  def self.close_debug_file
    return unless @@debug_file
    @@debug_file.as(File).close
    @@debug_file = nil
  end

  def self.instance : CM
    @@cm_instance ||= CM.new
  end

  def initialize
    @all_songs = SortedSongList.new("All Songs")
    @song_lists << @all_songs
    @cursor = uninitialized Cursor

    @inputs = [] of InputInstrument
    @outputs = [] of OutputInstrument
    @song_lists = [] of SongList
    @all_songs = SortedSongList.new("All Songs")
    @song_lists << @all_songs
    @messages = [] of Message # TODO hash
    # @message_bindings = {}
    # @code_bindings = {}

    @cursor = Cursor.new(self)
    clear_cursor

    @@cm_instance = self
  end

  def load(file)
    # TODO
  end

  # def bind_message(name, key)
  # end

  # def bind_code(code_key)
  # end

  def init_data
  end

  def clear_cursor
    @cursor.clear
  end

  def start(init_cursor = true)
    clear_cursor if init_cursor
    @running = true
    @cursor.patch.try(&.start)
    start_patch()
    @inputs.each(&.start)
  end

  def stop
    stop_patch()
    @inputs.map(&.stop)
    @running = false
    CM.close_debug_file
  end

  def send_message(name)
    # TODO
  end

  def panic(individual_notes = false)
    # TODO
  end

  def stop_curr_patch
    @cursor.patch.try(&.stop)
  end

  def start_curr_patch
    @cursor.patch.try(&.start)
  end

  # ================ cursor ================

  def next_song
    stop_patch()
    @cursor.next_song
    start_patch()
  end

  def prev_song
    stop_patch()
    @cursor.prev_song
    start_patch()
  end

  def next_patch
    stop_patch()
    @cursor.next_patch
    start_patch()
  end

  def prev_patch
    stop_patch()
    @cursor.prev_patch
    start_patch()
  end

  def goto_song(name_regex_str)
    stop_patch()
    @cursor.goto_song(name_regex_str)
    start_patch()
  end

  def goto_song_list(name_regex_str)
    stop_patch()
    @cursor.goto_song_list(name_regex_str)
    start_patch()
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
    # FIXME
    # @song_list_name = if @song_list
    #                     @song_list.name
    #                   else
    #                     nil : String
    #                   end
    # @song_name = if @song
    #                @song.name
    #              else
    #                nil : String
    #              end
    # @patch_name = if @patch
    #                 @patch.name
    #               else
    #                 nil : String
    #               end
  end

  # Using the names saved by #save, try to find them now.
  #
  # Since names can change we use Damerau-Levenshtein distance on lowercase
  # versions of all strings.
  def restore
    # FIXME
    # return unless @song_list_name # will be nil on initial load

    # @song_list = find_nearest_match(@song_lists, @song_list_name) || @all_songs
    # @song = find_nearest_match(@song_list.songs, @song_name) || @song_list.songs.first
    # if @song
    #   @patch = find_nearest_match(@song.patches, @patch_name) || @song.try(&.patches).try(&.first)
    # else
    #   @patch = nil : Patch
    # end
  end

  # List must contain objects that respond to #name. If +str+ is nil or
  # +list+ is +nil+ or empty then +nil+ is returned.
  def find_nearest_match(list, str)
    return nil unless str && list && !list.empty?

    str = str.downcase
    distances = list.collect { |item| Levenshtein.distance(str, item.name.downcase) }
    list[distances.index(distances.min)]
  end

  def start_patch
    @cursor.patch.try(&.start)
  end

  def stop_patch
    @cursor.patch.try(&.stop)
  end
end
