-- XPChronicle ▸ Core.lua
local ADDON_NAME = ...
XPChronicle = XPChronicle or {}
local TAG = '|cff33ff99XPChronicle|r: '

-- Timelock popup -------------------------------------------------------------
local function CreateTimelockPopup()
    StaticPopupDialogs["XPCHRONICLE_SET_TIMELOCK"] = {
        text = "Enter minutes past the hour to lock bars to (0-59):",
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 2,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(self)
            local secs = AvgXPDB.gridOffset or time() % 3600
            local mins = math.floor(secs / 60)
            self.editBox:SetText(mins)
        end,
        OnAccept = function(self)
            local v = tonumber(self.editBox:GetText())
            if v and v >= 0 and v < 60 then
                AvgXPDB.gridOffset = v * 60
                XPChronicle.DB:RebuildBuckets()
                XPChronicle.UI:Refresh()
                print(('%sgrid locked @ %dm'):format(TAG, v))
            else
                print(TAG .. 'please enter a value between 0-59.')
            end
        end,
    }
end

-- Private helpers ------------------------------------------------------------
local DB, UI, Graph, MB, Report, ReportTracker
local REFRESH_PERIOD = 0.25
local refreshAccumulator = 0

-- Event frame
local f = CreateFrame("Frame")
local EventHandlers = {}

-- Track last kill to pair with XP gain --------------------------------------
local lastKill = { name=nil, level=nil, t=0 }
local function rememberKill(name, level)
  lastKill.name, lastKill.level, lastKill.t = name, level, GetTime()
end
local function consumeRecentKill()
  if lastKill.name and (GetTime() - lastKill.t) <= 3.0 then
    local n, l = lastKill.name, lastKill.level
    lastKill.name, lastKill.level, lastKill.t = nil, nil, 0
    return n, l
  end
end

-- Hook for Character panel
local function HookCharacterFrame()
    if not CharacterFrame then return end
    CharacterFrame:HookScript("OnShow", function()
        if AvgXPDB.autoOpenReport and Report then
            if not Report.frame then Report:Create() end
            Report.frame:Show()
            Report:ShowReportTab()
        end
    end)
    CharacterFrame:HookScript("OnHide", function()
        if AvgXPDB.autoOpenReport and Report and Report.frame then
            Report.frame:Hide()
        end
    end)
end

function EventHandlers:ADDON_LOADED(name)
    if name == "Blizzard_CharacterUI" then
        HookCharacterFrame()
    end
end

-- Detailed XP capture --------------------------------------------------------
function EventHandlers:COMBAT_LOG_EVENT_UNFILTERED()
    local _, subevent, _, srcGUID, _, _, _, _, destName = CombatLogGetCurrentEventInfo()
    if subevent ~= "PARTY_KILL" then return end
    if not destName then return end
    if srcGUID ~= UnitGUID("player") and srcGUID ~= UnitGUID("pet") then return end
    local tName = UnitName("target")
    local level = (tName and destName and tName == destName) and UnitLevel("target") or nil
    rememberKill(destName, level)
end

-- Parse combat XP like: "You gain 120 experience." [(Mob dies) optional]
function EventHandlers:CHAT_MSG_COMBAT_XP_GAIN(msg)
    if not DB or not msg then return end
    local xp = tonumber(string.match(msg, "(%d+)%s+experience"))
    if not xp or xp <= 0 then return end

    local desc, mobName, mobLevel
    local paren = string.match(msg, "%((.-)%)")
    if paren then
        local mob = string.match(paren, "^(.-)%s+dies$")
        if mob and mob ~= "" then mobName = mob end
    end
    if not mobName then
        local n, l = consumeRecentKill()
        mobName, mobLevel = n, l
    end
    if mobName then desc = "Killed "..mobName end

    DB:LogEvent(xp, desc, "kill", {
      mobName = mobName,
      mobLevel = mobLevel,
      playerLevel = UnitLevel("player"),
    })
    DB:SuppressNextGenericEvent(1.5)
end

-- Quest turn-in: exact XP, robust title fetch + longer suppression
function EventHandlers:QUEST_TURNED_IN(questID, xpReward)
    if not DB then return end
    if (xpReward or 0) <= 0 then return end

    local title
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        title = C_QuestLog.GetTitleForQuestID(questID)
    end
    if not title and C_QuestLog and C_QuestLog.GetQuestInfo then
        title = C_QuestLog.GetQuestInfo(questID)
    end
    if not title and GetQuestLink then
        local link = GetQuestLink(questID)
        if link then title = link:match("%[(.-)%]") end
    end

    DB:LogEvent(xpReward, title or "Quest", "quest", {
      playerLevel = UnitLevel("player"),
      questID = questID,
    })
    DB:SuppressNextGenericEvent(2.5)
end

-- Discovery: "Discovered <Place>: <xp> experience gained"
function EventHandlers:CHAT_MSG_SYSTEM(msg)
    if not DB or not msg then return end
    local place, xp = string.match(msg, "^Discovered%s+(.+):%s+(%d+)%s+experience%s+gained%.?$")
    if place and xp then
        DB:LogEvent(tonumber(xp), place, "discover")
        DB:SuppressNextGenericEvent(1.5)
    end
end

function EventHandlers:PLAYER_LOGIN()
    DB = XPChronicle.DB
    UI = XPChronicle.UI
    Graph = XPChronicle.Graph
    MB = XPChronicle.MinimapButton
    Report = XPChronicle.Report
    ReportTracker = XPChronicle.ReportTracker
    
    DB:Init()
    DB:MigrateOldEvents()
    DB:RebuildBuckets()
    
    UI:CreateMainPanel()
    Graph:BuildBars()
    if XPChronicle.Options then XPChronicle.Options:Create() end
    if Report then Report:Create() end
    if ReportTracker then ReportTracker:Init() end
    
    if AvgXPDB.mainHidden then
        UI.back:Hide()
        Graph.frame:SetParent(UIParent)
    end
    
    DB:StartSession()
    UI:Refresh()
    
    MB:Create()
    MB:HookMinimapUpdate()
    
    if CharacterFrame then HookCharacterFrame() end
    
    f:SetScript("OnUpdate", function(_, dt)
        DB:OnUpdate(dt)
        refreshAccumulator = refreshAccumulator + dt
        if refreshAccumulator >= REFRESH_PERIOD then
            UI:Refresh()
            refreshAccumulator = 0
        end
    end)
end

function EventHandlers:PLAYER_XP_UPDATE()
    if not DB then return end
    DB:OnXPUpdate()
    UI:Refresh()
end

function EventHandlers:PLAYER_LOGOUT()
    if DB then DB:OnLogout() end
end

-- Generic dispatcher
f:SetScript("OnEvent", function(_, evt, ...)
    local handler = EventHandlers[evt]
    if handler then handler(EventHandlers, ...) end
end)

-- Register only the events we actually handle
for evt in pairs(EventHandlers) do f:RegisterEvent(evt) end
f:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("CHAT_MSG_SYSTEM")

-- One-time static popup creation
CreateTimelockPopup()
