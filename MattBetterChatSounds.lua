--[[
    MattBetterChatSounds
    Enhances chat by playing custom sounds for various chat events.
    Compatible with Retail, Classic Era, and Classic (Cataclysm/Wrath/etc.)
]]

-- ============================================================================
--  ADDON SETUP
-- ============================================================================
local addonName = "MattBetterChatSounds"
MattBetterChatSounds = {}
local addon = MattBetterChatSounds

-- ============================================================================
--  VERSION DETECTION
-- ============================================================================
local _, _, _, tocVersion = GetBuildInfo()
local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local isClassicEra = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)  -- Classic Era Anniversary
local isTBC = (WOW_PROJECT_ID == (WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5))  -- TBC Anniversary
local isMoP = (WOW_PROJECT_ID == (WOW_PROJECT_MISTS_OF_PANDARIA_CLASSIC or 17))  -- MoP Remix
local isClassic = isClassicEra or isTBC or isMoP
local hasInstanceChat = isRetail or isMoP  -- Dungeon Finder available in MoP and Retail
local hasBattleNet = isRetail  -- Battle.net whispers only in Retail

-- ============================================================================
--  LIBRARIES (Optional)
-- ============================================================================
local LDB, LDBIcon

-- ============================================================================
--  SOUND FILES
-- ============================================================================
local SOUND_PATH = "Interface\\AddOns\\MattBetterChatSounds\\Sounds\\"
local NAO_FONT_PATH = "Interface\\AddOns\\MattBetterChatSounds\\Media\\Naowh.ttf"
local FONT_SIZES = { title = 18, normal = 12, small = 11 }

-- Shared sound files (work on all versions)
local soundFiles = {
    CHAT_MSG_WHISPER        = SOUND_PATH .. "whisper.ogg",
    CHAT_MSG_PARTY          = SOUND_PATH .. "bcs.mp3",
    CHAT_MSG_PARTY_LEADER   = SOUND_PATH .. "text.mp3",
    CHAT_MSG_RAID           = SOUND_PATH .. "bcs.mp3",
    CHAT_MSG_RAID_LEADER    = SOUND_PATH .. "text.mp3",
    CHAT_MSG_RAID_WARNING   = SOUND_PATH .. "text2.mp3",
    CHAT_MSG_GUILD          = SOUND_PATH .. "guild.mp3",
}

-- Retail-only events
if hasBattleNet then
    soundFiles.CHAT_MSG_BN_WHISPER              = SOUND_PATH .. "whisper.ogg"
end

-- Instance chat (MoP, Retail) - Dungeon Finder available
if hasInstanceChat then
    soundFiles.CHAT_MSG_INSTANCE_CHAT           = SOUND_PATH .. "bcs.mp3"
    soundFiles.CHAT_MSG_INSTANCE_CHAT_LEADER    = SOUND_PATH .. "text.mp3"
end

-- ============================================================================
--  EVENT LABELS (for UI)
-- ============================================================================
local eventLabels = {
    CHAT_MSG_WHISPER                = "Whisper Messages",
    CHAT_MSG_BN_WHISPER             = "Battle.net Whispers",
    CHAT_MSG_PARTY                  = "Party Chat",
    CHAT_MSG_PARTY_LEADER           = "Party Leader Chat",
    CHAT_MSG_RAID                   = "Raid Chat",
    CHAT_MSG_RAID_LEADER            = "Raid Leader Chat",
    CHAT_MSG_RAID_WARNING           = "Raid Warning",
    CHAT_MSG_INSTANCE_CHAT          = "Instance Chat",
    CHAT_MSG_INSTANCE_CHAT_LEADER   = "Instance Leader Chat",
    CHAT_MSG_GUILD                  = "Guild Chat",
}

-- ============================================================================
--  DATABASE INITIALIZATION
-- ============================================================================
local function InitializeDatabase()
    MattBetterChatSoundsDB = MattBetterChatSoundsDB or {}
    
    -- Default all sounds to enabled
    for eventKey in pairs(soundFiles) do
        if MattBetterChatSoundsDB[eventKey] == nil then
            MattBetterChatSoundsDB[eventKey] = true
        end
    end
    
    -- Initialize minimap icon settings (LibDBIcon convention)
    if MattBetterChatSoundsDB.minimapIcon == nil then
        MattBetterChatSoundsDB.minimapIcon = { hide = false }
    end
