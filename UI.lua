-- XPChronicle ▸ UI.lua (Unified, modernized; fixed gradients)

XPChronicle          = XPChronicle or {}
XPChronicle.UI       = {}
local UI             = XPChronicle.UI
local DB             = XPChronicle.DB
local Utils          = XPChronicle.Utils

-- Default dimensions ---------------------------------------------------------
UI.PANEL_W   = 200  -- initial width; will auto-size to graph
UI.PANEL_H   = 56   -- initial height; will auto-size to label+graph
UI.PAD       = 8    -- outer padding for unified panel
UI.LABEL_GAP = 6    -- space between label and graph
UI.LABEL_H   = 28   -- reserved height for label block (auto-updated)

-- Right-click dropdown -------------------------------------------------------
local function InitMainMenu()
  if UI.mainMenu then return end

  UI.mainMenu = CreateFrame("Frame", "XPChronicleMainMenu",
                            UIParent, "UIDropDownMenuTemplate")

  UIDropDownMenu_Initialize(UI.mainMenu, function(_, level)
    local info

    -- Lock frame -------------------------------------------------------------
    info           = UIDropDownMenu_CreateInfo()
    info.text      = "Lock Frame"
    info.checked   = AvgXPDB.mainLocked
    info.func      = function()
      AvgXPDB.mainLocked = not AvgXPDB.mainLocked
      UI.back:SetMovable(not AvgXPDB.mainLocked)
      if AvgXPDB.mainLocked then UI.back:StopMovingOrSizing() end
    end
    UIDropDownMenu_AddButton(info, level)

    -- Time-lock --------------------------------------------------------------
    info           = UIDropDownMenu_CreateInfo()
    info.text      = "Set Time Lock…"
    info.func      = function() StaticPopup_Show("XPCHRONICLE_SET_TIMELOCK") end
    UIDropDownMenu_AddButton(info, level)

    -- Prediction mode --------------------------------------------------------
    info           = UIDropDownMenu_CreateInfo()
    info.text      = "Prediction Mode"
    info.checked   = AvgXPDB.predictionMode
    info.func      = function()
      AvgXPDB.predictionMode = not AvgXPDB.predictionMode
      XPChronicle.Graph:BuildBars()
      XPChronicle.Graph:Refresh()
    end
    UIDropDownMenu_AddButton(info, level)

    -- Open XP Report ---------------------------------------------------------
    info           = UIDropDownMenu_CreateInfo()
    info.text      = "Open XP Report"
    info.func      = function()
      XPChronicle.Report:Toggle()
    end
    UIDropDownMenu_AddButton(info, level)
  end)
end

-- Internal: compute inner width available for bars ---------------------------
function UI:GetInnerWidth()
  return (self.PANEL_W - (self.PAD * 2))
end

-- Internal: resize panel around content (TOT_W x BAR_H) ----------------------
function UI:SetUnifiedLayout(contentW, barH)
  self.PANEL_W = math.max(contentW + self.PAD * 2, 120)

  if self.back and self.back.label then
    local lh = math.ceil(self.back.label:GetStringHeight() or self.LABEL_H)
    self.LABEL_H = math.max(22, lh)
  end

  self.PANEL_H = self.PAD + self.LABEL_H + self.LABEL_GAP + barH + self.PAD

  if self.back then
    self.back:SetSize(self.PANEL_W, self.PANEL_H)
  end
end

