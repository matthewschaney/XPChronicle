-- UI.lua
-- Main panel creation, label updates, toggle graph, and right‑click lock/unlock

XPChronicle = XPChronicle or {}
XPChronicle.UI = {}
local UI    = XPChronicle.UI
local DB    = XPChronicle.DB
local Utils = XPChronicle.Utils

UI.PANEL_W = 200
UI.PANEL_H = 56

-- Initialize the right‑click lock menu (only once)
local function InitializeMainMenu()
  if UI.mainMenu then return end
  UI.mainMenu = CreateFrame("Frame", "XPChronicleMainMenu", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(UI.mainMenu, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text    = "Lock Frame"
    info.checked = AvgXPDB.mainLocked
    info.func   = function()
      AvgXPDB.mainLocked = not AvgXPDB.mainLocked
      UI.back:SetMovable(not AvgXPDB.mainLocked)
      if AvgXPDB.mainLocked then UI.back:StopMovingOrSizing() end
    end
    UIDropDownMenu_AddButton(info, level)
  end)
end

function UI:CreateMainPanel()
  local back = _G.AXPChronicleDisplay
    or CreateFrame("Frame", "XPChronicleDisplay", UIParent, "BackdropTemplate")
  self.back = back

  -- appearance
  back:SetSize(self.PANEL_W, self.PANEL_H)
  back:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  back:SetBackdropColor(0,0,0,0.55)

  -- mouse & drag setup
  back:EnableMouse(true)
  back:RegisterForDrag("LeftButton")
  back:SetMovable(not AvgXPDB.mainLocked)

  back:SetScript("OnDragStart", function(self, button)
    if button == "LeftButton" and not AvgXPDB.mainLocked then
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

  -- right‑click opens lock toggle
  InitializeMainMenu()
  back:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
      ToggleDropDownMenu(1, nil, UI.mainMenu, "cursor")
    end
  end)

  -- restore last position or default
  back:ClearAllPoints()
  if AvgXPDB.pos then
    back:SetPoint(AvgXPDB.pos.point, UIParent,
                  AvgXPDB.pos.relativePoint,
                  AvgXPDB.pos.x, AvgXPDB.pos.y)
  else
    back:SetPoint("CENTER", 0, 200)
  end

  -- label
  local label = back.label
    or back:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  back.label = label
  label:SetPoint("CENTER")
  label:SetWidth(self.PANEL_W)
  label:SetJustifyH("CENTER")
end

function UI:UpdateLabel()
  local sAvg = DB:GetSessionRate()
  local oAvg = DB:GetOverallRate()
  self.back.label:SetText(
    "Session: " .. Utils.fmt(sAvg) .. " XP/h\n\n" ..
    "Overall: " .. Utils.fmt(oAvg) .. " XP/h"
  )
end

function UI:Refresh()
  self:UpdateLabel()
  XPChronicle.Graph:Refresh()
end

function UI:ToggleGraph()
  local G = XPChronicle.Graph
  G.frame:SetShown(not G.frame:IsShown())
  AvgXPDB.graphHidden = not G.frame:IsShown()
end
