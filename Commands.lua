-- Commands.lua
-- Slash-command handling
XPChronicle = XPChronicle or {}
XPChronicle.Commands = {}
local CMD = XPChronicle.Commands
local DB = XPChronicle.DB
local UI = XPChronicle.UI
local Graph = XPChronicle.Graph

SLASH_XPCHRONICLE1 = "/avgxp"
SlashCmdList["XPCHRONICLE"] = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  
  if msg == "reset" then
    DB:Reset()
    UI:CreateMainPanel()
    Graph:BuildBars()
    DB:StartSession()
    UI:Refresh()
    print("|cff33ff99XPChronicle|r: data reset.")
    
  elseif msg == "graph" then
    UI:ToggleGraph()
    
  elseif msg == "minimap" then
    -- Get MinimapButton module at runtime
    local MB = XPChronicle.MinimapButton
    if not MB then
      print("|cff33ff99XPChronicle|r: Error - MinimapButton module not found")
      return
    end
    
    -- Ensure button is created first
    if not MB.button then
      MB:Create()
      MB:HookMinimapUpdate()
    end
    
    if MB.button then
      local isShown = MB.button:IsShown()
      if isShown then
        MB.button:Hide()
        AvgXPDB.minimapHidden = true
      else
        MB.button:Show()
        AvgXPDB.minimapHidden = false
      end
      print("|cff33ff99XPChronicle|r: minimap button " .. (isShown and "hidden" or "shown"))
    else
      print("|cff33ff99XPChronicle|r: Error - could not create minimap button")
    end
    
  elseif msg:match("^buckets%s+%d+") then
    local n = tonumber(msg:match("%d+"))
    if n and n >= 2 and n <= 24 then
      DB:SetBuckets(n)
      Graph:BuildBars()
      UI:Refresh()
    else
      print("|cff33ff99XPChronicle|r: choose 2-24 buckets.")
    end
    
  else
    print("|cff33ff99XPChronicle|r commands:")
    print(" /avgxp reset – clear all data")
    print(" /avgxp graph – toggle the graph display")
    print(" /avgxp minimap – toggle minimap button")
    print(" /avgxp buckets <n> – set graph length (2–24)")
  end
end