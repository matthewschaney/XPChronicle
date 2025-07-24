-- XPChronicle ▸ Options.lua
-- Dedicated configuration panel opened from the minimap button.

XPChronicle          = XPChronicle or {}
XPChronicle.Options  = {}
local Opt            = XPChronicle.Options

-- Short locals ---------------------------------------------------------------
local DB, UI, Graph  = XPChronicle.DB, XPChronicle.UI, XPChronicle.Graph
local MB             = XPChronicle.MinimapButton

-- Constants ------------------------------------------------------------------
local PANEL_W, PANEL_H = 380, 520
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

local function makeButton(parent, label, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetText(label)
  b:SetScript("OnClick", onClick)
  return b
end

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
  f:SetMovable(true)
  f:EnableMouse(true)
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
  s:SetWidth(300)
  s:SetPoint("TOP", 0, -50)
  s:SetMinMaxValues(2, 24)
  s:SetValueStep(1)
  s:SetObeyStepOnDrag(true)
  s:SetValue(AvgXPDB.buckets)

  s.Low:SetText("2")
  s.High:SetText("24")
  s.Text:SetText("Buckets: "..AvgXPDB.buckets)

  s:SetScript("OnValueChanged", function(self, v)
    DB:SetBuckets(v)
    Graph:BuildBars()
    UI:Refresh()
    self.Text:SetText("Buckets: "..v)
  end)

  ---------------------------------------------------------------------------
  -- [2] Bar‑colour picker ----------------------------------------------------
  ---------------------------------------------------------------------------
  local colourBtn = makeButton(f, "Bar Colour …", function()
    local cur = AvgXPDB.barColor or { .2, .8, 1 }

    local function apply(r, g, b)
      AvgXPDB.barColor = { r, g, b }
      Graph:BuildBars()
      Graph:Refresh()
    end

    ColorPickerFrame:Hide()
    ColorPickerFrame.func       = function()
                                    local r, g, b = ColorPickerFrame:GetColorRGB()
                                    apply(r, g, b)
                                  end
    ColorPickerFrame.swatchFunc = ColorPickerFrame.func  -- avoid nil call
    ColorPickerFrame.cancelFunc = function() apply(unpack(cur)) end
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame:SetColorRGB(cur[1], cur[2], cur[3])
    ColorPickerFrame:Show()
  end)
  colourBtn:SetPoint("TOPLEFT", 20, -100)

  ---------------------------------------------------------------------------
  -- [3] Window‑position editors ---------------------------------------------
  ---------------------------------------------------------------------------
  local function posEditor(label, getter, setter, yOff)
    local l = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l:SetPoint("TOPLEFT", 20, yOff)
    l:SetText(label)

    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetSize(50, 20)
    eb:SetAutoFocus(false)
    eb:SetPoint("LEFT", l, "RIGHT", 4, 0)
    eb:SetText(getter())
    eb:SetCursorPosition(0)

    eb:SetScript("OnEnterPressed", function(self)
      local v = tonumber(self:GetText()) or 0
      setter(v)
      self:ClearFocus()
    end)
  end

  local function applyMainPos(nx, ny)
    local p, rel, rp = UI.back:GetPoint()
    UI.back:ClearAllPoints()
    UI.back:SetPoint(p, rel, rp, nx, ny)
    AvgXPDB.pos = { point = p, relativePoint = rp, x = nx, y = ny }
  end

  posEditor("XP Frame X:",
            function() return (AvgXPDB.pos and AvgXPDB.pos.x) or 0 end,
            function(v) applyMainPos(v, (AvgXPDB.pos and AvgXPDB.pos.y) or 0) end,
            -160)

  posEditor("XP Frame Y:",
            function() return (AvgXPDB.pos and AvgXPDB.pos.y) or 0 end,
            function(v) applyMainPos((AvgXPDB.pos and AvgXPDB.pos.x) or 0, v) end,
            -185)

  ---------------------------------------------------------------------------
  -- [4] Lock checkboxes ------------------------------------------------------
  ---------------------------------------------------------------------------
  local lockMain = makeCheck(f, "Lock XP Frame", AvgXPDB.mainLocked, function(v)
    AvgXPDB.mainLocked = v
    UI.back:SetMovable(not v)
  end)
  lockMain:SetPoint("TOPLEFT", 20, -220)

  local lockHist = makeCheck(f, "Lock History Frame",
                             AvgXPDB.historyLocked or false, function(v)
    AvgXPDB.historyLocked = v
    if XPChronicle.History.frame then
      XPChronicle.History.frame:SetMovable(not v)
    end
  end)
  lockHist:SetPoint("TOPLEFT", 20, -245)

  ---------------------------------------------------------------------------
  -- [5] Timelock minute editbox ---------------------------------------------
  ---------------------------------------------------------------------------
  local hlLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  hlLabel:SetPoint("TOPLEFT", 20, -280)
  hlLabel:SetText("Timelock (min 0‑59):")

  local hlEdit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  hlEdit:SetSize(40, 20)
  hlEdit:SetAutoFocus(false)
  hlEdit:SetPoint("LEFT", hlLabel, "RIGHT", 4, 0)
  hlEdit:SetText(tostring((AvgXPDB.gridOffset or 0) / 60))
  hlEdit:SetCursorPosition(0)

  hlEdit:SetScript("OnEnterPressed", function(self)
    local m = tonumber(self:GetText())
    if m and m >= 0 and m < 60 then
      AvgXPDB.gridOffset = m * 60
      DB:RebuildBuckets()
      Graph:BuildBars()
      UI:Refresh()
    else
      print(TAG.."enter 0‑59.")
    end
    self:ClearFocus()
  end)

  ---------------------------------------------------------------------------
  -- [6] Frame‑menu enable toggle --------------------------------------------
  ---------------------------------------------------------------------------
  makeCheck(f, "Enable Right‑click Frame Menu",
            AvgXPDB.frameMenuEnabled ~= false,
            function(v) AvgXPDB.frameMenuEnabled = v end)
    :SetPoint("TOPLEFT", 20, -315)

------------------------------------------------------------------------
-- [7] Visibility toggles ---------------------------------------------
------------------------------------------------------------------------
local visXP = makeCheck(f, "Show XP Frame", not AvgXPDB.mainHidden,
  function(v)                                        --  ⬅︎ updated
    AvgXPDB.mainHidden = not v

    if v then
        UI.back:Show()
        Graph.frame:SetParent(UI.back)   -- re‑attach under stats panel
    else
        Graph.frame:SetParent(UIParent)  -- float on its own
        UI.back:Hide()
    end
  end)
visXP:SetPoint("TOPLEFT", 20, -345)

-- Show / hide **bar graph** -----------------------------------------
local visBar = makeCheck(f, "Show Bar Frame", not AvgXPDB.graphHidden,
  function(v)
    Graph.frame:SetShown(v)
    AvgXPDB.graphHidden = not v
  end)
visBar:SetPoint("TOPLEFT", 20, -370)

-- Show / hide **minimap button** ------------------------------------
local visMini = makeCheck(f, "Show Minimap Button", not AvgXPDB.minimapHidden,
  function(v)
    if not MB.button then MB:Create() end
    MB.button:SetShown(v)
    AvgXPDB.minimapHidden = not v
  end)
visMini:SetPoint("TOPLEFT", 20, -395)

  ---------------------------------------------------------------------------
  -- [8] Reset buttons --------------------------------------------------------
  ---------------------------------------------------------------------------
  local resetAcc = makeButton(f, "Full Reset", function()
    StaticPopup_Show("XPCHRONICLE_CONFIRM_FULL_RESET")
  end)
  resetAcc:SetPoint("BOTTOMLEFT", 20, 20)
  resetAcc:SetSize(90, 22)

  local resetChar = makeButton(f, "Character Reset", function()
    table.wipe(AvgXPDB.hourBuckets)
    table.wipe(AvgXPDB.history)
    table.wipe(AvgXPDB.historyEvents)
    DB:RebuildBuckets()
    DB:StartSession()
    UI:Refresh()
    print(TAG.."character data reset.")
  end)
  resetChar:SetPoint("LEFT", resetAcc, "RIGHT", 6, 0)
  resetChar:SetSize(110, 22)

  local resetSess = makeButton(f, "Session Reset", function()
    DB:StartSession()
    UI:Refresh()
  end)
  resetSess:SetPoint("LEFT", resetChar, "RIGHT", 6, 0)
  resetSess:SetSize(100, 22)

  ---------------------------------------------------------------------------
  -- Static‑popup for the full reset -----------------------------------------
  ---------------------------------------------------------------------------
  StaticPopupDialogs["XPCHRONICLE_CONFIRM_FULL_RESET"] = {
    text = "This will erase all XPChronicle data for |cffd6261call|r characters.\nContinue?",
    button1 = YES,
    button2 = CANCEL,
    whileDead = true,
    hideOnEscape = true,
    OnAccept = function()
      DB:Reset()
      UI:Refresh()
      Graph:BuildBars()
    end,
  }
end

-- Public API -----------------------------------------------------------------
function Opt:Toggle()
  if not self.frame then self:Create() end
  self.frame:SetShown(not self.frame:IsShown())
end
