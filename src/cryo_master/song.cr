require "./nameable"

class Song < Nameable
  property patches : Array(Patch)
  property notes = Array(String).new

  def initialize(name = "Unnamed")
    super(name)
    @patches = [] of Patch
    CM.instance.all_songs.songs << self
  end

  def <<(patch)
    @patches << patch
  end
end
