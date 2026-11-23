local _, FRR = ...
local W = {}
FRR.Widgets = W

-- Flat dark widgets for the options panel.
W.WHITE8 = "Interface\\Buttons\\WHITE8X8"
W.CARD_BG = {1, 1, 1, 0.04}
W.BORDER = {1, 1, 1, 0.08}
W.MUTED = {0.6, 0.63, 0.69}
W.ACCENT = {0.2, 0.8, 1}

function W.panel(parent, color, border)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({bgFile = W.WHITE8, edgeFile = W.WHITE8, edgeSize = 1})
    f:SetBackdropColor(unpack(color))
    f:SetBackdropBorderColor(unpack(border or W.BORDER))
    return f
end

function W.text(parent, font, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", font)
    if r then fs:SetTextColor(r, g, b) end
    return fs
end

local function hoverBorder(f)
    f:SetScript("OnEnter", function(self) self.box:SetBackdropBorderColor(1, 1, 1, 0.25) end)
    f:SetScript("OnLeave", function(self) self.box:SetBackdropBorderColor(unpack(W.BORDER)) end)
end

-- A labelled check box. get() -> boolean, set(boolean). Call :Refresh() after outside changes.
function W.toggle(parent, label, get, set)
    local b = CreateFrame("Button", nil, parent)
    b.box = W.panel(b, W.CARD_BG)
    b.box:SetSize(16, 16)
    b.box:SetPoint("LEFT", 0, 0)
    b.box:EnableMouse(false)
    b.check = b.box:CreateTexture(nil, "OVERLAY")
    b.check:SetTexture(W.WHITE8)
    b.check:SetPoint("TOPLEFT", 3, -3)
    b.check:SetPoint("BOTTOMRIGHT", -3, 3)
    b.check:SetVertexColor(unpack(W.ACCENT))
    b.label = W.text(b, "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
    b.label:SetText(label)
    b:SetSize(24 + b.label:GetStringWidth(), 18)
    function b:Refresh() self.check:SetShown(get() and true or false) end
    b:SetScript("OnClick", function(self) set(not get()) self:Refresh() end)
    hoverBorder(b)
    b:Refresh()
    return b
end

function W.button(parent, label, onClick, width)
    local b = CreateFrame("Button", nil, parent)
    b.box = W.panel(b, W.CARD_BG)
    b.box:SetAllPoints()
    b.box:EnableMouse(false)
    b.label = W.text(b, "GameFontHighlightSmall")
    b.label:SetPoint("CENTER")
    b.label:SetText(label)
    b:SetSize(width or (b.label:GetStringWidth() + 28), 24)
    b:SetScript("OnClick", onClick)
    hoverBorder(b)
    return b
end

-- A horizontal slider with a value read-out. get() -> number, set(number), format(number) -> string.
function W.slider(parent, label, min, max, step, get, set, format)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(280, 40)
    f.label = W.text(f, "GameFontHighlightSmall")
    f.label:SetPoint("TOPLEFT", 0, 0)
    f.label:SetText(label)
    f.value = W.text(f, "GameFontHighlightSmall", unpack(W.MUTED))
    f.value:SetPoint("TOPRIGHT", 0, 0)
    local s = CreateFrame("Slider", nil, f)
    s:SetOrientation("HORIZONTAL")
    s:SetPoint("BOTTOMLEFT", 0, 6)
    s:SetPoint("BOTTOMRIGHT", 0, 6)
    s:SetHeight(8)
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    local track = s:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(W.WHITE8)
    track:SetAllPoints()
    track:SetVertexColor(1, 1, 1, 0.08)
    s:SetThumbTexture(W.WHITE8)
    s:GetThumbTexture():SetSize(10, 16)
    s:GetThumbTexture():SetVertexColor(unpack(W.ACCENT))
    local refreshing = false
    s:SetScript("OnValueChanged", function(_, v)
        f.value:SetText(format(v))
        if not refreshing then set(v) end
    end)
    function f:Refresh()
        refreshing = true
        s:SetValue(get())
        f.value:SetText(format(get()))
        refreshing = false
    end
    f:Refresh()
    return f
end
