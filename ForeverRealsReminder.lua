-- ForeverRealsReminder
-- Reminds you to loot your Tarnished Undermine Real after a dungeon boss kill.

local ADDON, FRR = ...
local S, R = FRR.Settings, FRR.Rules

function FRR.Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff33e5ffForeverRealsReminder|r: " .. msg) end

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

-- Highest readable level among the boss units; nil if none can be read (hidden or not shown).
local function bossLevel()
    local best
    for i = 1, 5 do
        local unit = "boss" .. i
        local exists = UnitExists(unit)
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

-- The fight being tracked, and the last kill (its Real is credited to it).
local fight, lastKill
local lastQuantity

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
    fight = { id = encounterID }
    -- Boss frames fill in a moment after the pull.
    C_Timer.After(1, function()
        if fight and fight.id == encounterID then
            fight.level = bossLevel() or fight.level
            if fight.level then
                FRR.db.bossLevels = FRR.db.bossLevels or {}
                FRR.db.bossLevels[encounterID] = fight.level
            end
        end
    end)
end

local function onEncounterEnd(encounterID, encounterName, success)
    if secret(encounterID) or secret(success) then return end
    if fight and fight.id == encounterID then fight.level = bossLevel() or fight.level end
    if success == 1 then lastKill = { id = encounterID, at = GetTime() } end
    if S.Get("enabled") and decide(encounterID, encounterName, success) then
        lastQuantity = currency()
        FRR.Reminder.Show(encounterName)
    end
    fight = nil
end

local function onCurrency(currencyType, quantity, change)
    if secret(currencyType) or currencyType ~= R.CURRENCY then return end
    local gained
    if not secret(change) and type(change) == "number" then
        gained = change > 0
    else
        local q = currency()
        gained = q and lastQuantity and q > lastQuantity
    end
    if not gained then return end
    FRR.Reminder.Hide()
    if lastKill and GetTime() - lastKill.at < 300 then
        R.MarkLooted(FRR.db, charKey(), lastKill.id, resetAt())
        local name, instanceType, instanceID = instance()
        if instanceType == "party" and R.LearnDungeon(FRR.db, instanceID, name) then
            FRR.Print("learned a new Real dungeon: " .. tostring(name))
        end
    end
end

SLASH_FOREVERREALSREMINDER1 = "/frr"
SlashCmdList.FOREVERREALSREMINDER = function(msg)
    local cmd = (msg or ""):lower():match("^(%S*)")
    if cmd == "" or cmd == "options" then
        FRR.Options.Open()
    elseif cmd == "test" then
        FRR.Reminder.Show("Test")
    elseif cmd == "unlock" or cmd == "lock" then
        FRR.Print(FRR.Reminder.ToggleUnlock() and "unlocked: drag the reminder, then /frr lock" or "locked")
    elseif cmd == "debug" then
        local name, instanceType, instanceID = instance()
        local q, max = currency()
        FRR.Print(("here: %s (%s, id %s), Real dungeon: %s"):format(tostring(name), tostring(instanceType),
            tostring(instanceID), tostring(R.IsRealDungeon(FRR.db, instanceType, instanceID, name))))
        FRR.Print(("Reals: %s / %s, boss level now: %s"):format(tostring(q), tostring(max), tostring(bossLevel())))
        local l = FRR.last
        if l then
            FRR.Print(("last kill: %s (id %s, boss level %s) in %s (id %s): %s"):format(tostring(l.encounter),
                tostring(l.id), tostring(l.bossLevel), tostring(l.instance), tostring(l.instanceID), l.reason))
        end
    else
        FRR.Print("/frr options | test | unlock | lock | debug")
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
