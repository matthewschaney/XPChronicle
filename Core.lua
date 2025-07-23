-- XPChronicle ▸ Core.lua

local ADDON_NAME = ...
XPChronicle = XPChronicle or {}

local TAG = '|cff33ff99XPChronicle|r: '

-- Timelock popup.
local function CreateTimelockPopup()
    StaticPopupDialogs["XPCHRONICLE_SET_TIMELOCK"] = {
        text         = "Enter minutes past the hour to lock bars to (0-59):",
        button1      = ACCEPT,
        button2      = CANCEL,
        hasEditBox   = true,
        maxLetters   = 2,
        timeout      = 0,
        whileDead    = true,
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

-- Private helpers.
local DB, UI, Graph, MB
local REFRESH_PERIOD  = 0.25
local refreshAccumulator = 0

-- Event frame.
local f = CreateFrame("Frame")

local EventHandlers = {}

function EventHandlers:PLAYER_LOGIN()
    DB, UI, Graph, MB =
      XPChronicle.DB,
      XPChronicle.UI,
      XPChronicle.Graph,
      XPChronicle.MinimapButton

    DB:Init()
    DB:MigrateOldEvents()
    DB:RebuildBuckets()

    UI:CreateMainPanel()
    Graph:BuildBars()
    DB:StartSession()
    UI:Refresh()

    MB:Create()
    MB:HookMinimapUpdate()

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

-- Generic dispatcher.
f:SetScript("OnEvent", function(_, evt, ...)
    local handler = EventHandlers[evt]
    if handler then handler(EventHandlers, ...) end
end)

-- Register only the events we actually handle.
for evt in pairs(EventHandlers) do
    f:RegisterEvent(evt)
end

-- One‑time static popup creation.
CreateTimelockPopup()
