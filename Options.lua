local _, FRR = ...
local Options = {}
FRR.Options = Options

local W = FRR.Widgets
local NAME = "ForeverRealsReminder"

local function build()
    local S = FRR.Settings
    local panel = CreateFrame("Frame")
    panel.name = NAME
    local items = {}

    local title = W.text(panel, "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(NAME)
    local blurb = W.text(panel, "GameFontNormalSmall", unpack(W.MUTED))
    blurb:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    blurb:SetText("Reminds you to loot your Tarnished Undermine Real after a dungeon boss kill.")

    local enabled = W.toggle(panel, "Remind me to loot my Real after a boss kill", function() return S.Get("enabled") end, function(v) S.Set("enabled", v) end)
    enabled:SetPoint("TOPLEFT", 16, -70)
    items[#items + 1] = enabled

    local limit = S.LIMITS.scale
    local scale = W.slider(panel, "Size", limit[1], limit[2], 0.05,
        function() return S.Get("scale") end, function(v) S.Set("scale", v) end,
        function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end)
    scale:SetPoint("TOPLEFT", 16, -110)
    items[#items + 1] = scale

    limit = S.LIMITS.duration
    local duration = W.slider(panel, "Stays up for", limit[1], limit[2], 5,
        function() return S.Get("duration") end, function(v) S.Set("duration", v) end,
        function(v) return string.format("%d s", v) end)
    duration:SetPoint("TOPLEFT", 16, -160)
    items[#items + 1] = duration

    local test = W.button(panel, "Show a test reminder", function() FRR.Reminder.Show("Test") end, 180)
    test:SetPoint("TOPLEFT", 16, -215)
    local move = W.button(panel, "Unlock to move", function() FRR.Reminder.ToggleUnlock() end, 180)
    move:SetPoint("LEFT", test, "RIGHT", 10, 0)

    local reset = W.button(panel, "Reset to defaults", function()
        S.Reset()
        for _, item in ipairs(items) do item:Refresh() end
    end, 180)
    reset:SetPoint("TOPLEFT", 16, -255)

    panel:SetScript("OnShow", function() for _, item in ipairs(items) do item:Refresh() end end)
    return panel
end

function Options.Register()
    local panel = build()
    if Settings and Settings.RegisterCanvasLayoutCategory then -- the game's Settings, not ours
        local category = Settings.RegisterCanvasLayoutCategory(panel, NAME)
        Settings.RegisterAddOnCategory(category)
        Options.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        Options.panel = panel
    end
end

function Options.Open()
    if Options.categoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(Options.categoryID)
    elseif Options.panel and InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(Options.panel) -- the first call only opens the frame
        InterfaceOptionsFrame_OpenToCategory(Options.panel)
    end
end
