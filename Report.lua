-- XPChronicle ▸ Report.lua

XPChronicle = XPChronicle or {}
XPChronicle.Report = XPChronicle.Report or {}
local Report = XPChronicle.Report

-- Visual size for the dropdown menu relative to the dropdown control
-- 0.5 = half the size of your Report frame/dropdown.
local MENU_RELATIVE_SCALE = 0.5

-- Helper functions
local function secondsToClock(s)
    local h = math.floor((s or 0)/3600)
    s = (s or 0) % 3600
    local m = math.floor(s/60)
    local sec = math.floor(s % 60)
    return string.format("%02d:%02d:%02d", h, m, sec)
end

local function pct(part, whole)
    if (whole or 0) <= 0 then return 0 end
    return (part / whole) * 100
end

-- Create main frame
function Report:Create()
    if self.frame then return end

    -- Initialize report data if needed
    AvgXPDB = AvgXPDB or {}
    AvgXPDB.report = AvgXPDB.report or {
        levels = {},
        overall = {
            seconds = 0,
            zones = {},
            xp = {quest=0, kill=0, other=0},
            time = {solo=0, group=0},
            deaths = 0,
        },
        meta = {}
    }

    -- Main frame using Blizzard template
    local f = CreateFrame("Frame", "XPChronicleReportFrame", UIParent, "BasicFrameTemplateWithInset")
    self.frame = f
    f:SetSize(300, 420)
    f:SetPoint("CENTER")
    f:Hide()

    -- NOT movable - this is the key difference
    f:SetMovable(false)
    f:EnableMouse(true)

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", 0, -8)
    f.title:SetText("XPChronicle Leveling Report")

    -- Create tab buttons
    local reportTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    reportTab:SetSize(80, 22)
    reportTab:SetPoint("TOPLEFT", 15, -40)
    reportTab:SetText("Report")
    reportTab:SetScript("OnClick", function() self:ShowReportTab() end)
    self.reportTab = reportTab

    local eventsTab = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    eventsTab:SetSize(80, 22)
    eventsTab:SetPoint("LEFT", reportTab, "RIGHT", 5, 0)
    eventsTab:SetText("Events")
    eventsTab:SetScript("OnClick", function() self:ShowEventsTab() end)
    self.eventsTab = eventsTab

    -- Dropdown for report - matching LevelReport positioning but moved down for buttons
    local dd = CreateFrame("Frame", "XPChronicleReportDD", f, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", 10, -70)
    self.dd = dd
    self.currentSelection = "overall"

    -- Anchor menu directly under the control; keep strata high
    UIDropDownMenu_SetAnchor(dd, 0, 0, "TOPLEFT", dd, "BOTTOMLEFT")
    dd:SetFrameStrata("DIALOG")

    -- Scroll frame for report - matching LevelReport positioning but moved down
    local reportScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    reportScroll:SetPoint("TOPLEFT", 22, -110)
    reportScroll:SetPoint("BOTTOMRIGHT", -30, 14)
    self.reportScroll = reportScroll

    local reportScrollContent = CreateFrame("Frame", nil, reportScroll)
    reportScrollContent:SetSize(1, 1)
    reportScroll:SetScrollChild(reportScrollContent)

    local reportText = reportScrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reportText:SetPoint("TOPLEFT")
    reportText:SetWidth(250)
    reportText:SetJustifyH("LEFT")
    self.reportText = reportText

    -- Events content
    local eventsContent = CreateFrame("Frame", nil, f)
    eventsContent:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -70)
    eventsContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    eventsContent:Hide()
    self.eventsContent = eventsContent

    -- Mode buttons for events
    local eventModes = {}
    local modeNames = { "Event", "Hour", "Day" }
    for i, name in ipairs(modeNames) do
        local key = name:lower()
        local b = CreateFrame("Button", nil, eventsContent, "UIPanelButtonTemplate")
        b:SetSize(70, 22)
        b:SetPoint("TOPLEFT", 10 + (i - 1) * 75, 0)
        b:SetText(name)
        b:SetScript("OnClick", function()
            AvgXPDB.historyMode = key
            self:UpdateEvents()
        end)
        eventModes[key] = b
    end
    self.eventModes = eventModes

    -- Scroll frame for events
    local eventsScroll = CreateFrame("ScrollFrame", nil, eventsContent, "UIPanelScrollFrameTemplate")
    eventsScroll:SetPoint("TOPLEFT", 12, -30)
    eventsScroll:SetPoint("BOTTOMRIGHT", -20, 4)

    local eventsScrollContent = CreateFrame("Frame", nil, eventsScroll)
    eventsScrollContent:SetSize(1, 1)
    eventsScroll:SetScrollChild(eventsScrollContent)

    local eventsText = eventsScrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    eventsText:SetPoint("TOPLEFT", 0, 0)
    eventsText:SetJustifyH("LEFT")
    eventsText:SetJustifyV("TOP")
    eventsText:SetNonSpaceWrap(true)
    eventsText:SetWidth(250)
    self.eventsText = eventsText
    self.eventsScrollContent = eventsScrollContent

    -- Initialize dropdown
    self:InitializeDropDown()

    -- Default to report tab
    self:ShowReportTab()

    -- Hook to Character frame if needed
    self:AttachToCharacterFrame()

    -- ----- Keep the popup menu aligned & scaled -----
    local function FixDropDownListPosition(list)
        if not list or not list.dropdown then return end
        if list.dropdown ~= self.dd then return end

        -- Scale the menu to a fraction of the dropdown’s effective scale
        local ddScale = self.dd:GetEffectiveScale() or 1
        local targetScale = ddScale * (MENU_RELATIVE_SCALE or 1)
        if list:GetScale() ~= targetScale then
            list:SetScale(targetScale)
        end

        -- Place the menu exactly under the dropdown using absolute screen coords
        local x, y = self.dd:GetLeft(), self.dd:GetBottom()
        if x and y then
            list:ClearAllPoints()
            list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        else
            -- Fallback: relative anchor (still OK if coords unavailable)
            list:ClearAllPoints()
            list:SetPoint("TOPLEFT", self.dd, "BOTTOMLEFT", 0, 0)
        end
        list:SetFrameStrata("TOOLTIP")
    end

    hooksecurefunc("ToggleDropDownMenu", function(level)
        if level == 1 and DropDownList1 and DropDownList1.dropdown == self.dd then
            FixDropDownListPosition(DropDownList1)
        end
    end)

    if DropDownList1 then
        DropDownList1:HookScript("OnShow", function(s) FixDropDownListPosition(s) end)
    end
    if DropDownList2 then
        DropDownList2:HookScript("OnShow", function(s) FixDropDownListPosition(s) end)
    end
