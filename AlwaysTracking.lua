local addonName = ...

-- Tracking spells by kind. The Forever client lists two ranks for herbs and ore, and only one
-- tracking can be on at a time.
local TRACKERS = {
  herbs    = { label = "Find Herbs",    spells = { [2383] = true, [8387] = true } },
  minerals = { label = "Find Minerals", spells = { [2580] = true, [8388] = true } },
  treasure = { label = "Find Treasure", spells = { [2481] = true } },
  fish     = { label = "Find Fish",     spells = { [43308] = true } },
}
local TRACKER_ORDER = { "herbs", "minerals", "treasure", "fish" }

local DEFAULTS = {
  enabled = true,
  tracker = "herbs",
  interval = 5,      -- minutes between checks
  override = false,  -- also replace another tracking that is on
  verbose = true,    -- say so in chat when tracking is turned back on
}

local RETRY = 2            -- seconds between retries while a check waits (combat, casting, cooldown)
local VERIFY = 1.5         -- seconds after SetTracking before checking that it took
local MISSES_TO_INPUT = 2  -- timed attempts that silently fail before moving to key press mode
local LOGIN_DELAY = 3
local RESURRECT_DELAY = 1

-- Blizzard's movement and click bindings. If the client refuses SetTracking from a timer, the
-- attempt waits for the next of these, where the player's own key press or click allows it.
local INPUT_FUNCTIONS = {
  "MoveForwardStart", "MoveBackwardStart", "StrafeLeftStart", "StrafeRightStart",
  "MoveAndSteerStart", "TurnLeftStart", "TurnRightStart", "JumpOrAscendStart",
  "TurnOrActionStart", "CameraOrSelectOrMoveStart",
}

local db
local ticker, retryTicker
local pending = false    -- tracking is off and should be turned on as soon as nothing stops it
local applying = false   -- inside our own SetTracking call
local verifying = false  -- waiting to see whether the last call took
local inputMode = false  -- timed calls are refused: act on the player's next key press
local blocked = false    -- refused on key presses too: give up until /reload
local misses = 0
local status = "starting"

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99Always Tracking|r: " .. msg)
end

local function IsSecret(value)
  return issecretvalue ~= nil and issecretvalue(value)
end

local function Tracker()
  return TRACKERS[db.tracker]
end

-- Indices shift when the player learns or forgets a tracking spell, so every look starts afresh.
local function ReadTracking()
  local tracker = Tracker()
  local wanted, active
  for index = 1, C_Minimap.GetNumTrackingTypes() do
    local info = C_Minimap.GetTrackingInfo(index)
    if info and info.type == "spell" then
      info.index = index
      if not wanted and (tracker.spells[info.spellID] or info.name == tracker.label) then
        wanted = info
      end
      if info.active then active = info end
    end
  end
  return wanted, active
end

local function IsCasting()
  local casting, channeling = UnitCastingInfo("player"), UnitChannelInfo("player")
  return IsSecret(casting) or IsSecret(channeling) or casting ~= nil or channeling ~= nil
end

local function OnCooldown(spellID)
  if not (C_Spell and C_Spell.GetSpellCooldown) then return false end
  local cooldown = C_Spell.GetSpellCooldown(spellID)
  return cooldown and cooldown.isActive
end

local function InPvPInstance()
  local _, instanceType = IsInInstance()
  return instanceType == "pvp" or instanceType == "arena"
end

-- Why tracking can't be turned on right now. A lasting reason needs the player to change
-- something, or zoning checks again; a passing one is retried until it clears.
local function WaitReason(wanted, active)
  if not wanted then return "this character doesn't know " .. Tracker().label, true end
  if active and not db.override then return (active.name or "another tracking") .. " is on", true end
  if blocked then return "Blizzard blocks it until you /reload", true end
  if InPvPInstance() then return "in a battleground or arena", true end
  if InCombatLockdown() or UnitAffectingCombat("player") then return "in combat" end
  if UnitIsDeadOrGhost("player") then return "dead" end
  if UnitOnTaxi("player") then return "on a flight" end
  if IsCasting() then return "casting" end
  if OnCooldown(wanted.spellID) then return "on cooldown" end
end

local function StopRetry()
  if retryTicker then retryTicker:Cancel() end
  retryTicker = nil
end

local Check

local function StartRetry()
  if not retryTicker and not inputMode then
    retryTicker = C_Timer.NewTicker(RETRY, function() Check("retry") end)
  end
end

local function OnInput()
  if pending then Check("input") end
end

local function EnterInputMode(line)
  inputMode = true
  StopRetry()
  for _, name in ipairs(INPUT_FUNCTIONS) do
    if _G[name] then hooksecurefunc(name, OnInput) end
  end
  Print(line)
end

local function Verify()
  verifying = false
  local wanted = ReadTracking()
  if wanted and wanted.active then
    pending, misses = false, 0
    StopRetry()
    status = Tracker().label .. " is on"
    if db.verbose then Print(Tracker().label .. " turned back on.") end
    return
  end
  if not inputMode and not blocked then
    misses = misses + 1
    if misses >= MISSES_TO_INPUT then
      EnterInputMode("Timed attempts don't take, so tracking now turns on with your next movement key or click.")
    else
      StartRetry()
    end
  end
