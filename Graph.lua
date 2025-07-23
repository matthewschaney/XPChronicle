-- XPChronicle ▸ Graph.lua

XPChronicle           = XPChronicle or {}
XPChronicle.Graph     = {}
local Graph           = XPChronicle.Graph

-- Short locals.
local UI, DB, Utils   = XPChronicle.UI, XPChronicle.DB, XPChronicle.Utils

-- Constants.
local BAR_H           = 40                     -- Height of every bar.
local GAP             = 1                      -- One‑pixel gap between bars.
local BLUE            = { .2, .8, 1 }          -- Fill colour for history.
local RED             = { 1,  .2, .2 }         -- Fill colour for prediction.
local BK              = { 0,  0,  0,  .6 }     -- 60 % black for backing.
local TEX             = "Interface\\Buttons\\WHITE8x8"

--------------------------------------------------------------------- Helpers
local function createStatusBar(parent, w, h, col)
  local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
  bar:SetSize(w, h)
  bar:SetOrientation("VERTICAL")
  bar:SetStatusBarTexture(TEX)
  bar:GetStatusBarTexture():SetVertexColor(col[1], col[2], col[3])
  bar:SetBackdrop({ bgFile = TEX })            -- Needed for tooltip hitbox.
  bar:SetBackdropColor(0, 0, 0, 0)             -- Transparent backdrop.
  return bar
end

local function attachTooltip(frame, label, value, isPred)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(label)
    GameTooltip:AddLine(value,
                        isPred and 1 or .2,
                        isPred and .2 or .8,
                        isPred and .2 or 1)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", GameTooltip_Hide)
end

-------------------------------------------------------------------- :Init()
function Graph:Init()
  local g = _G.XPChronicleGraph
         or CreateFrame("Button", "XPChronicleGraph", UI.back)
  self.frame = g

  g:SetPoint("TOP", UI.back, "BOTTOM", 0, -8)
  g:SetSize(UI.PANEL_W, BAR_H)

  -- Backing texture: full‑width semi‑transparent black.
  if not self.backdrop then
    self.backdrop = g:CreateTexture(nil, "BACKGROUND")
    self.backdrop:SetColorTexture(unpack(BK))
    self.backdrop:SetAllPoints(g)
  end

  -- Right‑click toggles Prediction Mode.
  g:EnableMouse(true)
  g:RegisterForClicks("RightButtonUp")
  g:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then
      AvgXPDB.predictionMode = not AvgXPDB.predictionMode
      self:BuildBars()
      self:Refresh()
    end
  end)
end

----------------------------------------------------------------- :BuildBars()
function Graph:BuildBars()
  self:Init()

  local g, NB  = self.frame, AvgXPDB.buckets
  local BAR_W  = math.floor((UI.PANEL_W - (NB - 1) * GAP) / NB)

  -- Recycle or create tables.
  self.bars     = self.bars     or {}
  self.redBars  = self.redBars  or {}
  self.texts    = self.texts    or {}

  -- Trim tables if the bucket count was reduced.
  for i = #self.bars, NB + 1, -1 do
    self.bars[i]:Hide();    self.bars[i]    = nil
    self.redBars[i]:Hide(); self.redBars[i] = nil
    self.texts[i]:Hide();   self.texts[i]   = nil
  end

  -- Hide any remaining widgets.
  for _, t in ipairs { self.bars, self.redBars, self.texts } do
    for _, w in ipairs(t) do w:Hide() end
  end

  -- Create bars if needed, and reposition all bars.
  for i = 1, NB do
    if not self.bars[i] then
      self.bars[i]    = createStatusBar(g, BAR_W, BAR_H, BLUE)
      self.redBars[i] = createStatusBar(g, BAR_W, BAR_H, RED)
      self.texts[i]   = g:CreateFontString(nil,
                                           "OVERLAY",
                                           "GameFontNormalSmall")
      self.texts[i]:SetPoint("TOP", self.bars[i], "BOTTOM", 0, -2)
    else
      self.bars[i]:SetSize(BAR_W, BAR_H)
      self.redBars[i]:SetSize(BAR_W, BAR_H)
    end
    local x = (i - 1) * (BAR_W + GAP)
    self.bars[i]:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", x, 0)
    self.redBars[i]:SetPoint("BOTTOMLEFT", g, "BOTTOMLEFT", x, 0)
  end

  self.barWCache = BAR_W        -- Cached for label logic in Refresh.
  self:Refresh()
