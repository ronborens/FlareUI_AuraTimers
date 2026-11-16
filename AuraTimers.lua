local _, ns = ...

--------------------------------------------------
-- BUFF & DEBUFF TIMERS (an extension for FlareUI)
-- A spell on the bars whose buff is on you (Bloodrage, Lightning Shield), or whose debuff you put on
-- your target (Flame Shock), shows the time left on it in place of its cooldown, as Blizzard's Cooldown
-- Manager does: a gold swipe, the time in gold in the middle, and the stacks in the corner. Only your
-- own count.
-- Auras are secret in a fight, so the game draws them: each button has an AuraContainer of its own
-- (the player, or the target for a harmful spell) with one group filtered by the spell's aura IDs, and
-- the group's button binds the swipe, time and stacks. That art sits on the action button and is up
-- exactly while the aura is, covering the button's own cooldown with the aura's icon (section 3). The
-- aura IDs: the spell's own, the one the game ties to it (GetCooldownAuraBySpellID), and any of your
-- buffs seen out of a fight under the spell's name (saved: Bloodrage's buff has an ID of its own).
-- Containers are made out of a fight only: a button that first gets a spell in a fight waits for its
-- end.
--------------------------------------------------

--------------------------------------------------
-- 1. MODULE AND DATA
--------------------------------------------------
local AT = {}
ns.AuraTimers = AT

local DEFAULTS = { enabled = true, auraIDs = {} }
local BAR_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}
local GOLD = { 1, 0.82, 0.25 }
local SWIPE_ALPHA = 0.45
local FILTERS = { player = "HELPFUL|PLAYER", target = "HARMFUL|PLAYER" }
local GROUP = "aura"

local buttons = {}
local events
local pending = false        -- a sync on the next frame
local pendingBuild = false   -- buttons waiting for the end of a fight

local function Enabled()
    return ns.db and ns.db.enabled and true or false
end

local function Readable(v)
    return v ~= nil and (canaccessvalue == nil or canaccessvalue(v))
end

-- the spell in a button's slot (a spell, or a macro that casts one): its ID and name
local function ButtonSpell(button)
    local slot = button.action
    if not (Readable(slot) and type(slot) == "number" and slot > 0) then return nil end
    local ok, kind, id, subType = pcall(GetActionInfo, slot)
    if not (ok and Readable(kind) and Readable(id)) then return nil end
    if kind == "spell" or (kind == "macro" and Readable(subType) and subType == "spell") then
        local okName, name = pcall(C_Spell.GetSpellName, id)
        if okName and Readable(name) and type(name) == "string" then return id, name end
    end
end

--------------------------------------------------
-- 2. AURA IDS
--------------------------------------------------
local function Learned()
    if not ns.db then return nil end
    if type(ns.db.auraIDs) ~= "table" then ns.db.auraIDs = {} end
    return ns.db.auraIDs
end

