local _, FRR = ...
local Settings = {}
FRR.Settings = Settings

-- Saved in ForeverRealsReminderDB (FRR.db). An unset value means the default.
local DEFAULTS = {
    enabled = true,
    scale = 1,
    duration = 30,   -- seconds the reminder stays up if you don't loot
    minLevel = 60,   -- your level for reminders (Reals drop from level 55+ bosses)
    x = 0,           -- offset from the top centre of the screen
    y = -140,
}
local LIMITS = {
    scale = { 0.5, 2 },
    duration = { 5, 120 },
    minLevel = { 1, 60 },
}
local listeners = {}

Settings.DEFAULTS, Settings.LIMITS = DEFAULTS, LIMITS

function Settings.Get(key)
    local value = FRR.db and FRR.db[key]
    if value == nil then return DEFAULTS[key] end
    return value
end

function Settings.Set(key, value)
    local default = DEFAULTS[key]
    if default == nil or type(value) ~= type(default) or not FRR.db then return end
    local limit = LIMITS[key]
    if limit then value = math.max(limit[1], math.min(limit[2], value)) end
    FRR.db[key] = value
    for _, fn in ipairs(listeners) do fn(key, value) end
end

function Settings.Toggle(key)
    Settings.Set(key, not Settings.Get(key))
end

function Settings.Reset()
    if not FRR.db then return end
    for key in pairs(DEFAULTS) do FRR.db[key] = nil end
    for key, value in pairs(DEFAULTS) do
        for _, fn in ipairs(listeners) do fn(key, value) end
    end
end

function Settings.OnChange(fn) table.insert(listeners, fn) end