end

local function Apply(wanted)
  applying = true
  local ok, err = pcall(C_Minimap.SetTracking, wanted.index, true)
  applying = false
  if not ok then status = "error: " .. tostring(err) end
  verifying = true
  C_Timer.After(VERIFY, Verify)
end

function Check(source)
  if applying or verifying then return end
  if not db.enabled then
    pending = false
    StopRetry()
    status = "disabled"
    return
  end

  local wanted, active = ReadTracking()
  if wanted and wanted.active then
    pending = false
    StopRetry()
    status = Tracker().label .. " is on"
    return
  end

  local reason, lasting = WaitReason(wanted, active)
  if lasting then
    pending = false
    StopRetry()
    status = reason
    return
  end

  pending = true
  if reason then
    status = "waiting: " .. reason
    StartRetry()
    return
  end
  if inputMode and source ~= "input" and source ~= "manual" then
    status = "waiting for your next key press"
    return
  end

  status = "turning on " .. Tracker().label
  Apply(wanted)
end

local function StartTicker()
  if ticker then ticker:Cancel() end
  ticker = C_Timer.NewTicker(db.interval * 60, function() Check("timer") end)
end

-- ADDON_ACTION_BLOCKED and ADDON_ACTION_FORBIDDEN fire inside the call they block.
local function OnBlocked(event, blockedAddon)
  if not applying or blockedAddon ~= addonName then return end
  local hint = event == "ADDON_ACTION_FORBIDDEN" and " Choose Ignore in Blizzard's warning." or ""
  if not inputMode then
    EnterInputMode("Blizzard blocked the timed check, so tracking now turns on with your next movement key or click." .. hint)
  elseif not blocked then
    blocked, pending = true, false
    StopRetry()
    Print("Blizzard blocks it on key presses too, so it stays off until you /reload." .. hint)
  end
end

local function InitDB()
  AlwaysTrackingDB = AlwaysTrackingDB or {}
  db = AlwaysTrackingDB
  for key, value in pairs(DEFAULTS) do
    if db[key] == nil then db[key] = value end
  end
  if not TRACKERS[db.tracker] then db.tracker = DEFAULTS.tracker end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    InitDB()
    StartTicker()
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("PLAYER_ALIVE")
    events:RegisterEvent("PLAYER_UNGHOST")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("ADDON_ACTION_BLOCKED")
    events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
  elseif event == "PLAYER_ENTERING_WORLD" then
    C_Timer.After(LOGIN_DELAY, function() Check("login") end)
  elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
    -- PLAYER_ALIVE also fires on releasing the spirit, while still a ghost; Check waits that out.
    C_Timer.After(RESURRECT_DELAY, function() Check("resurrect") end)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if pending then Check("combat") end
  else
    OnBlocked(event, ...)
  end
end)

local function TrackerList()
  return table.concat(TRACKER_ORDER, ", ")
end

local function PrintStatus()
  Print(string.format("%s, tracking %s, check every %d min, %s.",
    db.enabled and "|cff00ff00on|r" or "|cffff0000off|r", Tracker().label, db.interval, status))
  if inputMode then Print("Timed checks are refused, so it acts on your next movement key or click.") end
  if db.override then Print("Override is on: it replaces another tracking that is on.") end
end

local function PrintHelp()
  Print("commands:")
  Print("  /at - status")
  Print("  /at on | off - turn the addon on or off")
  Print("  /at track <" .. table.concat(TRACKER_ORDER, "|") .. "> - which tracking to keep on")
  Print("  /at interval <minutes> - how often to check (1-60)")
  Print("  /at now - check right away")
  Print("  /at override - also replace another tracking that is on")
  Print("  /at quiet - toggle the chat message when tracking is turned back on")
end

SLASH_ALWAYSTRACKING1 = "/alwaystracking"
SLASH_ALWAYSTRACKING2 = "/at"
SlashCmdList.ALWAYSTRACKING = function(input)
  local cmd, arg = strtrim(input or ""):lower():match("^(%S*)%s*(.-)$")
  if cmd == "" or cmd == "status" then
    PrintStatus()
  elseif cmd == "on" or cmd == "off" then
    db.enabled = cmd == "on"
    Check("manual")
    PrintStatus()
  elseif cmd == "track" or cmd == "tracker" then
    if TRACKERS[arg] then
      db.tracker = arg
      Check("manual")
      PrintStatus()
    else
      Print("unknown tracking '" .. arg .. "'. Choose one of: " .. TrackerList() .. ".")
    end
  elseif cmd == "interval" then
    local minutes = tonumber(arg)
    if minutes and minutes >= 1 and minutes <= 60 then
      db.interval = math.floor(minutes)
      StartTicker()
      PrintStatus()
    else
      Print("the interval is a number of minutes from 1 to 60.")
    end
  elseif cmd == "now" then
    -- Typing the command is itself a key press, so this works even in key press mode.
    Check("manual")
    PrintStatus()
  elseif cmd == "override" then
    db.override = not db.override
    Check("manual")
    PrintStatus()
  elseif cmd == "quiet" then
    db.verbose = not db.verbose
    Print(db.verbose and "chat message on." or "chat message off.")
  else
    PrintHelp()
  end
end
