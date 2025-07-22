-- Core.lua
-- Wires up events, backfills/rebuilds buckets, ticker, and minimap icon

StaticPopupDialogs["XPCHRONICLE_SET_TIMELOCK"] = {
  text = "Enter minutes past the hour to lock bars to (0–59):",
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = true,
  maxLetters = 2,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  OnShow = function(self)
    local mins = math.floor((AvgXPDB.gridOffset or (time() % 3600)) / 60)
    self.editBox:SetText(tostring(mins))
  end,
  OnAccept = function(self)
    local v = tonumber(self.editBox:GetText())
    if v and v >= 0 and v < 60 then
      AvgXPDB.gridOffset = v * 60
      XPChronicle.DB:RebuildBuckets()
      XPChronicle.UI:Refresh()
      print("|cff33ff99XPChronicle|r: grid locked to " .. v .. "m past the hour.")
    else
      print("|cff33ff99XPChronicle|r: please enter a value 0–59.")
    end
  end,
}

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
    DB:MigrateOldEvents()
    DB:RebuildBuckets()

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
