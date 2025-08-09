-- XPChronicle ▸ Graph.lua

XPChronicle        = XPChronicle or {}
XPChronicle.Graph  = XPChronicle.Graph or {}
local Graph        = XPChronicle.Graph

-- Short locals ---------------------------------------------------------------
local UI, DB, Utils = XPChronicle.UI, XPChronicle.DB, XPChronicle.Utils

-- Constants ------------------------------------------------------------------
local BAR_H = 40                      -- Height of every bar
local GAP   = 1                       -- One‑pixel gap between bars
local BLUE  = { 0.2, 0.8, 1 }         -- Default history colour
local RED   = { 1,   0.2, 0.2 }       -- Default prediction colour
local BK    = { 0,   0,   0, 0.6 }    -- 60 % black backdrop
local TEX   = "Interface\\Buttons\\WHITE8x8"

-- Colour helpers -------------------------------------------------------------
local function histCol()
  return AvgXPDB.barColor or BLUE
end
local function predCol()
  return AvgXPDB.predColor or RED
end

-- Helpers --------------------------------------------------------------------
local function makeBar(parent, w, h, col)
  local b = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  b:SetOrientation("VERTICAL")
  b:SetStatusBarTexture(TEX)
  b:SetStatusBarColor(col[1], col[2], col[3])
  b:SetBackdrop({ bgFile = TEX })
  b:SetBackdropColor(0, 0, 0, 0)
  return b
end

local function tip(frame, label, value, isPred)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(label)
    GameTooltip:AddLine(value,
      isPred and 1 or .2, isPred and .2 or .8, isPred and .2 or 1)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", GameTooltip_Hide)
end

-- Init -----------------------------------------------------------------------
function Graph:Init()
  local g = _G.XPChronicleGraph
         or CreateFrame("Frame", "XPChronicleGraph", UI.back)
  self.frame = g
  g:SetPoint("TOP", UI.back, "BOTTOM", 0, -8)
  g:SetHeight(BAR_H)
  if not self.backdrop then
    self.backdrop = g:CreateTexture(nil, "BACKGROUND")
    self.backdrop:SetColorTexture(unpack(BK))
    self.backdrop:SetAllPoints(g)
  end
end

-- BuildBars ------------------------------------------------------------------
function Graph:BuildBars()
  self:Init()
  local NB      = AvgXPDB.buckets
  local BAR_W   = math.floor((UI.PANEL_W - (NB - 1) * GAP) / NB)
  local TOT_W   = BAR_W * NB + GAP * (NB - 1)

  self.frame:SetWidth(TOT_W)
  self.backdrop:SetAllPoints(self.frame)
  if UI.back then
    UI.back:SetWidth(TOT_W)
    if UI.back.label then UI.back.label:SetWidth(TOT_W) end
  end

  self.bars, self.redBars, self.texts = self.bars or {}, self.redBars or {},
                                        self.texts or {}

  for i = #self.bars, NB + 1, -1 do
    self.bars[i]:Hide();    self.bars[i]    = nil
    self.redBars[i]:Hide(); self.redBars[i] = nil
    self.texts[i]:Hide();   self.texts[i]   = nil
  end
  for _, tbl in ipairs { self.bars, self.redBars, self.texts } do
    for _, w in ipairs(tbl) do w:Hide() end
  end

  for i = 1, NB do
    if not self.bars[i] then
      self.bars[i]    = makeBar(self.frame, BAR_W, BAR_H, histCol())
      self.redBars[i] = makeBar(self.frame, BAR_W, BAR_H, predCol())
      self.texts[i]   = self.frame:CreateFontString(nil, "OVERLAY",
                                                    "GameFontNormalSmall")
      self.texts[i]:SetPoint("TOP", self.bars[i], "BOTTOM", 0, -2)
    else
      self.bars[i]:SetSize(BAR_W, BAR_H)
      self.redBars[i]:SetSize(BAR_W, BAR_H)
    end
    local x = (i - 1) * (BAR_W + GAP)
    self.bars[i]:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x, 0)
    self.redBars[i]:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", x, 0)
  end
  self.barWCache = BAR_W
  self:Refresh()
end

-- Refresh --------------------------------------------------------------------
function Graph:Refresh()
  local buckets, starts, lastIx = DB:GetHourlyBuckets()
  local NB, maxHist = AvgXPDB.buckets, DB:GetMaxBucket()

  if not self.lastIx or self.lastIx ~= lastIx or #self.bars ~= NB then
    self.lastIx = lastIx; return self:BuildBars() end

  -- History mode -------------------------------------------------------------
  if not AvgXPDB.predictionMode then
    for i = 1, NB do
      local idx = Utils.bucketIndexForBar(i, NB, lastIx)
      local xp  = buckets[idx] or 0
      local b   = self.bars[i]
      b:Show()
      b:SetMinMaxValues(0, maxHist)
      b:SetValue(xp)
      b:GetStatusBarTexture():SetVertexColor(unpack(histCol()))
      self.redBars[i]:Hide()
      local lblOk = self.barWCache >= 14
      self.texts[i]:SetText(lblOk and date("%H:%M", starts[idx]) or "")
      tip(b, date("%H:%M", starts[idx]), ("%d XP"):format(xp))
    end
    return
  end

  -- Prediction mode ----------------------------------------------------------
  local sAvg   = DB:GetSessionRate()
  local curXP  = UnitXP("player")
  local remain = UnitXPMax("player") - curXP
  local leftCt = math.floor(NB / 2)
  local rightCt= NB - leftCt
  local maxL   = (maxHist > 0) and maxHist or 1

  for i = 1, leftCt do
    local offset = leftCt - i
    local idx    = ((lastIx - offset - 1) % NB) + 1
    local xp     = buckets[idx] or 0
    local b      = self.bars[i]
    b:Show()
    b:SetMinMaxValues(0, maxL)
    b:SetValue(xp)
    b:GetStatusBarTexture():SetVertexColor(unpack(histCol()))
    self.redBars[i]:Hide()
    local lblOk = self.barWCache >= 14
    self.texts[i]:SetText(lblOk and date("%H:%M", starts[idx]) or "")
    tip(b, date("%H:%M", starts[idx]), ("%d XP"):format(xp))
  end

  local maxR = (sAvg > 0) and sAvg or 1
  for j = 1, rightCt do
    local i   = leftCt + j
    local r   = self.redBars[i]
    local b   = self.bars[i]
    b:Hide()
    local gain = 0
    if sAvg > 0 and remain > 0 then
      gain   = math.min(sAvg, remain)
      remain = remain - gain
    end
    r:Show()
    r:SetMinMaxValues(0, maxR)
    r:SetValue(gain)
    r:GetStatusBarTexture():SetVertexColor(unpack(predCol()))
    local lbl   = date("%H:%M", starts[lastIx] + j * 3600)
    local lblOk = self.barWCache >= 14
    self.texts[i]:SetText(lblOk and lbl or "")
    if gain > 0 then tip(r, lbl, ("%d XP predicted"):format(gain), true)
                  else r:SetScript("OnEnter", nil); r:SetScript("OnLeave", nil) end
  end
end
