-- XPChronicle ▸ DB.lua

local XPChronicle  = XPChronicle or {}
XPChronicle.DB     = XPChronicle.DB or {}
local DB           = XPChronicle.DB

-- Constants ------------------------------------------------------------------
local BUCKET_SECS  = 3600  -- Seconds per bucket.
local REFRESH_SECS = 1     -- OnUpdate cadence.

-- Utility helpers ------------------------------------------------------------
local function now() return time() end
local GetTime = GetTime

local function ensure(tbl, key, default)
  if tbl[key] == nil then tbl[key] = default end
  return tbl[key]
end

local function isNear(a, b, sec)
  return math.abs((a.ts or 0) - (b.ts or 0)) <= (sec or 2)
end

-- Priority table for deciding which event to keep
local PRIORITY = { generic = 1, kill = 2, discover = 3, quest = 4 }

local function shouldReplace(oldEv, newEv)
  if not oldEv then return false end
  if oldEv.xp ~= newEv.xp then return false end
  if not isNear(oldEv, newEv, 3) then return false end
  return (PRIORITY[newEv.kind] or 0) > (PRIORITY[oldEv.kind] or 0)
end

-- 1) Migrate legacy (.ts-less) events ----------------------------------------
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

  ensure(AvgXPDB, "hourBuckets",   {})
  ensure(AvgXPDB, "bucketStarts",  {})
  ensure(AvgXPDB, "history",       {})
  ensure(AvgXPDB, "historyEvents", {})

  local n     = AvgXPDB.buckets
  local base  = now() - (n - 1) * BUCKET_SECS
  for i = 1, n do
    AvgXPDB.bucketStarts[i] = (AvgXPDB.bucketStarts[i] or (base + (i - 1) * BUCKET_SECS))
    AvgXPDB.hourBuckets[i]  = AvgXPDB.hourBuckets[i]  or 0
  end
  AvgXPDB.lastBucketIx   = math.min(AvgXPDB.lastBucketIx or n, n)
  AvgXPDB.lastBucketTime = AvgXPDB.bucketStarts[AvgXPDB.lastBucketIx]

  self:MigrateOldEvents()

  self._acc, self._sessionXP, self._startXP, self._startTime = 0, 0, 0, 0
  self._suppressUntil = nil
  self._lastEvent = nil
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

-- Main logging with duplicate resolution -------------------------------------
function DB:LogEvent(xp, desc, kind, extra)
  local t = now()
  local ev = {
    day  = date("%Y-%m-%d", t),
    time = date("%H:%M:%S", t),
    xp   = xp,
    ts   = t,
    desc = desc,
    kind = kind or "generic",
  }
  if extra then for k,v in pairs(extra) do ev[k] = v end end

  local list = AvgXPDB.historyEvents
  local lastIx = #list

  -- 1️⃣ Replace any recent lower-priority event
  for i = lastIx, math.max(1, lastIx - 5), -1 do
    if shouldReplace(list[i], ev) then
      list[i] = ev
      self._lastEvent = ev
      return
    end
  end

  -- 2️⃣ Drop if same-or-higher priority event exists already
  for i = lastIx, math.max(1, lastIx - 5), -1 do
    local cand = list[i]
    if cand and cand.xp == ev.xp and isNear(cand, ev, 3) then
      if (PRIORITY[cand.kind] or 0) >= (PRIORITY[ev.kind] or 0) then
        return
      end
    end
  end

  -- 3️⃣ Skip blank generics
  if (not ev.desc or ev.desc == "") then
    if ev.kind ~= "generic" then
      ev.desc = ev.kind
    else
      return
    end
  end

  table.insert(list, ev)
  self._lastEvent = ev
end

-- Prevent double-logging immediately after a detailed event was captured
function DB:SuppressNextGenericEvent(window)
  self._suppressUntil = GetTime() + (window or 1.5)
end

-- 5) Rebuild buckets from full event log ------------------------------------
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
  if gain < 0 then
    gain = (UnitXPMax("player") - self._startXP) + cur
  end
  self._sessionXP = self._sessionXP + gain
  self._startXP   = cur

  self:Add(gain)
  self:LogHistory(gain)

  if not self._suppressUntil or GetTime() >= self._suppressUntil then
    self:LogEvent(gain, nil, "generic")
  end
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
