local T = ...

local function fresh()
    local FRR = { db = {} }
    assert(loadfile(T.root .. "/Rules.lua"))("ForeverRealsReminder", FRR)
    return FRR.db, FRR.Rules
end

local function ctx(over)
    local c = { success = 1, playerLevel = 60, minPlayerLevel = 60, inDungeon = true, bossLevel = 60,
                lootedToday = false, atCap = false }
    for k, v in pairs(over or {}) do c[k] = v end
    return c
end

T.test("rules_dungeons_by_id_name_and_learned", function()
    local db, R = fresh()
    T.eq(R.IsRealDungeon(db, "party", 329, "Stratholme"), true)
    T.eq(R.IsRealDungeon(db, "party", 99999, "Shaper's Terrace"), true)
    T.eq(R.IsRealDungeon(db, "party", 36, "Deadmines"), false)
    T.eq(R.IsRealDungeon(db, "raid", 409, "Molten Core"), false)
    T.eq(R.LearnDungeon(db, 109, "Sunken Temple"), true)
    T.eq(R.LearnDungeon(db, 109, "Sunken Temple"), false, "only once")
    T.eq(R.LearnDungeon(db, 329, "Stratholme"), false, "already listed")
    T.eq(R.IsRealDungeon(db, "party", 109, "Sunken Temple"), true)
end)

T.test("rules_show_on_qualifying_kill", function()
    local _, R = fresh()
    T.eq((R.ShouldRemind(ctx())), true)
    T.eq((R.ShouldRemind(ctx({ bossLevel = -1 }))), true, "skull boss")
    T.eq((R.ShouldRemind(ctx({ bossLevel = nil }))), true, "unknown level")
end)

T.test("rules_skip_reasons", function()
    local _, R = fresh()
    local cases = {
        { { success = 0 }, "wipe" },
        { { inDungeon = false }, "not a Real dungeon" },
        { { playerLevel = 59 }, "player level below 60" },
        { { bossLevel = 52 }, "boss below level 55" },
        { { lootedToday = true }, "already looted this boss today" },
        { { atCap = true }, "at the Real cap" },
    }
    for _, case in ipairs(cases) do
        local show, reason = R.ShouldRemind(ctx(case[1]))
        T.eq(show, false); T.eq(reason, case[2])
    end
end)

T.test("rules_daily_lockout_and_prune", function()
    local db, R = fresh()
    R.MarkLooted(db, "A-R", 227, 1000)
    T.eq(R.LootedToday(db, "A-R", 227, 999), true)
    T.eq(R.LootedToday(db, "B-R", 227, 999), false, "per character")
    T.eq(R.LootedToday(db, "A-R", 227, 1000), false, "reset passed")
    R.Prune(db, 1000)
    T.eq(db.chars["A-R"].got[227], nil)
end)

T.test("rules_at_cap", function()
    local _, R = fresh()
    T.eq(R.AtCap(250, 250), true); T.eq(R.AtCap(10, 250), false); T.eq(R.AtCap(10, 0), false)
end)

T.test("rules_classic_names_match_if_ids_differ", function()
    local db, R = fresh()
    T.eq(R.IsRealDungeon(db, "party", 1007, "Scholomance"), true)
    T.eq(R.IsRealDungeon(db, "party", 5000, "Blackrock Depths"), true)
end)
