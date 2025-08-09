-- XPChronicle ▸ ReportTracker.lua

XPChronicle = XPChronicle or {}
XPChronicle.ReportTracker = {}
local RT = XPChronicle.ReportTracker

local state = {
    level = nil,
    zone = nil,
    lastTick = GetTime(),
    grouped = false,
    prevXP = UnitXP("player"),
    prevMax = UnitXPMax("player"),
    recentQuestXP = 0,
    recentQuestAt = 0,
    recentOtherXP = 0,
    recentOtherAt = 0,
    recentKillXP = 0,
    recentKillAt = 0,
}

local function ensureReportData()
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
end

local function ensureLevel(level)
    ensureReportData()
    AvgXPDB.report.levels[level] = AvgXPDB.report.levels[level] or {
        startedAt = time(),
        endedAt = nil,
        seconds = 0,
        zones = {},
        xp = {quest=0, kill=0, other=0},
        time = {solo=0, group=0},
        deaths = 0,
    }
end

local function addSeconds(tbl, key, secs)
    if not tbl then return end
    tbl[key] = (tbl[key] or 0) + secs
end

local function xpDelta(currXP, currMax, prevXP, prevMax)
    if currMax ~= prevMax and currXP <= prevXP then
        return (prevMax - prevXP) + currXP
    else
        return currXP - prevXP
    end
end

function RT:Init()
    local f = CreateFrame("Frame")
    self.frame = f
    
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("PLAYER_LEVEL_UP")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    f:RegisterEvent("ZONE_CHANGED")
    f:RegisterEvent("ZONE_CHANGED_INDOORS")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("PLAYER_DEAD")
    f:RegisterEvent("PLAYER_XP_UPDATE")
    f:RegisterEvent("CHAT_MSG_SYSTEM")
    f:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
    f:RegisterEvent("QUEST_TURNED_IN")
    
    f:SetScript("OnEvent", function(_, ev, ...)
        if ev == "PLAYER_ENTERING_WORLD" then
            ensureReportData()
            state.level = UnitLevel("player")
            ensureLevel(state.level)
            state.zone = GetSubZoneText()
            if not state.zone or state.zone == "" then state.zone = GetRealZoneText() end
            if not state.zone or state.zone == "" then state.zone = nil end
            state.grouped = IsInGroup()
            state.lastTick = GetTime()
            f:SetScript("OnUpdate", function(_, elapsed)
                state._acc = (state._acc or 0) + elapsed
                if state._acc > 2 then
                    RT:FlushTick()
                    state._acc = 0
                end
            end)
        elseif ev == "PLAYER_LEVEL_UP" then
            local old = state.level
            local lvl = ...
            if AvgXPDB.report and AvgXPDB.report.levels and AvgXPDB.report.levels[old] then
                AvgXPDB.report.levels[old].endedAt = time()
            end
            state.level = lvl
            ensureLevel(state.level)
            state.lastTick = GetTime()
            state.recentQuestXP, state.recentQuestAt = 0, 0
            state.recentOtherXP, state.recentOtherAt = 0, 0
            state.recentKillXP, state.recentKillAt = 0, 0
        elseif ev == "ZONE_CHANGED" or ev == "ZONE_CHANGED_NEW_AREA" or ev == "ZONE_CHANGED_INDOORS" then
            RT:FlushTick()
            state.zone = GetSubZoneText()
            if not state.zone or state.zone == "" then state.zone = GetRealZoneText() end
            if not state.zone or state.zone == "" then state.zone = nil end
        elseif ev == "GROUP_ROSTER_UPDATE" then
            RT:FlushTick()
            state.grouped = IsInGroup()
        elseif ev == "PLAYER_DEAD" then
            if AvgXPDB.report and AvgXPDB.report.levels then
                local L = AvgXPDB.report.levels[state.level]
                if L then L.deaths = L.deaths + 1 end
            end
            if AvgXPDB.report and AvgXPDB.report.overall then
                AvgXPDB.report.overall.deaths = (AvgXPDB.report.overall.deaths or 0) + 1
            end
        elseif ev == "PLAYER_XP_UPDATE" then
            local currXP, currMax = UnitXP("player"), UnitXPMax("player")
            local d = xpDelta(currXP, currMax, state.prevXP or currXP, state.prevMax or currMax)
            state.prevXP, state.prevMax = currXP, currMax
            if d <= 0 then return end
            
            local now = GetTime()
            local remaining = d
            local win = 5.0
            
            if state.recentQuestXP > 0 and (now - state.recentQuestAt) < win then
                local q = math.min(remaining, state.recentQuestXP)
                if q > 0 then RT:AddXP("quest", q) end
                remaining = remaining - q
                state.recentQuestXP = state.recentQuestXP - q
            end
            
            if remaining > 0 and state.recentOtherXP > 0 and (now - state.recentOtherAt) < win then
                local o = math.min(remaining, state.recentOtherXP)
                if o > 0 then RT:AddXP("other", o) end
                remaining = remaining - o
                state.recentOtherXP = state.recentOtherXP - o
            end
            
            if remaining > 0 and state.recentKillXP > 0 and (now - state.recentKillAt) < win then
                local k = math.min(remaining, state.recentKillXP)
                if k > 0 then RT:AddXP("kill", k) end
                remaining = remaining - k
                state.recentKillXP = state.recentKillXP - k
            end
            
            if remaining > 0 then
                RT:AddXP("kill", remaining)
            end
        elseif ev == "CHAT_MSG_SYSTEM" then
            local msg = ...
            local amt = msg:match("(%d+)%s+experience")
            if amt then
                amt = tonumber(amt)
                if amt and amt > 0 then
                    state.recentOtherXP = (state.recentOtherXP or 0) + amt
                    state.recentOtherAt = GetTime()
                end
            end
        elseif ev == "CHAT_MSG_COMBAT_XP_GAIN" then
            local msg = ...
            local amt = msg:match("(%d+)%s+experience")
            if amt then
                amt = tonumber(amt)
                if amt and amt > 0 then
                    state.recentKillXP = (state.recentKillXP or 0) + amt
                    state.recentKillAt = GetTime()
                end
            end
        elseif ev == "QUEST_TURNED_IN" then
            local _, xp = ...
            xp = xp or 0
            if xp > 0 then
                state.recentQuestXP = state.recentQuestXP + xp
                state.recentQuestAt = GetTime()
            end
        end
    end)
    
    -- Update metadata
    local name = UnitName("player")
    local realm = GetRealmName()
    AvgXPDB.report.meta = AvgXPDB.report.meta or {}
    AvgXPDB.report.meta.char = name
    AvgXPDB.report.meta.realm = realm
    AvgXPDB.report.meta.lastUpdate = time()
