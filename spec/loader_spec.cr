require "./spec_helper"
require "../src/cryo_master/loader"

describe Loader do
  it "loads instruments" do
    cm = load_test_file()

    cm.inputs.size.should eq 2
    input = cm.inputs.first
    input.sym.should eq "one"
    input.name.should eq "first input"

    cm.outputs.size.should eq 2
    output = cm.outputs.last
    output.sym.should eq "two"
    output.name.should eq "second output"
  end

  it "loads messages" do
    cm = load_test_file()

    cm.messages.size.should eq 3

    m = cm.messages[0]
    m.name.should eq "Tune Request"
    m.messages.size.should eq 1
    m.messages[0].should eq PortMIDI.message(0xf6, 0, 0)

    m = cm.messages[1]
    m.name.should eq "Multiple Note-Offs"
    m.messages.size.should eq 3
    m.messages[0].should eq PortMIDI.message(0x80, 64, 0)
    m.messages[1].should eq PortMIDI.message(0x81, 64, 0)
    m.messages[2].should eq PortMIDI.message(0x82, 42, 127)

    m = cm.messages[2]
    m.name.should eq "Testing Another Literal Syntax"
    m.messages.size.should eq 1
    m.messages[0].should eq PortMIDI.message(0xf6, 0, 0)
  end

  it "loads triggers" do
    cm = load_test_file()
    input = cm.inputs.first

    input.triggers.size.should eq 5

    t = input.triggers.first
    t.trigger_msg.should eq PortMIDI.message(0xb0, 50, 127)
    t.action.should eq Trigger::Action::NEXT_SONG
    t.output_message.should be_nil

    t = input.triggers.last
    t.trigger_msg.should eq PortMIDI.message(0xb0, 54, 127)
    t.action.should eq Trigger::Action::MESSAGE
    t.output_message.should_not be_nil
    t.output_message.not_nil!.name.should eq "Tune Request"
  end

  it "loads songs" do
    cm = load_test_file()
    all = cm.all_songs.songs

    all.size.should eq 3
    # sorted
    ["Another Song", "Song Without Explicit Patch", "To Each His Own"].each_with_index do |n, i|
      all[i].name.should eq n
    end
  end

  it "loads notes" do
    cm = load_test_file()

    s = cm.all_songs.songs.find { |s| s.name == "Another Song" }.not_nil!
    s.notes.size.should eq 3
    [
      "the line before begin_example contains only whitespace",
      "this song has note text",
      "that spans multiple lines",
    ].each_with_index do |str, i|
      s.notes[i].should eq str
    end
  end

  it "loads patches" do
    cm = load_test_file()

    s = cm.all_songs.songs.find { |s| s.name == "To Each His Own" }.not_nil!
    s.patches.size.should eq 2
    p = s.patches.first
    p.name.should eq "Vanilla Through, Filter Two's Sustain"
  end

  it "loads start and stop messages" do
    cm = load_test_file()
    s = cm.all_songs.songs.find { |s| s.name == "Another Song" }.not_nil!
    p = s.patches.last

    p.start_messages.size.should eq 3
    p.start_messages[0].should eq PortMIDI.message(0xb0, 0x7a, 0x00)
    p.start_messages[1].should eq PortMIDI.message(0xb0, 7, 127)
    p.start_messages[2].should eq PortMIDI.message(0xb1, 7, 127)

    p.stop_messages.size.should eq 3
    p.stop_messages[0].should eq PortMIDI.message(0xb2, 7, 127)
    p.stop_messages[1].should eq PortMIDI.message(0xb3, 7, 127)
    p.stop_messages[2].should eq PortMIDI.message(0xb0, 0x7a, 127)
  end

  it "loads connections" do
    cm = load_test_file()

    s = cm.all_songs.songs.find { |s| s.name == "To Each His Own" }.not_nil!
    p = s.patches.first
    p.connections.size.should eq 2
    conn = p.connections.first
    conn.input.should eq cm.inputs.first
    conn.input_chan.should eq -1
    conn.output.should eq cm.outputs.first
    conn.output_chan.should eq -1

    s = cm.all_songs.songs.find { |s| s.name == "Another Song" }.not_nil!
    p = s.patches.last
    p.connections.size.should eq 2
    conn = p.connections.first
    conn.input_chan.should eq 2
    conn.output_chan.should eq 3
  end

  it "loads connection values" do
    cm = load_test_file()
    s = cm.all_songs.songs.find { |s| s.name == "To Each His Own" }.not_nil!

    p = s.patches.first
    conn = p.connections.first
    conn.xpose.should eq 0
    conn.zone.should eq (0_u8..127_u8)

    conn = p.connections.last
    conn.pc_prog.should eq 12
    conn.bank_msb.should eq 3
    conn.bank_lsb.should eq 2

    p = s.patches[1]
    conn = p.connections.last
    conn.pc_prog.should eq Connection::IGNORE
    conn.bank_msb.should eq Connection::IGNORE
    conn.bank_lsb.should eq 5
    conn.xpose.should eq -12

    s = cm.all_songs.songs.find { |s| s.name == "Another Song" }.not_nil!
    p = s.patches.first

    conn = p.connections[0]
    conn.zone.should eq (0_u8..63_u8)

    conn = p.connections[1]
    conn.zone.should eq (64_u8..127_u8)
  end
end