end
addon.InitializeDatabase = InitializeDatabase

-- ============================================================================
--  SOUND PLAYBACK
-- ============================================================================
local function PlayChatSound(event)
    local soundFile = soundFiles[event]
    if not soundFile then return end
    
    -- Check if this sound is enabled
    if MattBetterChatSoundsDB[event] == false then
        return
    end
    
    -- Play the sound using Dialog channel (most reliable in instances)
    PlaySoundFile(soundFile, "Dialog")
end

-- ============================================================================
--  CHAT EVENT HANDLING
-- ============================================================================
local chatFrame = CreateFrame("Frame")

chatFrame:SetScript("OnEvent", function(self, event, message, sender, ...)
    -- Don't play sounds for our own messages
    -- Note: In retail WoW, sender can be a "secret" value in combat/instances
    -- which cannot be converted to string. We use pcall to safely handle this.
    local playerName = UnitName("player")
    if sender then
        local success, senderName = pcall(Ambiguate, sender, "short")
        if success and senderName == playerName then
            return
        end
        -- If pcall failed (secret value), we still play the sound
        -- since we can't determine if it's from the player or not
    end
    
    PlayChatSound(event)
end)

-- Register all chat events for the current game version
local function RegisterChatEvents()
    for eventKey in pairs(soundFiles) do
        chatFrame:RegisterEvent(eventKey)
    end
end

RegisterChatEvents()

-- ============================================================================
--  MINIMAP BUTTON (Optional)
-- ============================================================================
local function InitializeMinimapButton()
    -- Try to get libraries from LibStub first
    if LibStub then
        LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
        LDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    end
    
    -- If we got both libraries, use the proper LDB approach
    if LDB and LDBIcon then
        addon.ChatSoundsLDB = LDB:NewDataObject(addonName, {
            type = "launcher",
            text = "Matt Better Chat Sounds",
            icon = "Interface\\AddOns\\MattBetterChatSounds\\Images\\bcsicon.png",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    addon:ToggleOptions()
                elseif button == "RightButton" then
                    addon:ToggleMinimapButton()
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("Matt Better Chat Sounds")
                tooltip:AddLine("|cffffff00Left-click|r to open settings")
                tooltip:AddLine("|cffffff00Right-click|r to hide minimap button")
            end,
        })
        
        if not LDBIcon:IsRegistered(addonName) then
            LDBIcon:Register(addonName, addon.ChatSoundsLDB, MattBetterChatSoundsDB.minimapIcon)
        end
        
        return true
    end
    
    -- Fallback: Create a draggable minimap button if libraries aren't available
    local rad, cos, sin = math.rad, math.cos, math.sin
    local function UpdateMinimapButtonPosition(button, angle)
        local radian = rad(angle or 225)
        local x = cos(radian) * ((Minimap:GetWidth() / 2) + 5)
        local y = sin(radian) * ((Minimap:GetHeight() / 2) + 5)
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    local minimapFrame = CreateFrame("Button", "MattBetterChatSoundsMinimapButton", Minimap)
    minimapFrame:SetSize(31, 31)
    minimapFrame:SetFrameStrata("MEDIUM")
    minimapFrame:SetFrameLevel(8)
    minimapFrame:SetMovable(true)
    minimapFrame:EnableMouse(true)
    minimapFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapFrame:RegisterForDrag("LeftButton")
    minimapFrame:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    
    -- Store saved position angle (default 225 degrees = bottom-left)
    MattBetterChatSoundsDB.minimapPos = MattBetterChatSoundsDB.minimapPos or 225
    UpdateMinimapButtonPosition(minimapFrame, MattBetterChatSoundsDB.minimapPos)
    
    -- Border overlay
    local overlay = minimapFrame:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", 0, 0)
    
    -- Background
    local bg = minimapFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("CENTER", 0, 1)
    
    -- Icon
    local icon = minimapFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\AddOns\\MattBetterChatSounds\\Images\\bcsicon.png")
    icon:SetPoint("CENTER", 0, 1)
    
    -- Dragging
    minimapFrame:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            local angle = math.deg(math.atan2(py - my, px - mx)) % 360
            MattBetterChatSoundsDB.minimapPos = angle
            UpdateMinimapButtonPosition(self, angle)
        end)
    end)
    
    minimapFrame:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    
    minimapFrame:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            addon:ToggleOptions()
        elseif button == "RightButton" then
            addon:ToggleMinimapButton()
        end
    end)
    
    minimapFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Matt Better Chat Sounds")
        GameTooltip:AddLine("|cffffff00Left-click|r to open settings", 1, 1, 1)
        GameTooltip:AddLine("|cffffff00Drag|r to move around minimap", 1, 1, 1)
        GameTooltip:AddLine("|cffffff00Right-click|r to hide", 1, 1, 1)
        GameTooltip:Show()
    end)
    
    minimapFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    addon.minimapButton = minimapFrame
    return true
