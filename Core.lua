-- Core.lua
-- Coordinates events between DB, UI, Graph, and Commands

XPChronicle = XPChronicle or {}

local DB       = XPChronicle.DB
local UI       = XPChronicle.UI
local Graph    = XPChronicle.Graph

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_XP_UPDATE")
f:RegisterEvent("PLAYER_LOGOUT")

f:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    DB:Init()
    UI:CreateMainPanel()
    Graph:BuildBars()
    DB:StartSession()
    UI:Refresh()
  elseif event == "PLAYER_XP_UPDATE" then
    DB:OnXPUpdate()
    UI:Refresh()
  elseif event == "PLAYER_LOGOUT" then
    DB:OnLogout()
  end
end)

f:SetScript("OnUpdate", function(_, dt)
  DB:OnUpdate(dt)
  UI:Refresh()
end)