end

function RT:AddXP(kind, amount)
    if not AvgXPDB.report or not AvgXPDB.report.levels then return end
    local L = AvgXPDB.report.levels[state.level]
    if not L then return end
    L.xp[kind] = (L.xp[kind] or 0) + amount
    if AvgXPDB.report.overall and AvgXPDB.report.overall.xp then
        AvgXPDB.report.overall.xp[kind] = (AvgXPDB.report.overall.xp[kind] or 0) + amount
    end
end

function RT:FlushTick()
    local now = GetTime()
    local dt = now - (state.lastTick or now)
    state.lastTick = now
    dt = math.max(0, dt)
    
    if not AvgXPDB.report or not AvgXPDB.report.levels then return end
    local L = AvgXPDB.report.levels[state.level]
    if not L then return end
    
    L.seconds = L.seconds + dt
    
    local z = state.zone
    if z and z ~= "" then
        addSeconds(L.zones, z, dt)
    end
    
    local tfield = state.grouped and "group" or "solo"
    L.time[tfield] = (L.time[tfield] or 0) + dt
    
    if AvgXPDB.report.overall then
        AvgXPDB.report.overall.seconds = (AvgXPDB.report.overall.seconds or 0) + dt
        if z and z ~= "" then
            addSeconds(AvgXPDB.report.overall.zones, z, dt)
        end
        if AvgXPDB.report.overall.time then
            AvgXPDB.report.overall.time[tfield] = (AvgXPDB.report.overall.time[tfield] or 0) + dt
        end
    end
end