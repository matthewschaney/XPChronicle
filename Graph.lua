-- Graph.lua (Fixed version)
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
  local g = self.frame
  local NB = AvgXPDB.buckets
  local BAR_W = UI.PANEL_W / NB

  -- clear out old bars/texts/overlays
  if self.bars then     for _,b in ipairs(self.bars)     do b:Hide() end end
  if self.texts then    for _,t in ipairs(self.texts)    do t:Hide() end end
  if self.redBars then  for _,r in ipairs(self.redBars)  do r:Hide() end end
  self.bars, self.texts, self.redBars = {}, {}, {}

  -- Create all bars - we'll configure them in Refresh
  for i = 1, NB do
    -- Blue bar (for history or partial current)
    local bar = CreateFrame("StatusBar", nil, g, "BackdropTemplate")
    bar:SetSize(BAR_W, BAR_H)
    bar:SetOrientation("VERTICAL")
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:GetStatusBarTexture():SetVertexColor(0.2,0.8,1)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    bar:SetBackdropColor(0,0,0,0.6)
    bar:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", (i-1)*BAR_W, 0)

    -- Red bar (for predictions)
    local redBar = CreateFrame("StatusBar", nil, g, "BackdropTemplate")
    redBar:SetSize(BAR_W, BAR_H)
    redBar:SetOrientation("VERTICAL")
    redBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    redBar:GetStatusBarTexture():SetVertexColor(1,0.2,0.2)
    redBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    redBar:SetBackdropColor(0,0,0,0)
    redBar:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", (i-1)*BAR_W, 0)

    -- Text label
    local txt = g:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("TOP", bar, "BOTTOM", 0, -2)

    self.bars[i] = bar
    self.redBars[i] = redBar
    self.texts[i] = txt
  end

  self:Refresh()
end

