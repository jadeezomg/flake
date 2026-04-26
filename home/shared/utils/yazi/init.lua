-- Custom linemode: human-readable size + mtime (year omitted when current).
-- Referenced from yazi.toml via `[mgr] linemode = "size_and_mtime"`.
function Linemode:size_and_mtime()
  local mtime = math.floor(self._file.cha.mtime or 0)
  local formatted
  if mtime == 0 then
    formatted = ""
  elseif os.date("%Y", mtime) == os.date("%Y") then
    formatted = os.date("%b %d %H:%M", mtime)
  else
    formatted = os.date("%b %d  %Y", mtime)
  end

  local size = self._file:size()
  return string.format("%s %s", size and ya.readable_size(size) or "-", formatted)
end
