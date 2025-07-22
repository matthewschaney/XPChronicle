-- DB.lua
-- XPChronicle: core XP‑tracking, history & bucket management,
-- with timestamp migration & full rebuild‑on‑resize

XPChronicle = XPChronicle or {}
XPChronicle.DB = {}
local DB = XPChronicle.DB

local BUCKET_SECS = 3600
local REFRESH     = 1

-- 1) Backfill old historyEvents so they all get a .ts
function DB:MigrateOldEvents()
  local match = string.match
  for _, ev in ipairs(AvgXPDB.historyEvents or {}) do
    if not ev.ts and ev.day and ev.time then
      local y,mo,d,hh,mm,ss = match(ev.day.." "..ev.time,
        "(%d+)%-(%d+)%-(%d+)%s+(%d+):(%d+):(%d+)"
      )
      if y then
        local ok, ts = pcall(time, {
          year  = tonumber(y),
          month = tonumber(mo),
          day   = tonumber(d),
          hour  = tonumber(hh),
          min   = tonumber(mm),
          sec   = tonumber(ss),
        })
        if ok and ts then ev.ts = ts end
      end
    end
  end
end

-- 2) Init & Reset
function DB:Init()
  AvgXPDB = AvgXPDB or {}
  if type(AvgXPDB) ~= "table" then AvgXPDB = {} end

  -- totals & buckets
  AvgXPDB.totalXP       = AvgXPDB.totalXP       or 0
  AvgXPDB.totalTime     = AvgXPDB.totalTime     or 0
  AvgXPDB.buckets       = AvgXPDB.buckets       or 6
  AvgXPDB.hourBuckets   = AvgXPDB.hourBuckets   or {}
  AvgXPDB.bucketStarts  = AvgXPDB.bucketStarts  or {}
  for i=1,AvgXPDB.buckets do
    AvgXPDB.hourBuckets[i]  = AvgXPDB.hourBuckets[i]  or 0
    AvgXPDB.bucketStarts[i] = AvgXPDB.bucketStarts[i]
      or (time() - (AvgXPDB.buckets - i) * BUCKET_SECS)
  end
  AvgXPDB.lastBucketIx   = AvgXPDB.lastBucketIx
    and math.min(AvgXPDB.lastBucketIx, AvgXPDB.buckets)
    or AvgXPDB.buckets
  AvgXPDB.lastBucketTime = AvgXPDB.bucketStarts[AvgXPDB.lastBucketIx]
  if AvgXPDB.graphHidden == nil then AvgXPDB.graphHidden = false end

  -- history & events
  AvgXPDB.history       = AvgXPDB.history       or {}
  AvgXPDB.historyEvents = AvgXPDB.historyEvents or {}
  AvgXPDB.historyMode   = AvgXPDB.historyMode   or "hour"

  -- frame locks & minimap pos
  AvgXPDB.mainLocked    = AvgXPDB.mainLocked    == nil and false or AvgXPDB.mainLocked
  AvgXPDB.historyLocked = AvgXPDB.historyLocked == nil and false or AvgXPDB.historyLocked
  AvgXPDB.minimapPos    = AvgXPDB.minimapPos    or {}

  -- time‑lock offset (defaults to 0 past the hour)
  AvgXPDB.gridOffset    = AvgXPDB.gridOffset or 0
  -- prediction mode toggle (added)
  AvgXPDB.predictionMode = AvgXPDB.predictionMode or false

  -- backfill old events
  self:MigrateOldEvents()

  -- session internals
  self._acc       = 0
  self._sessionXP = 0
  self._startXP   = 0
  self._startTime = 0
end

function DB:Reset()
  -- preserve any user‑set gridOffset across resets
  local oldOffset = AvgXPDB and AvgXPDB.gridOffset
  AvgXPDB = {}
  if oldOffset then
    AvgXPDB.gridOffset = oldOffset
  end
  self:Init()
end

