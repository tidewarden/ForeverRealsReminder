-- ForeverRealsReminder
-- Reminds you to loot your Tarnished Undermine Real after a dungeon boss kill.

local ADDON, FRR = ...
local S, R = FRR.Settings, FRR.Rules

local function secret(v) return issecretvalue and issecretvalue(v) end
local function now() return (GetServerTime and GetServerTime()) or time() end

local function charKey()
    return UnitName("player") .. "-" .. ((GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or "?")
end

local function resetAt()
    local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset and C_DateAndTime.GetSecondsUntilDailyReset()
    return now() + ((type(left) == "number" and not secret(left)) and left or 86400)
end

local function instance()
    local name, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    return name, instanceType, instanceID
end

local function currency()
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(R.CURRENCY)
    if not info or secret(info.quantity) then return nil, nil end
    return info.quantity, info.maxQuantity
end

-- Highest readable level among the boss units, or failing those your and your party's targets (Classic
-- dungeons may have no boss frames). Errs towards a higher level, i.e. towards showing the reminder.
-- nil if nothing can be read.
local UNITS = { "boss1", "boss2", "boss3", "boss4", "boss5", "target", "party1target", "party2target",
                "party3target", "party4target" }
local function bossLevel()
    local best
    for _, unit in ipairs(UNITS) do
        local exists = UnitExists(unit) and UnitCanAttack("player", unit)
        if not secret(exists) and exists then
            local level = UnitLevel(unit)
            if not secret(level) and type(level) == "number" then
                if level == -1 then return -1 end
                if not best or level > best then best = level end
            end
        end
    end
    return best
end

-- The fight being tracked; kills whose Real hasn't come in yet (oldest first); the last known Real total.
local fight
local pending = {}
local lastQuantity
local PENDING_FOR = 300 -- seconds a kill waits to be credited with a Real

local function sampleLevel()
    if not fight then return end
    local level = bossLevel()
    if level and (fight.level == nil or level == -1 or (fight.level ~= -1 and level > fight.level)) then
        fight.level = level
    end
end

local function decide(encounterID, encounterName, success)
    local name, instanceType, instanceID = instance()
    local quantity, maxQuantity = currency()
    FRR.db.bossLevels = FRR.db.bossLevels or {}
    local level = (fight and fight.id == encounterID and fight.level) or FRR.db.bossLevels[encounterID]
    local ctx = {
        success = success,
        playerLevel = UnitLevel("player"),
        minPlayerLevel = S.Get("minLevel"),
        inDungeon = R.IsRealDungeon(FRR.db, instanceType, instanceID, name),
        bossLevel = level,
        lootedToday = R.LootedToday(FRR.db, charKey(), encounterID, now()),
        atCap = R.AtCap(quantity, maxQuantity),
    }
    local show, reason = R.ShouldRemind(ctx)
    FRR.last = { encounter = encounterName, id = encounterID, instance = name, instanceID = instanceID,
                 bossLevel = level, reason = reason }
    return show
end

local function onEncounterStart(encounterID)
    if secret(encounterID) then return end
    fight = { id = encounterID }
    sampleLevel()
    -- Boss frames fill in a moment after the pull.
    C_Timer.After(1, function() if fight and fight.id == encounterID then sampleLevel() end end)
end

local function onEncounterEnd(encounterID, encounterName, success)
    if secret(encounterID) or secret(success) then fight = nil; return end
    if fight and fight.id == encounterID then
        sampleLevel()
        if fight.level then
            FRR.db.bossLevels = FRR.db.bossLevels or {}
            FRR.db.bossLevels[encounterID] = fight.level
        end
    end
    if success == 1 then pending[#pending + 1] = { id = encounterID, at = GetTime() } end
    if S.Get("enabled") and decide(encounterID, encounterName, success) then
        FRR.Reminder.Show(encounterName)
    end
    fight = nil
end

local function onCurrency(currencyType, _, change)
    if secret(currencyType) or currencyType ~= R.CURRENCY then return end
    local q = currency()
    local gained
    if not secret(change) and type(change) == "number" then
        gained = change > 0
    else -- quantityChange is optional: compare with the last total instead
        gained = q ~= nil and lastQuantity ~= nil and q > lastQuantity
    end
    if q then lastQuantity = q end
    if not gained then return end
    FRR.Reminder.Hide()
    -- Credit the oldest kill still waiting: bosses are usually looted in the order they die.
    while pending[1] and GetTime() - pending[1].at > PENDING_FOR do table.remove(pending, 1) end
    local kill = table.remove(pending, 1)
    if kill then
        R.MarkLooted(FRR.db, charKey(), kill.id, resetAt())
        local name, instanceType, instanceID = instance()
        if instanceType == "party" then R.LearnDungeon(FRR.db, instanceID, name) end
    end
end

SLASH_FOREVERREALSREMINDER1 = "/frr"
SlashCmdList.FOREVERREALSREMINDER = function(msg)
    local cmd = (msg or ""):lower():match("^(%S*)")
    if cmd == "test" then
        FRR.Reminder.Show("Test")
    elseif cmd == "unlock" or cmd == "lock" then
        FRR.Reminder.ToggleUnlock() -- the frame itself says "Drag me, then /frr lock"
    else
        FRR.Options.Open()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and ... == ADDON then
        ForeverRealsReminderDB = ForeverRealsReminderDB or {}
        FRR.db = ForeverRealsReminderDB
    elseif event == "PLAYER_LOGIN" then
        R.Prune(FRR.db, now())
        lastQuantity = currency()
        FRR.Options.Register()
        events:RegisterEvent("ENCOUNTER_START")
        events:RegisterEvent("ENCOUNTER_END")
        events:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
    elseif event == "ENCOUNTER_START" then
        onEncounterStart(...)
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, _, _, success = ...
        onEncounterEnd(encounterID, encounterName, success)
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        onCurrency(...)
    end
end)

-- For tests.
FRR._onEncounterStart, FRR._onEncounterEnd, FRR._onCurrency = onEncounterStart, onEncounterEnd, onCurrency
