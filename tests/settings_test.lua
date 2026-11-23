local T = ...

local function fresh()
    local FRR = { db = {} }
    assert(loadfile(T.root .. "/Settings.lua"))("ForeverRealsReminder", FRR)
    return FRR, FRR.Settings
end

T.test("settings_defaults", function()
    local _, S = fresh()
    T.eq(S.Get("enabled"), true); T.eq(S.Get("duration"), 30)
    T.eq(S.Get("scale"), 1)
end)

T.test("settings_clamps_numbers", function()
    local _, S = fresh()
    S.Set("scale", 9); T.eq(S.Get("scale"), 2)
    S.Set("scale", 0); T.eq(S.Get("scale"), 0.5)
end)

T.test("settings_rejects_wrong_type_and_unknown_key", function()
    local _, S = fresh()
    S.Set("scale", "big"); T.eq(S.Get("scale"), 1)
    S.Set("nope", 1); T.eq(S.Get("nope"), nil)
end)

T.test("settings_reset_and_listeners", function()
    local _, S = fresh()
    local seen = 0
    S.OnChange(function() seen = seen + 1 end)
    S.Set("enabled", false); T.eq(S.Get("enabled"), false)
    S.Reset(); T.eq(S.Get("enabled"), true); T.eq(S.Get("duration"), 30)
    assert(seen >= 2)
end)
