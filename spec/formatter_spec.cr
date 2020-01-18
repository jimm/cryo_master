require "./spec_helper"
require "../src/cryo_master/formatter"

include Formatter

describe Formatter do
  it "converts note numbers to names" do
    note_num_to_name(0_u8).should eq "C-1"
    note_num_to_name(1_u8).should eq "C#-1"
    note_num_to_name(64_u8).should eq "E4"
    note_num_to_name(52_u8).should eq "E3"
    note_num_to_name(54_u8).should eq "F#3"
    note_num_to_name(51_u8).should eq "D#3"
    note_num_to_name(127_u8).should eq "G9"
  end

  it "converts note names to numbers" do
    note_name_to_num("c-1").should eq 0_u8
    note_name_to_num("C#-1").should eq 1_u8
    note_name_to_num("e4").should eq 64_u8
    note_name_to_num("e3").should eq 52_u8
    note_name_to_num("fs3").should eq 54_u8
    note_name_to_num("f#3").should eq 54_u8
    note_name_to_num("ef3").should eq 51_u8
    note_name_to_num("eb3").should eq 51_u8
    note_name_to_num("g9").should eq 127_u8
    note_name_to_num("G9").should eq 127_u8
  end

  it "converts note numbers to given number" do
    note_name_to_num("0").should eq 0_u8
    note_name_to_num("42").should eq 42_u8
  end
end
