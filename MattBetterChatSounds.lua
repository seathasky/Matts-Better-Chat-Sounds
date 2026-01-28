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
    local playerName = UnitName("player")
    if sender then
        local senderName = Ambiguate(sender, "short")
        if senderName == playerName then
            return
        end
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
    if not LibStub then return false end
    
    local success = pcall(function()
        LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
        LDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    end)
    
    if not success or not LDB or not LDBIcon then
        return false
    end
    
    addon.ChatSoundsLDB = LDB:NewDataObject(addonName, {
        type = "launcher",
        text = "Matt Better Chat Sounds",
        icon = "Interface\\AddOns\\MattBetterChatSounds\\Images\\BetterChatSounds.tga",
        OnClick = function(_, button)
            if button == "LeftButton" then
                addon:ToggleOptions()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Matt Better Chat Sounds")
            tooltip:AddLine("|cffffff00Left-click|r to open settings")
        end,
    })
    
    if not LDBIcon:IsRegistered(addonName) then
        LDBIcon:Register(addonName, addon.ChatSoundsLDB, MattBetterChatSoundsDB)
    end
    
    return true
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
    
    -- Create main frame
    local f = CreateFrame("Frame", "MattBetterChatSoundsOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(450, 500)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    
    self.optionsFrame = f
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -35)
    title:SetText("Matt's Better Chat Sounds")
    title:SetTextColor(1, 0.82, 0)
    
    -- Description
    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -15)
    desc:SetWidth(400)
    desc:SetText("Enable or disable sounds for different chat types.\nSounds play through the Dialog audio channel.")
    
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
    
    -- Create checkboxes
    local yOffset = -100
    for _, eventKey in ipairs(orderedEvents) do
        -- Only show options for events available in this version
        if soundFiles[eventKey] then
            local label = eventLabels[eventKey] or eventKey
            
            local checkbox = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
            checkbox:SetPoint("TOPLEFT", 40, yOffset)
            checkbox.Text:SetText(label)
            checkbox.Text:SetFontObject("GameFontNormal")
            
            checkbox:SetChecked(MattBetterChatSoundsDB[eventKey] ~= false)
            checkbox:SetScript("OnClick", function(self)
                MattBetterChatSoundsDB[eventKey] = self:GetChecked()
            end)
            
            -- Test button for this sound
            local testBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            testBtn:SetSize(50, 22)
            testBtn:SetPoint("LEFT", checkbox.Text, "RIGHT", 10, 0)
            testBtn:SetText("Test")
            testBtn:SetScript("OnClick", function()
                local soundFile = soundFiles[eventKey]
                if soundFile then
                    PlaySoundFile(soundFile, "Dialog")
                end
            end)
            
            yOffset = yOffset - 32
        end
    end
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(100, 25)
    closeBtn:SetPoint("BOTTOM", 0, 15)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
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
    else
        addon:ToggleOptions()
    end
end
