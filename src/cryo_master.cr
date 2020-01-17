require "option_parser"
require "port_midi"
require "./cryo_master/cm"
require "./cryo_master/loader"
require "./cryo_master/version"
require "./cryo_master/curses/main"

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
    OptionParser.parse do |parser|
      parser.banner = "usage: cryo_master [arguments]"
      parser.on("-l", "--list-devices", "List MIDI devices and exit") do
        PortMIDI.init
        PortMIDI.list_all_devices
        PortMIDI.terminate
        exit(0)
      end
      parser.on("-v", "--version", "List cryo_master version and exit") do
        puts CryoMaster::VERSION
        exit(0)
      end
      parser.on("-n", "--no-midi", "No MIDI (for testing and .cm file debugging)") { testing = true }
      parser.on("-d", "--debug", "Debug output to #{CM::DEBUG_FILE}") { CM.debug = true }
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit(0)
      end
      parser.invalid_option do |flag|
        STDERR.puts "error: #{flag} is not a valid option"
        STDERR.puts parser
        exit(1)
      end
    end

    if ARGV.size > 0
      PortMIDI.init
      cm = Loader.new.load(ARGV[0], testing)
      cm.start
      Main.new.run
      cm.stop
      PortMIDI.terminate
    else
      STDERR.puts "error: missing file name"
      exit(1)
    end
  end

  def list_devices
    inputs = {} of Int32 => LibPortMIDI::DeviceInfo
    outputs = {} of Int32 => LibPortMIDI::DeviceInfo
    (0...LibPortMIDI.count_devices).each do |i|
      device = LibPortMIDI.get_device_info(i).value
      inputs[i] = device if device.input != 0
      outputs[i] = device if device.output != 0
    end
    list_io_devices("Inputs", inputs)
    list_io_devices("Outputs", outputs)
  end

  def list_io_devices(title : String, devices : Hash(Int32, LibPortMIDI::DeviceInfo))
    puts title
    devices.each do |index, dev|
      puts "  #{index}: #{String.new(dev.name)}#{dev.opened == 1 ? " (open)" : ""}"
    end
  end
end

CryoMaster.run
