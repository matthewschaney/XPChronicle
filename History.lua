-- History.lua
-- Scrollable “tome” window with toggle buttons for event/hour/day

XPChronicle = XPChronicle or {}
XPChronicle.History = {}
local H  = XPChronicle.History
local UI = XPChronicle.UI

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

  -- Title
  local title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  title:SetPoint("TOP",0,-10)
  title:SetText("XP Chronicle History")

  -- Mode buttons
  self.modes = {}
  for i, modeTitle in ipairs({"Event","Hour","Day"}) do
    local m = modeTitle:lower()
    local btn = CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    btn:SetSize(60,20)
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", 20 + (i-1)*70, -30)
    btn:SetText(modeTitle)
    btn:SetScript("OnClick", function()
      AvgXPDB.historyMode = m
      H:Update()
    end)
    self.modes[m] = btn
  end

  -- ScrollFrame
  local scroll = CreateFrame("ScrollFrame","XPChronicleHistoryScrollFrame",f,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -60)
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
  -- clear old lines
  for _, child in ipairs({content:GetChildren()}) do
    child:Hide()
    child:SetParent(nil)
  end

  -- highlight active button
  local mode = AvgXPDB.historyMode or "hour"
  for m,btn in pairs(self.modes) do
    if m == mode then btn:Disable() else btn:Enable() end
  end

  local y = 0

  if mode == "event" then
    -- raw events grouped by day
    local days = {}
    for _, ev in ipairs(AvgXPDB.historyEvents or {}) do
      days[ev.day] = days[ev.day] or {}
      table.insert(days[ev.day], ev)
    end
    local dayKeys = {}
    for d in pairs(days) do table.insert(dayKeys, d) end
    table.sort(dayKeys, function(a,b) return a > b end)

    for _, day in ipairs(dayKeys) do
      local hdr = content:CreateFontString(nil,"OVERLAY","GameFontNormal")
      hdr:SetPoint("TOPLEFT", 0, -y)
      hdr:SetText(day)
      y = y + hdr:GetStringHeight() + 5

      table.sort(days[day], function(a,b) return a.time < b.time end)
      for _, ev in ipairs(days[day]) do
        local line = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", 0, -y)
        line:SetText(("  [%s] +%d XP"):format(ev.time, ev.xp))
        y = y + line:GetStringHeight() + 3
      end

      y = y + 10
    end

  elseif mode == "hour" then
    -- per-hour aggregates
    local hist = AvgXPDB.history or {}
    local dayKeys = {}
    for d in pairs(hist) do table.insert(dayKeys, d) end
    table.sort(dayKeys, function(a,b) return a > b end)

    for _, day in ipairs(dayKeys) do
      local hdr = content:CreateFontString(nil,"OVERLAY","GameFontNormal")
      hdr:SetPoint("TOPLEFT", 0, -y)
      hdr:SetText(day)
      y = y + hdr:GetStringHeight() + 5

      local hours = {}
      for hr in pairs(hist[day]) do table.insert(hours, hr) end
      table.sort(hours)

      for _, hr in ipairs(hours) do
        local xp = hist[day][hr]
        local line = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", 0, -y)
        line:SetText(("  [%s] +%d XP"):format(hr, xp))
        y = y + line:GetStringHeight() + 3
      end

      y = y + 10
    end

  elseif mode == "day" then
    -- daily totals
    local hist = AvgXPDB.history or {}
    local dayKeys = {}
    for d in pairs(hist) do table.insert(dayKeys, d) end
    table.sort(dayKeys, function(a,b) return a > b end)

    for _, day in ipairs(dayKeys) do
      local total = 0
      for _, xp in pairs(hist[day]) do total = total + xp end

      local line = content:CreateFontString(nil,"OVERLAY","GameFontNormal")
      line:SetPoint("TOPLEFT", 0, -y)
      line:SetText(("%s: +%d XP"):format(day, total))
      y = y + line:GetStringHeight() + 5
    end
  end

  content:SetHeight(y)
end