-- 3) Rotate buckets
function DB:Rotate()
  while (time() - AvgXPDB.lastBucketTime) >= BUCKET_SECS do
    AvgXPDB.lastBucketTime = AvgXPDB.lastBucketTime + BUCKET_SECS
    AvgXPDB.lastBucketIx   = (AvgXPDB.lastBucketIx % AvgXPDB.buckets) + 1
    AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx]  = 0
    AvgXPDB.bucketStarts[AvgXPDB.lastBucketIx] = AvgXPDB.lastBucketTime
  end
end

-- 4) Add & log
function DB:Add(xp)
  AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx] =
    (AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx] or 0) + xp
end

function DB:LogHistory(xp)
  local t   = time()
  local day = date("%Y-%m-%d", t)
  local hr  = date("%H:00",    t)
  AvgXPDB.history[day]       = AvgXPDB.history[day]       or {}
  AvgXPDB.history[day][hr]   = (AvgXPDB.history[day][hr] or 0) + xp
end

function DB:LogEvent(xp)
  local t       = time()
  local day     = date("%Y-%m-%d", t)
  local timestr = date("%H:%M:%S", t)
  table.insert(AvgXPDB.historyEvents, {
    day  = day,
    time = timestr,
    xp   = xp,
    ts   = t,
  })
end

-- 5) Rebuild all buckets from entire historyEvents (snapped by gridOffset)
function DB:RebuildBuckets()
  local now    = time()
  local n      = AvgXPDB.buckets
  local sec    = BUCKET_SECS
  local offset = AvgXPDB.gridOffset or 0
  local base   = now - ((now - offset) % sec)

  for i=1,n do
    AvgXPDB.bucketStarts[i] = base - (n - i) * sec
    AvgXPDB.hourBuckets[i]  = 0
  end
  AvgXPDB.lastBucketIx   = n
  AvgXPDB.lastBucketTime = AvgXPDB.bucketStarts[n]

  for _, ev in ipairs(AvgXPDB.historyEvents) do
    local ts = ev.ts
    if ts and ts >= AvgXPDB.bucketStarts[1] then
      local idx = math.floor((ts - AvgXPDB.bucketStarts[1]) / sec) + 1
      if idx >= 1 and idx <= n then
        AvgXPDB.hourBuckets[idx] = AvgXPDB.hourBuckets[idx] + ev.xp
      end
    end
  end
end

-- 6) Override SetBuckets to rebuild
function DB:SetBuckets(n)
  AvgXPDB.buckets = n
  self:RebuildBuckets()
end

-- 7) Session & logout
function DB:StartSession()
  self._startXP   = UnitXP("player")
  self._startTime = time()
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
  self:LogEvent(gain)
end

function DB:OnLogout()
  local t = time() - self._startTime
  AvgXPDB.totalXP   = AvgXPDB.totalXP   + self._sessionXP
  AvgXPDB.totalTime = AvgXPDB.totalTime + t
end

function DB:OnUpdate(dt)
  self._acc = (self._acc or 0) + dt
  if self._acc >= REFRESH then
    self._acc = self._acc - REFRESH
    self:Rotate()
  end
end

-- 8) Rates & accessors
function DB:GetSessionRate()
  local elapsed = math.max(time() - self._startTime, 1)
  return self._sessionXP / (elapsed / 3600)
end

function DB:GetOverallRate()
  local elapsed = AvgXPDB.totalTime + (time() - self._startTime)
  if elapsed <= 0 then return 0 end
  return (AvgXPDB.totalXP + self._sessionXP) / (elapsed / 3600)
end

function DB:GetHourlyBuckets()
  return AvgXPDB.hourBuckets, AvgXPDB.bucketStarts, AvgXPDB.lastBucketIx
end

function DB:GetMaxBucket()
  local m = 1
  for _, v in ipairs(AvgXPDB.hourBuckets) do m = math.max(m, v or 0) end
  return m
end