-- Main panel -----------------------------------------------------------------
function UI:CreateMainPanel()
  local back = _G.XPChronicleDisplay
           or CreateFrame("Frame", "XPChronicleDisplay",
                           UIParent, "BackdropTemplate")
  self.back  = back

  -- Styling: unified, modern panel ------------------------------------------
  back:SetSize(UI.PANEL_W, UI.PANEL_H)
  back:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  back:SetBackdropColor(0.07, 0.07, 0.07, 0.82)      -- deep charcoal
  back:SetBackdropBorderColor(0.2, 0.6, 1, 0.85)     -- subtle blue glow

  -- Soft vertical gradient overlay (SetGradient — not SetGradientAlpha)
  local grad = back:CreateTexture(nil, "BACKGROUND")
  grad:SetAllPoints()
  grad:SetTexture("Interface\\Buttons\\WHITE8x8")
  grad:SetGradient("VERTICAL", CreateColor(1,1,1,0.06), CreateColor(0,0,0,0.20))

  -- Edge highlight (top)
  local topShine = back:CreateTexture(nil, "BORDER")
  topShine:SetPoint("TOPLEFT", 3, -3)
  topShine:SetPoint("TOPRIGHT", -3, -3)
  topShine:SetHeight(20)
  topShine:SetTexture("Interface\\Buttons\\WHITE8x8")
  topShine:SetGradient("VERTICAL", CreateColor(1,1,1,0.08), CreateColor(1,1,1,0))

  -- Drag & lock --------------------------------------------------------------
  back:EnableMouse(true)
  back:RegisterForDrag("LeftButton")
  back:SetMovable(not AvgXPDB.mainLocked)

  back:SetScript("OnDragStart", function(self, btn)
    if btn == "LeftButton" and not AvgXPDB.mainLocked then
      self:StartMoving()
    end
  end)

  back:SetScript("OnDragStop", function(self)
    if not AvgXPDB.mainLocked then
      self:StopMovingOrSizing()
      local p, _, rp, x, y = self:GetPoint()
      AvgXPDB.pos = { point = p, relativePoint = rp, x = x, y = y }
    end
  end)

  -- Right-click menu ---------------------------------------------------------
  InitMainMenu()
  back:SetScript("OnMouseUp", function(_, btn)
    if btn == "RightButton" and (AvgXPDB.frameMenuEnabled ~= false) then
      ToggleDropDownMenu(1, nil, UI.mainMenu, "cursor")
    end
  end)

  -- Position restore ---------------------------------------------------------
  back:ClearAllPoints()
  if AvgXPDB.pos then
    back:SetPoint(AvgXPDB.pos.point, UIParent,
                  AvgXPDB.pos.relativePoint,
                  AvgXPDB.pos.x, AvgXPDB.pos.y)
  else
    back:SetPoint("CENTER", 0, 200)
  end

  -- Label (now anchored to the TOP inside the unified panel) -----------------
  local label = back.label
            or back:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  back.label  = label
  label:ClearAllPoints()
  label:SetPoint("TOPLEFT", back, "TOPLEFT", UI.PAD, -UI.PAD)
  label:SetPoint("TOPRIGHT", back, "TOPRIGHT", -UI.PAD, -UI.PAD)
  label:SetJustifyH("CENTER")

  local f = select(1, label:GetFont())
  label:SetFont(f or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")

  self.LABEL_H = math.max(22, math.ceil(label:GetStringHeight() or 22))
  self:SetUnifiedLayout(self.PANEL_W - self.PAD * 2, 40)

  XPChronicle.Graph:Init()
end

-- Label update ---------------------------------------------------------------
function UI:UpdateLabel()
  local sAvg = DB:GetSessionRate()
  local cur  = UnitXP("player")
  local max  = UnitXPMax("player")
  local rem  = max - cur

  local eta  = "--:--"
  if sAvg > 0 then
    local hrs  = rem / sAvg
    local h    = math.floor(hrs)
    local m    = math.floor((hrs - h) * 60 + .5)
    eta        = string.format("%d:%02d", h, m)
  end

  if not self.back or not self.back.label then return end

  self.back.label:SetText(
    "Session: "       .. Utils.fmt(sAvg) .. " XP/h\n" ..
    "Time to level: " .. eta
  )

  self.LABEL_H = math.max(22, math.ceil(self.back.label:GetStringHeight() or 22))
end

-- External API ---------------------------------------------------------------
function UI:Refresh()
  self:UpdateLabel()
  local NB = AvgXPDB.buckets or 12
  local innerW = self:GetInnerWidth()
  local barW = math.max(1, math.floor((innerW - (NB - 1)) / NB)) -- rough pass
  local totW = barW * NB + (NB - 1)
  self:SetUnifiedLayout(totW, 40)

  XPChronicle.Graph:Refresh()
end

function UI:ToggleGraph()
  local G = XPChronicle.Graph
  if not G or not G.frame then return end
  local show = not G.frame:IsShown()
  G.frame:SetShown(show)
  AvgXPDB.graphHidden = not show
end
