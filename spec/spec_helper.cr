require "spec"
require "../src/cryo_master/loader"

def load_test_file
  load_test_file("spec/testfile.org")
end

def load_test_file(path)
  Loader.new.load(path, true)
end