end

-- Toggle minimap button visibility
function addon:ToggleMinimapButton()
    MattBetterChatSoundsDB.minimapIcon = MattBetterChatSoundsDB.minimapIcon or { hide = false }
    MattBetterChatSoundsDB.minimapIcon.hide = not MattBetterChatSoundsDB.minimapIcon.hide
    
    if LDBIcon then
        -- LDB method
        if MattBetterChatSoundsDB.minimapIcon.hide then
            LDBIcon:Hide(addonName)
        else
            LDBIcon:Show(addonName)
        end
    elseif addon.minimapButton then
        -- Manual button method
        if MattBetterChatSoundsDB.minimapIcon.hide then
            addon.minimapButton:Hide()
        else
            addon.minimapButton:Show()
        end
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Minimap button " .. (MattBetterChatSoundsDB.minimapIcon.hide and "hidden" or "shown") .. ". Type |cffffff00/mbcs|r to toggle.")
    
    -- Update checkbox if options frame is open
    if self.optionsFrame and self.minimapCheckbox then
        self.minimapCheckbox:SetChecked(not MattBetterChatSoundsDB.minimapIcon.hide)
        if self.minimapCheckbox.mmCheck and self.minimapCheckbox.mmBox then
            if not MattBetterChatSoundsDB.minimapIcon.hide then
                self.minimapCheckbox.mmCheck:Show()
                self.minimapCheckbox.mmBox:Hide()
            else
                self.minimapCheckbox.mmCheck:Hide()
                self.minimapCheckbox.mmBox:Show()
            end
        end
    end
end

-- Set minimap button visibility (for checkbox)
function addon:SetMinimapButtonShown(show)
    MattBetterChatSoundsDB.minimapIcon = MattBetterChatSoundsDB.minimapIcon or { hide = false }
    MattBetterChatSoundsDB.minimapIcon.hide = not show
    
    if LDBIcon then
        if show then
            LDBIcon:Show(addonName)
        else
            LDBIcon:Hide(addonName)
        end
    elseif addon.minimapButton then
        if show then
            addon.minimapButton:Show()
        else
            addon.minimapButton:Hide()
        end
    end
end

-- ============================================================================
--  ADDON LOADED
-- ============================================================================
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    
    InitializeDatabase()
    InitializeMinimapButton()
    
    self:UnregisterEvent("ADDON_LOADED")
end)