end

function Report:AttachToCharacterFrame()
    local function DoAttach()
        if not CharacterFrame then return end

        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", -30, -15)
        self.frame:SetParent(CharacterFrame)
        self.frame:SetFrameLevel(CharacterFrame:GetFrameLevel() + 2)

        if self.dd then
            self.dd:SetFrameLevel(self.frame:GetFrameLevel() + 1)
            UIDropDownMenu_SetAnchor(self.dd, 0, 0, "TOPLEFT", self.dd, "BOTTOMLEFT")
        end

        CharacterFrame:HookScript("OnShow", function()
            if AvgXPDB.autoOpenReport then
                self.frame:Show()
                self:ShowReportTab()
                self:Refresh()
            end
        end)

        CharacterFrame:HookScript("OnHide", function()
            self.frame:Hide()
        end)

        if CharacterFrame:IsShown() and AvgXPDB.autoOpenReport then
            self.frame:Show()
            self:ShowReportTab()
            self:Refresh()
        end
    end

    if CharacterFrame then
        DoAttach()
    else
        local wait = CreateFrame("Frame")
        wait:RegisterEvent("ADDON_LOADED")
        wait:SetScript("OnEvent", function(self, event, addon)
            if addon == "Blizzard_CharacterUI" then
                DoAttach()
                wait:UnregisterEvent("ADDON_LOADED")
            end
        end)
    end
end

