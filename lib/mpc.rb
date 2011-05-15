require 'socket'
require 'tree'

class Mpc
  @@regexps = {
    "ACK"  => /\AACK \[(\d+)\@(\d+)\] \{(.*)\} (.+)\Z/,
    "OK"   => /\AOK\n\Z/,
    "FILE" => /\Afile\:(.*)\Z/,
  }

  def initialize(host = "127.0.0.1", port = 6600)
    @socket = TCPSocket.new(host, port)
    @socket.gets
  end

  def shutdown!
    @socket.close
  end

  def play(song = nil)
    song.nil? ? command = "play" : command = "play #{song.to_s}"
    puts(command)
  end

  def playing?
    status_hash = status
    status_hash[:state] == "play"
  end

  def pause
    puts("pause 1")
  end

  def paused?
    status_hash = status
    status_hash[:state] == "pause"
  end

  def stop
    puts("stop")
  end

  def stopped?
    status_hash = status
    status_hash[:state] == "stop"
  end

  def playing?
    status_hash = status
    status_hash[:state] == "play"
  end

  def next
    puts("next")
  end

  def previous
    puts("previous")
  end

  def random(state = nil)
    if state.nil?
      random? ? random_state = 0 : random_state = 1
    else
      random_state = state
    end
    puts("random #{random_state}")
  end

  def random?
    status_hash = status
    status_hash[:random] == "1"
  end

  def repeat(state = nil)
    if state.nil?
      repeat? ? repeat_state = 0 : repeat_state = 1
    else
      repeat_state = state
    end
    puts("repeat #{repeat_state}")
  end

  def repeat?
    status_hash = status
    status_hash[:repeat] == "1"
  end

  def set_volume(volume)
    begin
      unless (0..100).include?(volume)
        raise Exception.new("Volume should be between 0 (minimum) and 100 (maximum)")
      end
      puts("setvol #{volume.to_s}")
    end
  end

 def volume
   status_hash = status
   status_hash[:volume]
 end

 def volume_up
  set_volume(volume.to_i + 20)
 end

 def volume_down
  set_volume(volume.to_i - 20)
 end

 def seek(time, song = nil)
  if song.nil?
    song = current_song[:pos]
  end
  puts("seek #{song.to_s} #{time.to_s}")
 end

 def song_time
  status_hash = status
  status_hash[:time]
 end

 def find(type, what = "")
  unless type.match(/\A(title|artist|album|filename|all)\Z/)
    raise Exception.new("Wrong type: #{type}")
  end
  if what == ""
    raise Exception.new(" \"What\" can\"t be an empty string")
  elsif type == "all"
    ["title", "artist", "album", "filename"].map{|t| find(t, what)}.reduce{|total, result| total+result}.uniq
  else
    print "search #{type} \"#{what}\"\n"
    parse_song_list(puts("search #{type} \"#{what}\""))
  end
 end

 def current_playlist_songs
  parse_song_list(puts("playlistid"))
 end

 def list_all_songs
  parse_song_list(puts("listallinfo"))
 end

 def current_song
   parse_song_list(puts("currentsong")).first
 end

 def stats
   to_hash(puts("stats"))
 end

 def ping
   unless status[:state] == "stop"
     output = {:song_time=>current_song[:time],:time=>status[:time].split(":").first,:artist=>current_song[:artist],:title=>current_song[:title],:file=>current_song[:file],:album=>current_song[:album],:id=>current_song[:id]}
   else
     output = {:song_time=>0,:time=>0,:artist=>nil,:title=>nil,:file=>nil,:album=>nil,:id=>nil}
   end
 end

 def list_playlists
   output = Array.new
   puts("listplaylists").each do |line|
     if line.match(/\Aplaylist\:(.*)\n\Z/)
       output << to_hash(line)
     end
   end
   output
 end

 def list_playlist_info(name)
   parse_song_list(puts("listplaylistinfo #{name}"))
 end

 def add_to_playlist(uri, name = nil)
   if name.nil?
     puts("add \"#{uri}\"")
   else
     puts("playlistadd \"#{name}\" \"#{uri}\"")
   end
 end

 def rename_playlist(original_name, name)
  puts("rename \"#{original_name}\" \"#{name}\"")
 end

 def create_playlist(name)
  puts("save \"#{name}\"")
 end

 def destroy_playlist(name)
  puts("rm \"#{name}\"")
 end

 def clear!(name = nil)
   if name.nil?
     puts("clear")
   else
     puts("playlistclear \"#{name}\"")
   end
 end

 def get_paths
  song_list(puts("listall"))
 end

 def list_library
   root = Tree::TreeNode.new("/")
   # root = Hash.new
   get_paths.each do |path|
     segments = path.split("/")
     if root[segments.first].nil?
       root << Tree::TreeNode.new(segments.first,segments.first)
       # root[segments.first] = {}
     end
     last_element = root[segments.first]
     first_element = segments.delete_at(0)
     segments.each_with_index do |element, index|
        if last_element[element].nil?
          last_element << Tree::TreeNode.new(element, first_element + "/" + segments[0...index+1].join("/") )
          # last_element[element] = {}
        end
        last_element = last_element[element]
     end
   end
   root
 end

 def delete_song(song)
   puts("delete #{song.to_s}")
 end

 def move_song(from, to)
  puts("move #{from.to_s} #{to.to_s}")
 end
 private

  def puts(command)
    @socket.puts(command)
    gets
  end

  def gets
    response = ""
    while line = @socket.gets do
      if @@regexps["OK"].match(line)
        return response
      elsif error = @@regexps["ACK"].match(line)
        raise Exception.new(line)
      else
        response << line
      end
    end
    response
  end

  def status
    output = puts("status")
    to_hash(output)
  end

  def to_hash(string)
    status_hash = Hash.new
    string.each do |line|
      key, value = line.chomp.split(": ", 2) 
      status_hash[key.downcase.to_sym] = value
    end 
    status_hash
  end

  def parse_song_list(song_list)
    output = Array.new
    song_hash = Hash.new
    song_list.each do |song|
      if song.match(@@regexps["FILE"])
        output << song_hash
        song_hash = Hash.new
      end
      song_hash.merge!(to_hash(song))
    end
    output << song_hash
    output.delete_at(0)
    output
  end

  def song_list(list)
    output = Array.new
    list.each do |song|
      if song.match(@@regexps["FILE"])
        output << song.split(": ",2)[1].gsub!("\n","")
      end
    end
    output
  end

  class Exception < StandardError  
  end
end
