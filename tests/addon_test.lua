local T = ...
local fake = require("fake_wow")

-- Whole addon in a fake world: a boss kill shows the reminder, looting the Real hides it and locks
-- that boss for the day.
local function world(opts)
    local clock = { up = 1000, epoch = 1000000000 }
    local game = { quantity = 5, max = 250, instance = { "Stratholme", "party", 1, "", 5, 0, false, 329 },
                   level = 60, bossLevel = 60 }
    for k, v in pairs(opts or {}) do game[k] = v end
    _G.issecretvalue = nil
    _G.GetTime = function() return clock.up end
    _G.GetServerTime = function() return clock.epoch end
    _G.UnitName = function() return "Me" end
    _G.GetNormalizedRealmName = function() return "Realm" end
    _G.GetInstanceInfo = function() return unpack(game.instance) end
    _G.UnitLevel = function(unit) if unit == "player" then return game.level end return game.bossLevel end
    _G.UnitExists = function(unit) return unit == "boss1" end
    _G.UnitCanAttack = function() return true end
    _G.C_DateAndTime = { GetSecondsUntilDailyReset = function() return 3600 end }
    _G.C_CurrencyInfo = { GetCurrencyInfo = function() return { quantity = game.quantity, maxQuantity = game.max, iconFileID = 1 } end }
    local later = {}
    _G.C_Timer = { After = function(_, fn) later[#later + 1] = fn end,
                   NewTicker = function() return { Cancel = function() end } end }
    local FRR, w = fake.fresh(T.root, { files = { "Settings.lua", "Rules.lua", "Reminder.lua", "Widgets.lua",
        "Options.lua", "ForeverRealsReminder.lua" } })
    FRR.Options.Register = function() end
    local events
    for _, f in ipairs(w.frames) do if f._events.ADDON_LOADED then events = f end end
    local fire = function(...) events:GetScript("OnEvent")(events, ...) end
    fire("ADDON_LOADED", "ForeverRealsReminder")
    fire("PLAYER_LOGIN")
    return FRR, fire, game, clock, later
end

local function kill(fire, later, id)
    fire("ENCOUNTER_START", id, "Baron Rivendare", 1, 5)
    for _, fn in ipairs(later) do fn() end
    fire("ENCOUNTER_END", id, "Baron Rivendare", 1, 5, 1)
end

T.test("addon_kill_shows_loot_hides_and_locks_for_the_day", function()
    local FRR, fire, game, clock, later = world()
    kill(fire, later, 456)
    T.eq(FRR.Reminder.IsShown(), true)
    game.quantity = 8
    fire("CURRENCY_DISPLAY_UPDATE", 3469, 8, 3)
    T.eq(FRR.Reminder.IsShown(), false)
    kill(fire, later, 456) -- same boss again today (another group)
    T.eq(FRR.Reminder.IsShown(), false); T.eq(FRR.last.reason, "already looted this boss today")
    clock.epoch = clock.epoch + 3601
    kill(fire, later, 456)
    T.eq(FRR.Reminder.IsShown(), true, "after the daily reset")
end)

T.test("addon_other_currency_does_not_hide", function()
    local FRR, fire, _, _, later = world()
    kill(fire, later, 456)
    fire("CURRENCY_DISPLAY_UPDATE", 1, 100, 10)
    T.eq(FRR.Reminder.IsShown(), true)
end)

T.test("addon_low_boss_and_low_player_and_wrong_dungeon", function()
    local FRR, fire, _, _, later = world({ bossLevel = 52 })
    kill(fire, later, 1); T.eq(FRR.Reminder.IsShown(), false); T.eq(FRR.last.reason, "boss below level 55")
    FRR, fire, _, _, later = world({ level = 58 })
    kill(fire, later, 1); T.eq(FRR.Reminder.IsShown(), false)
    FRR, fire, _, _, later = world({ instance = { "Deadmines", "party", 1, "", 5, 0, false, 36 } })
    kill(fire, later, 1); T.eq(FRR.Reminder.IsShown(), false)
end)

T.test("addon_learns_unlisted_dungeon_when_a_real_drops", function()
    local FRR, fire, game, _, later = world({ instance = { "Sunken Temple", "party", 1, "", 5, 0, false, 109 } })
    kill(fire, later, 7)
    T.eq(FRR.Reminder.IsShown(), false)
    game.quantity = 6
    fire("CURRENCY_DISPLAY_UPDATE", 3469, 6, 1)
    T.eq(FRR.db.learnedDungeons[109], "Sunken Temple")
    kill(fire, later, 8)
    T.eq(FRR.Reminder.IsShown(), true)
end)

T.test("addon_loot_without_quantity_change_still_hides_and_learns", function()
    local FRR, fire, game, _, later = world({ instance = { "Sunken Temple", "party", 1, "", 5, 0, false, 109 } })
    kill(fire, later, 7)
    game.quantity = 6
    fire("CURRENCY_DISPLAY_UPDATE", 3469, nil, nil)
    T.eq(FRR.db.learnedDungeons[109], "Sunken Temple")
end)

T.test("addon_two_kills_then_two_loots_credit_each_boss", function()
    local FRR, fire, game, _, later = world()
    kill(fire, later, 1); kill(fire, later, 2)
    game.quantity = 6; fire("CURRENCY_DISPLAY_UPDATE", 3469, 6, 1)
    game.quantity = 7; fire("CURRENCY_DISPLAY_UPDATE", 3469, 7, 1)
    T.eq(FRR.Rules.LootedToday(FRR.db, "Me-Realm", 1, 1000000000), true)
    T.eq(FRR.Rules.LootedToday(FRR.db, "Me-Realm", 2, 1000000000), true)
end)

T.test("addon_target_level_used_when_no_boss_frames", function()
    local FRR, fire, _, _, later = world({ bossLevel = 52 })
    _G.UnitExists = function(unit) return unit == "target" end
    kill(fire, later, 3)
    T.eq(FRR.last.bossLevel, 52); T.eq(FRR.Reminder.IsShown(), false)
end)

T.test("addon_wipe_shows_nothing_and_secret_ids_are_ignored", function()
    local FRR, fire = world()
    fire("ENCOUNTER_END", 9, "Boss", 1, 5, 0)
    T.eq(FRR.Reminder.IsShown(), false)
    _G.issecretvalue = function(v) return v == "S" end
    fire("ENCOUNTER_START", "S", "Boss", 1, 5)
    fire("ENCOUNTER_END", "S", "Boss", 1, 5, 1)
    T.eq(FRR.Reminder.IsShown(), false)
end)
