require "./spec_helper"
require "../src/cryo_master/cm"

def cm_spec_assert_no_start_sent(cm)
  not_expected = PortMIDI.message(0xb0_u8, 7_u8, 127_u8)
  cm.outputs.each_with_index do |output, i|
    output.io_messages.find { |msg| msg == not_expected }.should be_nil
  end
end

def cm_spec_assert_no_stop_sent(cm)
  not_expected = PortMIDI.message(0xb2_u8, 7_u8, 127_u8)
  cm.outputs.each_with_index do |output, i|
    output.io_messages.find { |msg| msg == not_expected }.should be_nil
  end
end

def cm_spec_assert_start_sent(cm)
  expected = PortMIDI.message(0xb0_u8, 7_u8, 127_u8)
  cm.outputs.each_with_index do |output, i|
    output.io_messages.find { |msg| msg == expected }.should_not be_nil
  end
end

def cm_spec_assert_stop_sent(cm)
  expected = PortMIDI.message(0xb2_u8, 7_u8, 127_u8)
  output = cm.outputs[0]
  output.io_messages.find { |msg| msg == expected }.should_not be_nil
end

describe CM do
  it "next_patch_start_and_stop_messages" do
    cm = load_test_file()
    cm.start

    cm.next_song
    cm_spec_assert_no_start_sent(cm)
    cm_spec_assert_no_stop_sent(cm)

    cm.next_patch
    cm_spec_assert_start_sent(cm)
    cm_spec_assert_no_stop_sent(cm)

    cm.prev_patch
    cm_spec_assert_start_sent(cm)
    cm_spec_assert_stop_sent(cm)

    cm.stop
  end

  it "next_song_start_and_stop_messages" do
    cm = load_test_file()
    cm.start

    cm.next_song
    cm_spec_assert_no_start_sent(cm)
    cm_spec_assert_no_stop_sent(cm)

    cm.next_patch
    cm_spec_assert_start_sent(cm)
    cm_spec_assert_no_stop_sent(cm)

    cm.prev_song
    cm_spec_assert_start_sent(cm)
    cm_spec_assert_stop_sent(cm)

    cm.stop
  end
end
