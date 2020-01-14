require "./cm"
require "./song_list"
require "./song"
require "./patch"

# A `Cursor` knows the current `SongList`, `Song`, and `Patch`, how
# to move between songs and patches, and how to find them given name
# regexes.
class Cursor
  getter song_list : SongList
  getter song : Song?
  getter patch : Patch?
  property song_list_name : String?
  property song_name : String?
  property patch_name : String?

  def initialize(@cm : CM)
    @song_list = @cm.all_songs
    @song_list_name = nil
    @song_name = nil
    clear
  end

  # Set @song_list, @song, and @patch to +nil+.
  def clear
    @song_list = @cm.all_songs
    @song = nil
    @patch = nil
    # Do not erase names saved by #mark.
  end

  # Set @song_list to All Songs, @song to first song, and
  # @patch to song's first patch. Song and patch may be +nil+.
  def init
    @song_list = @cm.song_lists.first
    @song = @song_list.songs.first
    @patch = @song.try(&.patches).try(&.first)
  end

  def next_song
    return unless @song_list
    slist = @song_list.as(SongList)
    return if slist.songs.last == @song

    @song = @song_list.songs[(slist.songs.index(@song) || -1) + 1]
    @patch = @song.try(&.patches).try(&.first)
  end

  def prev_song
    return unless @song_list
    return if @song_list.songs.first == @song

    @song = @song_list.songs[(@song_list.songs.index(@song) || 1) - 1]
    @patch = @song.try(&.patches).try(&.first)
  end

  def next_patch
    return unless @song
    s = @song.as(Song)
    if s.patches.last == @patch
      next_song
    elsif @patch
      @patch = s.patches[(s.patches.index(@patch) || -1) + 1]
    end
  end

  def prev_patch
    return unless @song
    s = @song.as(Song)
    if s.patches.first == @patch
      prev_song
    elsif @patch
      @patch = s.patches[(s.patches.index(@patch) || 1) - 1]
    end
  end

  def goto_song(name_regex)
    new_song_list = new_song = new_patch = nil
    new_song = @song_list.find(name_regex) if @song_list
    new_song = CM.instance.all_songs.find(name_regex) unless new_song
    new_patch = new_song ? new_song.patches.first : nil

    if (new_song && new_song != @song) ||         # moved to new song
       (new_song == @song && @patch != new_patch) # same song but not at same first patch

      if @song_list.songs.includes?(new_song)
        new_song_list = @song_list
      else
        # Not found in current song list. Switch to @cm.all_songs list.
        new_song_list = CM.instance.all_songs
      end

      @song_list = new_song_list
      @song = new_song
      @patch = new_patch
    end
  end

  def goto_song_list(name_regex)
    new_song_list = @cm.song_lists.find { |song_list| name_regex.match(song_list.name, 0, Regex::Options::IGNORE_CASE) }
    return unless new_song_list

    @song_list = new_song_list

    new_song = @song_list.songs.first
    new_patch = new_song ? new_song.patches.first : nil

    if new_patch != @patch
      new_patch.start if new_patch
    end
    @song = new_song
    @patch = new_patch
  end

  # Remembers the names of the current song list, song, and patch.
  # Used by #restore.
  def mark
    @song_list_name = @song_list ? @song_list.name : nil
    @song_name = @song ? @song.name : nil
    @patch_name = @patch ? @patch.name : nil
  end

  # Using the names saved by #save, try to find them now.
  #
  # Since names can change we use Damerau-Levenshtein distance on lowercase
  # versions of all strings.
  def restore
    return unless @song_list_name # will be nil on initial load

    @song_list = find_nearest_match(@cm.song_lists, @song_list_name) || @cm.all_songs
    @song = find_nearest_match(@song_list.songs, @song_name) || @song_list.songs.first
    if @song
      @patch = find_nearest_match(@song.patches, @patch_name) || @song.patches.first
    else
      @patch = nil
    end
  end

  # List must contain objects that respond to #name. If +str+ is nil or
  # +list+ is +nil+ or empty then +nil+ is returned.
  def find_nearest_match(list, str)
    return nil unless str && list && !list.empty?

    str = str.downcase
    distances = list.collect { |item| dameraulevenshtein(str, item.name.downcase) }
    list[distances.index(distances.min)]
  end

  # https://gist.github.com/182759 (git://gist.github.com/182759.git)
  # Referenced from http://en.wikipedia.org/wiki/Damerau%E2%80%93Levenshtein_distance
  def dameraulevenshtein(seq1, seq2)
    oneago = nil
    thisrow = (1..seq2.size).to_a + [0]
    seq1.size.times do |x|
      twoago, oneago, thisrow = oneago, thisrow, [0] * seq2.size + [x + 1]
      seq2.size.times do |y|
        delcost = oneago[y] + 1
        addcost = thisrow[y - 1] + 1
        subcost = oneago[y - 1] + ((seq1[x] != seq2[y]) ? 1 : 0)
        thisrow[y] = [delcost, addcost, subcost].min
        if x > 0 && y > 0 && seq1[x] == seq2[y - 1] && seq1[x - 1] == seq2[y] && seq1[x] != seq2[y]
          thisrow[y] = [thisrow[y], twoago[y - 2] + 1].min
        end
      end
    end
    return thisrow[seq2.size - 1]
  end
end
