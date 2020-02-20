require "./spec_helper"
require "../src/cryo_master/consts"
require "../src/cryo_master/controller"

include Consts

describe Controller do
  it "cc_will_modify" do
    cc = Controller.new(7_u8)

    cc.will_modify?.should eq false

    cc.filtered = true
    cc.will_modify?.should eq true
    cc.filtered = false

    cc.translated_cc_num = 8
    cc.will_modify?.should eq true
    cc.translated_cc_num = 7

    cc.min = 1
    cc.will_modify?.should eq true
    cc.min = 0

    cc.max = 126
    cc.will_modify?.should eq true
    cc.max = 127
  end

  it "cc_out_chan" do
    cc = Controller.new(7_u8)
    cc.process([CONTROLLER, 7_u8, 127_u8, 0_u8], 3_u8).should eq [(CONTROLLER + 3).to_u8, 7_u8, 127_u8, 0]
  end

  it "cc_filter" do
    cc = Controller.new(7_u8)
    cc.filtered = true
    cc.process([CONTROLLER, 7_u8, 127_u8, 0_u8], 0_u8).should be_nil
  end

  it "cc_map" do
    cc = Controller.new(7_u8)
    cc.translated_cc_num = 10_u8
    cc.process([CONTROLLER, 7_u8, 127_u8, 0_u8], 0_u8).should eq [CONTROLLER.to_u8, 10_u8, 127_u8, 0]
  end

  it "cc_limit" do
    cc = Controller.new(7_u8)
    cc.min = 1_u8
    cc.max = 120_u8

    [
      [0, 1],
      [1, 1],
      [64, 64],
      [120, 120],
      [121, 120],
      [127, 120],
    ].each do |in_out_vals|
      in_val, out_val = in_out_vals
      out_bytes = cc.process([CONTROLLER, 7_u8, in_val.to_u8, 0_u8], 0_u8).not_nil!
      out_bytes[2].should eq out_val.to_u8
    end
  end
end
