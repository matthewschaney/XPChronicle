-- XPChronicle ▸ Utils.lua

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


-- XPChronicle ▸ DB.lua

local XPChronicle  = XPChronicle or {}
XPChronicle.DB     = XPChronicle.DB or {}
local DB           = XPChronicle.DB

-- Constants ------------------------------------------------------------------
local BUCKET_SECS  = 3600  -- Seconds per bucket.
local REFRESH_SECS = 1     -- OnUpdate cadence.

-- Utility helpers ------------------------------------------------------------
local function now() return time() end

--- Ensure `tbl[key]` is non‑nil; return the final value.
local function ensure(tbl, key, default)
  if tbl[key] == nil then tbl[key] = default end
  return tbl[key]
end

-- 1) Migrate legacy (.ts‑less) events ----------------------------------------
function DB:MigrateOldEvents()
  local match = string.match
  for _, ev in ipairs(AvgXPDB.historyEvents or {}) do
    if not ev.ts and ev.day and ev.time then
      local y, mo, d, hh, mm, ss =
        match(ev.day .. " " .. ev.time,
              "(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+):(%d+)")
      if y then
        local ok, ts = pcall(time, {
          year  = tonumber(y),  month = tonumber(mo),  day  = tonumber(d),
          hour  = tonumber(hh), min   = tonumber(mm),  sec  = tonumber(ss),
        })
        if ok and ts then ev.ts = ts end
      end
    end
  end
end

-- 2) Init / Reset database ---------------------------------------------------
function DB:Init()
  AvgXPDB = (type(AvgXPDB) == "table") and AvgXPDB or {}

  -- Scalars & toggles --------------------------------------------------------
  ensure(AvgXPDB, "totalXP",        0)
  ensure(AvgXPDB, "totalTime",      0)
  ensure(AvgXPDB, "buckets",        6)
  ensure(AvgXPDB, "graphHidden",    false)
  ensure(AvgXPDB, "historyMode",    "hour")
  ensure(AvgXPDB, "mainLocked",     false)
  ensure(AvgXPDB, "reportLocked",   false)
  ensure(AvgXPDB, "gridOffset",     0)
  ensure(AvgXPDB, "predictionMode", false)
  ensure(AvgXPDB, "minimapPos",     {})

  -- Tables -------------------------------------------------------------------
  ensure(AvgXPDB, "hourBuckets",   {})
  ensure(AvgXPDB, "bucketStarts",  {})
  ensure(AvgXPDB, "history",       {})
  ensure(AvgXPDB, "historyEvents", {})

  -- Bucket seeds -------------------------------------------------------------
  local n     = AvgXPDB.buckets
  local base  = now() - (n - 1) * BUCKET_SECS
  for i = 1, n do
    AvgXPDB.bucketStarts[i] = (AvgXPDB.bucketStarts[i] or 
                              (base + (i - 1) * BUCKET_SECS))
    AvgXPDB.hourBuckets[i]  = AvgXPDB.hourBuckets[i]  or 0
  end
  AvgXPDB.lastBucketIx   = math.min(AvgXPDB.lastBucketIx or n, n)
  AvgXPDB.lastBucketTime = AvgXPDB.bucketStarts[AvgXPDB.lastBucketIx]

  -- One‑off migration --------------------------------------------------------
  self:MigrateOldEvents()

  -- Session internals --------------------------------------------------------
  self._acc, self._sessionXP, self._startXP, self._startTime = 0, 0, 0, 0
end

function DB:Reset()
  local offset = AvgXPDB and AvgXPDB.gridOffset
  AvgXPDB      = { gridOffset = offset }
  self:Init()
end

-- 3) Rotate rolling buckets --------------------------------------------------
function DB:Rotate()
  while (now() - AvgXPDB.lastBucketTime) >= BUCKET_SECS do
    AvgXPDB.lastBucketTime = AvgXPDB.lastBucketTime + BUCKET_SECS
    AvgXPDB.lastBucketIx   = (AvgXPDB.lastBucketIx % AvgXPDB.buckets) + 1
    AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx]  = 0
    AvgXPDB.bucketStarts[AvgXPDB.lastBucketIx] = AvgXPDB.lastBucketTime
  end
