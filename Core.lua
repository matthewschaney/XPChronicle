-- Core.lua
-- Wires up events, ticker, and spawns the minimap icon
-- (only the PLAYER_LOGIN block is shown; rest stays the same)

XPChronicle = XPChronicle or {}
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("PLAYER_LOGOUT")

f:SetScript("OnEvent", function(_, event, ...)
  local DB    = XPChronicle.DB
  local UI    = XPChronicle.UI
  local Graph = XPChronicle.Graph
  local MB    = XPChronicle.MinimapButton

  if event == "PLAYER_LOGIN" then
    DB:Init()

    -- backfill old events with a numeric timestamp and rebuild all buckets
    if DB.MigrateOldEvents then DB:MigrateOldEvents() end
    if DB.RebuildBuckets    then DB:RebuildBuckets()    end

    UI:CreateMainPanel()
    Graph:BuildBars()
    DB:StartSession()
    UI:Refresh()

    MB:Create()
    MB:HookMinimapUpdate()

  elseif event == "PLAYER_XP_UPDATE" then
    DB:OnXPUpdate()
    UI:Refresh()

  elseif event == "PLAYER_LOGOUT" then
    DB:OnLogout()
  end
end)

f:SetScript("OnUpdate", function(_, dt)
  XPChronicle.DB:OnUpdate(dt)
  XPChronicle.UI:Refresh()
end)
