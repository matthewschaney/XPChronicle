-- History.lua
-- Scrollable “tome” window with Event/Hour/Day toggle,
-- position persistence, and right-click lock/unlock.

XPChronicle = XPChronicle or {}
XPChronicle.History = {}
local H  = XPChronicle.History
local UI = XPChronicle.UI

-- One‑time setup of the right-click lock menu
local function InitializeHistoryMenu()
  if H.lockMenu then return end
  H.lockMenu = CreateFrame("Frame", "XPChronicleHistoryMenu", UIParent, "UIDropDownMenuTemplate")
  UIDropDownMenu_Initialize(H.lockMenu, function(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text    = "Lock Frame"
    info.checked = AvgXPDB.historyLocked
    info.func   = function()
      AvgXPDB.historyLocked = not AvgXPDB.historyLocked
      H.frame:SetMovable(not AvgXPDB.historyLocked)
      if AvgXPDB.historyLocked then H.frame:StopMovingOrSizing() end
    end
    UIDropDownMenu_AddButton(info, level)
  end)
end

function H:Create()
  if self.frame then return end

  -- Frame & backdrop
  local f = CreateFrame("Frame", "XPChronicleHistoryFrame", UI.back, "BackdropTemplate")
  f:SetSize(300, 400)
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 32, edgeSize = 16,
    insets   = { left=5, right=5, top=5, bottom=5 },
  })

  -- Restore saved position or center
  if AvgXPDB.historyPos then
    f:SetPoint(
      AvgXPDB.historyPos.point, UIParent,
      AvgXPDB.historyPos.relativePoint,
      AvgXPDB.historyPos.x, AvgXPDB.historyPos.y
    )
  else
    f:SetPoint("CENTER")
  end

  -- Mouse, drag & lock
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetMovable(not AvgXPDB.historyLocked)
  f:SetScript("OnDragStart", function(self, button)
    if button=="LeftButton" and not AvgXPDB.historyLocked then
      self:StartMoving()
    end
  end)
  f:SetScript("OnDragStop", function(self)
    if not AvgXPDB.historyLocked then
      self:StopMovingOrSizing()
      local p, _, rp, x, y = self:GetPoint()
      AvgXPDB.historyPos = { point=p, relativePoint=rp, x=x, y=y }
    end
  end)

  -- Right-click menu to lock/unlock
  InitializeHistoryMenu()
  f:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
      ToggleDropDownMenu(1, nil, H.lockMenu, "cursor")
    end
  end)

  -- Title
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetText("XP Chronicle History")

  -- Mode buttons
  self.modes = {}
  for i,modeTitle in ipairs({ "Event", "Hour", "Day" }) do
    local m = modeTitle:lower()
    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(60, 20)
    btn:SetPoint("TOPLEFT", f, "TOPLEFT", 20 + (i-1)*70, -30)
    btn:SetText(modeTitle)
    btn:SetScript("OnClick", function()
      AvgXPDB.historyMode = m
      H:Update()
    end)
    self.modes[m] = btn
  end

  -- ScrollFrame + content fontstring
  local scroll = CreateFrame("ScrollFrame", "XPChronicleHistoryScrollFrame", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT",     f, "TOPLEFT",     20, -60)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 20)

  local content = CreateFrame("Frame", "XPChronicleHistoryContent", scroll)
  content:SetSize(1,1)
  scroll:SetScrollChild(content)
  self.content = content

  local fs = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
    self:Update()
    self.frame:Show()
  end
end

function H:Update()
  if not self.frame then return end

  -- Highlight the active mode button
  local mode = AvgXPDB.historyMode or "hour"
  for m,btn in pairs(self.modes) do
    btn:SetEnabled(m ~= mode)
  end

  -- Build the lines of text
  local lines = {}
  if mode == "event" then
    local days = {}
    for _,ev in ipairs(AvgXPDB.historyEvents or {}) do
      days[ev.day] = days[ev.day] or {}
      table.insert(days[ev.day], ev)
    end
    local dayKeys = {}
    for d in pairs(days) do table.insert(dayKeys, d) end
    table.sort(dayKeys, function(a,b) return a > b end)
    for _,day in ipairs(dayKeys) do
      table.insert(lines, day)
      table.sort(days[day], function(a,b) return a.time < b.time end)
      for _,ev in ipairs(days[day]) do
        table.insert(lines, ("  [%s] +%d XP"):format(ev.time, ev.xp))
      end
      table.insert(lines, "")
    end

  elseif mode == "hour" then
    local hist = AvgXPDB.history or {}
    local dayKeys = {}
    for d in pairs(hist) do table.insert(dayKeys, d) end
    table.sort(dayKeys, function(a,b) return a > b end)
    for _,day in ipairs(dayKeys) do
      table.insert(lines, day)
      local hours = {}
      for hr in pairs(hist[day]) do table.insert(hours, hr) end
      table.sort(hours)
      for _,hr in ipairs(hours) do
        table.insert(lines, ("  [%s] +%d XP"):format(hr, hist[day][hr]))
      end
      table.insert(lines, "")
    end

  elseif mode == "day" then
    local totals = {}
    for _,ev in ipairs(AvgXPDB.historyEvents or {}) do
      totals[ev.day] = (totals[ev.day] or 0) + ev.xp
    end
    local dayKeys = {}
    for d in pairs(totals) do table.insert(dayKeys, d) end
    table.sort(dayKeys, function(a,b) return a > b end)
    for _,day in ipairs(dayKeys) do
      table.insert(lines, ("%s: +%d XP"):format(day, totals[day]))
    end
  end

  -- Update the fontstring and scroll height
  local text = table.concat(lines, "\n")
  self.textFS:SetText(text)
  local height = #lines * 14  -- approx 14px per line
  self.content:SetHeight(height)
end
