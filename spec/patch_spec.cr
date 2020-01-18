require "./spec_helper"
require "../src/cryo_master/patch"

describe Patch do
  it "sends start messages" do
    p = Patch.new("test patch")
    conn = create_conn()
    p.connections << conn
    p.start_messages << 0x1234

    p.start
    conn.output.io_messages.size.should eq 1
    conn.output.io_messages[0].should eq 0x1234
    p.stop
  end

  it "sends stop messages" do
    p = Patch.new("test patch")
    conn = create_conn()
    p.connections << conn
    p.stop_messages << 0x000000f6

    p.start
    p.stop
    conn.output.io_messages.size.should eq 1
    conn.output.io_messages[0].should eq 0x000000f6
  end
end