-- the aura IDs a spell's buff or debuff can have, a key that changes when they do, and whether the
-- spell is known to leave an aura at all (the game ties one to it, or one was seen under its name)
local function AuraIDs(id, name)
    local set, list, known = { [id] = true }, { id }, false
    local ok, aura = pcall(C_UnitAuras.GetCooldownAuraBySpellID, id)
    if ok and Readable(aura) and type(aura) == "number" and aura > 0 then
        known = true
        if not set[aura] then
            set[aura] = true
            list[#list + 1] = aura
        end
    end
    local learned = Learned()
    for auraID in pairs(learned and learned[name] or {}) do
        known = true
        if not set[auraID] then
            set[auraID] = true
            list[#list + 1] = auraID
        end
    end
    table.sort(list)
    return set, table.concat(list, ","), known
end

-- Auras are secret (in an instance even out of combat). An error or an unreadable answer counts as
-- secret.
local function AurasLocked()
    if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
    local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
    return not ok or (canaccessvalue ~= nil and not canaccessvalue(secret)) or secret == true
end

-- Out of a fight: your own buffs by name, so a spell whose buff has another ID finds it
local function Learn()
    if InCombatLockdown() or AurasLocked() then return end
    local learned = Learned()
    if not learned then return end
    local changed = false
    for i = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL|PLAYER")
        if not ok or not aura then break end
        local name, id = aura.name, aura.spellId
        if Readable(name) and Readable(id) and type(name) == "string" and type(id) == "number" then
            learned[name] = learned[name] or {}
            if not learned[name][id] then
                learned[name][id] = true
                changed = true
            end
        end
    end
    return changed
end

--------------------------------------------------
-- 3. THE ART ON EACH BUTTON
-- While a timer shows, the button's own cooldown makes way for it, as on Blizzard's Cooldown Manager:
-- the time left on the aura, then the cooldown's once it ends. Whether the aura's frame is showing is
-- itself secret (IsVisible gives a secret boolean, and a test on it is an error), so nothing here asks:
-- the art carries the aura's icon, drawn over Blizzard's cooldown and its numbers. The game shows and
-- hides the art with the aura, and the cooldown under it is covered or seen with it.
-- The art is the aura button's child, and those frames have "secret aspects": no OnShow / OnHide script
-- may be set on them, and in a fight they are forbidden objects (any call from an addon is an error).
-- So the art is set up once, as the game makes it, and the game fills it from then on, the icon too
-- (SetIcon). It is only touched again out of a fight, behind IsForbidden.
--------------------------------------------------
-- A font like the one the button already uses, or the game's
local function CopyFont(fontString, from, fallbackSize)
    local path, size, flags
    if from and from.GetFont then path, size, flags = from:GetFont() end
    fontString:SetFont(path or STANDARD_TEXT_FONT, size or fallbackSize, flags or "OUTLINE")
end

-- FlareUI Borders lifts the cooldown numbers onto a frame of their own, just under the hotkey and count
-- texts (ActionBars.LiftCountdown). The timer's art has to cover those numbers and stay under the
-- texts, so that frame is set two levels lower, leaving the room.
local function LowerLift(button)
    local lift, texts = button.FlareUI_CountdownLift, button.TextOverlayContainer
    if not (lift and texts) then return end
    local level = math.max(button:GetFrameLevel() + 3, texts:GetFrameLevel() - 3)
    if lift:GetFrameLevel() > level then lift:SetFrameLevel(level) end
end

-- Over the cooldown and its numbers
local function Level(part, actionButton)
    local cd = actionButton.cooldown
    local base = cd and cd:GetFrameLevel() or actionButton:GetFrameLevel()
    local lift = actionButton.FlareUI_CountdownLift
    local numbers = cd and cd.GetCountdownFontString and cd:GetCountdownFontString()
    if lift and numbers and numbers:GetParent() == lift then
        LowerLift(actionButton)
        base = math.max(base, lift:GetFrameLevel())
    end
    part:SetFrameLevel(base + 1)
    part.Swipe:SetFrameLevel(base + 2)
end

-- The icon over the cooldown takes the button's icon's crop and masks
local function Paint(part, actionButton)
    local icon, cover = actionButton.icon, part.Icon
    if not (icon and cover) then return end
    cover:SetTexCoord(icon:GetTexCoord())
    for i = cover:GetNumMaskTextures(), 1, -1 do cover:RemoveMaskTexture(cover:GetMaskTexture(i)) end
    for i = 1, icon:GetNumMaskTextures() do cover:AddMaskTexture(icon:GetMaskTexture(i)) end
end

-- Level and crop again, for art that can be touched now (out of a fight)
local function Retouch(part, actionButton)
    if part:IsForbidden() then return end
    Level(part, actionButton)
    Paint(part, actionButton)
end

-- The timer's look on an action button: part (laid over the button) gets an icon over the cooldown, a
-- gold swipe over it, the time in gold in the middle and the stacks in the corner
local function CreateArt(part, actionButton)
    part:SetAllPoints(actionButton)
    local icon = actionButton.icon or actionButton

    part.Icon = part:CreateTexture(nil, "BACKGROUND")
    part.Icon:SetAllPoints(icon)

    local swipe = CreateFrame("Cooldown", nil, part, "CooldownFrameTemplate")
    swipe:SetAllPoints(icon)
    swipe:SetReverse(true)
    swipe:SetDrawEdge(false)
    swipe:SetDrawBling(false)
    swipe:SetHideCountdownNumbers(true)
    swipe:SetSwipeColor(GOLD[1], GOLD[2], GOLD[3], SWIPE_ALPHA)
    part.Swipe = swipe

    -- the texts are the swipe's own, so they draw over it at its level
    local countdown = actionButton.cooldown and actionButton.cooldown.GetCountdownFontString
        and actionButton.cooldown:GetCountdownFontString()
    part.Time = swipe:CreateFontString(nil, "OVERLAY")
    CopyFont(part.Time, countdown, 14)
    part.Time:SetPoint("CENTER", part, "CENTER", 0, 0)
    part.Time:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    part.Count = swipe:CreateFontString(nil, "OVERLAY")
    CopyFont(part.Count, actionButton.Count, 12)
    part.Count:SetPoint("BOTTOMRIGHT", part, "BOTTOMRIGHT", -4, 4)

    Level(part, actionButton)
    Paint(part, actionButton)
    return part
end

-- The time left as text: FlareUI's own format when it offers one, else the game's
local function BindTime(auraButton, fontString)
    local F = _G.FlareUI
    if not (type(F) == "table" and F.SetAuraDurationText and pcall(F.SetAuraDurationText, auraButton, fontString, false)) then
        pcall(auraButton.SetDurationText, auraButton, fontString, {})
    end
    fontString:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
end

-- The group's button: the timer's art, laid over the action button, filled by the game. The game can
-- make more than one over time (its pool): each one's art is kept, for Retouch.
local function InitFrame(actionButton)
    local made = setmetatable({}, { __mode = "k" })   -- the game can set a button up again: one art each
    return function(auraButton)
        local part = made[auraButton]
        if not part then
            part = CreateArt(CreateFrame("Frame", nil, auraButton), actionButton)
            made[auraButton] = part
            actionButton.FlareUIExt_AuraArts = actionButton.FlareUIExt_AuraArts or setmetatable({}, { __mode = "k" })
            actionButton.FlareUIExt_AuraArts[part] = true
        end
        pcall(auraButton.SetIcon, auraButton, part.Icon)
        pcall(auraButton.SetDurationCooldown, auraButton, part.Swipe)
        BindTime(auraButton, part.Time)
        pcall(auraButton.SetApplicationCount, auraButton, part.Count, {})
    end
end

--------------------------------------------------
-- 4. CONTAINERS
--------------------------------------------------
local function GroupOptions(actionButton, ids)
    local E = Enum or {}
    return {
        maxFrameCount = 1,
        candidateFilters = { includeSpellIDs = ids },
        sortMethod = E.AuraContainerSortMethod and E.AuraContainerSortMethod.Default,
        sortDirection = E.AuraContainerSortDirection and E.AuraContainerSortDirection.Normal,
        initializeFrame = InitFrame(actionButton),
        layout = { elementWidth = 1, elementHeight = 1, elementSpacing = 0, lineSpacing = 0 },
    }
end

-- Made out of a fight only: nil (and the button waits) in one
local function Build(button, unit, ids)
    if InCombatLockdown() then
        pendingBuild = true
        return nil
    end
    if C_AddOns.DoesAddOnExist("Blizzard_AuraContainer") and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    end
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, button, "CustomAuraContainerTemplate")
    if not (ok and type(container) == "table" and container.AddAuraGroup) then
        AT.failed = true
        return nil
    end
    container:SetSize(1, 1)
    container:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    container:SetUnit(unit)
    if not pcall(container.AddAuraGroup, container, GROUP, FILTERS[unit], GroupOptions(button, ids)) then
        AT.failed = true
        return nil
    end
    container:Show()
    pcall(container.SetEnabled, container, true)
    local t = { container = container, unit = unit }
    button.FlareUIExt_AuraTimer = t
    return t
end

local function Disable(t)
    if not t or t.sig == nil then return end
    -- (refused in a fight: tried again at its end)
    if pcall(t.container.SetAuraGroupEnabled, t.container, GROUP, false) then
        t.sig = nil
    else
        pendingBuild = true
    end
end

-- Points a button's group at its spell's aura (a no-op when nothing changed)
local function Sync(button, on)
    local t = button.FlareUIExt_AuraTimer
    local id, name
    if on then id, name = ButtonSpell(button) end
    if not id then
        Disable(t)
        return
    end
    local okHarm, harmful = pcall(C_Spell.IsSpellHarmful, id)
    local unit = (okHarm and Readable(harmful) and harmful) and "target" or "player"
    local ids, idKey, known = AuraIDs(id, name)
    -- A spell cast on yourself or a friend gets a watcher only once it is known to leave a buff on
    -- you: most (heals, mounts, professions) never do, and each watcher is work on every buff change.
    -- A spell cast on an enemy is always watched: a debuff on a target can't be learned beforehand.
    if unit == "player" and not known then
        Disable(t)
        return
    end
    local sig = unit .. ":" .. idKey
    if t and t.sig == sig then return end
    if not t then
        if AT.failed then return end
        t = Build(button, unit, ids)
        if not t then return end
    else
        local container = t.container
        if unit ~= t.unit then
            if not pcall(container.SetUnit, container, unit) then
                pendingBuild = true
                return
            end
            pcall(container.SetAuraGroupFilterString, container, GROUP, FILTERS[unit])
            t.unit = unit
        end
        -- (refused in a fight: tried again at its end)
        if not (pcall(container.SetAuraGroupCandidateFilters, container, GROUP, { includeSpellIDs = ids })
            and pcall(container.SetAuraGroupEnabled, container, GROUP, true)) then
            pendingBuild = true
            return
        end
    end
    t.sig = sig
end

local function SyncAll()
    local on = Enabled()
    for _, button in ipairs(buttons) do
        Sync(button, on)
        -- (FlareUI Borders may have lifted the cooldown numbers since, or the icon lost its masks)
        for art in pairs(button.FlareUIExt_AuraArts or {}) do Retouch(art, button) end
    end
end

-- slot and page changes come in bursts: one pass on the next frame
local function Schedule()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = false
        SyncAll()
    end)
