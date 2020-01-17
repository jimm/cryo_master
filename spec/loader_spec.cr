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

    s = cm.all_songs.songs[0]
    s.notes.size.should eq 0

    s = cm.all_songs.songs[1]
    s.notes.size.should eq 3
    [
      "the line before begin_example contains only whitespace",
      "this song has note text",
      "that spans multiple lines",
    ].each_with_index do |str, i|
      s.notes[i].should eq str
    end
  end
end
