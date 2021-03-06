require "./nameable"
require "./patch"

class Song < Nameable
  property patches : Array(Patch)
  property notes = Array(String).new

  def initialize(name = "Unnamed")
    super(name)
    @patches = [] of Patch
  end

  def <<(patch)
    @patches << patch
  end
end
