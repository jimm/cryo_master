require "./spec_helper"
require "../src/cryo_master/instrument"
require "../src/cryo_master/consts"

include Consts

def input_test_events
  [
    PortMIDI.message(NOTE_ON, 64_u8, 127_u8),
    PortMIDI.message(CONTROLLER, 7_u8, 127_u8),
    PortMIDI.message(NOTE_OFF, 64_u8, 127_u8),
    PortMIDI.message(TUNE_REQUEST, 0_u8, 0_u8),
  ].map do |msg|
    event = LibPortMIDI::Event.new
    event.message = msg
    event
  end
end

describe InputInstrument do
  it "through_connection" do
    conn = create_conn()
    input = conn.input
    output = conn.output
    buf = input_test_events()

    input.read(buf, 4)

    input.io_messages.size.should eq 4
    output.io_messages.size.should eq 4
    buf.each_with_index do |event, i|
      input.io_messages[i].should eq event.message
      output.io_messages[i].should eq event.message
    end
  end

  it "two_connections" do
    conn = create_conn()
    input = conn.input
    output = conn.output

    output2 = OutputInstrument.new("out2", "output2 name", -1)
    conn2 = Connection.new(input, 0_u8, output2, 0_u8)
    conn2.start

    buf = input_test_events()
    input.read(buf, 4)

    input.io_messages.size.should eq 4
    output.io_messages.size.should eq 4
    output2.io_messages.size.should eq 4
    buf.each_with_index do |event, i|
      input.io_messages[i].should eq event.message
      output.io_messages[i].should eq event.message
      output2.io_messages[i].should eq event.message
    end
  end

  it "connection_switch_routes_offs_correctly" do
    conn = create_conn()
    input = conn.input
    output = conn.output

    output2 = OutputInstrument.new("output2", "output2 name", -1)
    conn2 = Connection.new(input, 0_u8, output2, 0_u8)

    buf = input_test_events()

    input.read(buf, 2) # note on, controller
    conn.stop
    conn2.start
    input.read(buf[2..], 2) # note off, tune request

    # Make sure note off was sent to original output
    input.io_messages.size.should eq 4
    output.io_messages.size.should eq 3
    output2.io_messages.size.should eq 1
    buf.each_with_index do |event, i|
      input.io_messages[i].should eq event.message
    end

    buf[..-2].each_with_index do |event, i|
      output.io_messages[i].should eq event.message
    end

    output2.io_messages[0].should eq buf.last.message
  end

  it "connection_switch_sustains_correctly" do
    conn = create_conn()
    input = conn.input
    output = conn.output

    output2 = OutputInstrument.new("output2", "output2 name", -1)
    conn2 = Connection.new(input, 0_u8, output2, 0_u8)

    buf = [
      PortMIDI.message(NOTE_ON, 64_u8, 127_u8),
      PortMIDI.message(CONTROLLER, CC_SUSTAIN, 127_u8),
      PortMIDI.message(NOTE_OFF, 64_u8, 127_u8),
      PortMIDI.message(CONTROLLER, CC_SUSTAIN, 0_u8),
    ].map do |msg|
      event = LibPortMIDI::Event.new
      event.message = msg
      event
    end

    input.read(buf, 2) # note on, sustain on
    conn.stop
    conn2.start
    input.read(buf[2..], 2) # note off, sustain off

    # Make sure note off was sent to original output
    input.io_messages.size.should eq 4
    output.io_messages.size.should eq 4
    output2.io_messages.size.should eq 0
    buf.each_with_index do |event, i|
      input.io_messages[i].should eq event.message
      output.io_messages[i].should eq event.message
    end
  end
end
