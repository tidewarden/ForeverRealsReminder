local _, FRR = ...

-- When to show the reminder. No game API in here, so it is all testable.
-- Sources (Nov 2026): forg.gg/en/forever/tips/undermine-real and conquestcapped.com's Real guide agree that
-- Tarnished Undermine Reals (currency 3469) drop from dungeon bosses of level 55+, once per boss per day per
-- character, and every group member loots their own.
local Rules = {}
FRR.Rules = Rules

Rules.CURRENCY = 3469
Rules.BOSS_MIN_LEVEL = 55

-- Instance IDs (8th return of GetInstanceInfo) of the Classic dungeons that drop Reals.
Rules.DUNGEON_IDS = {
    [230] = "Blackrock Depths",
    [229] = "Blackrock Spire", -- Lower and Upper share one instance ID
    [429] = "Dire Maul",       -- East, West and North
    [289] = "Scholomance",
    [329] = "Stratholme",      -- Live and Dead
}
-- Names as GetInstanceInfo gives them (English client): Forever's new dungeons, whose IDs aren't
-- published, and the Classic ones in case Forever renumbered them.
Rules.DUNGEON_NAMES = {
    ["Blackmaw Hold"] = true,
    ["Shaper's Terrace"] = true,
    ["Blackrock Depths"] = true,
    ["Blackrock Spire"] = true,
    ["Lower Blackrock Spire"] = true,
    ["Upper Blackrock Spire"] = true,
    ["Dire Maul"] = true,
    ["Scholomance"] = true,
    ["Stratholme"] = true,
}

function Rules.IsRealDungeon(db, instanceType, instanceID, name)
    if instanceType ~= "party" then return false end
    if Rules.DUNGEON_IDS[instanceID] or Rules.DUNGEON_NAMES[name] then return true end
    return db.learnedDungeons ~= nil and db.learnedDungeons[instanceID] ~= nil
end

-- A Real dropped here: remember the dungeon even if it wasn't on the list (covers ones the guides missed).
function Rules.LearnDungeon(db, instanceID, name)
    if not instanceID or Rules.DUNGEON_IDS[instanceID] then return false end
    db.learnedDungeons = db.learnedDungeons or {}
    if db.learnedDungeons[instanceID] then return false end
    db.learnedDungeons[instanceID] = name or "?"
    return true
end

-- nil = unknown (count it), -1 = skull (far above you, counts).
function Rules.BossCounts(level)
    if level == nil or level == -1 then return true end
    return level >= Rules.BOSS_MIN_LEVEL
end

local function char(db, charKey)
    db.chars = db.chars or {}
    local c = db.chars[charKey]
    if not c then c = { got = {} }; db.chars[charKey] = c end
    c.got = c.got or {}
    return c
end

-- This character looted this boss's Real; it can't drop again for them until the daily reset.
function Rules.MarkLooted(db, charKey, encounterID, resetAt)
    char(db, charKey).got[encounterID] = resetAt
end

function Rules.LootedToday(db, charKey, encounterID, now)
    local resetAt = char(db, charKey).got[encounterID]
    return resetAt ~= nil and resetAt > now
end

-- Drop expired daily records so the saved file doesn't grow forever.
function Rules.Prune(db, now)
    for _, c in pairs(db.chars or {}) do
        for enc, resetAt in pairs(c.got or {}) do
            if resetAt <= now then c.got[enc] = nil end
        end
    end
end

-- ctx: { success, playerLevel, minPlayerLevel, inDungeon, bossLevel, lootedToday, atCap }
-- Returns show, reason (the reason is for /frr debug).
function Rules.ShouldRemind(ctx)
    if ctx.success ~= 1 then return false, "wipe" end
    if not ctx.inDungeon then return false, "not a Real dungeon" end
    if (ctx.playerLevel or 0) < ctx.minPlayerLevel then return false, "player level below " .. ctx.minPlayerLevel end
    if not Rules.BossCounts(ctx.bossLevel) then return false, "boss below level " .. Rules.BOSS_MIN_LEVEL end
    if ctx.lootedToday then return false, "already looted this boss today" end
    if ctx.atCap then return false, "at the Real cap" end
    return true, "show"
end

function Rules.AtCap(quantity, maxQuantity)
    return (maxQuantity or 0) > 0 and (quantity or 0) >= maxQuantity
end