function Graph:Refresh()
  local buckets, starts, lastIx = DB:GetHourlyBuckets()
  local NB = AvgXPDB.buckets
  local BAR_W = UI.PANEL_W / NB  -- Define BAR_W at the top so it's available throughout

  -- Store last known bucket index to detect rotation
  if not self.lastKnownBucketIx then
    self.lastKnownBucketIx = lastIx
  end

  -- Rebuild if needed (bucket count changed or bucket rotated)
  if not self.bars or #self.bars ~= NB or self.lastKnownBucketIx ~= lastIx then
    self.lastKnownBucketIx = lastIx
    self:BuildBars()
    return
  end

  -- Clear all tooltips
  for i = 1, NB do
    self.bars[i]:SetScript("OnEnter", nil)
    self.bars[i]:SetScript("OnLeave", nil)
    self.redBars[i]:SetScript("OnEnter", nil)
    self.redBars[i]:SetScript("OnLeave", nil)
  end

  if not AvgXPDB.predictionMode then
    -- Normal mode - just show history
    local maxVal = DB:GetMaxBucket()
    for i = 1, NB do
      local idx = Utils.bucketIndexForBar(i, NB, lastIx)
      local xp = buckets[idx] or 0
      
      self.bars[i]:Show()
      self.bars[i]:SetMinMaxValues(0, maxVal)
      self.bars[i]:SetValue(xp)
      self.bars[i]:GetStatusBarTexture():SetVertexColor(0.2,0.8,1)
      
      -- Ensure red bars are completely hidden
      self.redBars[i]:Hide()
      self.redBars[i]:SetValue(0)
      self.redBars[i]:ClearAllPoints()
      
      self.texts[i]:SetText(date("%H:%M", starts[idx]))
      
      -- Tooltip
      self.bars[i]:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(date("%H:%M", starts[idx]))
        GameTooltip:AddLine(string.format("%d XP", xp), 1,1,1)
        GameTooltip:Show()
      end)
      self.bars[i]:SetScript("OnLeave", GameTooltip_Hide)
    end
    return
  end

  ----------------------------------------------------------------
  -- Prediction Mode - Split view with present in center
  ----------------------------------------------------------------
  local sAvg = DB:GetSessionRate()
  local curXP = UnitXP("player")
  local maxXP = UnitXPMax("player")
  local remainXP = maxXP - curXP
  local hoursToLevel = (sAvg > 0) and (remainXP / sAvg) or 999

  -- Calculate how many buckets for history vs future
  local historyBuckets = math.floor(NB / 2)
  local futureBuckets = NB - historyBuckets
  
  -- Find max value for scaling
  local maxVal = math.max(DB:GetMaxBucket(), sAvg)

  -- Current time info
  local now = time()
  local currentBucketStart = starts[lastIx]
  local timeIntoCurrentBucket = now - currentBucketStart
  local fractionOfCurrentBucket = timeIntoCurrentBucket / 3600

  ----------------------------------------------------------------
  -- 1) Historical buckets (left side)
  ----------------------------------------------------------------
  for i = 1, historyBuckets - 1 do
    -- Calculate which bucket from history to show
    local offset = historyBuckets - i
    local histIdx = ((lastIx - offset - 1) % NB) + 1
    local xp = buckets[histIdx] or 0
    
    self.bars[i]:Show()
    self.bars[i]:SetMinMaxValues(0, maxVal)
    self.bars[i]:SetValue(xp)
    self.bars[i]:GetStatusBarTexture():SetVertexColor(0.2,0.8,1)
    
    -- Make sure red bars are completely hidden
    self.redBars[i]:Hide()
    self.redBars[i]:SetValue(0)
    self.redBars[i]:ClearAllPoints()
    
    self.texts[i]:SetText(date("%H:%M", starts[histIdx]))
    
    -- Tooltip
    local capturedIdx = histIdx  -- Capture for closure
    self.bars[i]:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(date("%H:%M", starts[capturedIdx]))
      GameTooltip:AddLine(string.format("%d XP", xp), 1,1,1)
      GameTooltip:Show()
    end)
    self.bars[i]:SetScript("OnLeave", GameTooltip_Hide)
  end

  ----------------------------------------------------------------
  -- 2) Current bucket (blue only, no red overlay)
  ----------------------------------------------------------------
  local BAR_W = UI.PANEL_W / NB  -- Calculate BAR_W here
  local currentBarIdx = historyBuckets
  local currentXP = buckets[lastIx] or 0
  
  -- For the current bucket, calculate expected total XP for the full hour
  local remainingTimeInBucket = 1 - fractionOfCurrentBucket
  local expectedXPRemaining = sAvg * remainingTimeInBucket
  local totalExpectedForHour = currentXP + math.min(expectedXPRemaining, remainXP)
  
  -- Blue part: actual XP earned
  self.bars[currentBarIdx]:Show()
  self.bars[currentBarIdx]:SetMinMaxValues(0, maxVal)
  self.bars[currentBarIdx]:SetValue(currentXP)
  self.bars[currentBarIdx]:GetStatusBarTexture():SetVertexColor(0.2,0.8,1)
  
  -- Hide the red bar completely for current hour
  self.redBars[currentBarIdx]:Hide()
  self.redBars[currentBarIdx]:SetValue(0)
  self.redBars[currentBarIdx]:ClearAllPoints()
  
  self.texts[currentBarIdx]:SetText(date("%H:%M", starts[lastIx]))
  
  -- Tooltip for current bucket
  local capturedCurrentXP = currentXP
  local capturedExpectedRemaining = math.min(expectedXPRemaining, remainXP)
  local capturedLastIx = lastIx
  self.bars[currentBarIdx]:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(date("%H:%M", starts[capturedLastIx]) .. " (Current)")
    GameTooltip:AddLine(string.format("%d XP earned", capturedCurrentXP), 0.2,0.8,1)
    GameTooltip:AddLine(string.format("%d XP predicted", capturedExpectedRemaining), 1,0.2,0.2)
    GameTooltip:Show()
  end)
  self.bars[currentBarIdx]:SetScript("OnLeave", GameTooltip_Hide)

  ----------------------------------------------------------------
  -- 3) Future buckets (right side - all red)
  ----------------------------------------------------------------
  local xpAccountedFor = math.min(expectedXPRemaining, remainXP)
  local hoursAccountedFor = remainingTimeInBucket
  
  for i = currentBarIdx + 1, NB do
    local futureHour = i - currentBarIdx
    local bucketTime = starts[lastIx] + (futureHour * 3600)
    
    if xpAccountedFor < remainXP then
      -- Still have XP to distribute
      local xpThisBucket = math.min(sAvg, remainXP - xpAccountedFor)
      
      self.bars[i]:Hide()
      
      self.redBars[i]:Show()
      self.redBars[i]:SetBackdropColor(0,0,0,0.6)  -- Add black background
      self.redBars[i]:ClearAllPoints()
      self.redBars[i]:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", (i-1)*BAR_W, 0)
      self.redBars[i]:SetMinMaxValues(0, maxVal)
      self.redBars[i]:SetValue(xpThisBucket)
      
      xpAccountedFor = xpAccountedFor + xpThisBucket
      hoursAccountedFor = hoursAccountedFor + (xpThisBucket / sAvg)
      
      -- Tooltip
      local capturedBucketTime = bucketTime
      local capturedXPThisBucket = math.floor(xpThisBucket)
      self.redBars[i]:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(date("%H:%M", capturedBucketTime))
        GameTooltip:AddLine(string.format("%d XP predicted", capturedXPThisBucket), 1,0.2,0.2)
        GameTooltip:Show()
      end)
      self.redBars[i]:SetScript("OnLeave", GameTooltip_Hide)
    else
      -- We've distributed all XP, rest are empty
      self.bars[i]:Show()
      self.bars[i]:SetMinMaxValues(0, maxVal)
      self.bars[i]:SetValue(0)
      self.bars[i]:GetStatusBarTexture():SetVertexColor(0.2,0.8,1)
      
      -- Make sure red bars are fully hidden
      self.redBars[i]:Hide()
      self.redBars[i]:SetValue(0)
      self.redBars[i]:ClearAllPoints()
    end
    
    self.texts[i]:SetText(date("%H:%M", bucketTime))
  end
end