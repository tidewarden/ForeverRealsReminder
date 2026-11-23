local _, FRR = ...
local S = FRR.Settings

-- The on-screen reminder: the Real's icon at the top of the screen with a countdown.
-- /frr unlock shows it with a drag handle; the position is saved.
local Reminder = {}
FRR.Reminder = Reminder

local FALLBACK_ICON = 134400 -- question mark, until the currency info is available
local frame, ticker, hideAt
local unlocked = false

local function place()
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", S.Get("x"), S.Get("y"))
    frame:SetScale(S.Get("scale"))
end

local function build()
    if frame then return end
    frame = CreateFrame("Frame", "ForeverRealsReminderFrame", UIParent)
    frame:SetSize(260, 64)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save as an offset from the top centre of the screen, the anchor place() uses.
        local scale = self:GetScale()
        local x = self:GetCenter() * scale - UIParent:GetWidth() / 2
        local y = self:GetTop() * scale - UIParent:GetHeight()
        S.Set("x", math.floor(x / scale + 0.5)); S.Set("y", math.floor(y / scale + 0.5))
        place()
    end)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(56, 56)
    frame.icon:SetPoint("LEFT", 4, 0)
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -6)
    frame.title:SetText("Loot your Real!")
    frame.title:SetTextColor(1, 0.82, 0)

    frame.sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.sub:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)

    frame:Hide()
    place()
    S.OnChange(function(key) if key == "x" or key == "y" or key == "scale" then place() end end)
end

function Reminder.IsShown() return frame ~= nil and frame:IsShown() end

local function setIcon()
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(FRR.Rules.CURRENCY)
    frame.icon:SetTexture(info and info.iconFileID or FALLBACK_ICON)
end

local function tick()
    if unlocked then return end
    local left = math.ceil(hideAt - GetTime())
    if left <= 0 then Reminder.Hide(); return end
    frame.sub:SetText(Reminder.subtitle .. "  " .. left .. "s")
end

-- subtitle: the boss name, so you know which corpse to loot.
function Reminder.Show(subtitle)
    build()
    setIcon()
    Reminder.subtitle = subtitle or "Tarnished Undermine Real"
    hideAt = GetTime() + S.Get("duration")
    frame:Show()
    tick()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(0.25, tick)
end

function Reminder.Hide()
    if ticker then ticker:Cancel(); ticker = nil end
    if frame and not unlocked then frame:Hide() end
end

function Reminder.ToggleUnlock()
    build()
    unlocked = not unlocked
    frame:EnableMouse(unlocked)
    if unlocked then
        setIcon()
        frame.sub:SetText("Drag me, then /frr lock")
        frame:Show()
    else
        frame:Hide()
    end
    return unlocked
end
