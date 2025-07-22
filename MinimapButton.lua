-- MinimapButton.lua
-- A minimap button that can be positioned around the minimap edge
XPChronicle = XPChronicle or {}
XPChronicle.MinimapButton = {}
local MB = XPChronicle.MinimapButton

-- Default position (angle in degrees)
local DEFAULT_ANGLE = 225 -- Bottom-left position

function MB:Create()
  if self.button then return end
  
  -- Initialize saved position
  AvgXPDB.minimapPos = AvgXPDB.minimapPos or DEFAULT_ANGLE
  
  local b = CreateFrame("Button", "XPChronicleMinimapButton", Minimap)
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  
  -- Create a mask to make the icon circular
  local mask = b:CreateMaskTexture()
  mask:SetSize(26, 26) -- Slightly larger to fit the border better
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  mask:SetPoint("CENTER", b, "CENTER", 0, 0)
  
  -- Icon texture
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(26, 26) -- Match mask size
  icon:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
  icon:SetPoint("CENTER", b, "CENTER", 0, 0) -- Center on button
  icon:AddMaskTexture(mask)
  
  -- Store reference to icon for pushed state
  b.icon = icon
  
  -- Set up button states
  b:SetPushedTexture("Interface\\Icons\\INV_Misc_Book_11")
  b:GetPushedTexture():SetTexCoord(0.05, 0.95, 0.05, 0.95)
  b:GetPushedTexture():SetAlpha(0) -- Hide the default pushed texture
  
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:GetHighlightTexture():SetSize(32, 32)
  
  -- Handle pushed state manually
  b:SetScript("OnMouseDown", function(self)
    self.icon:SetPoint("CENTER", 1, -1)
  end)
  
  b:SetScript("OnMouseUp", function(self)
    self.icon:SetPoint("CENTER", 0, 0)
  end)
  
  -- Make button draggable around minimap
  b:SetMovable(true)
  b:EnableMouse(true)
  b:RegisterForDrag("LeftButton", "RightButton")
  b:SetClampedToScreen(true)
  
  -- Click behavior
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
      XPChronicle.History:Toggle()
    elseif button == "RightButton" then
      -- Could add a context menu here in the future
      print("|cff33ff99XPChronicle|r: Right-click menu not yet implemented")
    end
  end)
  
  -- Dragging behavior
  b:SetScript("OnDragStart", function(self)
    self.isDragging = true
    self:SetScript("OnUpdate", function(self)
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale()
      px, py = px / scale, py / scale
      
      -- Calculate angle from minimap center
      local angle = math.deg(math.atan2(py - my, px - mx))
      
      -- Update position
      AvgXPDB.minimapPos = angle
      self:ClearAllPoints()
      MB:UpdatePosition()
    end)
  end)
  
  b:SetScript("OnDragStop", function(self)
    self.isDragging = false
    self:SetScript("OnUpdate", nil)
  end)
  
  -- Tooltip
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("XP Chronicle", 0.2, 0.8, 1)
    GameTooltip:AddLine("Left-click to view XP history", 1, 1, 1)
    GameTooltip:AddLine("Drag to reposition", 1, 1, 1)
    GameTooltip:Show()
  end)
  
  b:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)
  
  self.button = b
  self:UpdatePosition()
  
  -- Respect saved visibility state
  if AvgXPDB.minimapHidden then
    b:Hide()
  end
end

function MB:UpdatePosition()
  if not self.button then return end
  
  local angle = AvgXPDB.minimapPos or DEFAULT_ANGLE
  local radius = 80 -- Distance from minimap center
  
  -- Convert angle to radians and calculate position
  local radian = math.rad(angle)
  local x = math.cos(radian) * radius
  local y = math.sin(radian) * radius
  
  self.button:ClearAllPoints()
  self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Hook into minimap size changes (for different UI scales)
function MB:HookMinimapUpdate()
  -- Update position when minimap changes
  hooksecurefunc(Minimap, "SetScale", function()
    MB:UpdatePosition()
  end)
end