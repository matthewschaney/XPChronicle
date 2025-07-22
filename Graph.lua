-- Graph.lua
-- Bar‑graph construction & refresh

XPChronicle = XPChronicle or {}
XPChronicle.Graph = {}
local Graph = XPChronicle.Graph
local UI    = XPChronicle.UI
local DB    = XPChronicle.DB
local Utils = XPChronicle.Utils

local BAR_H = 40

function Graph:Init()
  local g = _G.XPChronicleGraph
    or CreateFrame("Frame","XPChronicleGraph",UI.back)
  self.frame = g
  g:SetPoint("TOP", UI.back, "BOTTOM", 0, -8)
end

function Graph:BuildBars()
  self:Init()
  local g = self.frame
  local _, _, lastIx = DB:GetHourlyBuckets()
  local NB  = AvgXPDB.buckets
  local BAR_W = UI.PANEL_W / NB

  g:SetSize(UI.PANEL_W, BAR_H)
  if self.bars then for _,o in ipairs(self.bars) do o:Hide() end end
  if self.texts then for _,o in ipairs(self.texts) do o:Hide() end end

  self.bars, self.texts = {}, {}
  for i = 1, NB do
    local bar = CreateFrame("StatusBar", nil, g, "BackdropTemplate")
    bar:SetSize(BAR_W, BAR_H)
    bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:GetStatusBarTexture():SetVertexColor(0.2,0.8,1)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    bar:SetBackdropColor(0,0,0,0.6)
    bar:SetPoint("BOTTOMLEFT", (i-1)*BAR_W, 0)
    self.bars[i] = bar

    local txt = g:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    txt:SetPoint("TOP", bar, "BOTTOM", 0, -2)
    self.texts[i] = txt

    bar:SetScript("OnEnter", function(self)
      local idx = Utils.bucketIndexForBar(i, NB, AvgXPDB.lastBucketIx)
      local xp  = AvgXPDB.hourBuckets[idx] or 0
      GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
      GameTooltip:AddLine(date("%H:%M",AvgXPDB.bucketStarts[idx]))
      GameTooltip:AddLine(string.format("%d XP",xp),1,1,1)
      GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", GameTooltip_Hide)
  end

  g:SetShown(not AvgXPDB.graphHidden)
end

function Graph:Refresh()
  local buckets, starts, lastIx = DB:GetHourlyBuckets()
  local NB  = AvgXPDB.buckets
  local max = DB:GetMaxBucket()

  for i=1,NB do
    local idx = Utils.bucketIndexForBar(i, NB, lastIx)
    local bar = self.bars[i]
    local txt = self.texts[i]

    bar:SetMinMaxValues(0, max)
    bar:SetValue(buckets[idx] or 0)
    txt:SetText(date("%H:%M", starts[idx]))
  end
end
