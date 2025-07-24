-- XPChronicle ▸ Options.lua
-- Dedicated configuration panel opened from the minimap button.

XPChronicle          = XPChronicle or {}
XPChronicle.Options  = {}
local Opt            = XPChronicle.Options

-- Short locals ---------------------------------------------------------------
local DB, UI, Graph  = XPChronicle.DB, XPChronicle.UI, XPChronicle.Graph
local MB             = XPChronicle.MinimapButton

-- Constants ------------------------------------------------------------------
local PANEL_W, PANEL_H = 380, 640          -- ↑ taller
local TEX              = "Interface\\Buttons\\WHITE8x8"
local TAG              = '|cff33ff99XPChronicle|r: '

-- Private helpers ------------------------------------------------------------
local function makeCheck(parent, label, initial, onClick)
  local c = CreateFrame("CheckButton", nil, parent,
                        "ChatConfigCheckButtonTemplate")
  c:SetSize(24, 24)
  c.Text:SetText(label)
  c:SetChecked(initial)
  c:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
  return c
end

local function makeButton(parent, label, onClick, w)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetText(label)
  if w then b:SetWidth(w) end
  b:SetScript("OnClick", onClick)
  return b
end

local function updateSwatch(tex, col) tex:SetColorTexture(col[1], col[2], col[3], 1) end