end

------------------------------------------------------------------- :Refresh()
function Graph:Refresh()
  local buckets, starts, lastIx = DB:GetHourlyBuckets()
  local NB      = AvgXPDB.buckets
  local maxHist = DB:GetMaxBucket()

  -- Rebuild if buckets rotated or count changed.
  if not self.lastIx or self.lastIx ~= lastIx or #self.bars ~= NB then
    self.lastIx = lastIx
    return self:BuildBars()
  end

  ---------------------------------------------------------------- Normal Mode
  if not AvgXPDB.predictionMode then
    for i = 1, NB do
      local idx  = Utils.bucketIndexForBar(i, NB, lastIx)
      local xp   = buckets[idx] or 0
      local bar  = self.bars[i]

      bar:Show()
      bar:SetMinMaxValues(0, maxHist)
      bar:SetValue(xp)
      bar:GetStatusBarTexture():SetVertexColor(unpack(BLUE))
      self.redBars[i]:Hide()

      local showLbl = self.barWCache >= 14
      self.texts[i]:SetText(showLbl and date("%H:%M", starts[idx]) or "")
      attachTooltip(bar, date("%H:%M", starts[idx]),
                    string.format("%d XP", xp))
    end
    return
  end

  --------------------------------------------------------- Prediction Mode
  local sAvg         = DB:GetSessionRate()
  local curXP        = UnitXP("player")
  local remainXP     = UnitXPMax("player") - curXP

  local histBuckets   = math.floor(NB / 2)      -- Left half.
  local futureBuckets = NB - histBuckets        -- Right half.

  -- History (blue, independent scale).
  local maxLeft = (maxHist > 0) and maxHist or 1
  for i = 1, histBuckets do
    local offset = histBuckets - i              -- 0 → current hour.
    local idx    = ((lastIx - offset - 1) % NB) + 1
    local xp     = buckets[idx] or 0
    local bar    = self.bars[i]

    bar:Show()
    bar:SetMinMaxValues(0, maxLeft)
    bar:SetValue(xp)
    bar:GetStatusBarTexture():SetVertexColor(unpack(BLUE))
    self.redBars[i]:Hide()

    local showLbl = self.barWCache >= 14
    self.texts[i]:SetText(showLbl and date("%H:%M", starts[idx]) or "")
    attachTooltip(bar, date("%H:%M", starts[idx]),
                  string.format("%d XP", xp))
  end

  -- Future (red, independent scale, backdrop always visible).
  local maxRight = (sAvg > 0) and sAvg or 1
  local xpLeft   = remainXP
  for j = 1, futureBuckets do
    local i   = histBuckets + j
    local r   = self.redBars[i]
    local bar = self.bars[i]
    bar:Hide()

    local xpThis = 0
    if sAvg > 0 and xpLeft > 0 then
      xpThis = math.min(sAvg, xpLeft)
      xpLeft = xpLeft - xpThis
    end

    r:Show()
    r:SetBackdropColor(0, 0, 0, 0)              -- Keep backdrop transparent.
    r:SetMinMaxValues(0, maxRight)
    r:SetValue(xpThis)

    local lbl = date("%H:%M", starts[lastIx] + j * 3600)
    local showLbl = self.barWCache >= 14
    self.texts[i]:SetText(showLbl and lbl or "")

    if xpThis > 0 then
      attachTooltip(r, lbl,
                    string.format("%d XP predicted", xpThis), true)
    else
      r:SetScript("OnEnter", nil)
      r:SetScript("OnLeave", nil)
    end
  end
end
