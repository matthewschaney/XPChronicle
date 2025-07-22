-- Graph.lua
-- Bar‑graph construction, refresh, and right‑click toggle Prediction Mode
-- (fixed bucket count; composite current‑hour; projected red bars)

XPChronicle = XPChronicle or {}
XPChronicle.Graph = {}
local Graph = XPChronicle.Graph
local UI    = XPChronicle.UI
local DB    = XPChronicle.DB
local Utils = XPChronicle.Utils

local BAR_H = 40

function Graph:Init()
  local g = _G.XPChronicleGraph
         or CreateFrame("Button", "XPChronicleGraph", UI.back)
  self.frame = g

  g:SetPoint("TOP", UI.back, "BOTTOM", 0, -8)
  g:SetSize(UI.PANEL_W, BAR_H)

  -- right‑click toggles Prediction Mode
  g:EnableMouse(true)
  g:RegisterForClicks("RightButtonUp")
  g:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      AvgXPDB.predictionMode = not AvgXPDB.predictionMode
      self:BuildBars()
      self:Refresh()
    end
  end)
end

function Graph:BuildBars()
  self:Init()
  local g, DBbuckets, starts, lastIx = self.frame, DB:GetHourlyBuckets()
  local buckets, starts, lastIx = DBbuckets, starts, lastIx
  local NB      = AvgXPDB.buckets
  local BAR_W   = UI.PANEL_W / NB

  -- clear out old bars/texts/overlays
  if self.bars then     for _,b in ipairs(self.bars)     do b:Hide()        end end
  if self.texts then    for _,t in ipairs(self.texts)    do t:Hide()        end end
  if self.redOverlay then for _,r in ipairs(self.redOverlay) do r:Hide()     end end
  self.bars, self.texts, self.redOverlay = {}, {}, {}

  -- simple, non‑prediction mode
  if not AvgXPDB.predictionMode then
    local maxVal = DB:GetMaxBucket()
    for i = 1, NB do
      local idx = Utils.bucketIndexForBar(i, NB, lastIx)
      local xp  = buckets[idx] or 0

      local bar = CreateFrame("StatusBar", nil, g, "BackdropTemplate")
      bar:SetSize(BAR_W, BAR_H)
      bar:SetOrientation("VERTICAL")
      bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
      bar:GetStatusBarTexture():SetVertexColor(0.2,0.8,1)
      bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
      bar:SetBackdropColor(0,0,0,0.6)
      bar:SetMinMaxValues(0, maxVal)
      bar:SetValue(xp)
      bar:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", (i-1)*BAR_W, 0)

      local txt = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      txt:SetPoint("TOP", bar, "BOTTOM", 0, -2)

      bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(date("%H:%M", starts[idx]))
        GameTooltip:AddLine(string.format("%d XP", xp), 1,1,1)
        GameTooltip:Show()
      end)
      bar:SetScript("OnLeave", GameTooltip_Hide)

      self.bars[i]  = bar
      self.texts[i] = txt
    end
    return
  end

  ----------------------------------------------------------------
  -- Prediction Mode
  ----------------------------------------------------------------
  local sAvg     = DB:GetSessionRate()
  local curXP    = UnitXP("player")
  local maxXP    = UnitXPMax("player")
  local remainXP = maxXP - curXP
  local hoursRem = (sAvg > 0) and (remainXP / sAvg) or 0

  -- how many future buckets (capped to NB)
  local pPredict = math.ceil(hoursRem)
  if pPredict > NB then pPredict = NB end
  local frac    = hoursRem - math.floor(hoursRem)

  -- how many full history buckets (excluding current hour)
  local histCount = NB - pPredict

  -- overall max for scaling overlays
  local maxVal = math.max(DB:GetMaxBucket(), sAvg)

  ----------------------------------------------------------------
  -- 1) historical buckets (all blue)
  ----------------------------------------------------------------
  for j = 1, histCount do
    local idx = ((lastIx - histCount + j - 2) % NB) + 1
    local xp  = buckets[idx] or 0

    local bar = CreateFrame("StatusBar", nil, g, "BackdropTemplate")
    bar:SetSize(BAR_W, BAR_H)
    bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:GetStatusBarTexture():SetVertexColor(0.2,0.8,1)
    bar:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
    bar:SetBackdropColor(0,0,0,0.6)
    bar:SetMinMaxValues(0, maxVal)
    bar:SetValue(xp)
    bar:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", (j-1)*BAR_W, 0)

    local txt = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("TOP", bar, "BOTTOM", 0, -2)

    bar:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(date("%H:%M", starts[idx]))
      GameTooltip:AddLine(string.format("%d XP", xp), 1,1,1)
      GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", GameTooltip_Hide)

    self.bars[j]  = bar
    self.texts[j] = txt
  end

  ----------------------------------------------------------------
  -- 2) composite current‑hour bucket
  ----------------------------------------------------------------
  local iComp  = histCount + 1
  local DB_cur = buckets[lastIx] or 0
  -- how much we predict _in this hour_
  local predThis = math.min(remainXP, sAvg)

  -- blue background bar
  local blueBar = CreateFrame("StatusBar", nil, g, "BackdropTemplate")
  blueBar:SetSize(BAR_W, BAR_H)
  blueBar:SetOrientation("VERTICAL")
  blueBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  blueBar:GetStatusBarTexture():SetVertexColor(0.2,0.8,1)
  blueBar:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
  blueBar:SetBackdropColor(0,0,0,0.6)
  blueBar:SetMinMaxValues(0, maxVal)
  blueBar:SetValue(DB_cur)
  blueBar:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", (iComp-1)*BAR_W, 0)

  local txtC = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  txtC:SetPoint("TOP", blueBar, "BOTTOM", 0, -2)

  blueBar:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(date("%H:%M", starts[lastIx]))
    GameTooltip:AddLine(string.format("%d XP so far", DB_cur), 0.2,0.8,1)
    GameTooltip:AddLine(string.format("%d XP predicted", predThis), 1,0.2,0.2)
    GameTooltip:Show()
  end)
  blueBar:SetScript("OnLeave", GameTooltip_Hide)

  -- red overlay as its own StatusBar
  local redBar = CreateFrame("StatusBar", nil, g, "BackdropTemplate")
  redBar:SetSize(BAR_W, BAR_H)
  redBar:SetOrientation("VERTICAL")
  redBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  redBar:GetStatusBarTexture():SetVertexColor(1,0.2,0.2)
  redBar:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
  redBar:SetBackdropColor(0,0,0,0)             -- transparent bg
  -- initial anchor; will update in Refresh
  redBar:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", (iComp-1)*BAR_W, 0)
  redBar:SetMinMaxValues(0, maxVal)
  redBar:SetValue(predThis)

  self.bars[iComp]      = blueBar
  self.redOverlay[iComp] = redBar
  self.texts[iComp]     = txtC

  ----------------------------------------------------------------
  -- 3) purely future buckets (all red)
  ----------------------------------------------------------------
  for j = 2, pPredict do
    local i = histCount + j
    local xpVal = (j == pPredict and frac > 0)
                and (frac * sAvg)
                or sAvg

    local bar = CreateFrame("StatusBar", nil, g, "BackdropTemplate")
    bar:SetSize(BAR_W, BAR_H)
    bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:GetStatusBarTexture():SetVertexColor(1,0.2,0.2)
    bar:SetBackdrop({ bgFile="Interface\\Buttons\\WHITE8x8" })
    bar:SetBackdropColor(0,0,0,0.6)
    bar:SetMinMaxValues(0, maxVal)
    bar:SetValue(xpVal)
    bar:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", (i-1)*BAR_W, 0)

    local txt = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("TOP", bar, "BOTTOM", 0, -2)

    bar:SetScript("OnEnter", function(self)
      local t0 = starts[lastIx] + (j-1)*3600
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(date("%H:%M", t0))
      GameTooltip:AddLine(string.format("%d XP", math.floor(xpVal+0.5)), 1,1,1)
      GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", GameTooltip_Hide)

    self.bars[i]  = bar
    self.texts[i] = txt
  end
end

function Graph:Refresh()
  local buckets, starts, lastIx = DB:GetHourlyBuckets()
  local NB = AvgXPDB.buckets

  -- if the user toggled bucket‑count or mode, rebuild
  if not self.bars or #self.bars ~= NB then
    self:BuildBars()
  end

  -- Normal mode update
  if not AvgXPDB.predictionMode then
    local maxVal = DB:GetMaxBucket()
    for i=1,NB do
      local idx = Utils.bucketIndexForBar(i, NB, lastIx)
      local bar, txt = self.bars[i], self.texts[i]
      bar:SetMinMaxValues(0, maxVal)
      bar:SetValue(buckets[idx] or 0)
      txt:SetText(date("%H:%M", starts[idx]))
    end
    return
  end

  ----------------------------------------------------------------
  -- Prediction‑mode update
  ----------------------------------------------------------------
  local sAvg     = DB:GetSessionRate()
  local curXP    = UnitXP("player")
  local maxXP    = UnitXPMax("player")
  local remainXP = maxXP - curXP
  local hoursRem = (sAvg>0) and (remainXP / sAvg) or 0

  local pPredict = math.ceil(hoursRem)
  if pPredict > NB then pPredict = NB end
  local frac     = hoursRem - math.floor(hoursRem)
  local histCount = NB - pPredict
  local maxVal   = math.max(DB:GetMaxBucket(), sAvg)

  -- 1) historical
  for j=1,histCount do
    local idx = ((lastIx - histCount + j - 2) % NB) + 1
    local bar, txt = self.bars[j], self.texts[j]
    bar:SetMinMaxValues(0, maxVal)
    bar:SetValue(buckets[idx] or 0)
    txt:SetText(date("%H:%M", starts[idx]))
  end

  -- 2) composite
  do
    local iComp = histCount + 1
    local bar   = self.bars[iComp]
    local red   = self.redOverlay[iComp]
    local txt   = self.texts[iComp]
    local DBcur = buckets[lastIx] or 0
    local pred  = math.min(remainXP, sAvg)

    -- reposition & update
    bar:SetMinMaxValues(0, maxVal)
    bar:SetValue(DBcur)
    red:ClearAllPoints()
    -- anchor just above blue fill
    local offsetY = (DBcur / maxVal) * BAR_H
    red:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT",
                 (iComp-1)*(UI.PANEL_W/NB), offsetY)
    red:SetMinMaxValues(0, maxVal)
    red:SetValue(pred)

    txt:SetText(date("%H:%M", starts[lastIx]))
  end

  -- 3) remaining future
  for j=2,pPredict do
    local i   = histCount + j
    local bar = self.bars[i]
    local txt = self.texts[i]
    local xpVal = (j == pPredict and frac > 0)
                and (frac * sAvg)
                or sAvg

    bar:SetMinMaxValues(0, maxVal)
    bar:SetValue(xpVal)
    txt:SetText(date("%H:%M", starts[lastIx] + (j-1)*3600))
  end
end
