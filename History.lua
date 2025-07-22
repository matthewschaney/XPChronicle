-- History.lua
-- Scrollable “tome” window with Event/Hour/Day toggle

XPChronicle = XPChronicle or {}
XPChronicle.History = {}
local H  = XPChronicle.History
local UI = XPChronicle.UI

function H:Create()
  if self.frame then return end

  -----------------------------------------------------------------------------
  -- Frame & backdrop
  -----------------------------------------------------------------------------
  local f = CreateFrame("Frame","XPChronicleHistoryFrame",UI.back,"BackdropTemplate")
  f:SetSize(300,400)
  f:SetPoint("CENTER")
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 32, edgeSize = 16,
    insets   = { left=5, right=5, top=5, bottom=5 },
  })
  f:EnableMouse(true); f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop",  f.StopMovingOrSizing)

  -- Title
  local title = f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
  title:SetPoint("TOP",0,-10)
  title:SetText("XP Chronicle History")

  -----------------------------------------------------------------------------
  -- Mode buttons
  -----------------------------------------------------------------------------
  self.modes = {}
  for i,modeTitle in ipairs({"Event","Hour","Day"}) do
    local m   = modeTitle:lower()
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

  -----------------------------------------------------------------------------
  -- ScrollFrame + single multiline FontString
  -----------------------------------------------------------------------------
  local scroll = CreateFrame("ScrollFrame","XPChronicleHistoryScrollFrame",f,"UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",     f, "TOPLEFT",     20, -60)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 20)

  local content = CreateFrame("Frame","XPChronicleHistoryContent",scroll)
  content:SetSize(1,1)
  scroll:SetScrollChild(content)
  self.content = content

  local fs = content:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 0, 0)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetNonSpaceWrap(true)
  fs:SetWidth(scroll:GetWidth())
  self.textFS = fs

  f:Hide()
  self.frame = f
end

function H:Toggle()
  if not self.frame then self:Create() end
  if self.frame:IsShown() then
    self.frame:Hide()
  else
    H:Update()
    self.frame:Show()
  end
end

function H:Update()
  -- Ensure frame exists
  if not self.frame then return end

  -- Highlight active button
  local mode = AvgXPDB.historyMode or "hour"
  for m,btn in pairs(self.modes) do
    btn:SetEnabled(m ~= mode)
  end

  -----------------------------------------------------------------------------
  -- Build lines
  -----------------------------------------------------------------------------
  local lines = {}

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
      table.insert(lines, day)
      table.sort(days[day], function(a,b) return a.time < b.time end)
      for _, ev in ipairs(days[day]) do
        table.insert(lines, ("  [%s] +%d XP"):format(ev.time, ev.xp))
      end
      table.insert(lines, "")  -- blank line
    end

  elseif mode == "hour" then
    -- per-hour aggregates
    local hist = AvgXPDB.history or {}
    local dayKeys = {}
    for d in pairs(hist) do table.insert(dayKeys, d) end
    table.sort(dayKeys, function(a,b) return a > b end)

    for _, day in ipairs(dayKeys) do
      table.insert(lines, day)
      local hours = {}
      for hr in pairs(hist[day]) do table.insert(hours, hr) end
      table.sort(hours)
      for _, hr in ipairs(hours) do
        table.insert(lines, ("  [%s] +%d XP"):format(hr, hist[day][hr]))
      end
      table.insert(lines, "")
    end

  elseif mode == "day" then
    -- daily totals (sum of raw events)
    local totals = {}
    for _, ev in ipairs(AvgXPDB.historyEvents or {}) do
      totals[ev.day] = (totals[ev.day] or 0) + ev.xp
    end
    local dayKeys = {}
    for d in pairs(totals) do table.insert(dayKeys, d) end
    table.sort(dayKeys, function(a,b) return a > b end)

    for _, day in ipairs(dayKeys) do
      table.insert(lines, ("%s: +%d XP"):format(day, totals[day]))
    end
  end

  -----------------------------------------------------------------------------
  -- Set text & adjust height
  -----------------------------------------------------------------------------
  local text = table.concat(lines, "\n")
  self.textFS:SetText(text)

  -- Estimate height: 14px per line
  local height = #lines * 14
  self.content:SetHeight(height)
end
