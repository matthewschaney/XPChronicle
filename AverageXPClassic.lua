-- AverageXPClassic.lua – v1.0.0 - Initial Release

-----------------------------------------------------------------
-- basic constants
-----------------------------------------------------------------
-- seconds per bucket (1 hour)
local BUCKET_SECS = 3600
local PANEL_W, PANEL_H = 200, 56
local BAR_H = 40
-- /avgxp buckets <n>
local NUM_BUCKETS_DEF = 6
-- seconds between auto‑updates
local REFRESH = 1

-----------------------------------------------------------------
-- saved‑variable init
-----------------------------------------------------------------
AvgXPDB = AvgXPDB or {}
local function InitDB()
if type(AvgXPDB) ~= 'table' then AvgXPDB = {} end
AvgXPDB.totalXP = AvgXPDB.totalXP or 0
AvgXPDB.totalTime = AvgXPDB.totalTime or 0
AvgXPDB.buckets = AvgXPDB.buckets or NUM_BUCKETS_DEF
AvgXPDB.hourBuckets = AvgXPDB.hourBuckets or {}
AvgXPDB.bucketStarts = AvgXPDB.bucketStarts or {}
for i = 1, AvgXPDB.buckets do
AvgXPDB.hourBuckets[i] = AvgXPDB.hourBuckets[i] or 0
AvgXPDB.bucketStarts[i] = AvgXPDB.bucketStarts[i]
or (time() - (AvgXPDB.buckets - i) * BUCKET_SECS)
end
-- start in (and point to) the newest bucket – the right‑most bar
AvgXPDB.lastBucketIx = AvgXPDB.lastBucketIx
and math.min(AvgXPDB.lastBucketIx, AvgXPDB.buckets)
or AvgXPDB.buckets
AvgXPDB.lastBucketTime = AvgXPDB.bucketStarts[AvgXPDB.lastBucketIx]
if AvgXPDB.graphHidden == nil then AvgXPDB.graphHidden = false end
end
InitDB()

-----------------------------------------------------------------
-- helpers
-----------------------------------------------------------------
local NB = AvgXPDB.buckets
local BAR_W = PANEL_W / NB
local function fmt(n) return string.format('%.0f', n) end
-- map bar position (1 = leftmost) to the bucket index in saved tables
local function bucketIndexForBar(i)
-- 0 = current hour on right
local offset = NB - i
return ((AvgXPDB.lastBucketIx - offset - 1) % NB) + 1
end

-----------------------------------------------------------------
-- main panel
-----------------------------------------------------------------
local back = _G.AverageXPClassicDisplay
if not back then
back = CreateFrame('Frame', 'AverageXPClassicDisplay', UIParent,
'BackdropTemplate')
end
back:SetSize(PANEL_W, PANEL_H)
back:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8x8' })
back:SetBackdropColor(0, 0, 0, 0.55)
back:SetMovable(true); back:EnableMouse(true)
back:RegisterForDrag('LeftButton')
back:SetScript('OnDragStart', back.StartMoving)
back:SetScript('OnDragStop', function(self)
self:StopMovingOrSizing()
local p, _, rp, x, y = self:GetPoint()
AvgXPDB.pos = { point = p, relativePoint = rp, x = x, y = y }
end)
back:ClearAllPoints()
if AvgXPDB.pos then
back:SetPoint(AvgXPDB.pos.point, UIParent,
AvgXPDB.pos.relativePoint, AvgXPDB.pos.x, AvgXPDB.pos.y)
else
back:SetPoint('CENTER', 0, 200)
end
local label = back.label or back:CreateFontString(nil, 'OVERLAY',
'GameFontNormalLarge')
back.label = label
label:SetPoint('CENTER')
label:SetWidth(PANEL_W)
label:SetJustifyH('CENTER')

-----------------------------------------------------------------
-- graph
-----------------------------------------------------------------
local graph = _G.AverageXPClassicGraph or CreateFrame('Frame',
'AverageXPClassicGraph', back)
graph:SetPoint('TOP', back, 'BOTTOM', 0, -8)
local bars, texts = {}, {}
local function BuildBars()
NB = AvgXPDB.buckets
BAR_W = PANEL_W / NB
graph:SetSize(PANEL_W, BAR_H)
-- hide any existing objects
for _, o in ipairs(bars) do o:Hide() end
for _, o in ipairs(texts) do o:Hide() end
wipe(bars); wipe(texts)
for i = 1, NB do
local bar = CreateFrame('StatusBar', nil, graph, 'BackdropTemplate')
bar:SetSize(BAR_W, BAR_H)
-- fill bottom → top
bar:SetOrientation('VERTICAL')
bar:SetStatusBarTexture('Interface\\Buttons\\WHITE8x8')
bar:GetStatusBarTexture():SetVertexColor(0.2, 0.8, 1)
bar:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8x8' })
bar:SetBackdropColor(0, 0, 0, 0.6)
bar:SetPoint('BOTTOMLEFT', (i - 1) * BAR_W, 0)
bars[i] = bar
local txt = graph:CreateFontString(nil, 'OVERLAY',
'GameFontNormalSmall')
txt:SetPoint('TOP', bar, 'BOTTOM', 0, -2)
texts[i] = txt
bar:SetScript('OnEnter', function(self)
local idx = bucketIndexForBar(i)
local xp = AvgXPDB.hourBuckets[idx] or 0
GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
GameTooltip:AddLine(date('%H:%M', AvgXPDB.bucketStarts[idx]))
GameTooltip:AddLine(string.format('%d XP', xp), 1, 1, 1)
GameTooltip:Show()
end)
bar:SetScript('OnLeave', GameTooltip_Hide)
end
graph:SetShown(not AvgXPDB.graphHidden)
end
BuildBars()

