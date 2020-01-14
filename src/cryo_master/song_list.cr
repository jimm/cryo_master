class SongList < Nameable
  @songs : Array(Song)

  def initialize(name)
    super
    @songs = [] of Song
  end

  def songs
    @songs
  end

  def find(regex : Regex) : Song?
    @songs.find { |s| regex.match(s.name, 0, Regex::Options::IGNORE_CASE) }
  end
end
