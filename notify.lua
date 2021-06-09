-- notify.lua -- Desktop notifications for mpv.
-- Just put this file into your ~/.config/mpv/scripts folder and mpv will find it.
--
-- Copyright (c) 2014 Roland Hieber
-- (Also some minor edits from Arindam Das)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-------------------------------------------------------------------------------
-- helper functions
-------------------------------------------------------------------------------

function print_debug(s)
  print("INFO: " .. s) -- comment out for no debug info
  return true
end

-- url-escape a string, per RFC 2396, Section 2
function string.urlescape(str)
  local s, c = string.gsub(str, "([^A-Za-z0-9_.!~*'()/-])",
  function(c)
    return ("%%%02x"):format(c:byte())
  end)
  return s
end

-- escape string for html
function string.htmlescape(str)
  local str = string.gsub(str, "<", "&lt;")
  str = string.gsub(str, ">", "&gt;")
  str = string.gsub(str, "&", "&amp;")
  str = string.gsub(str, "\"", "&quot;")
  str = string.gsub(str, "'", "&apos;")
  return str
end

-- escape string for shell inclusion
function string.shellescape(str)
  return "'"..string.gsub(str, "'", "'\"'\"'").."'"
end

-- converts string to a valid filename on most (modern) filesystems
function string.safe_filename(str)
  local s, _ = string.gsub(str, "([^A-Za-z0-9_.-])",
  function(c)
    return ("%02x"):format(c:byte())
  end)
  return s
end

-- write the string to a file
function string.dumpf(str, path)
  local file = io.open(path, "w")
  file:write(str)
  file:close()
end

-- check if a file exists ignoring case
function find_lowercase_file(path, filename)
  local command = ("find %s -iname %s -type f"):format(string.shellescape(path), string.shellescape(filename), "r")
  local pfile = io.popen(command)
  local output = pfile:read()
  pfile:close()
  return output
end


-------------------------------------------------------------------------------
-- here we go.
-------------------------------------------------------------------------------

-- scale an image file
-- @return boolean of success
function scaled_image(src, dst)
  local convert_cmd = ("convert -scale x64 -- %s %s"):format(
  string.shellescape(src), string.shellescape(dst))
  -- print_debug("executing " .. convert_cmd)
  if os.execute(convert_cmd) then
    return true
  end
  return false
end

-- extract image from audio file
function extracted_image_from_audiofile (audiofile, imagedst)
  local ffmpeg_cmd_a = ("ffmpeg -loglevel -8 -vsync 2 -y -i %s %s > /dev/null"):format(
  string.shellescape(audiofile), string.shellescape(imagedst)
  )

  -- print_debug("executing " .. ffmpeg_cmd_a)
  if os.execute(ffmpeg_cmd_a) then
    return true
  end

  return false
end

-- extract image from video file
function extracted_image_from_videofile (audiofile, imagedst)
  local ffmpeg_cmd_v = ("ffmpegthumbnailer -i %s -o %s 2>&1 >/dev/null"):format(
  string.shellescape(audiofile), string.shellescape(imagedst)
  )

  -- print_debug("executing " .. ffmpeg_cmd_v)
  if os.execute(ffmpeg_cmd_v) then
    return true
  end

  return false
end

function get_value(data, keys)
  for _,v in pairs(keys) do
    if data[v] and string.len(data[v]) > 0 then
      return data[v]
    end
  end
  return ""
end

-- return path without .. or .
function os.realpath(path)
  local pfile = io.popen(("realpath %s"):format(string.shellescape(path)), "r")
  local output = pfile:read()
  pfile:close()
  return output
end

-- copy file
function os.copy(source, dest)
  local command = ("cp %s %s"):format(string.shellescape(source), string.shellescape(dest))
  os.execute(command)
end

