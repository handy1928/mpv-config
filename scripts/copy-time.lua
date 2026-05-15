-- copy-time (Windows version)

-- Copies current timecode in HH:MM:SS.MS format to clipboard

-------------------------------------------------------------------------------
-- Script adapted by Alex Rogers (https://github.com/linguisticmind)
-- Modified from https://github.com/Arieleg/mpv-copyTime
-- Released under GNU GPL 3.0

require "mp"

-- Function to convert time string to milliseconds
local function timeToMilliseconds(timeString)
  local hours, minutes, seconds, milliseconds = timeString:match("(%d+):(%d+):(%d+).(%d+)")
  return (tonumber(hours) * 3600000) + (tonumber(minutes) * 60000) + (tonumber(seconds) * 1000) + tonumber(milliseconds)
end

-- Function to calculate time difference and return the result as a formatted time string
local function calculateTimeDifference(timeString1, timeString2)
  local milliseconds1 = timeToMilliseconds(timeString1)
  local milliseconds2 = timeToMilliseconds(timeString2)

  local diffMilliseconds = milliseconds2 - milliseconds1

  local sign = "-"
  if diffMilliseconds < 0 then
      sign = ""
      diffMilliseconds = math.abs(diffMilliseconds)
  end

  local hours = math.floor(diffMilliseconds / 3600000)
  local minutes = math.floor((diffMilliseconds % 3600000) / 60000)
  local seconds = math.floor((diffMilliseconds % 60000) / 1000)
  local milliseconds = diffMilliseconds % 1000

  --return string.format("%s%02d:%02d:%02d.%03d", sign, hours, minutes, seconds, milliseconds)
  --return string.format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
  return string.format("%s%d", sign, diffMilliseconds)
end

function calc_curr_time()
  local time_pos = mp.get_property_number("time-pos")
  local time_in_seconds = time_pos
  local time_seg = time_pos % 60
  time_pos = time_pos - time_seg
  local time_hours = math.floor(time_pos / 3600)
  time_pos = time_pos - (time_hours * 3600)
  local time_minutes = time_pos/60
  time_seg,time_ms=string.format("%.03f", time_seg):match"([^.]*).(.*)"
  time = string.format("%02d:%02d:%02d.%s", time_hours, time_minutes, time_seg, time_ms)
  return time
end

function copy_time()
  time = calc_curr_time()
  mp.commandv("script-message", "set-clipboard", time)
end

function calc_time_diff()
  mp.commandv("script-message", "get-clipboard", "calc-time-diff-inside")
end

function calc_time_diff_inside(response)
  time = calc_curr_time()
  local timeDifference = calculateTimeDifference(time, response)
  mp.commandv("script-message", "set-clipboard", timeDifference)
  mp.osd_message(string.format("Copied to clipboard: %s", timeDifference))
end

mp.register_script_message('calc-time-diff-inside', calc_time_diff_inside)

mp.add_key_binding(nil, "copy-time", copy_time)
mp.add_key_binding(nil, "calc-time-diff", calc_time_diff)
