-- XPChronicle ▸ Commands.lua

XPChronicle = XPChronicle or {}
XPChronicle.Commands = {}
local CMD   = XPChronicle.Commands
local DB    = XPChronicle.DB
local UI    = XPChronicle.UI
local Graph = XPChronicle.Graph
local MB    = XPChronicle.MinimapButton

-- Utility: Standardized message printing.
local function printMsg(msg)
  print("|cff33ff99XPChronicle|r: " .. msg)
end

-- Command Handlers.
local function handleReset()
  DB:Reset()
  UI:CreateMainPanel()
  Graph:BuildBars()
  DB:StartSession()
  UI:Refresh()
  printMsg("data reset.")
end

local function handleGraph()
  UI:ToggleGraph()
end

local function handleMinimap()
  if not MB then
    printMsg("Error - MinimapButton module not found")
    return
  end

  if not MB.button then
    MB:Create()
    MB:HookMinimapUpdate()
  end

  if MB.button then
    local isShown = MB.button:IsShown()
    MB.button:SetShown(not isShown)
    AvgXPDB.minimapHidden = isShown
    printMsg("minimap button " .. (isShown and "hidden" or "shown"))
  else
    printMsg("Error - could not create minimap button")
  end
end

local function handleBuckets(arg)
  local n = tonumber(arg)
  if n and n >= 2 and n <= 24 then
    DB:SetBuckets(n)
    Graph:BuildBars()
    UI:Refresh()
  else
    printMsg("choose 2-24 buckets.")
  end
end

local function showHelp()
  printMsg("commands:")
  print(" /xpchronicle reset - clear all data")
  print(" /xpchronicle graph - toggle the graph display")
  print(" /xpchronicle minimap - toggle minimap button")
  print(" /xpchronicle buckets <n> - set graph length (2-24)")
  print(" (alias: /xpchron)")
end

-- Slash command dispatcher.
local function slashHandler(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")

  if msg == "reset" then
    handleReset()
  elseif msg == "graph" then
    handleGraph()
  elseif msg == "minimap" then
    handleMinimap()
  elseif msg:match("^buckets%s+%d+") then
    local arg = msg:match("%d+")
    handleBuckets(arg)
  else
    showHelp()
  end
end

-- Register slash commands.
SLASH_XPCHRONICLE1 = "/xpchronicle"
SLASH_XPCHRONICLE2 = "/xpchron"
SlashCmdList["XPCHRONICLE"] = slashHandler
