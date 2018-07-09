class SortedSongList < SongList
  property name : String

  def initialize(@name)
    super
  end
  def songs
    @songs.sort_by(&.name)
  end
end