end

-- Add XP & write history -----------------------------------------------------
function DB:Add(xp)
  AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx] =
    (AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx] or 0) + xp
end

function DB:LogHistory(xp)
  local t   = now()
  local day = date("%Y-%m-%d", t)
  local hr  = date("%H:00",    t)
  ensure(AvgXPDB.history, day, {})[hr] =
    (AvgXPDB.history[day][hr] or 0) + xp
end

function DB:LogEvent(xp)
  local t = now()
  table.insert(AvgXPDB.historyEvents, {
    day  = date("%Y-%m-%d", t),
    time = date("%H:%M:%S", t),
    xp   = xp,
    ts   = t,
  })
end

-- 5) Rebuild buckets from full event log (grid‑snapped) ----------------------
function DB:RebuildBuckets()
  local n      = AvgXPDB.buckets
  local offset = AvgXPDB.gridOffset or 0
  local base   = now() - ((now() - offset) % BUCKET_SECS)

  for i = 1, n do
    AvgXPDB.bucketStarts[i] = base - (n - i) * BUCKET_SECS
    AvgXPDB.hourBuckets[i]  = 0
  end
  AvgXPDB.lastBucketIx   = n
  AvgXPDB.lastBucketTime = AvgXPDB.bucketStarts[n]

  for _, ev in ipairs(AvgXPDB.historyEvents) do
    local ts = ev.ts
    if ts and ts >= AvgXPDB.bucketStarts[1] then
      local idx = math.floor((ts - AvgXPDB.bucketStarts[1]) / BUCKET_SECS) + 1
      if idx >= 1 and idx <= n then
        AvgXPDB.hourBuckets[idx] = AvgXPDB.hourBuckets[idx] + ev.xp
      end
    end
  end
end

-- Exposed: change bucket count -----------------------------------------------
function DB:SetBuckets(n)
  AvgXPDB.buckets = n
  self:RebuildBuckets()
end

-- Session lifecycle ----------------------------------------------------------
function DB:StartSession()
  self._startXP   = UnitXP("player")
  self._startTime = now()
  self._sessionXP = 0
end

function DB:OnXPUpdate()
  local cur  = UnitXP("player")
  local gain = cur - self._startXP
  if gain < 0 then                                         -- Level‑up wrap.
    gain = (UnitXPMax("player") - self._startXP) + cur
  end
  self._sessionXP = self._sessionXP + gain
  self._startXP   = cur

  self:Add(gain); self:LogHistory(gain); self:LogEvent(gain)
end

function DB:OnLogout()
  local elapsed = now() - self._startTime
  AvgXPDB.totalXP   = AvgXPDB.totalXP   + self._sessionXP
  AvgXPDB.totalTime = AvgXPDB.totalTime + elapsed
end

function DB:OnUpdate(dt)
  self._acc = self._acc + dt
  if self._acc >= REFRESH_SECS then
    self._acc = self._acc - REFRESH_SECS
    self:Rotate()
  end
end

-- Rate helpers / misc --------------------------------------------------------
function DB:GetSessionRate()
  local elapsed = math.max(now() - self._startTime, 1)
  return self._sessionXP / (elapsed / 3600)
end

function DB:GetOverallRate()
  local elapsed = AvgXPDB.totalTime + (now() - self._startTime)
  local hrs = elapsed / 3600
  return (elapsed > 0) and (AvgXPDB.totalXP + self._sessionXP) / hrs or 0
end

function DB:GetHourlyBuckets()
  return AvgXPDB.hourBuckets, AvgXPDB.bucketStarts, AvgXPDB.lastBucketIx
end

function DB:GetMaxBucket()
  local max = 1
  for _, v in ipairs(AvgXPDB.hourBuckets) do
    if v and v > max then max = v end
  end
  return max
end