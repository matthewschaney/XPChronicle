-- MinimapButton.lua
-- A little icon next to the minimap to open the history “tome”

XPChronicle = XPChronicle or {}
XPChronicle.MinimapButton = {}
local MB = XPChronicle.MinimapButton

function MB:Create()
  if self.button then return end

  local b = CreateFrame("Button","XPChronicleMinimapButton", MinimapCluster or Minimap)
  b:SetSize(28,28)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)

  b:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_11")
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

  b:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -5, 0)
  b:SetScript("OnClick", function()
    XPChronicle.History:Toggle()
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
    GameTooltip:AddLine("Tome of XP")
    GameTooltip:AddLine("Click to view XP history",1,1,1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)

  self.button = b
end
