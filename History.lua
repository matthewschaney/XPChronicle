-- XPChronicle ▸ History.lua

XPChronicle            = XPChronicle or {}
XPChronicle.History    = {}
local H                = XPChronicle.History
local UI               = XPChronicle.UI
local DB               = XPChronicle.DB

-- Lock menu ------------------------------------------------------------------
local function InitLockMenu()
  if H.lockMenu then return end

  H.lockMenu = CreateFrame("Frame", "XPChronicleHistoryMenu",
                           UIParent, "UIDropDownMenuTemplate")

  UIDropDownMenu_Initialize(H.lockMenu, function(_, level)
    local info       = UIDropDownMenu_CreateInfo()
    info.text        = "Lock Frame"
    info.checked     = AvgXPDB.historyLocked
    info.func        = function()
      AvgXPDB.historyLocked = not AvgXPDB.historyLocked
      H.frame:SetMovable(not AvgXPDB.historyLocked)
      if AvgXPDB.historyLocked then
        H.frame:StopMovingOrSizing()
      end
    end
    UIDropDownMenu_AddButton(info, level)
  end)
end

-- Frame setup-----------------------------------------------------------------
function H:Create()
  if self.frame then return end

  -- Frame shell---------------------------------------------------------------
  local f = CreateFrame("Frame", "XPChronicleHistoryFrame",
                        UI.back, "BackdropTemplate")
  self.frame = f
  f:SetSize(300, 400)
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 32, edgeSize = 16,
    insets   = { left = 5, right = 5, top = 5, bottom = 5 },
  })

  -- Positioning --------------------------------------------------------------
  if AvgXPDB.historyPos then
    f:SetPoint(AvgXPDB.historyPos.point, UIParent,
               AvgXPDB.historyPos.relativePoint,
               AvgXPDB.historyPos.x, AvgXPDB.historyPos.y)
  else
    f:SetPoint("CENTER")
  end

  -- Drag & lock --------------------------------------------------------------
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetMovable(not AvgXPDB.historyLocked)

  f:SetScript("OnDragStart", function(self, btn)
    if btn == "LeftButton" and not AvgXPDB.historyLocked then
      self:StartMoving()
    end
  end)

  f:SetScript("OnDragStop", function(self)
    if not AvgXPDB.historyLocked then
      self:StopMovingOrSizing()
      local p, _, rp, x, y = self:GetPoint()
      AvgXPDB.historyPos = { point = p, relativePoint = rp, x = x, y = y }
    end
  end)

  -- Lock menu ----------------------------------------------------------------
  InitLockMenu()
  f:SetScript("OnMouseUp", function(_, btn)
    if btn == "RightButton" then
      ToggleDropDownMenu(1, nil, H.lockMenu, "cursor")
    end
  end)

  -- Title --------------------------------------------------------------------
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetText("XPChronicle History")

  -- Mode buttons -------------------------------------------------------------
  self.modes = {}
  for i, name in ipairs({ "Event", "Hour", "Day" }) do
    local key = name:lower()
    local b   = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(60, 20)
    b:SetPoint("TOPLEFT", 20 + (i - 1) * 70, -30)
    b:SetText(name)
    b:SetScript("OnClick", function()
      AvgXPDB.historyMode = key
      H:Update()
    end)
    self.modes[key] = b
  end

  -- Scroll area --------------------------------------------------------------
  local scroll = CreateFrame("ScrollFrame",
                  "XPChronicleHistoryScrollFrame", f,
                  "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 20, -60)
  scroll:SetPoint("BOTTOMRIGHT", -40, 20)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)
  self.content = content

  local fs = content:CreateFontString(nil, "OVERLAY",
                                      "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 0, 0)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetNonSpaceWrap(true)
  fs:SetWidth(scroll:GetWidth())
  self.textFS = fs

  f:Hide()
end

-- Public API -----------------------------------------------------------------
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

  -- Highlight active button --------------------------------------------------
  local mode = AvgXPDB.historyMode or "hour"
  for m, btn in pairs(self.modes) do
    btn:SetEnabled(m ~= mode)
  end

  -- Build text lines ---------------------------------------------------------
  local lines = {}

  if mode == "event" then
    local byDay = {}
    for _, ev in ipairs(AvgXPDB.historyEvents or {}) do
      byDay[ev.day] = byDay[ev.day] or {}
      table.insert(byDay[ev.day], ev)
    end
    local keys = {}
    for d in pairs(byDay) do table.insert(keys, d) end
    table.sort(keys, function(a, b) return a > b end)

    for _, day in ipairs(keys) do
      table.insert(lines, day)
      table.sort(byDay[day], function(a, b) return a.time < b.time end)
      for _, ev in ipairs(byDay[day]) do
        table.insert(lines, ("  [%s] +%d XP"):format(ev.time, ev.xp))
      end
      table.insert(lines, "")
    end

  elseif mode == "hour" then
    local hist = AvgXPDB.history or {}
    local days = {}
    for d in pairs(hist) do table.insert(days, d) end
    table.sort(days, function(a, b) return a > b end)

    for _, day in ipairs(days) do
      table.insert(lines, day)
      local hrs = {}
      for hr in pairs(hist[day]) do table.insert(hrs, hr) end
      table.sort(hrs)
      for _, hr in ipairs(hrs) do
        table.insert(lines, ("  [%s] +%d XP"):format(hr, hist[day][hr]))
      end
      table.insert(lines, "")
    end

  else -- "day"
    local totals = {}
    for _, ev in ipairs(AvgXPDB.historyEvents or {}) do
      totals[ev.day] = (totals[ev.day] or 0) + ev.xp
    end
    local days = {}
    for d in pairs(totals) do table.insert(days, d) end
    table.sort(days, function(a, b) return a > b end)
    for _, day in ipairs(days) do
      table.insert(lines, ("%s: +%d XP"):format(day, totals[day]))
    end
  end

  -- Push to fontstring -------------------------------------------------------
  self.textFS:SetText(table.concat(lines, "\n"))
  self.content:SetHeight(#lines * 14) -- Rough line height.
end
