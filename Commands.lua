-- XPChronicle ▸ Commands.lua

XPChronicle         = XPChronicle or {}
XPChronicle.Commands= XPChronicle.Commands or {}
local CMD           = XPChronicle.Commands

local DB            = XPChronicle.DB
local UI            = XPChronicle.UI
local Graph         = XPChronicle.Graph
local MB            = XPChronicle.MinimapButton
local Opt           = XPChronicle.Options
local Hist          = XPChronicle.History

-- Utility --------------------------------------------------------------------
local function say(msg)
  print("|cff33ff99XPChronicle|r: " .. msg)
end

-- Handlers -------------------------------------------------------------------
local function hReset()
  DB:Reset(); UI:CreateMainPanel(); Graph:BuildBars()
  DB:StartSession(); UI:Refresh()
  say("data reset.")
end

local function hGraph() UI:ToggleGraph() end

local function hHistory() Hist:Toggle() end

local function hOptions() Opt:Toggle() end

local function hMinimap()
  if not MB then say("Error: MinimapButton module missing"); return end
  if not MB.button then MB:Create(); MB:HookMinimapUpdate() end
  if MB.button then
    local vis = MB.button:IsShown()
    MB.button:SetShown(not vis)
    AvgXPDB.minimapHidden = vis
    say("minimap button " .. (vis and "hidden" or "shown"))
  else
    say("Error: could not create minimap button")
  end
end

local function hBuckets(arg)
  local n = tonumber(arg)
  if n and n >= 2 and n <= 24 then
    DB:SetBuckets(n); Graph:BuildBars(); UI:Refresh()
  else
    say("choose 2‑24 buckets.")
  end
end

-- Help -----------------------------------------------------------------------
local function help()
  say("slash commands:")
  print(" /xpchronicle reset        - full data reset")
  print(" /xpchronicle graph        - toggle bar graph")
  print(" /xpchronicle history      - toggle history window")
  print(" /xpchronicle minimap      - toggle minimap button")
  print(" /xpchronicle options      - open options panel")
  print(" /xpchronicle buckets <n>  - set buckets (2-24)")
  print(" (alias: /xpchron)")
end

-- Dispatcher -----------------------------------------------------------------
local function slash(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if     msg == "reset"           then hReset()
  elseif msg == "graph"           then hGraph()
  elseif msg == "history"         then hHistory()
  elseif msg == "options"         then hOptions()
  elseif msg == "minimap"         then hMinimap()
  elseif msg:match("^buckets%s+%d+") then
         hBuckets(msg:match("%d+"))
  else  help() end
end

-- Register -------------------------------------------------------------------
SLASH_XPCHRONICLE1 = "/xpchronicle"
SLASH_XPCHRONICLE2 = "/xpchron"
SlashCmdList["XPCHRONICLE"] = slash
