require "option_parser"
require "./cryo_master/*"

# usage: cryo_master [-l] [-v] [-n] [-w] [-p port] [-d] [cm_file]
#
# Starts CryoMaster and optionally loads cm_file.
#
# -l lists all available MIDI inputs and outputs and exits.
#
# -v outputs the version number and exits.
#
# The -n flag tells PatchMaster to not use MIDI. All MIDI errors such as not
# being able to connect to the MIDI instruments specified in pm_file are
# ignored, and no MIDI data is sent/received. That is useful if you want to
# run PatchMaster without actually talking to any MIDI instruments.
#
# To run PatchMaster using a Web browser GUI use -w and point your browser
# at http://localhost:4567. To change the port, use -p.
#
# The -d flag turns on debug mode. The app becomes slightly more verbose and
# logs everything to `/tmp/cm_debug.txt'.
module CryoMaster
  extend self

  def run
    debug = false
    testing = false
    OptionParser.parse! do |parser|
      parser.banner = "usage: cryo_master [arguments]"
      parser.on("-l", "--list-devices", "List MIDI devices and exit") { list_devices; exit(0) }
      parser.on("-v", "--version", "List cryo_master version and exit") { puts CryoMaster::VERSION; exit(0) }
      parser.on("-n", "--no-midi", "No MIDI (for testing and .cm file debugging)") { testing = true }
      parser.on("-d", "--debug", "Debug output to /tmp/cm_debug.txt") { debug = true }
      parser.on("-h", "--help", "Show this help") { puts parser; exit(0) }
      parser.invalid_option do |flag|
        STDERR.puts "error: #{flag} is not a valid option"
        STDERR.puts parser
        exit(1)
      end
    end

    if ARGV.size > 0
      cm = Loader.new.load(ARGV[0], testing)
      cm.start
      # TODO start GUI, call stop after GUI is done
      # cm.stop
    else
      STDERR.puts "error: missing file name"
      exit(1)
    end
  end

  def list_devices
    LibPortMidi.initialize()
    inputs = {} of Int32 => LibPortMidi::DeviceInfo
    outputs = {} of Int32 => LibPortMidi::DeviceInfo
    (0...LibPortMidi.count_devices).each do |i|
      device = LibPortMidi.get_device_info(i).value
      if device.input != 0
        inputs[i] = device
      end
      if device.output != 0
        outputs[i] = device
      end
    end
    list_io_devices("Inputs", inputs)
    list_io_devices("Outputs", outputs)
    LibPortMidi.terminate()
  end

  def list_io_devices(title : String, devices : Hash(Int32, LibPortMidi::DeviceInfo))
    puts title
    devices.each do |index, dev|
      puts "  #{index}: #{String.new(dev.name)}#{dev.opened == 1 ? " (open)" : ""}"
    end
  end
end

CryoMaster.run
