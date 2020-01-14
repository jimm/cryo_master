require "./nameable"

class Song < Nameable
  property patches : Array(Patch)
  property notes = Array(String).new

  def initialize(all_songs_list, name = "Unnamed")
    super(name)
    @patches = [Patch.new]
    all_songs_list.songs << self
  end

  def <<(patch)
    @patches << patch
  end
end
