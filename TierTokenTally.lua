local ADDON_NAME, ns = ...

---------------------------------------------------------------------------
-- Tier token mappings
---------------------------------------------------------------------------

local CLASSID_TO_TOKEN = {
    [3]  = "Voidcast",    -- Hunter
    [7]  = "Voidcast",    -- Shaman
    [13] = "Voidcast",    -- Evoker
    [4]  = "Voidcured",   -- Rogue
    [10] = "Voidcured",   -- Monk
    [11] = "Voidcured",   -- Druid
    [12] = "Voidcured",   -- Demon Hunter
    [1]  = "Voidforged",  -- Warrior
    [2]  = "Voidforged",  -- Paladin
    [6]  = "Voidforged",  -- Death Knight
    [5]  = "Voidwoven",   -- Priest
    [8]  = "Voidwoven",   -- Mage
    [9]  = "Voidwoven",   -- Warlock
}

local TOKEN_ORDER = { "Voidcast", "Voidcured", "Voidforged", "Voidwoven" }

local TOKEN_COLORS = {
    Voidcast   = { r = 0.00, g = 0.80, b = 1.00 },
    Voidcured  = { r = 0.27, g = 1.00, b = 0.27 },
    Voidforged = { r = 1.00, g = 0.27, b = 0.27 },
    Voidwoven  = { r = 1.00, g = 0.80, b = 0.00 },
}

local TOKEN_CLASSES = {
    Voidcast   = "(Hunter, Shaman, Evoker)",
    Voidcured  = "(Rogue, Monk, Druid, Demon Hunter)",
    Voidforged = "(Warrior, Paladin, Death Knight)",
    Voidwoven  = "(Priest, Mage, Warlock)",
}

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

local db
local settingsCategory

---------------------------------------------------------------------------
-- Token counting
---------------------------------------------------------------------------

local function NewTokenTable()
    return { Voidcast = 0, Voidcured = 0, Voidforged = 0, Voidwoven = 0 }
end

local function CountGroupTokens()
    local tokens = NewTokenTable()
    local count = 0

    if IsInRaid(LE_PARTY_CATEGORY_HOME) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
        for i = 1, GetNumGroupMembers() do
            local _, _, classID = UnitClass("raid" .. i)
            local token = classID and CLASSID_TO_TOKEN[classID]
            if token then
                tokens[token] = tokens[token] + 1
                count = count + 1
            end
        end
    elseif IsInGroup() then
        local _, _, classID = UnitClass("player")
        local token = classID and CLASSID_TO_TOKEN[classID]
        if token then
            tokens[token] = tokens[token] + 1
            count = count + 1
        end
        for i = 1, GetNumGroupMembers() - 1 do
            local _, _, classID = UnitClass("party" .. i)
            local token = classID and CLASSID_TO_TOKEN[classID]
            if token then
                tokens[token] = tokens[token] + 1
                count = count + 1
            end
        end
    end

    return tokens, count
end

---------------------------------------------------------------------------
-- Report to raid chat
---------------------------------------------------------------------------

local function ReportToRaidChat()
    local channel
    if IsInRaid(LE_PARTY_CATEGORY_HOME) then
        channel = "RAID"
    elseif IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
        channel = "INSTANCE_CHAT"
    else
        print("Tier Token Tally: Must be in a raid to report")
        return
    end
    local tokens, count = CountGroupTokens()
    SendChatMessage("--- Report from Tier Token Tally ---", channel)
    for _, name in ipairs(TOKEN_ORDER) do
        SendChatMessage(format("%s %s: %d", name, TOKEN_CLASSES[name], tokens[name]), channel)
    end
end

---------------------------------------------------------------------------
-- Tooltip rendering
---------------------------------------------------------------------------

