require "./spec_helper"
require "../src/cryo_master/cursor"

describe Cursor do
  it "goes to next_patch" do
    cm = load_test_file()
    c = cm.cursor
    c.next_patch
    c.song_list.should eq cm.all_songs
    c.song.should eq c.song_list.songs[0]
    c.patch.should eq c.song.not_nil!.patches[1]
  end

  it "goes to next_patch_at_end_of_song" do
    cm = load_test_file()
    c = cm.cursor
    c.next_patch
    c.next_patch
    c.song_list.should eq cm.all_songs
    c.song.should eq c.song_list.songs[1]
    c.patch.should eq c.song.not_nil!.patches[0]
  end

  it "goes to next_patch_at_end_of_song_list" do
    cm = load_test_file()
    c = cm.cursor
    c.next_song
    c.next_song
    c.next_patch
    c.song_list.should eq cm.all_songs
    c.song.should eq c.song_list.songs[2]
    c.patch.should eq c.song.not_nil!.patches[1]
  end

  it "goes to prev_patch" do
    cm = load_test_file()
    c = cm.cursor
    c.goto_song_list("one")
    c.next_patch
    c.prev_patch
    c.song_list.name.should eq "Song List One"
    c.song.should eq c.song_list.songs[0]
    c.patch.should eq c.song.not_nil!.patches[0]
  end

  it "goes to prev_patch_start_of_song" do
    cm = load_test_file()
    c = cm.cursor
    c.goto_song_list("one")
    c.next_song
    c.prev_patch
    c.song.should eq c.song_list.songs[0]
    c.patch.should eq c.song.not_nil!.patches[0]
  end

  it "goes to prev_patch_start_of_song_list" do
    cm = load_test_file()
    c = cm.cursor
    c.goto_song_list("one")
    c.prev_patch
    c.song.should eq c.song_list.songs[0]
    c.patch.should eq c.song.not_nil!.patches[0]
  end

  it "goes to next_song" do
    cm = load_test_file()
    c = cm.cursor
    c.goto_song_list("one")
    c.next_song
    c.song.should eq c.song_list.songs[1]
    c.patch.should eq c.song.not_nil!.patches[0]
  end

  it "goes to prev_song" do
    cm = load_test_file()
    c = cm.cursor
    c.goto_song_list("one")
    c.next_song
    c.next_patch
    c.prev_song
    c.song_list.should_not eq cm.all_songs # sanity check
    c.song.should eq c.song_list.songs[0]
    c.patch.should eq c.song.not_nil!.patches[0]
  end

  it "goes to song_list" do
    cm = load_test_file()
    c = cm.cursor
    c.goto_song_list("one")
    c.song_list.name.should eq "Song List One"
    c.song_list.should_not eq cm.all_songs
  end

  it "goes to song" do
    cm = load_test_file()
    c = cm.cursor
    c.goto_song("nother")
    c.song.not_nil!.name.should eq "Another Song"
  end

  it "goes to patch" do
    cm = load_test_file()
    c = cm.cursor
    c.goto_song_list("one")
    s = c.song
    c.patch.should eq s.not_nil!.patches[0]
  end

  it "goes to goto_song" do
    cm = load_test_file()
    c = cm.cursor

    c.goto_song("nother")
    s = c.song
    s.should_not be_nil
    s.not_nil!.name.should eq "Another Song"
  end

  it "goes to goto_song_no_such_song" do
    cm = load_test_file()
    c = cm.cursor

    before = c.song
    before.should_not be_nil

    c.goto_song("nosuch")
    s = c.song
    s.should eq before
  end

  it "goes to goto_song_list" do
    cm = load_test_file()
    c = cm.cursor

    c.goto_song_list("two")
    sl = c.song_list
    sl.should_not be_nil
    sl.name.should eq "Song List Two"
  end

  it "goes to goto_song_list_no_such_song_list" do
    cm = load_test_file()
    c = cm.cursor

    before = c.song_list
    before.should_not be_nil

    c.goto_song_list("nosuch")
    sl = c.song_list
    sl.should eq before
  end
end
