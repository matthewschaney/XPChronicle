-- History.lua
-- The scrollable “tome” window showing every XP gain by date & time

XPChronicle = XPChronicle or {}
XPChronicle.History = {}
local H    = XPChronicle.History
local UI   = XPChronicle.UI

function H:Create()
  if self.frame then return end

  local f = CreateFrame("Frame","XPChronicleHistoryFrame",UI.back,"BackdropTemplate")
  f:SetSize(300,400)
  f:SetPoint("CENTER")
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 32, edgeSize = 16,
    insets   = { left=5, right=5, top=5, bottom=5 },
  })
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  local title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  title:SetPoint("TOP",0,-10)
  title:SetText("XP Chronicle History")

  local scroll = CreateFrame("ScrollFrame","XPChronicleHistoryScrollFrame",f,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 20)

  local content = CreateFrame("Frame","XPChronicleHistoryContent",scroll)
  content:SetSize(1,1)
  scroll:SetScrollChild(content)
  self.content = content

  f:Hide()
  self.frame = f
end

function H:Toggle()
  if not self.frame then self:Create() end
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    self:Update()
    self.frame:Show()
  end
end

function H:Update()
  local content = self.content
  for _, child in ipairs({content:GetChildren()}) do
    child:Hide()
    child:SetParent(nil)
  end

  local hist = AvgXPDB.history or {}
  local days = {}
  for day in pairs(hist) do tinsert(days, day) end
  table.sort(days, function(a,b) return a > b end)

  local y = 0
  for _, day in ipairs(days) do
    local header = content:CreateFontString(nil,"OVERLAY","GameFontNormal")
    header:SetPoint("TOPLEFT", 0, -y)
    header:SetText(day)
    y = y + header:GetStringHeight() + 5

    local entries = hist[day]
    table.sort(entries, function(a,b) return a.time < b.time end)
    for _, e in ipairs(entries) do
      local line = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
      line:SetPoint("TOPLEFT", 0, -y)
      line:SetText(("  [%s] +%d XP"):format(e.time, e.xp))
      y = y + line:GetStringHeight() + 3
    end

    y = y + 10
  end

  content:SetHeight(y)
end