-----------------------------------------------------------------
-- bucket rotation
-----------------------------------------------------------------
local function Rotate()
while (time() - AvgXPDB.lastBucketTime) >= BUCKET_SECS do
AvgXPDB.lastBucketTime = AvgXPDB.lastBucketTime + BUCKET_SECS
AvgXPDB.lastBucketIx = AvgXPDB.lastBucketIx % NB + 1
AvgXPDB.hourBuckets [AvgXPDB.lastBucketIx] = 0
AvgXPDB.bucketStarts[AvgXPDB.lastBucketIx] = AvgXPDB.lastBucketTime
end
end
local function Add(xp)
AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx] =
 (AvgXPDB.hourBuckets[AvgXPDB.lastBucketIx] or 0) + xp
end

-----------------------------------------------------------------
-- session
-----------------------------------------------------------------
local startXP, startTime, sessionXP = 0, 0, 0

-----------------------------------------------------------------
-- redraw
-----------------------------------------------------------------
local function Refresh()
local elapsed = math.max(time() - startTime, 1)
local sAvg = sessionXP / (elapsed / 3600)
local oAvg = (AvgXPDB.totalTime + elapsed) > 0
and (AvgXPDB.totalXP + sessionXP) /
 ((AvgXPDB.totalTime + elapsed) / 3600) or 0
label:SetText('Session: ' .. fmt(sAvg) .. ' XP/h\n\nOverall: ' ..
fmt(oAvg) .. ' XP/h')
local max = 1
for i = 1, NB do max = math.max(max, AvgXPDB.hourBuckets[i] or 0) end
for i = 1, NB do
local idx = bucketIndexForBar(i)
bars[i]:SetMinMaxValues(0, max)
bars[i]:SetValue(AvgXPDB.hourBuckets[idx] or 0)
texts[i]:SetText(date('%H:%M', AvgXPDB.bucketStarts[idx]))
end
end

-----------------------------------------------------------------
-- events
-----------------------------------------------------------------
local f = CreateFrame('Frame')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('PLAYER_XP_UPDATE')
f:RegisterEvent('PLAYER_LOGOUT')
function f:PLAYER_LOGIN()
InitDB()
startXP, startTime, sessionXP = UnitXP('player'), time(), 0
Refresh()
end
function f:PLAYER_XP_UPDATE()
local cur = UnitXP('player')
local gain = cur - startXP
if gain < 0 then gain = (UnitXPMax('player') - startXP) + cur end
sessionXP, startXP = sessionXP + gain, cur
Add(gain); Refresh()
end
function f:PLAYER_LOGOUT()
local t = time() - startTime
AvgXPDB.totalXP = AvgXPDB.totalXP + sessionXP
AvgXPDB.totalTime = AvgXPDB.totalTime + t
end
f:SetScript('OnEvent', function(_, e, ...) f[e](f, ...) end)

-----------------------------------------------------------------
-- per‑second ticker
-----------------------------------------------------------------
local acc = 0
f:SetScript('OnUpdate', function(_, dt)
acc = acc + dt
if acc >= REFRESH then Rotate(); Refresh(); acc = 0 end
end)

-----------------------------------------------------------------
-- slash commands
-----------------------------------------------------------------
SLASH_AVGXPCLASSIC1 = '/avgxp'
SlashCmdList.AVGXPCLASSIC = function(msg)
msg = (msg or ''):lower():gsub('^%s+', '')
if msg == 'reset' then
AvgXPDB = {}; InitDB(); BuildBars()
startXP, startTime, sessionXP = UnitXP('player'), time(), 0
print('|cff33ff99AverageXPClassic|r: data reset.'); Refresh()
elseif msg == 'graph' then
AvgXPDB.graphHidden = not AvgXPDB.graphHidden
graph:SetShown(not AvgXPDB.graphHidden)
elseif msg:match('^buckets%s+%d') then
local n = tonumber(msg:match('%d+'))
if n and n >= 2 and n <= 24 then
AvgXPDB.buckets = n
for i = #AvgXPDB.hourBuckets + 1, n do
AvgXPDB.hourBuckets[i] = 0
AvgXPDB.bucketStarts[i] = time() - (n - i) * BUCKET_SECS
end
for i = n + 1, #AvgXPDB.hourBuckets do
AvgXPDB.hourBuckets[i] = nil
AvgXPDB.bucketStarts[i] = nil
end
BuildBars(); Refresh()
else
print('|cff33ff99AverageXPClassic|r: choose 2-24 buckets.')
end
else
print('|cff33ff99AverageXPClassic|r commands:')
print(' /avgxp reset - clear data')
print(' /avgxp graph - toggle graph')
print(' /avgxp buckets <n> - set graph length (2-24)')
end
end