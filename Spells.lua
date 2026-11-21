local _, ns = ...

--------------------------------------------------
-- TIMER SPELLS (the window behind the Choose Spells button)
-- A list of the spells on your bars that can show a timer, each with a tick box: untick one and its
-- button shows its cooldown as usual, with no timer (AuraTimers.lua, IGNORED SPELLS). Spells already
-- switched off stay on the list while they are off your bars, so they can be switched back on.
-- A plain window of the addon's own: it opens in a fight too, but a timer switched off there goes at
-- the fight's end.
--------------------------------------------------
local Picker = { rows = {} }
ns.SpellPicker = Picker

local WIDTH, HEIGHT, ROW = 320, 440, 26
local QUESTION_MARK = 134400

local function Timers() return ns.AuraTimers end

-- A tick box, from the game's template or (should a client lack it) the same art by hand
local function NewCheck(parent)
    local ok, check = pcall(CreateFrame, "CheckButton", nil, parent, "UICheckButtonTemplate")
    if ok and check then return check end
    check = CreateFrame("CheckButton", nil, parent)
    check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    check:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    return check
end

local function Row(i)
    local row = Picker.rows[i]
    if row then return row end
    row = NewCheck(Picker.content)
    row:SetSize(24, 24)
    row:SetPoint("TOPLEFT", Picker.content, "TOPLEFT", 0, -(i - 1) * ROW)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row, "RIGHT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.label:SetWidth(WIDTH - 110)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    -- the name is part of the tick box: a click on it ticks too
    row:SetHitRectInsets(0, -(WIDTH - 80), 0, 0)
    row:SetScript("OnClick", function(self)
        local timers = Timers()
        if timers and self.spell then timers.SetIgnored(self.spell, not self:GetChecked()) end
    end)
    Picker.rows[i] = row
    return row
end

function Picker.Fill()
    local timers = Timers()
    local list = timers and timers.Candidates() or {}
    for i, spell in ipairs(list) do
        local row = Row(i)
        row.spell = spell.name
        row.icon:SetTexture(spell.icon or QUESTION_MARK)
        row.label:SetText(spell.name)
        row:SetChecked(not spell.ignored)
        row:Show()
    end
    for i = #list + 1, #Picker.rows do Picker.rows[i]:Hide() end
    Picker.content:SetHeight(math.max(1, #list * ROW))
    Picker.empty:SetShown(#list == 0)
end

local function Create()
    local name = "FlareUI_AuraTimersSpells"
    local ok, frame = pcall(CreateFrame, "Frame", name, UIParent, "BasicFrameTemplateWithInset")
    if not (ok and frame) then
        frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 0, 0)
    end
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    -- Escape closes it
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, name) end

    local title = frame.TitleText
    if not title then
        title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -8)
    end
    title:SetText("Timer Spells")

    local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 14, -32)
    hint:SetPoint("TOPRIGHT", -14, -32)
    hint:SetJustifyH("LEFT")
    hint:SetText("Untick a spell to stop showing its timer. Its button then shows the cooldown as usual.")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -66)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 50, 1)
    scroll:SetScrollChild(content)
    Picker.content = content

    Picker.empty = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    Picker.empty:SetPoint("TOPLEFT", 16, -76)
    Picker.empty:SetPoint("TOPRIGHT", -16, -76)
    Picker.empty:SetJustifyH("LEFT")
    Picker.empty:SetText("No spell on your bars can show a timer yet. Attack spells appear straight away; a buff spell appears after you have had its buff once out of combat.")

    -- the bars can change while it is open
    frame:SetScript("OnShow", Picker.Fill)
    frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    frame:SetScript("OnEvent", function(self) if self:IsShown() then Picker.Fill() end end)

    Picker.frame = frame
    return frame
end

-- Open, or close when it is open
function Picker.Open()
    local frame = Picker.frame or Create()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        frame:Raise()
    end
end
