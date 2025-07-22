-- MinimapButton.lua
-- A minimap button that can be positioned around the minimap edge and remembered,
-- with backward‑compatibility for old {x,y} storage.

XPChronicle = XPChronicle or {}
XPChronicle.MinimapButton = {}
local MB = XPChronicle.MinimapButton

-- Default angle (degrees) if we have nothing sensible in saved vars
local DEFAULT_ANGLE = 225

function MB:Create()
  if self.button then return end

  -- If saved var is missing or not a number, default to angle
  if type(AvgXPDB.minimapPos) ~= "number" then
    AvgXPDB.minimapPos = DEFAULT_ANGLE
  end

  local b = CreateFrame("Button", "XPChronicleMinimapButton", Minimap)
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)

  -- Circular mask
  local mask = b:CreateMaskTexture()
  mask:SetSize(26, 26)
  mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
  mask:SetPoint("CENTER", b, "CENTER")

  -- Icon texture
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(26, 26)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Book_11")
  icon:SetPoint("CENTER", b, "CENTER")
  icon:AddMaskTexture(mask)
  b.icon = icon

  -- Pushed & highlight
  b:SetPushedTexture("Interface\\Icons\\INV_Misc_Book_11")
  b:GetPushedTexture():SetTexCoord(0.05, 0.95, 0.05, 0.95)
  b:GetPushedTexture():SetAlpha(0)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:GetHighlightTexture():SetSize(32, 32)

  b:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1) end)
  b:SetScript("OnMouseUp",   function(self) self.icon:SetPoint("CENTER", 0,  0) end)

  -- Drag & click
  b:EnableMouse(true)
  b:RegisterForDrag("LeftButton", "RightButton")
  b:SetClampedToScreen(true)

  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
      XPChronicle.History:Toggle()
    elseif button == "RightButton" then
      XPChronicle.UI:ToggleGraph()
    end
  end)

  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(self)
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale()
      px, py = px/scale, py/scale

      local dx, dy = px - mx, py - my
      local angle = math.deg(math.atan2(dy, dx))
      AvgXPDB.minimapPos = angle
      self:ClearAllPoints()
      MB:UpdatePosition()
    end)
  end)

  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("XPChronicle", 0.2,0.8,1)
    GameTooltip:AddLine("Left‑click: XP History", 1,1,1)
    GameTooltip:AddLine("Drag: Reposition", 1,1,1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.button = b
  self:UpdatePosition()
end

function MB:UpdatePosition()
  if not self.button then return end

  local raw = AvgXPDB.minimapPos
  local angle

  if type(raw) == "number" then
    angle = raw
  elseif type(raw) == "table" and raw.x and raw.y then
    -- legacy storage: convert {x,y} back into an angle
    angle = math.deg(math.atan2(raw.y, raw.x))
  else
    angle = DEFAULT_ANGLE
  end

  local radius = 80
  local rad = math.rad(angle)
  local x = math.cos(rad) * radius
  local y = math.sin(rad) * radius

  self.button:ClearAllPoints()
  self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MB:HookMinimapUpdate()
  hooksecurefunc(Minimap, "SetScale", function() MB:UpdatePosition() end)
end
