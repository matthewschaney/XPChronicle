-- XPChronicle ▸ UI.lua

XPChronicle          = XPChronicle or {}
XPChronicle.UI       = {}
local UI             = XPChronicle.UI
local DB             = XPChronicle.DB
local Utils          = XPChronicle.Utils

-- Default dimensions ---------------------------------------------------------
UI.PANEL_W = 200
UI.PANEL_H = 56

-- Right‑click dropdown -------------------------------------------------------
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

    -- Time‑lock --------------------------------------------------------------
    info = UIDropDownMenu_CreateInfo()
    info.text = "Set Time Lock…"
    info.func = function() StaticPopup_Show("XPCHRONICLE_SET_TIMELOCK") end
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
  end)
end

-- Main panel -----------------------------------------------------------------
function UI:CreateMainPanel()
  local back = _G.XPChronicleDisplay
           or CreateFrame("Frame", "XPChronicleDisplay",
                           UIParent, "BackdropTemplate")
  self.back  = back

  -- Styling ------------------------------------------------------------------
  back:SetSize(UI.PANEL_W, UI.PANEL_H)
  back:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  back:SetBackdropColor(0, 0, 0, .55)

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

  -- Right‑click menu ---------------------------------------------------------
  InitMainMenu()
  back:SetScript("OnMouseUp", function(_, btn)
    if btn == "RightButton" then
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

  -- Label --------------------------------------------------------------------
  local label = back.label
            or back:CreateFontString(nil, "OVERLAY",
                                     "GameFontNormalLarge")
  back.label  = label
  label:SetPoint("CENTER")
  label:SetWidth(UI.PANEL_W)
  label:SetJustifyH("CENTER")
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

  self.back.label:SetText(
    "Session: "       .. Utils.fmt(sAvg) .. " XP/h\n" ..
    "Time to level: " .. eta
  )
end

-- External API ---------------------------------------------------------------
function UI:Refresh()
  self:UpdateLabel()
  XPChronicle.Graph:Refresh()
end

function UI:ToggleGraph()
  local G    = XPChronicle.Graph
  local show = not G.frame:IsShown()
  G.frame:SetShown(show)
  AvgXPDB.graphHidden = not show
end
