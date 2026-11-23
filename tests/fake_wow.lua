-- A tiny fake of the WoW frame API for stub tests. fresh() rebuilds the whole world and loads the
-- addon files you ask for. Extend NewFrame as your code starts calling more frame methods; anything
-- not modelled (textures, lines, font strings) is a harmless no-op object. Copy the richer version in
-- ~/repos/GatherLiteHud/tests/fake_wow.lua if you need Minimap, bindings, CVars or hooksecurefunc.
local unpack = unpack or table.unpack
local M = {}

local noop = {}
setmetatable(noop, { __index = function() return function() return noop end end })

local function NewFrame(world, name, objType, parent)
    local f = { _name = name, _type = objType or "Frame", _parent = parent, _shown = true,
                _w = 100, _h = 100, _events = {}, _scripts = {}, _points = {} }
    function f:GetName() return self._name end
    function f:GetParent() return self._parent end
    function f:SetPoint(...) table.insert(self._points, { ... }) end
    function f:ClearAllPoints() self._points = {} end
    function f:SetSize(w, h) self._w, self._h = w, h end
    function f:GetWidth() return self._w end
    function f:GetHeight() return self._h end
    function f:SetShown(v) self._shown = v and true or false end
    function f:Show() self._shown = true end
    function f:Hide() self._shown = false end
    function f:IsShown() return self._shown end
    function f:RegisterEvent(e) self._events[e] = true end
    function f:RegisterUnitEvent(e) self._events[e] = true end
    function f:SetScript(n, fn) self._scripts[n] = fn end
    function f:GetScript(n) return self._scripts[n] end
    function f:CreateTexture() return noop end
    function f:CreateFontString() return noop end
    setmetatable(f, { __index = function() return function() return noop end end }) -- unmodelled methods
    table.insert(world.frames, f)
    return f
end

function M.fresh(root, opts)
    opts = opts or {}
    local world = { frames = {}, printed = {} }
    _G.UIParent = NewFrame(world, "UIParent")
    _G.SlashCmdList = {}
    _G.ForeverRealsReminderDB = nil
    _G.CreateFrame = function(objType, name, parent) return NewFrame(world, name, objType, parent or _G.UIParent) end
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) table.insert(world.printed, msg) end }

    local FRR = { db = {} }
    FRR.Print = function(msg) table.insert(world.printed, msg) end
    for _, file in ipairs(opts.files or { "Settings.lua" }) do
        local chunk, err = loadfile(root .. "/" .. file)
        if not chunk then error(err) end
        chunk("ForeverRealsReminder", FRR)
    end
    return FRR, world
end

return M
