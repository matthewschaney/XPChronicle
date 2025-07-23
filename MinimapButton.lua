-- XPChronicle ▸ MinimapButton.lua

XPChronicle                = XPChronicle or {}
XPChronicle.MinimapButton   = {}
local MB                    = XPChronicle.MinimapButton

-- Constants ------------------------------------------------------------------
local DEFAULT_ANGLE = 225               -- Fallback when nothing saved.
local RADIUS        = 80                -- Distance from minimap centre.
local TEX_ICON      = "Interface\\Icons\\INV_Misc_Book_11"
local TEX_MASK      = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- Helpers --------------------------------------------------------------------
local function getSavedAngle()
  local raw = AvgXPDB.minimapPos
  if type(raw) == "number" then
    return raw
  elseif type(raw) == "table" and raw.x and raw.y then
    -- Legacy {x,y} storage: convert to degrees, then persist.
    local deg = math.deg(math.atan2(raw.y, raw.x))
    AvgXPDB.minimapPos = deg
    return deg
  end
  return DEFAULT_ANGLE
end

local function saveCursorAngle()
  local mx, my  = Minimap:GetCenter()
  local px, py  = GetCursorPosition()
  local scale   = UIParent:GetEffectiveScale()
  px, py        = px / scale, py / scale
  local angle   = math.deg(math.atan2(py - my, px - mx))
  AvgXPDB.minimapPos = angle
  return angle
end

-- Creation -------------------------------------------------------------------
function MB:Create()
  if self.button then return end

  if type(AvgXPDB.minimapPos) ~= "number" then
    AvgXPDB.minimapPos = DEFAULT_ANGLE
  end

  local b = CreateFrame("Button", "XPChronicleMinimapButton", Minimap)
  self.button = b
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)

  -- Icon + circular mask.
  local mask = b:CreateMaskTexture()
  mask:SetSize(26, 26)
  mask:SetTexture(TEX_MASK, "CLAMPTOBLACKADDITIVE") -- Classic alpha mask.
  mask:SetPoint("CENTER")

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(26, 26)
  icon:SetTexture(TEX_ICON)
  icon:SetPoint("CENTER")
  icon:AddMaskTexture(mask)
  b.icon = icon

  -- Pushed + highlight states.
  b:SetPushedTexture(TEX_ICON)
  b:GetPushedTexture():SetTexCoord(.05, .95, .05, .95)
  b:GetPushedTexture():SetAlpha(0)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:GetHighlightTexture():SetSize(32, 32)

  -- Visual nudge on click.
  b:SetScript("OnMouseDown", 
      function(self) self.icon:SetPoint("CENTER", 1,-1)end)
  b:SetScript("OnMouseUp",   
      function(self) self.icon:SetPoint("CENTER", 0, 0)end)

  -- Mouse / drag registration.
  b:EnableMouse(true)
  b:RegisterForDrag("LeftButton", "RightButton")
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetClampedToScreen(true)

  -- Click behaviour.
  b:SetScript("OnClick", function(_, btn)
    if btn == "LeftButton" then
      XPChronicle.History:Toggle()
    else -- RightButton
      XPChronicle.UI:ToggleGraph()
    end
  end)

  -- Drag behaviour.
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      AvgXPDB.minimapPos = saveCursorAngle()
      MB:UpdatePosition()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

  -- Tooltip.
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("XPChronicle", .2, .8, 1)
    GameTooltip:AddLine("Left‑click: History", 1, 1, 1)
    GameTooltip:AddLine("Right‑click: Toggle Graph", 1, 1, 1)
    GameTooltip:AddLine("Drag: Reposition", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)

  self:UpdatePosition()
end

-- Positioning ----------------------------------------------------------------
function MB:UpdatePosition()
  if not self.button then return end

  local angle = getSavedAngle()
  local rad   = math.rad(angle)
  local x     = math.cos(rad) * RADIUS
  local y     = math.sin(rad) * RADIUS

  self.button:ClearAllPoints()
  self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Keep button aligned when minimap scale changes -----------------------------
function MB:HookMinimapUpdate()
  hooksecurefunc(Minimap, "SetScale", function() MB:UpdatePosition() end)
end
