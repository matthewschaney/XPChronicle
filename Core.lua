-- XPChronicle ▸ Core.lua
local ADDON_NAME = ...
XPChronicle = XPChronicle or {}
local TAG = '|cff33ff99XPChronicle|r: '

-- Timelock popup -------------------------------------------------------------
local function CreateTimelockPopup()
    StaticPopupDialogs["XPCHRONICLE_SET_TIMELOCK"] = {
        text = "Enter minutes past the hour to lock bars to (0‑59):",
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
                print(TAG .. 'please enter a value between 0‑59.')
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

function EventHandlers:PLAYER_LOGIN()
    -- Get references to modules
    DB = XPChronicle.DB
    UI = XPChronicle.UI
    Graph = XPChronicle.Graph
    MB = XPChronicle.MinimapButton
    Report = XPChronicle.Report
    ReportTracker = XPChronicle.ReportTracker
    
    -- Initialize database first
    DB:Init()
    DB:MigrateOldEvents()
    DB:RebuildBuckets()
    
    -- Create UI components
    UI:CreateMainPanel()
    Graph:BuildBars()
    
    -- Create options if available
    if XPChronicle.Options then
        XPChronicle.Options:Create()
    end
    
    -- Create Report
    if Report then
        Report:Create()
    end
    
    -- Initialize ReportTracker
    if ReportTracker then
        ReportTracker:Init()
    end
    
    -- Honor "Hide XP frame" preference
    if AvgXPDB.mainHidden then
        UI.back:Hide()
        Graph.frame:SetParent(UIParent)
    end
    
    -- Start session tracking
    DB:StartSession()
    UI:Refresh()
    
    -- Create minimap button
    MB:Create()
    MB:HookMinimapUpdate()
    
    -- Hook character frame if already loaded
    if CharacterFrame then
        HookCharacterFrame()
    end
    
    -- Set up update handler
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
for evt in pairs(EventHandlers) do
    f:RegisterEvent(evt)
end

-- One‑time static popup creation
CreateTimelockPopup()