end

-- The containers only follow UNIT_AURA: a new target would keep the old one's debuffs
local function TargetChanged()
    for _, button in ipairs(buttons) do
        local t = button.FlareUIExt_AuraTimer
        if t and t.sig and t.unit == "target" then pcall(t.container.UpdateAllAuras, t.container) end
    end
end

--------------------------------------------------
-- 5. EVENTS
--------------------------------------------------
local SYNC_EVENTS = {
    ACTIONBAR_SLOT_CHANGED = true, ACTIONBAR_PAGE_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true,
    UPDATE_SHAPESHIFT_FORM = true, SPELLS_CHANGED = true, PLAYER_ENTERING_WORLD = true,
}

local learnPending = false
local function OnEvent(_, event)
    if SYNC_EVENTS[event] then
        Schedule()
    elseif event == "PLAYER_TARGET_CHANGED" then
        TargetChanged()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingBuild then
            pendingBuild = false
            Schedule()
        end
        -- a buff first cast in the fight and still up is learned now
        C_Timer.After(1, function() if Learn() then Schedule() end end)
    elseif event == "UNIT_AURA" and not learnPending then
        -- a burst of aura changes is read once, a second later
        learnPending = true
        C_Timer.After(1, function()
            learnPending = false
            if Learn() then Schedule() end
        end)
    end