-- ============================================================================
--  OPTIONS UI
-- ============================================================================
function MattBetterChatSounds:ToggleOptions()
    if self.optionsFrame then
        self.optionsFrame:SetShown(not self.optionsFrame:IsShown())
        return
    end

    -- Create minimal main frame (avoid SetBackdrop for cross-version compatibility)
    local f = CreateFrame("Frame", "MattBetterChatSoundsOptionsFrame", UIParent)
    f:SetSize(520, 520)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")

    self.optionsFrame = f

    -- Background (solid slightly lighter gray)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetColorTexture(0.12, 0.12, 0.12, 0.96)

    -- Border (2px dark gray around the frame)
    local borderTop = f:CreateTexture(nil, "ARTWORK")
    borderTop:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
    borderTop:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    borderTop:SetHeight(2)
    borderTop:SetColorTexture(0.06, 0.06, 0.06, 1)

    local borderBottom = f:CreateTexture(nil, "ARTWORK")
    borderBottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -2, -2)
    borderBottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
    borderBottom:SetHeight(2)
    borderBottom:SetColorTexture(0.06, 0.06, 0.06, 1)

    local borderLeft = f:CreateTexture(nil, "ARTWORK")
    borderLeft:SetPoint("TOPLEFT", f, "TOPLEFT", -2, 2)
    borderLeft:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -2, -2)
    borderLeft:SetWidth(2)
    borderLeft:SetColorTexture(0.06, 0.06, 0.06, 1)

    local borderRight = f:CreateTexture(nil, "ARTWORK")
    borderRight:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)
    borderRight:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 2, -2)
    borderRight:SetWidth(2)
    borderRight:SetColorTexture(0.06, 0.06, 0.06, 1)

    -- Top accent bar (pink)
    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(4)
    accent:SetPoint("TOPLEFT", 6, -6)
    accent:SetPoint("TOPRIGHT", -6, -6)
    accent:SetColorTexture(0.86, 0.14, 0.63, 1)

    -- Title (pink)
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -18)
    title:SetFont(NAO_FONT_PATH, FONT_SIZES.title, "OUTLINE")
    title:SetText("Matt's Better Chat Sounds")
    title:SetTextColor(0.95, 0.18, 0.6)

    -- Description (light gray)
    local desc = f:CreateFontString(nil, "OVERLAY")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -6)
    desc:SetWidth(480)
    desc:SetJustifyH("CENTER")
    desc:SetFont(NAO_FONT_PATH, FONT_SIZES.normal)
    desc:SetTextColor(0.8, 0.8, 0.8)
    desc:SetText("Enable or disable sounds for different chat types. Sounds play through the Dialog audio channel.")

    -- Build ordered list of events (only show events available for this version)
    local orderedEvents = {
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_BN_WHISPER",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_RAID_WARNING",
        "CHAT_MSG_GUILD",
    }

    -- Container for options (left column)
    local container = CreateFrame("Frame", nil, f)
    container:SetPoint("TOPLEFT", 20, -80)
    container:SetPoint("BOTTOMRIGHT", -20, 60)

    -- Create checkboxes (minimal styled)
    local yOffset = -4
    for _, eventKey in ipairs(orderedEvents) do
        if soundFiles[eventKey] then
            local key = eventKey
            local label = eventLabels[key] or key

            -- Checkbox base (use InterfaceOptions template then override visuals)
            local checkbox = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
            checkbox:SetPoint("TOPLEFT", 6, yOffset)
            checkbox.Text:SetText(label)
            checkbox.Text:SetFont(NAO_FONT_PATH, FONT_SIZES.normal)
            checkbox.Text:SetTextColor(0.9,0.9,0.9)

            -- Remove the default textures so we can draw our own minimal checkbox
            do
                local nt = checkbox:GetNormalTexture()
                if nt then nt:SetTexture(nil); nt:Hide() end
                local pt = checkbox:GetPushedTexture()
                if pt then pt:SetTexture(nil); pt:Hide() end
                local ht = checkbox:GetHighlightTexture()
                if ht then ht:SetTexture(nil); ht:Hide() end
                local ct = checkbox:GetCheckedTexture()
                if ct then ct:SetTexture(nil); ct:Hide() end
                local dt = checkbox:GetDisabledCheckedTexture()
                if dt then dt:SetTexture(nil); dt:Hide() end
            end

            local box = checkbox:CreateTexture(nil, "ARTWORK")
            box:SetSize(16,16)
            box:SetPoint("LEFT", checkbox, "LEFT", 0, 0)
            box:SetColorTexture(0.13,0.13,0.13,1)

            local border = checkbox:CreateTexture(nil, "OVERLAY")
            border:SetSize(18,18)
            border:SetPoint("CENTER", box, "CENTER", 0, 0)
            border:SetColorTexture(0.22,0.22,0.22,1)

            local check = checkbox:CreateTexture(nil, "OVERLAY")
            check:SetSize(10,10)
            check:SetPoint("CENTER", box, "CENTER", 0, 0)
            -- use a solid colored square for a minimal, screenshot-like check
            check:SetTexture(nil)
            check:SetColorTexture(1, 0.1, 0.6, 1)

            -- Initialize visible state
            if MattBetterChatSoundsDB[key] == false then
                check:Hide()
                checkbox:SetChecked(false)
                box:Show()
                border:Show()
            else
                check:Show()
                checkbox:SetChecked(true)
                box:Hide()
                border:Hide()
            end

            checkbox:SetScript("OnClick", function(self)
                local v = self:GetChecked()
                MattBetterChatSoundsDB[key] = v
                if v then
                    check:Show()
                    box:Hide()
                    border:Hide()
                else
                    check:Hide()
                    box:Show()
                    border:Show()
                end
            end)

            -- Test button (red/gray minimalist style)
            local testBtn = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
            testBtn:SetSize(56, 22)
            testBtn:SetPoint("LEFT", checkbox.Text, "RIGHT", 12, 0)
            testBtn:SetText("Test")

            -- background and border (gray + pink accents)
            local tbg = testBtn:CreateTexture(nil, "BACKGROUND")
            tbg:SetAllPoints(testBtn)
            tbg:SetColorTexture(0.12, 0.12, 0.12, 1)
            local tborder = testBtn:CreateTexture(nil, "BORDER")
            tborder:SetPoint("TOPLEFT", testBtn, "TOPLEFT", -1, 1)
            tborder:SetPoint("BOTTOMRIGHT", testBtn, "BOTTOMRIGHT", 1, -1)
            tborder:SetColorTexture(0.86, 0.14, 0.63, 1)

            testBtn:GetFontString():SetFont(NAO_FONT_PATH, FONT_SIZES.normal)
            testBtn:GetFontString():SetTextColor(1, 1, 1)
            testBtn:SetScript("OnEnter", function() tbg:SetColorTexture(0.16, 0.16, 0.16, 1); tborder:SetColorTexture(0.98,0.22,0.65,1) end)
            testBtn:SetScript("OnLeave", function() tbg:SetColorTexture(0.12, 0.12, 0.12, 1); tborder:SetColorTexture(0.86, 0.14, 0.63, 1) end) 

            testBtn:SetScript("OnClick", function()
                local soundFile = soundFiles[key]
                if soundFile then
                    PlaySoundFile(soundFile, "Dialog")
                end
            end)

            yOffset = yOffset - 30
        end
    end

    -- Close button (red/gray style)
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(110, 26)
    closeBtn:SetPoint("BOTTOM", 0, 16)
    closeBtn:SetText("Close")

    local cbg = closeBtn:CreateTexture(nil, "BACKGROUND")
    cbg:SetAllPoints(closeBtn)
    cbg:SetColorTexture(0.12, 0.12, 0.12, 1)
    local cborder = closeBtn:CreateTexture(nil, "BORDER")
    cborder:SetPoint("TOPLEFT", closeBtn, "TOPLEFT", -1, 1)
    cborder:SetPoint("BOTTOMRIGHT", closeBtn, "BOTTOMRIGHT", 1, -1)
    cborder:SetColorTexture(0.86, 0.14, 0.63, 1)

    closeBtn:GetFontString():SetFont(NAO_FONT_PATH, FONT_SIZES.normal)
    closeBtn:GetFontString():SetTextColor(1, 1, 1)
    closeBtn:SetScript("OnEnter", function() cbg:SetColorTexture(0.16,0.16,0.16,1); cborder:SetColorTexture(0.98,0.22,0.65,1) end)
    closeBtn:SetScript("OnLeave", function() cbg:SetColorTexture(0.12, 0.12, 0.12, 1); cborder:SetColorTexture(0.86, 0.14, 0.63, 1) end)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Minimap button toggle (show if LDBIcon or manual button is available)
    if LDBIcon or addon.minimapButton then
        local minimapCheckbox = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
        minimapCheckbox:SetPoint("BOTTOMLEFT", 22, 18)
        minimapCheckbox.Text:SetText("Show Minimap Button")
        minimapCheckbox.Text:SetFont(NAO_FONT_PATH, FONT_SIZES.normal)
        minimapCheckbox.Text:SetTextColor(0.9,0.9,0.9)
        -- clickable by default

        -- Make a small minimal box like above
        do
            local nt = minimapCheckbox:GetNormalTexture()
            if nt then nt:SetTexture(nil); nt:Hide() end
            local ct = minimapCheckbox:GetCheckedTexture()
            if ct then ct:SetTexture(nil); ct:Hide() end
            local dt = minimapCheckbox:GetDisabledCheckedTexture()
            if dt then dt:SetTexture(nil); dt:Hide() end
            local ht = minimapCheckbox:GetHighlightTexture()
            if ht then ht:SetTexture(nil); ht:Hide() end
        end
        local mmBox = minimapCheckbox:CreateTexture(nil, "ARTWORK")
        mmBox:SetSize(16, 16)
        mmBox:SetPoint("LEFT", minimapCheckbox, "LEFT", 2, 0)
        mmBox:SetColorTexture(0.35,0.35,0.35,1)
        local mmCheck = minimapCheckbox:CreateTexture(nil, "OVERLAY")
        mmCheck:SetSize(11, 11)
        mmCheck:SetPoint("CENTER", mmBox, "CENTER", 0, 0)
        mmCheck:SetTexture(nil)
        mmCheck:SetColorTexture(1, 0.1, 0.6, 1)

        -- expose for external updates
        minimapCheckbox.mmCheck = mmCheck
        minimapCheckbox.mmBox = mmBox

        local shown = not (MattBetterChatSoundsDB.minimapIcon and MattBetterChatSoundsDB.minimapIcon.hide)
        if shown then
            mmCheck:Show()
            mmBox:Hide()
            minimapCheckbox:SetChecked(true)
        else
            mmCheck:Hide()
            mmBox:Show()
            minimapCheckbox:SetChecked(false)
        end

        minimapCheckbox:SetScript("OnClick", function(self)
            local v = self:GetChecked()
            addon:SetMinimapButtonShown(v)
            if v then
                mmCheck:Show()
                mmBox:Hide()
            else
                mmCheck:Hide()
                mmBox:Show()
            end
        end)

        -- Store reference for updating from right-click toggle
        self.minimapCheckbox = minimapCheckbox
    end

    f:Show()