function Report:InitializeDropDown()
    local function buildChoices()
        local choices = {}
        table.insert(choices, { text = "Overall", value = "overall" })
        if AvgXPDB.report and AvgXPDB.report.levels then
            for lvl, _ in pairs(AvgXPDB.report.levels) do
                table.insert(choices, { text = "Level " .. lvl, value = lvl })
            end
        end
        table.sort(choices, function(a, b)
            if a.value == "overall" then return true end
            if b.value == "overall" then return false end
            return (tonumber(a.value) or 0) < (tonumber(b.value) or 0)
        end)
        return choices
    end

    local function InitDD(_, level)
        local function OnClick(button)
            Report.currentSelection = button.value
            UIDropDownMenu_SetSelectedValue(Report.dd, button.value)
            Report:RenderReport(button.value)
        end

        if level and level > 1 then return end

        local info
        local choices = buildChoices()
        for _, c in ipairs(choices) do
            info = UIDropDownMenu_CreateInfo()
            info.text = c.text
            info.value = c.value
            info.func = OnClick
            info.checked = (Report.currentSelection == c.value)
            UIDropDownMenu_AddButton(info, level or 1)
        end
    end

    self._InitDD = InitDD

    UIDropDownMenu_SetWidth(self.dd, 170)
    UIDropDownMenu_Initialize(self.dd, self._InitDD)
    UIDropDownMenu_SetSelectedValue(self.dd, self.currentSelection)
    UIDropDownMenu_SetText(self.dd, "Overall")

    UIDropDownMenu_SetAnchor(self.dd, 0, 0, "TOPLEFT", self.dd, "BOTTOMLEFT")
end

function Report:ShowReportTab()
    self.eventsContent:Hide()
    self.dd:Show()
    self.reportScroll:Show()
    self.reportTab:Disable()
    self.eventsTab:Enable()
    self:RenderReport(self.currentSelection)
end

function Report:ShowEventsTab()
    self.dd:Hide()
    self.reportScroll:Hide()
    self.eventsContent:Show()
    self.eventsTab:Disable()
    self.reportTab:Enable()
    self:UpdateEvents()
end

