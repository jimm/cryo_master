class SortedSongList < SongList
  def songs
    super.sort_by!(&.name)
  end
end
