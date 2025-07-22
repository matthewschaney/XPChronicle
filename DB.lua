-- DB.lua
-- Saved‑variable setup, bucket rotation, session tracking, and history logging

XPChronicle = XPChronicle or {}
XPChronicle.DB = {}
local DB = XPChronicle.DB

local BUCKET_SECS = 3600
local REFRESH     = 1

function DB:Init()
  AvgXPDB = AvgXPDB or {}
  if type(AvgXPDB) ~= "table" then AvgXPDB = {} end

  -- core xp/hr data
  AvgXPDB.totalXP    = AvgXPDB.totalXP    or 0
  AvgXPDB.totalTime  = AvgXPDB.totalTime  or 0
  AvgXPDB.buckets    = AvgXPDB.buckets    or 6
  AvgXPDB.hourBuckets  = AvgXPDB.hourBuckets  or {}
  AvgXPDB.bucketStarts = AvgXPDB.bucketStarts or {}

  for i = 1, AvgXPDB.buckets do
    AvgXPDB.hourBuckets[i]  = AvgXPDB.hourBuckets[i]  or 0
    AvgXPDB.bucketStarts[i] = AvgXPDB.bucketStarts[i]
      or (time() - (AvgXPDB.buckets - i) * BUCKET_SECS)
  end

  AvgXPDB.lastBucketIx   = AvgXPDB.lastBucketIx
    and math.min(AvgXPDB.lastBucketIx, AvgXPDB.buckets)
    or AvgXPDB.buckets
  AvgXPDB.lastBucketTime = AvgXPDB.bucketStarts[AvgXPDB.lastBucketIx]

  if AvgXPDB.graphHidden == nil then AvgXPDB.graphHidden = false end

  -- history table keyed by "YYYY‑MM‑DD" → list of { time="HH:MM:SS", xp=number }
  AvgXPDB.history = AvgXPDB.history or {}

  -- session internals
  self._acc       = 0
  self._sessionXP = 0
  self._startXP   = 0
  self._startTime = 0
end

function DB:Reset()
  AvgXPDB = {}
  self:Init()
end

function DB:Rotate()
  while (time() - AvgXPDB.lastBucketTime) >= BUCKET_SECS do
    AvgXPDB.lastBucketTime = AvgXPDB.lastBucketTime + BUCKET_SECS
    AvgXPDB.lastBucketIx = (AvgXPDB.lastBucketIx % AvgXPDB.buckets) + 1
    AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx]  = 0
    AvgXPDB.bucketStarts[AvgXPDB.lastBucketIx] = AvgXPDB.lastBucketTime
  end
end

function DB:Add(xp)
  AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx] =
    (AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx] or 0) + xp
end

function DB:LogHistory(xp)
  local t = time()
  local day = date("%Y-%m-%d", t)
  local hist = AvgXPDB.history
  hist[day] = hist[day] or {}
  table.insert(hist[day], {
    time = date("%H:%M:%S", t),
    xp   = xp
  })
end

function DB:StartSession()
  self._startXP   = UnitXP("player")
  self._startTime = time()
  self._sessionXP = 0
end

function DB:OnXPUpdate()
  local cur = UnitXP("player")
  local gain = cur - self._startXP
  if gain < 0 then
    gain = (UnitXPMax("player") - self._startXP) + cur
  end
  self._sessionXP = self._sessionXP + gain
  self._startXP   = cur

  self:Add(gain)
  self:LogHistory(gain)
end

function DB:OnLogout()
  local t = time() - self._startTime
  AvgXPDB.totalXP   = AvgXPDB.totalXP + self._sessionXP
  AvgXPDB.totalTime = AvgXPDB.totalTime + t
end

function DB:OnUpdate(dt)
  self._acc = (self._acc or 0) + dt
  if self._acc >= REFRESH then
    self._acc = self._acc - REFRESH
    self:Rotate()
  end
end

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
  local max = 1
  for _, v in ipairs(AvgXPDB.hourBuckets) do
    max = math.max(max, v or 0)
  end
  return max
end

function DB:SetBuckets(n)
  AvgXPDB.buckets = n
  for i = #AvgXPDB.hourBuckets + 1, n do
    AvgXPDB.hourBuckets[i]  = 0
    AvgXPDB.bucketStarts[i] = time() - (n - i) * BUCKET_SECS
  end
  for i = n + 1, #AvgXPDB.hourBuckets do
    AvgXPDB.hourBuckets[i]  = nil
    AvgXPDB.bucketStarts[i] = nil
  end
end
