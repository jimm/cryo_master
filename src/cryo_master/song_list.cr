class SongList < Nameable
  @songs : Array(Song)

  def initialize(name)
    super
    @songs = [] of Song
  end

  def songs
    @songs
  end
end