end

--------------------------------------------------
-- 6. ON AND OFF
--------------------------------------------------
local function Setup()
    if events then return end
    for _, prefix in ipairs(BAR_PREFIXES) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button then buttons[#buttons + 1] = button end
        end
    end
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
    -- FlareUI restyles the buttons (and lifts the cooldown numbers again) whenever its bars refresh
    local bars = type(_G.FlareUI) == "table" and _G.FlareUI.ActionBars
    if type(bars) == "table" then
        if type(bars.LiftCountdown) == "function" then
            hooksecurefunc(bars, "LiftCountdown", function(button, on)
                if on and Enabled() and type(button) == "table" then LowerLift(button) end
            end)
        end
        if type(bars.Refresh) == "function" then
            hooksecurefunc(bars, "Refresh", function() if Enabled() then Schedule() end end)
        end
    end
end

-- On and off live. Never on this session: nothing is made.
function AT.Refresh()
    if not events and not Enabled() then return end
    Setup()
    events:UnregisterAllEvents()
    if Enabled() then
        for event in pairs(SYNC_EVENTS) do events:RegisterEvent(event) end
        events:RegisterEvent("PLAYER_TARGET_CHANGED")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:RegisterUnitEvent("UNIT_AURA", "player")
        Learn()
    end
    SyncAll()
end

local started = false
ns.OnReady("FlareUI_AuraTimersDB", DEFAULTS, function()
    ns.RegisterOptions("FlareUI: Buff & Debuff Timers", {
        { key = "enabled", label = "Buff & Debuff Timers",
          flare = { key = "ab.extAuraTimers", section = "ab.buttonAppearance", half = true },
          tip = "While a spell's effect is up, its action button shows the time left in gold instead of the cooldown, with its stacks. Your buffs (Bloodrage, Lightning Shield) and your debuffs on your target (Flame Shock). Works in combat too. A buff's timer starts showing after the first time you have that buff out of combat." },
    }, "/flaretimers", function() if started then AT.Refresh() end end)
end, function()
    started = true
    AT.Refresh()
end)