end

-- ============================================================================
--  SLASH COMMANDS
-- ============================================================================
SLASH_MATTBETTERCHATSOUNDS1 = "/mbcs"
SLASH_MATTBETTERCHATSOUNDS2 = "/mattbetterchatsounds"
SlashCmdList["MATTBETTERCHATSOUNDS"] = function(msg)
    msg = (msg or ""):lower():trim()
    
    if msg == "test" then
        PlaySoundFile(SOUND_PATH .. "bcs.mp3", "Dialog")
    elseif msg == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Sound Status:")
        for eventKey in pairs(soundFiles) do
            local label = eventLabels[eventKey] or eventKey
            local enabled = MattBetterChatSoundsDB[eventKey] ~= false
            DEFAULT_CHAT_FRAME:AddMessage("  " .. label .. ": " .. (enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
        end
    elseif msg == "minimap" then
        addon:ToggleMinimapButton()
    elseif msg == "showminimap" then
        addon:SetMinimapButtonShown(true)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Minimap button shown.")
    elseif msg == "hideminimap" then
        addon:SetMinimapButtonShown(false)
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs|r - Open settings")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs test|r - Play test sound")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs status|r - Show sound status")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs minimap|r - Toggle minimap button")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs showminimap|r - Show minimap button")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs hideminimap|r - Hide minimap button")
    else
        addon:ToggleOptions()
    end
end
