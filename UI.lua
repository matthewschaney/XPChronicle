-- UI.lua
-- Main panel creation, label updates, toggle graph,
-- right‑click Lock Frame + Set Time Lock + Prediction Mode

XPChronicle = XPChronicle or {}
XPChronicle.UI = {}
local UI    = XPChronicle.UI
local DB    = XPChronicle.DB
local Utils = XPChronicle.Utils

UI.PANEL_W = 200
UI.PANEL_H = 56

-- One‑time setup of the right‑click dropdown menu
local function InitializeMainMenu()
  if UI.mainMenu then return end
  UI.mainMenu = CreateFrame("Frame", "XPChronicleMainMenu", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(UI.mainMenu, function(self, level)
    local info

    -- Lock Frame
    info = UIDropDownMenu_CreateInfo()
    info.text    = "Lock Frame"
    info.checked = AvgXPDB.mainLocked
    info.func    = function()
      AvgXPDB.mainLocked = not AvgXPDB.mainLocked
      UI.back:SetMovable(not AvgXPDB.mainLocked)
      if AvgXPDB.mainLocked then UI.back:StopMovingOrSizing() end
    end
    UIDropDownMenu_AddButton(info, level)

    -- Set Time Lock…
    info = UIDropDownMenu_CreateInfo()
    info.text = "Set Time Lock…"
    info.func = function()
      StaticPopup_Show("XPCHRONICLE_SET_TIMELOCK")
    end
    UIDropDownMenu_AddButton(info, level)

    -- Prediction Mode toggle
    info = UIDropDownMenu_CreateInfo()
    info.text    = "Prediction Mode"
    info.checked = AvgXPDB.predictionMode
    info.func    = function()
      AvgXPDB.predictionMode = not AvgXPDB.predictionMode
      XPChronicle.Graph:BuildBars()
      XPChronicle.Graph:Refresh()
    end
    UIDropDownMenu_AddButton(info, level)
  end)
end

function UI:CreateMainPanel()
  local back = _G["XPChronicleDisplay"]
             or CreateFrame("Frame", "XPChronicleDisplay", UIParent, "BackdropTemplate")
  UI.back = back

  -- panel styling
  back:SetSize(UI.PANEL_W, UI.PANEL_H)
  back:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  back:SetBackdropColor(0,0,0,0.55)

  -- dragging
  back:EnableMouse(true)
  back:RegisterForDrag("LeftButton")
  back:SetMovable(not AvgXPDB.mainLocked)
  back:SetScript("OnDragStart", function(self, button)
    if button=="LeftButton" and not AvgXPDB.mainLocked then
      self:StartMoving()
    end
  end)
  back:SetScript("OnDragStop", function(self)
    if not AvgXPDB.mainLocked then
      self:StopMovingOrSizing()
      local p, _, rp, x, y = self:GetPoint()
      AvgXPDB.pos = { point=p, relativePoint=rp, x=x, y=y }
    end
  end)

  -- right‑click menu
  InitializeMainMenu()
  back:SetScript("OnMouseUp", function(self, button)
    if button=="RightButton" then
      ToggleDropDownMenu(1, nil, UI.mainMenu, "cursor")
    end
  end)

  -- restore position
  back:ClearAllPoints()
  if AvgXPDB.pos then
    back:SetPoint(
      AvgXPDB.pos.point, UIParent,
      AvgXPDB.pos.relativePoint,
      AvgXPDB.pos.x, AvgXPDB.pos.y
    )
  else
    back:SetPoint("CENTER", 0, 200)
  end

  -- label
  local label = back.label
    or back:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  back.label = label
  label:SetPoint("CENTER")
  label:SetWidth(UI.PANEL_W)
  label:SetJustifyH("CENTER")
end

function UI:UpdateLabel()
  local sAvg = DB:GetSessionRate()
  local cur  = UnitXP("player")
  local max  = UnitXPMax("player")
  local rem  = max - cur

  local eta = "--:--"
  if sAvg > 0 then
    local hrs = rem / sAvg
    local h   = math.floor(hrs)
    local m   = math.floor((hrs - h) * 60 + 0.5)
    eta       = string.format("%d:%02d", h, m)
  end

  UI.back.label:SetText(
    "Session: "       .. Utils.fmt(sAvg) .. " XP/h\n" ..
    "Time to level: " .. eta
  )
end

function UI:Refresh()
  UI:UpdateLabel()
  XPChronicle.Graph:Refresh()
end

function UI:ToggleGraph()
  local G    = XPChronicle.Graph
  local show = not G.frame:IsShown()
  G.frame:SetShown(show)
  AvgXPDB.graphHidden = not show
end
