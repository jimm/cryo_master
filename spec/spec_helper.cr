require "spec"
require "../src/cryo_master/loader"
require "../src/cryo_master/instrument"
require "../src/cryo_master/connection"

def load_test_file
  load_test_file("spec/testfile.org")
end

def load_test_file(path)
  Loader.new.load(path, true)
end

def create_conn
  input = InputInstrument.new("in", "input name", -1)
  output = OutputInstrument.new("out", "output name", -1)
  conn = Connection.new(input, 0_u8, output, 0_u8)
  conn.start # add conn to input
  conn
end