-- look for a list of possible cover art images in the same folder as the file
-- @param path absolute file path of currently played file, or nil if no match
function coppied_directory_cover(path, imagedst)
  -- print_debug("get_folder_cover_art: file path is " .. path)
  local cover_extensions = { "png", "jpg", "jpeg", "gif" }
  local cover_names = { "cover", "folder", "front", "back", "insert" }

  local dir = os.realpath(string.match(path, "^(.*)/[^/]+$"))

  for _, name in pairs(cover_names) do
    for _, ext in pairs(cover_extensions) do
      -- print_debug("get_folder_cover_art: trying " .. cover_path)
      local cover_name = name .. "." .. ext
      local actual_name = find_lowercase_file(dir, cover_name)
      if actual_name ~= nil then
	os.copy(actual_name, imagedst)
	return true
      end
    end
  end
  return false
end

COVER_ART_PATH = "/tmp/mpv.covert_art.jpg"
ICON_PATH = "/tmp/mpv.icon.jpg"
ARTIST_PATH = "/tmp/mpv.artist.txt"
ALBUM_PATH = "/tmp/mpv.album.txt"
TITLE_PATH = "/tmp/mpv.title.txt"

function notify_current_track()
  -- os.remove(COVER_ART_PATH)
  os.remove(ICON_PATH)

  local metadata = mp.get_property_native("metadata")

  -- track doesn't contain metadata
  if not metadata then
    return
  end

  -- we try to fetch metadata values using all possible keys
  local artist = get_value(metadata, {"artist", "ARTIST"})
  local album  = get_value(metadata, {"album", "ALBUM"})
  local title  = get_value(metadata, {"title", "TITLE", "icy-title"})
  artist:dumpf(ARTIST_PATH)
  album:dumpf(ALBUM_PATH)
  title:dumpf(TITLE_PATH)

  -- print_debug("notify_current_track(): -> extracted metadata:")
  -- print_debug("artist: " .. artist)
  -- print_debug("album: " .. album)
  -- print_debug("title: " .. title)

  -- absolute filename of currently playing audio file
  local abs_filename = os.getenv("PWD") .. "/" .. mp.get_property_native("path")
  local bad_string = os.getenv("PWD") .. "//"
  local abs_filename = string.gsub(abs_filename,bad_string,"/")
  -- print_debug(abs_filename)

  params = ""
  -- extract cover art: set it as icon in notification params
  if coppied_directory_cover(abs_filename, COVER_ART_PATH) then
    if scaled_image(COVER_ART_PATH, ICON_PATH) then
      params = "-i " .. ICON_PATH
    end
  elseif extracted_image_from_audiofile(abs_filename, COVER_ART_PATH) then
    if scaled_image(COVER_ART_PATH, ICON_PATH) then
      params = "-i " .. ICON_PATH
    end
  elseif extracted_image_from_videofile(abs_filename, COVER_ART_PATH) then
    params = "-i "..COVER_ART_PATH
  end

  -- form notification summary
  summary_str ="Now playing:"
  if (string.len(artist) > 0) then
    summary_str = string.htmlescape(artist)
  end
  summary = string.shellescape(summary_str)

  body_str = mp.get_property_native("filename")
  if (string.len(title) > 0) then
    if (string.len(album) > 0) then
      body_str = ("%s<br /><i>%s</i>"):format(
      string.htmlescape(title), string.htmlescape(album))
    else
      body_str = string.htmlescape(title)
    end
  end

  body = string.shellescape(body_str)

  local command = ("notify-send -a mpv %s -- %s %s"):format(params, summary, body)
  -- print_debug("command: " .. command)
  os.execute(command)

end

-- notify hook
function notify_metadata_updated(name, data)
  notify_current_track()
end

-- empty or remove files so the clients know nothing is playing
function cleanup(event)
  local text_files = {ARTIST_PATH, ALBUM_PATH, TITLE_PATH}
  local emptystr = ""
  for _, path in ipairs(text_files) do
    emptystr:dumpf(path)
  end
  local binary_files = {ICON_PATH, COVER_ART_PATH}
  for _, path in ipairs(binary_files) do
    os.remove(path)
  end
end


-- insert main() here

mp.register_event("file-loaded", notify_current_track)
mp.register_event("shutdown", cleanup)
-- mp.observe_property("metadata", nil, notify_metadata_updated)
