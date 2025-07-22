-- MinimapButton.lua
-- A minimap button that can be positioned around the minimap edge and remembered

XPChronicle = XPChronicle or {}
XPChronicle.MinimapButton = {}
local MB = XPChronicle.MinimapButton

-- Default position (angle in degrees)
local DEFAULT_ANGLE = 225 -- Bottom‑left position

function MB:Create()
  if self.button then return end

  -- pull from saved vars, or fall back to DEFAULT_ANGLE
  AvgXPDB.minimapPos = AvgXPDB.minimapPos or DEFAULT_ANGLE

  local b = CreateFrame("Button", "XPChronicleMinimapButton", Minimap)
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)

  -- circular mask
  local mask = b:CreateMaskTexture()
  mask:SetSize(26, 26)
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  mask:SetPoint("CENTER", b, "CENTER", 0, 0)

  -- icon
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(26, 26)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
  icon:SetPoint("CENTER", b, "CENTER", 0, 0)
  icon:AddMaskTexture(mask)
  b.icon = icon

  -- pushed/highlight states
  b:SetPushedTexture("Interface\\Icons\\INV_Misc_Book_11")
  b:GetPushedTexture():SetTexCoord(0.05, 0.95, 0.05, 0.95)
  b:GetPushedTexture():SetAlpha(0)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:GetHighlightTexture():SetSize(32, 32)

  b:SetScript("OnMouseDown", function(self)
    self.icon:SetPoint("CENTER", 1, -1)
  end)
  b:SetScript("OnMouseUp", function(self)
    self.icon:SetPoint("CENTER", 0, 0)
  end)

  -- dragging around the circle
  b:SetMovable(true)
  b:EnableMouse(true)
  b:RegisterForDrag("LeftButton", "RightButton")
  b:SetClampedToScreen(true)

  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
      XPChronicle.History:Toggle()
    elseif button == "RightButton" then
      -- you can swap this for any other behavior you like
      XPChronicle.UI:ToggleGraph()
    end
  end)

  b:SetScript("OnDragStart", function(self)
    self.isDragging = true
    self:SetScript("OnUpdate", function(self)
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale()
      px, py = px/scale, py/scale

      local angle = math.deg(math.atan2(py - my, px - mx))
      AvgXPDB.minimapPos = angle                  -- **persist the angle**
      self:ClearAllPoints()
      MB:UpdatePosition()
    end)
  end)

  b:SetScript("OnDragStop", function(self)
    self.isDragging = false
    self:SetScript("OnUpdate", nil)
  end)

  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("XPChronicle", 0.2, 0.8, 1)
    GameTooltip:AddLine("Left-click: XP History", 1,1,1)
    GameTooltip:AddLine("Drag: Reposition", 1,1,1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)

  self.button = b
  self:UpdatePosition()
end

function MB:UpdatePosition()
  if not self.button then return end
  local angle  = AvgXPDB.minimapPos or DEFAULT_ANGLE
  local radius = 80
  local rad    = math.rad(angle)
  local x = math.cos(rad) * radius
  local y = math.sin(rad) * radius
  self.button:ClearAllPoints()
  self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MB:HookMinimapUpdate()
  hooksecurefunc(Minimap, "SetScale", function()
    MB:UpdatePosition()
  end)
end