local function ShowMinimapTooltip(anchor)
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
    GameTooltip:SetOwner(anchor, "ANCHOR_LEFT")
    GameTooltip:AddLine("Tier Token Tally v" .. version, 1, 1, 1)

    local tokens, count = CountGroupTokens()
    if count > 0 then
        GameTooltip:AddLine(" ")
        for _, name in ipairs(TOKEN_ORDER) do
            local c = TOKEN_COLORS[name]
            GameTooltip:AddDoubleLine(name .. " " .. TOKEN_CLASSES[name], tokens[name], c.r, c.g, c.b, 1, 1, 1)
        end
    else
        GameTooltip:AddLine("Not in a group", 0.7, 0.7, 0.7)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-Click to report to raid chat", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-Click to open settings", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

local function OpenSettings()
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory:GetID())
    end
end

---------------------------------------------------------------------------
-- Minimap button (no libraries)
---------------------------------------------------------------------------

local ICON = "Interface\\Icons\\INV_Chest_Plate16"

local minimapButton = CreateFrame("Button", "TierTokenTallyMinimapButton", Minimap)
minimapButton:Hide()
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:RegisterForClicks("AnyUp")

local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetSize(54, 54)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetTexture(ICON)
icon:SetPoint("CENTER", 0, 1)

local function UpdateMinimapButtonPosition()
    local angle = math.rad(db and db.minimapAngle or 220)
    local radius = (Minimap:GetWidth() / 2) + 10
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

minimapButton:SetScript("OnEnter", function(self)
    ShowMinimapTooltip(self)
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

minimapButton:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        OpenSettings()
    else
        ReportToRaidChat()
    end
end)

-- Dragging to reposition around minimap edge
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
        UpdateMinimapButtonPosition()
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

---------------------------------------------------------------------------
-- Settings panel (Options > AddOns)
---------------------------------------------------------------------------

local function CreateSettingsPanel()
    local panel = CreateFrame("Frame")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Tier Token Tally")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetText("Displays tier token distribution for your raid group.")

    -- Show Minimap Button checkbox
    local minimapCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)
    minimapCheck.text:SetText("Show Minimap Button")
    minimapCheck:SetChecked(db.showMinimap ~= false)
    minimapCheck:SetScript("OnClick", function(self)
        db.showMinimap = self:GetChecked()
        if db.showMinimap then
            minimapButton:Show()
        else
            minimapButton:Hide()
        end
    end)

    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, C_AddOns.GetAddOnMetadata(ADDON_NAME, "Title"))
    Settings.RegisterAddOnCategory(settingsCategory)
end

---------------------------------------------------------------------------
-- Event handling
---------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        self:UnregisterEvent("ADDON_LOADED")

        -- Initialize saved variables
        TierTokenTallyDB = TierTokenTallyDB or {}
        db = TierTokenTallyDB
        if db.minimapAngle == nil then db.minimapAngle = 220 end
        if db.showMinimap == nil then db.showMinimap = true end

        -- Position and show/hide minimap button
        UpdateMinimapButtonPosition()
        if db.showMinimap then
            minimapButton:Show()
        end

        -- Create settings panel
        CreateSettingsPanel()
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

SLASH_TIERTOKENTALLY1 = "/tiertokentally"
SLASH_TIERTOKENTALLY2 = "/ttt"
SlashCmdList["TIERTOKENTALLY"] = function(msg)
    msg = strtrim(msg):lower()
    if msg == "report" then
        ReportToRaidChat()
    elseif msg == "settings" or msg == "config" or msg == "options" then
        OpenSettings()
    else
        local tokens, count = CountGroupTokens()
        if count > 0 then
            for _, name in ipairs(TOKEN_ORDER) do
                local c = TOKEN_COLORS[name]
                local hex = format("|cFF%02X%02X%02X", c.r * 255, c.g * 255, c.b * 255)
                print(format("%s%s|r %s: %d", hex, name, TOKEN_CLASSES[name], tokens[name]))
            end
        else
            print("Tier Token Tally: Not in a group")
        end
    end
end