-- UI creation ----------------------------------------------------------------
function Opt:Create()
  if self.frame then return end

  ---------------------------------------------------------------------------
  -- Shell -------------------------------------------------------------------
  ---------------------------------------------------------------------------
  local f = CreateFrame("Frame", "XPChronicleOptionsFrame", UIParent,
                        "BackdropTemplate")
  self.frame = f
  f:SetSize(PANEL_W, PANEL_H)
  f:SetPoint("CENTER")
  f:SetBackdrop({ bgFile = TEX, edgeFile = TEX, tile = false, edgeSize = 1 })
  f:SetBackdropColor(0, 0, 0, .75)
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop",  f.StopMoving)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -12)
  title:SetText("XPChronicle Options")

  ---------------------------------------------------------------------------
  -- [1] Bucket‑count slider --------------------------------------------------
  ---------------------------------------------------------------------------
  local s = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")
  s:SetWidth(300); s:SetPoint("TOP", 0, -50)
  s:SetMinMaxValues(2, 24); s:SetValueStep(1); s:SetObeyStepOnDrag(true)
  s:SetValue(AvgXPDB.buckets)
  s.Low:SetText("2"); s.High:SetText("24")
  s.Text:SetText("Buckets: "..AvgXPDB.buckets)
  s:SetScript("OnValueChanged", function(self, v)
    DB:SetBuckets(v); Graph:BuildBars(); UI:Refresh()
    self.Text:SetText("Buckets: "..v)
  end)

  ---------------------------------------------------------------------------
  -- [2] Colour pickers -------------------------------------------------------
  ---------------------------------------------------------------------------
  -- History colour -----------------------------------------------------------
  local histBtn  = makeButton(f, "History Bar Colour …", nil, 220)
  histBtn:SetPoint("TOPLEFT", 20, -100)
  local histSw   = f:CreateTexture(nil, "ARTWORK"); histSw:SetSize(24, 24)
  histSw:SetPoint("LEFT", histBtn, "RIGHT", 8, 0)
  updateSwatch(histSw, AvgXPDB.barColor or { .2, .8, 1 })

  histBtn:SetScript("OnClick", function()
    local cur = AvgXPDB.barColor or { .2, .8, 1 }
    ColorPickerFrame:Hide()
    local function apply(r,g,b)
      AvgXPDB.barColor = { r,g,b }; updateSwatch(histSw, AvgXPDB.barColor)
      Graph:BuildBars(); Graph:Refresh()
    end
    ColorPickerFrame.func = function() apply(ColorPickerFrame:GetColorRGB()) end
    ColorPickerFrame.swatchFunc = ColorPickerFrame.func
    ColorPickerFrame.cancelFunc = function() apply(unpack(cur)) end
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame:SetColorRGB(cur[1], cur[2], cur[3]); ColorPickerFrame:Show()
  end)

  -- Prediction colour --------------------------------------------------------
  local predBtn  = makeButton(f, "Prediction Bar Colour …", nil, 220)
  predBtn:SetPoint("TOPLEFT", 20, -135)
  local predSw   = f:CreateTexture(nil, "ARTWORK"); predSw:SetSize(24,24)
  predSw:SetPoint("LEFT", predBtn, "RIGHT", 8, 0)
  updateSwatch(predSw, AvgXPDB.predColor or { 1, .2, .2 })

  predBtn:SetScript("OnClick", function()
    local cur = AvgXPDB.predColor or { 1, .2, .2 }
    ColorPickerFrame:Hide()
    local function apply(r,g,b)
      AvgXPDB.predColor = { r,g,b }; updateSwatch(predSw, AvgXPDB.predColor)
      Graph:BuildBars(); Graph:Refresh()
    end
    ColorPickerFrame.func = function() apply(ColorPickerFrame:GetColorRGB()) end
    ColorPickerFrame.swatchFunc = ColorPickerFrame.func
    ColorPickerFrame.cancelFunc = function() apply(unpack(cur)) end
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame:SetColorRGB(cur[1], cur[2], cur[3]); ColorPickerFrame:Show()
  end)

  ---------------------------------------------------------------------------
  -- [3] Window‑position editors ---------------------------------------------
  ---------------------------------------------------------------------------
  local function posEditor(label, getter, setter, y)
    local l = f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    l:SetPoint("TOPLEFT", 20, y); l:SetText(label)
    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetSize(50,20); eb:SetAutoFocus(false)
    eb:SetPoint("LEFT", l, "RIGHT", 4, 0)
    eb:SetText(getter()); eb:SetCursorPosition(0)
    eb:SetScript("OnEnterPressed", function(self)
      setter(tonumber(self:GetText()) or 0); self:ClearFocus()
    end)
  end
  local function applyMainPos(nx,ny)
    local p, rel, rp = UI.back:GetPoint()
    UI.back:ClearAllPoints(); UI.back:SetPoint(p, rel, rp, nx, ny)
    AvgXPDB.pos = { point = p, relativePoint = rp, x = nx, y = ny }
  end
  posEditor("XP Frame X:", function() return (AvgXPDB.pos and AvgXPDB.pos.x) or 0 end,
            function(v) applyMainPos(v,(AvgXPDB.pos and AvgXPDB.pos.y) or 0) end, -175)
  posEditor("XP Frame Y:", function() return (AvgXPDB.pos and AvgXPDB.pos.y) or 0 end,
            function(v) applyMainPos((AvgXPDB.pos and AvgXPDB.pos.x) or 0, v) end, -200)

  ---------------------------------------------------------------------------
  -- [4] Lock check‑boxes -----------------------------------------------------
  ---------------------------------------------------------------------------
  local lockMain = makeCheck(f,"Lock XP Frame",AvgXPDB.mainLocked,function(v)
    AvgXPDB.mainLocked = v; UI.back:SetMovable(not v)
  end)
  lockMain:SetPoint("TOPLEFT",20,-235)

  local lockHist = makeCheck(f,"Lock History Frame",AvgXPDB.historyLocked or false,
    function(v)
      AvgXPDB.historyLocked = v
      if XPChronicle.History.frame then XPChronicle.History.frame:SetMovable(not v) end
    end)
  lockHist:SetPoint("TOPLEFT",20,-260)

  local lockMini = makeCheck(f,"Lock Minimap Button",AvgXPDB.minimapLocked or false,
    function(v) AvgXPDB.minimapLocked = v end)
  lockMini:SetPoint("TOPLEFT",20,-285)

  ---------------------------------------------------------------------------
  -- [5] Timelock edit‑box ----------------------------------------------------
  ---------------------------------------------------------------------------
  local hlLabel = f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  hlLabel:SetPoint("TOPLEFT",20,-320)
  hlLabel:SetText("Timelock (min 0‑59):")
  local hlEdit = CreateFrame("EditBox",nil,f,"InputBoxTemplate")
  hlEdit:SetSize(40,20); hlEdit:SetAutoFocus(false)
  hlEdit:SetPoint("LEFT",hlLabel,"RIGHT",4,0)
  hlEdit:SetText(tostring((AvgXPDB.gridOffset or 0)/60)); hlEdit:SetCursorPosition(0)
  hlEdit:SetScript("OnEnterPressed",function(self)
    local m=tonumber(self:GetText()); if m and m>=0 and m<60 then
      AvgXPDB.gridOffset=m*60; DB:RebuildBuckets(); Graph:BuildBars(); UI:Refresh()
    else print(TAG.."enter 0‑59.") end; self:ClearFocus()
  end)

  ---------------------------------------------------------------------------
  -- [6] Misc toggles ---------------------------------------------------------
  ---------------------------------------------------------------------------
  makeCheck(f,"Enable Right‑click Frame Menu",AvgXPDB.frameMenuEnabled~=false,
            function(v) AvgXPDB.frameMenuEnabled=v end)
    :SetPoint("TOPLEFT",20,-355)

  makeCheck(f,"Prediction Mode",AvgXPDB.predictionMode,function(v)
              AvgXPDB.predictionMode=v; Graph:BuildBars(); Graph:Refresh()
            end):SetPoint("TOPLEFT",230,-355)

  ---------------------------------------------------------------------------
  -- [7] Visibility toggles ---------------------------------------------------
  ---------------------------------------------------------------------------
  local visXP = makeCheck(f,"Show XP Frame",not AvgXPDB.mainHidden,function(v)
    AvgXPDB.mainHidden=not v
    if v then UI.back:Show(); Graph.frame:SetParent(UI.back)
    else      Graph.frame:SetParent(UIParent); UI.back:Hide() end
  end)
  visXP:SetPoint("TOPLEFT",20,-385)

  local visBar = makeCheck(f,"Show Bar Frame",not AvgXPDB.graphHidden,function(v)
    Graph.frame:SetShown(v); AvgXPDB.graphHidden=not v
  end)
  visBar:SetPoint("TOPLEFT",20,-410)

  local visMini = makeCheck(f,"Show Minimap Button",not AvgXPDB.minimapHidden,function(v)
    if not MB.button then MB:Create() end
    MB.button:SetShown(v); AvgXPDB.minimapHidden=not v
  end)
  visMini:SetPoint("TOPLEFT",20,-435)

  ---------------------------------------------------------------------------
  -- [8] Reset buttons (centred) ---------------------------------------------
  ---------------------------------------------------------------------------
  local totalW = 90+110+100+12   -- widths + two 6‑px gaps = 312
  local firstX = -math.floor(totalW/2) + 45      -- centre of first button
  local resetAcc  = makeButton(f,"Full Reset",function()
                      StaticPopup_Show("XPCHRONICLE_CONFIRM_FULL_RESET") end,90)
  resetAcc:SetPoint("BOTTOM",0+firstX,20)

  local resetChar = makeButton(f,"Character Reset",function()
                      table.wipe(AvgXPDB.hourBuckets); table.wipe(AvgXPDB.history)
                      table.wipe(AvgXPDB.historyEvents)
                      DB:RebuildBuckets(); DB:StartSession(); UI:Refresh()
                      print(TAG.."character data reset.") end,110)
  resetChar:SetPoint("LEFT",resetAcc,"RIGHT",6,0)

  local resetSess = makeButton(f,"Session Reset",function()
                      DB:StartSession(); UI:Refresh() end,100)
  resetSess:SetPoint("LEFT",resetChar,"RIGHT",6,0)

  ---------------------------------------------------------------------------
  -- Static‑popup for the full reset -----------------------------------------
  ---------------------------------------------------------------------------
  StaticPopupDialogs["XPCHRONICLE_CONFIRM_FULL_RESET"] = {
    text="This will erase all XPChronicle data for |cffd6261call|r characters.\nContinue?",
    button1=YES, button2=CANCEL, whileDead=true, hideOnEscape=true,
    OnAccept=function() DB:Reset(); UI:Refresh(); Graph:BuildBars() end,
  }
end

-- Public API -----------------------------------------------------------------
function Opt:Toggle()
  if not self.frame then self:Create() end
  self.frame:SetShown(not self.frame:IsShown())
end
