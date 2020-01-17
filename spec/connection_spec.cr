require "./spec_helper"
require "../src/cryo_master/consts"
require "../src/cryo_master/connection"

include Consts

describe Connection do
  it "sends start messages" do
    conn = create_conn()

    msgs = [
      PortMIDI.message(TUNE_REQUEST, 0, 0),
      PortMIDI.message(CONTROLLER, CC_VOLUME_MSB, 127),
    ]
    conn.start(msgs)

    sent = conn.output.io_messages
    sent.size.should eq 2
    sent.should eq msgs
  end

  it "sends nothing on start if no start messages" do
    conn = create_conn()

    conn.start([] of UInt32)

    sent = conn.output.io_messages
    sent.size.should eq 0
  end

  it "sends stop messages" do
    conn = create_conn()

    msgs = [
      PortMIDI.message(TUNE_REQUEST, 0, 0),
      PortMIDI.message(CONTROLLER, CC_VOLUME_MSB, 127),
    ]
    conn.stop(msgs)

    sent = conn.output.io_messages
    sent.size.should eq 2
    sent.should eq msgs
  end

  it "sends nothing on stop if no stop messages" do
    conn = create_conn()

    conn.stop([] of UInt32)

    sent = conn.output.io_messages
    sent.size.should eq 0
  end

  it "connection_filter_other_input_chan" do
    conn = create_conn()
    conn.midi_in(PortMIDI.message(NOTE_ON + 3, 64, 127))
    conn.output.io_messages.size.should eq 0
  end

  it "connection_allow_all_chans" do
    conn = create_conn()
    conn.input_chan = Connection::IGNORE
    conn.midi_in(PortMIDI.message(NOTE_ON + 3, 64, 127))
    conn.output.io_messages.size.should eq 1
    conn.output.io_messages[0].should eq PortMIDI.message(NOTE_ON, 64, 127) # mutated to output chan
  end

  it "connection_allow_all_chans_in_and_out" do
    conn = create_conn()
    conn.input_chan = Connection::IGNORE
    conn.output_chan = Connection::IGNORE
    conn.midi_in(PortMIDI.message(NOTE_ON + 3, 64, 127))
    conn.output.io_messages.size.should eq 1
    conn.output.io_messages[0].should eq PortMIDI.message(NOTE_ON + 3, 64, 127) # out chan not changed
  end

  it "connection_xpose" do
    conn = create_conn()

    conn.midi_in(PortMIDI.message(NOTE_ON, 64, 127))
    conn.xpose = 12
    conn.midi_in(PortMIDI.message(NOTE_ON, 64, 127))
    conn.xpose = -12
    conn.midi_in(PortMIDI.message(NOTE_ON, 64, 127))

    conn.output.io_messages.size.should eq 3
    conn.output.io_messages[0].should eq PortMIDI.message(NOTE_ON, 64, 127)
    conn.output.io_messages[1].should eq PortMIDI.message(NOTE_ON, 64 + 12, 127)
    conn.output.io_messages[2].should eq PortMIDI.message(NOTE_ON, 64 - 12, 127)
  end

  it "connection_zone" do
    conn = create_conn()

    conn.zone = (0_u8..64_u8)
    conn.midi_in(PortMIDI.message(NOTE_ON, 48, 127))
    conn.midi_in(PortMIDI.message(NOTE_OFF, 48, 127))
    conn.midi_in(PortMIDI.message(NOTE_ON, 76, 127))
    conn.midi_in(PortMIDI.message(NOTE_OFF, 76, 127))

    conn.output.io_messages.size.should eq 2
    conn.output.io_messages[0].should eq PortMIDI.message(NOTE_ON, 48, 127)
    conn.output.io_messages[1].should eq PortMIDI.message(NOTE_OFF, 48, 127)
  end

  it "connection_zone_poly_pressure" do
    conn = create_conn()

    conn.zone = (0_u8..64_u8)
    conn.midi_in(PortMIDI.message(POLY_PRESSURE, 48, 127))
    conn.midi_in(PortMIDI.message(POLY_PRESSURE, 76, 127))

    conn.output.io_messages.size.should eq 1
    conn.output.io_messages[0].should eq PortMIDI.message(POLY_PRESSURE, 48, 127)
  end

  it "connection_cc_processed" do
    conn = create_conn()
    cc = Controller.new
    cc.filtered = true
    conn.cc_maps[7] = cc

    conn.midi_in(PortMIDI.message(CONTROLLER, 7, 127))
    conn.output.io_messages.size.should eq 0
  end
end