function Report:RenderReport(key)
    if not AvgXPDB.report then
        self.reportText:SetText("|cffff8080No data available yet.|r\n\nStart playing to track your leveling!")
        return
    end

    local L, isOverall
    if key == "overall" then
        L = AvgXPDB.report.overall
        isOverall = true
    else
        L = (AvgXPDB.report.levels or {})[tonumber(key or 0)]
    end

    if not L then
        self.reportText:SetText("|cffff8080No data for this level.|r")
        return
    end

    local zones = {}
    for zn, s in pairs(L.zones or {}) do
        if zn and zn ~= "" and zn ~= "Unknown" then
            table.insert(zones, { zn = zn, s = s })
        end
    end
    table.sort(zones, function(a, b) return a.s > b.s end)

    local zoneTotal = 0
    for _, z in ipairs(zones) do
        zoneTotal = zoneTotal + (z.s or 0)
    end

    local lines = {}

    if isOverall then
        table.insert(lines, "|cffffff00Overall Statistics|r")
    else
        table.insert(lines, ("|cffffff00Level %d|r"):format(key))
        if L.startedAt then
            table.insert(lines, ("Started: |cffaaaaaa%s|r"):format(date("%b %d, %Y %H:%M", L.startedAt)))
        end
        if L.endedAt then
            table.insert(lines, ("Completed: |cffaaaaaa%s|r"):format(date("%b %d, %Y %H:%M", L.endedAt)))
        end
    end

    table.insert(lines, ("Time spent: |cffffffff%s|r"):format(secondsToClock(math.floor(L.seconds or 0))))

    table.insert(lines, "\n|cffffff00Zones & Dungeons|r")
    if #zones == 0 or zoneTotal <= 0 then
        table.insert(lines, "• |cff888888(no zone time recorded)|r")
    else
        for i = 1, math.min(6, #zones) do
            local z = zones[i]
            table.insert(lines, ("• %s - |cff00ff00%.1f%%|r"):format(z.zn, pct(z.s, zoneTotal)))
        end
        if #zones > 6 then
            table.insert(lines, ("• |cff888888... and %d more zones|r"):format(#zones - 6))
        end
    end

    local q = (L.xp and L.xp.quest) or 0
    local k = (L.xp and L.xp.kill) or 0
    local o = (L.xp and L.xp.other) or 0
    local totalXP = q + k + o

    table.insert(lines, "\n|cffffff00Experience Sources|r")
    if totalXP > 0 then
        table.insert(lines, ("• Quests: |cff00ff00%.1f%%|r |cffaaaaaa(%s)|r"):format(pct(q, totalXP), BreakUpLargeNumbers(q)))
        table.insert(lines, ("• Killing: |cff00ff00%.1f%%|r |cffaaaaaa(%s)|r"):format(pct(k, totalXP), BreakUpLargeNumbers(k)))
        if o > 0 then
            table.insert(lines, ("• Other: |cff00ff00%.1f%%|r |cffaaaaaa(%s)|r"):format(pct(o, totalXP), BreakUpLargeNumbers(o)))
        end
    else
        table.insert(lines, "• |cff888888(no experience tracked yet)|r")
    end

    local solo = (L.time and L.time.solo) or 0
    local group = (L.time and L.time.group) or 0
    local totT = solo + group

    table.insert(lines, "\n|cffffff00Play Style|r")
    if totT > 0 then
        table.insert(lines, ("• Solo: |cff00ff00%.1f%%|r"):format(pct(solo, totT)))
        table.insert(lines, ("• Group: |cff00ff00%.1f%%|r"):format(pct(group, totT)))
    else
        table.insert(lines, "• |cff888888(no time tracked yet)|r")
    end

    table.insert(lines, "\n|cffffff00Other Stats|r")
    table.insert(lines, ("• Deaths: |cffff0000%d|r"):format(L.deaths or 0))

    self.reportText:SetText(table.concat(lines, "\n"))
end

function Report:UpdateEvents()
    local mode = AvgXPDB.historyMode or "hour"

    -- Highlight active button
    for m, btn in pairs(self.eventModes) do
        btn:SetEnabled(m ~= mode)
    end

    -- Build text lines
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
        local hist, days = AvgXPDB.history or {}, {}
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
    else -- day
        local totals, days = {}, {}
        for _, ev in ipairs(AvgXPDB.historyEvents or {}) do
            totals[ev.day] = (totals[ev.day] or 0) + ev.xp
        end
        for d in pairs(totals) do table.insert(days, d) end
        table.sort(days, function(a, b) return a > b end)
        for _, day in ipairs(days) do
            table.insert(lines, ("%s: +%d XP"):format(day, totals[day]))
        end
    end

    self.eventsText:SetText(table.concat(lines, "\n"))
    self.eventsScrollContent:SetHeight(#lines * 14)
end

function Report:Toggle()
    if not self.frame then self:Create() end

    if self.frame:IsShown() then
        self.frame:Hide()
        if CharacterFrame and CharacterFrame:IsShown() and not AvgXPDB.autoOpenReport then
            ToggleCharacter("PaperDollFrame")
        end
    else
        if self.frame:GetParent() == CharacterFrame or not CharacterFrame then
            if not CharacterFrame or not CharacterFrame:IsShown() then
                ToggleCharacter("PaperDollFrame")
                if not AvgXPDB.autoOpenReport then
                    C_Timer.After(0, function()
                        if CharacterFrame and CharacterFrame:IsShown() then
                            self.frame:Show()
                            self:ShowReportTab()
                            self:Refresh()
                        end
                    end)
                end
            else
                self.frame:Show()
                self:ShowReportTab()
                self:Refresh()
            end
        else
            self.frame:ClearAllPoints()
            self.frame:SetPoint("CENTER")
            self.frame:SetParent(UIParent)
            self.frame:Show()
            self:ShowReportTab()
            self:Refresh()
        end
    end
end

function Report:Refresh()
    if not self.frame or not self.frame:IsShown() then return end

    if self._InitDD then
        UIDropDownMenu_Initialize(self.dd, self._InitDD)
    else
        self:InitializeDropDown()
    end

    local choices = {}
    table.insert(choices, { text = "Overall", value = "overall" })
    if AvgXPDB.report and AvgXPDB.report.levels then
        for lvl, _ in pairs(AvgXPDB.report.levels) do
            table.insert(choices, { text = "Level " .. lvl, value = lvl })
        end
    end
    table.sort(choices, function(a, b)
        if a.value == "overall" then return true end
        if b.value == "overall" then return false end
        return (tonumber(a.value) or 0) < (tonumber(b.value) or 0)
    end)

    for _, c in ipairs(choices) do
        if c.value == self.currentSelection then
            UIDropDownMenu_SetText(self.dd, c.text)
            break
        end
    end

    UIDropDownMenu_SetAnchor(self.dd, 0, 0, "TOPLEFT", self.dd, "BOTTOMLEFT")

    if self.reportScroll:IsShown() then
        self:RenderReport(self.currentSelection)
    else
        self:UpdateEvents()
    end
end
