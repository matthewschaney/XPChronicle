-- UI.lua
-- Main panel creation, label updates, toggle graph

XPChronicle = XPChronicle or {}
XPChronicle.UI = {}
local UI    = XPChronicle.UI
local DB    = XPChronicle.DB
local Utils = XPChronicle.Utils

UI.PANEL_W = 200
UI.PANEL_H = 56

function UI:CreateMainPanel()
  local back = _G.AXPChronicleDisplay
    or CreateFrame("Frame","XPChronicleDisplay",UIParent,"BackdropTemplate")
  self.back = back

  back:SetSize(self.PANEL_W, self.PANEL_H)
  back:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  back:SetBackdropColor(0,0,0,0.55)
  back:SetMovable(true); back:EnableMouse(true)
  back:RegisterForDrag("LeftButton")
  back:SetScript("OnDragStart", back.StartMoving)
  back:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    AvgXPDB.pos = { point = p, relativePoint = rp, x = x, y = y }
  end)

  back:ClearAllPoints()
  if AvgXPDB.pos then
    back:SetPoint(AvgXPDB.pos.point, UIParent,
                 AvgXPDB.pos.relativePoint,
                 AvgXPDB.pos.x, AvgXPDB.pos.y)
  else
    back:SetPoint("CENTER", 0, 200)
  end

  local label = back.label
    or back:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  back.label = label
  label:SetPoint("CENTER")
  label:SetWidth(self.PANEL_W)
  label:SetJustifyH("CENTER")
end

function UI:UpdateLabel()
  local sAvg = DB:GetSessionRate()
  local oAvg = DB:GetOverallRate()
  local fmt  = Utils.fmt
  self.back.label:SetText(
    "Session: " .. fmt(sAvg) .. " XP/h\n\n" ..
    "Overall: " .. fmt(oAvg) .. " XP/h"
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
