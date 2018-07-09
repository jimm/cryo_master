@[Link("portmidi")]
lib LibPortMidi
  NO_DEVICE = -1

  enum Error
    NoError = 0
    NoData = 0
    GotData = 1
    HostError = -10000
    InvalidDeviceId
    InsufficientMemory
    BufferTooSmall
    BufferOverflow
    BadPtr
    BadData
    InternalError
    BufferMaxSize
  end

  alias Stream = Void*
  alias Message = UInt32
  alias Timestamp = UInt32
  alias TimeProcPtr = Void* -> Timestamp

  struct DeviceInfo
    struct_version : Int32      # internal
    interf : UInt8*             # underlying MIDI API
    name : UInt8*               # device name
    input : Int32               # true iff input is available
    output : Int32              # true iff output is available
    opened : Int32              # used by generic MidiPort code
  end

  struct Event
    message : Message
    timestamp : Timestamp
  end

  # Filter bit-mask definitions

  # filter active sensing messages (0xFE): */
  PM_FILT_ACTIVE = (1 << 0x0E)
  # filter system exclusive messages (0xF0): */
  PM_FILT_SYSEX = (1 << 0x00)
  # filter MIDI clock message (0xF8) */
  PM_FILT_CLOCK = (1 << 0x08)
  # filter play messages (start 0xFA, stop 0xFC, continue 0xFB) */
  PM_FILT_PLAY = ((1 << 0x0A) | (1 << 0x0C) | (1 << 0x0B))
  # filter tick messages (0xF9) */
  PM_FILT_TICK = (1 << 0x09)
  # filter undefined FD messages */
  PM_FILT_FD = (1 << 0x0D)
  # filter undefined real-time messages */
  PM_FILT_UNDEFINED = PM_FILT_FD
  # filter reset messages (0xFF) */
  PM_FILT_RESET = (1 << 0x0F)
  # filter all real-time messages */
  PM_FILT_REALTIME = (PM_FILT_ACTIVE | PM_FILT_SYSEX | PM_FILT_CLOCK | PM_FILT_PLAY | PM_FILT_UNDEFINED | PM_FILT_RESET | PM_FILT_TICK)
  # filter note-on and note-off (0x90-0x9F and 0x80-0x8F) */
  PM_FILT_NOTE = ((1 << 0x19) | (1 << 0x18))
  # filter channel aftertouch (most midi controllers use this) (0xD0-0xDF)*/
  PM_FILT_CHANNEL_AFTERTOUCH = (1 << 0x1D)
  # per-note aftertouch (0xA0-0xAF) */
  PM_FILT_POLY_AFTERTOUCH = (1 << 0x1A)
  # filter both channel and poly aftertouch */
  PM_FILT_AFTERTOUCH = (PM_FILT_CHANNEL_AFTERTOUCH | PM_FILT_POLY_AFTERTOUCH)
  # Program changes (0xC0-0xCF) */
  PM_FILT_PROGRAM = (1 << 0x1C)
  # Control Changes (CC's) (0xB0-0xBF)*/
  PM_FILT_CONTROL = (1 << 0x1B)
  # Pitch Bender (0xE0-0xEF*/
  PM_FILT_PITCHBEND = (1 << 0x1E)
  # MIDI Time Code (0xF1)*/
  PM_FILT_MTC = (1 << 0x01)
  # Song Position (0xF2) */
  PM_FILT_SONG_POSITION = (1 << 0x02)
  # Song Select (0xF3)*/
  PM_FILT_SONG_SELECT = (1 << 0x03)
  # Tuning request (0xF6)*/
  PM_FILT_TUNE = (1 << 0x06)
  # All System Common messages (mtc, song position, song select, tune request) */
  PM_FILT_SYSTEMCOMMON = (PM_FILT_MTC | PM_FILT_SONG_POSITION | PM_FILT_SONG_SELECT | PM_FILT_TUNE)

  fun initialize =
    Pm_Initialize() : Error

  fun terminate =
    Pm_Terminate() : Error

  fun host_error? =
    Pm_HasHostError(stream : Stream) : Int32

  fun get_error_text =
    Pm_GetErrorText(errnum : Error) : UInt8*

  fun count_devices =
    Pm_CountDevices() : Int32

  fun get_default_input_device_id =
    Pm_GetDefaultInputDeviceID() : Int32

  fun get_default_output_device_id =
    Pm_GetDefaultOutputDeviceID() : Int32

  fun get_device_info =
    Pm_GetDeviceInfo(device_id : Int32) : DeviceInfo*

  fun open_input =
    Pm_OpenInput(stream : Stream*, input_device : Int32,
                 input_driver_info : Void*, buffer_size : Int32,
                 time_proc : TimeProcPtr,
                 time_info : TimeProcPtr) : Error

  fun open_output =
    Pm_OpenOutput(stream : Stream*, output_device : Int32,
                  output_driver_info : Void*, buffer_size : Int32,
                  time_proc : TimeProcPtr,
                  time_info : TimeProcPtr,
                  latency : Int32) : Error

  fun set_filter =
    Pm_SetFilter(stream : Stream, filters_bitmask : UInt32) : Error

  fun set_channel_mask =
    Pm_SetChannelMask(stream : Stream, bitmask : UInt32) : Error

  fun abort_write =
    Pm_Abort(stream : Stream) : Error

  fun close_stream =
    Pm_Close(stream : Stream) : Error

  fun synchronize =
    Pm_Synchronize(stream : Stream) : Error

  fun midi_read =
    Pm_Read(stream : Stream, buffer : Pointer(Void*), length : Int32) : Int32

  fun poll =
    Pm_Poll(stream : Stream) : Error

  fun midi_write =
    Pm_Write(stream : Stream, buffer : Event*, length : Int32) : Error

  fun midi_write_short =
    Pm_WriteShort(stream : Stream, when_tstamp : Int32, msg : UInt32) : Error

  fun midi_write_sysex =
    Pm_WriteSysEx(stream : Stream, when_tstamp : Int32, msg : UInt8*) : Error
end

module PortMidi
  include Consts

  def self.before(t1 : Int32, t2 : Int32) : Bool
    (t1 - t2) < 0
  end

  def self.message(status : UInt8, data1 : UInt8, data2 : UInt8) : LibPortMidi::Message
    (((data2.to_u32 << 16) & 0xFF0000_u32) |
     ((data1.to_u32 << 8) & 0xFF00_u32) |
     (status.to_u32 & 0xFF_u32))
  end

  def self.message_status(msg : LibPortMidi::Message) : UInt8
    (msg.to_i32 & 0xff).to_u8
  end

  def self.message_data1(msg : LibPortMidi::Message) : UInt8
    ((msg.to_i32 >> 8) & 0xff).to_u8
  end

  def self.message_data2(msg : LibPortMidi::Message) : UInt8
    ((msg.to_i32 >> 16) & 0xff).to_u8
  end

  def self.message_to_tuple(msg : LibPortMidi::Message)
    {message_status(msg), message_data1(msg), message_data2(msg)}
  end

  def self.message_to_bytes(msg : LibPortMidi::Message)
    [message_status(msg), message_data1(msg), message_data2(msg)]
  end

  def self.channel?(msg : LibPortMidi::Message) : Bool
    message_status(msg) < 0xf0_u8
  end
end
