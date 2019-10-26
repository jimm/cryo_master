class SongList < Nameable
  @songs : Array(Song)

  def initialize(name)
    super
    @songs = [] of Song
  end

  def songs
    @songs
  end

  def find(regex_str : String) : Song?
    regex = Regex.new(regex_str)
    @songs.find { |s| regex.match(s.name) }
  end
end
