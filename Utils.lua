-- Utils.lua
-- Common helpers (formatting, bucket indexing)

XPChronicle = XPChronicle or {}
XPChronicle.Utils = {}
local Utils = XPChronicle.Utils

function Utils.fmt(n)
  return string.format("%.0f", n)
end

function Utils.bucketIndexForBar(i, NB, lastIx)
  local offset = NB - i
  return ((lastIx - offset - 1) % NB) + 1
end
