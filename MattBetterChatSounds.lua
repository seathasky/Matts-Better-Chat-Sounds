local addonName = "MattBetterChatSounds"
MattBetterChatSounds = {}
local addon = MattBetterChatSounds

local LDB, LDBIcon
local frame = CreateFrame("Frame")

-- Move InitializeDatabase before it's called
local function InitializeDatabase()
    if not MattBetterChatSoundsDB then
        MattBetterChatSoundsDB = {}
    end
    
    local events = {
        { key = "CHAT_MSG_WHISPER", label = "Whisper Messages" },
        { key = "CHAT_MSG_PARTY", label = "Party Chat" },
        { key = "CHAT_MSG_PARTY_LEADER", label = "Party Leader Chat" },
        { key = "CHAT_MSG_RAID", label = "Raid Chat" },
        { key = "CHAT_MSG_RAID_LEADER", label = "Raid Leader Chat" },
        { key = "CHAT_MSG_GUILD", label = "Guild Chat" }  
    }
    
    -- Add Battle.net whisper only if it exists (retail/modern versions)
    if _G["CHAT_MSG_BN_WHISPER"] or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        table.insert(events, 2, { key = "CHAT_MSG_BN_WHISPER", label = "Battle.net Whisper Messages" })
    end
    
    for _, eventData in ipairs(events) do
        if MattBetterChatSoundsDB[eventData.key] == nil then
            MattBetterChatSoundsDB[eventData.key] = true
        end
    end
end
addon.InitializeDatabase = InitializeDatabase

local function InitializeAddon()
    -- Check for LibStub (optional for minimap functionality)
    if not LibStub then
        print("|cFFFF9900"..addonName.."|r: LibStub not found. Minimap icon will not be available.")
        return true -- Still allow addon to work without minimap
    end

    -- Try to load libraries (optional)
    local success, err = pcall(function()
        LDB = LibStub:GetLibrary("LibDataBroker-1.1", true) -- true = silent mode
        LDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    end)

    if not success or not LDB or not LDBIcon then
        print("|cFFFF9900"..addonName.."|r: DataBroker libraries not available. Minimap icon disabled.")
        LDB = nil
        LDBIcon = nil
        return true -- Still allow addon to work
    end

    -- Create LDB object only if libraries are available
    if LDB then
        addon.ChatSoundsLDB = LDB:NewDataObject(addonName, {
            type = "launcher",
            text = "Matt Better Chat Sounds",
            icon = "Interface\\AddOns\\MattBetterChatSounds\\Images\\BetterChatSounds.tga",
            OnClick = function(_, button)
                if button == "LeftButton" then
                    if addon.ToggleOptions then
                        addon:ToggleOptions()
                    else
                        print("Error: GUI function not found")
                    end
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("Matt Better Chat Sounds")
                tooltip:AddLine("|cffffff00Left-click|r to open settings.")
            end,
        })
    end

    return true
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            if not InitializeAddon() then
                return
            end

            -- Update the call to use addon's InitializeDatabase
            addon.InitializeDatabase()
            
            -- Register minimap icon
            if LDBIcon and not LDBIcon:IsRegistered(addonName) then
                LDBIcon:Register(addonName, addon.ChatSoundsLDB, MattBetterChatSoundsDB)
            end

            -- Register chat events after successful initialization
            self:RegisterEvent("CHAT_MSG_WHISPER")
            -- Only register Battle.net whisper if it exists
            if _G["CHAT_MSG_BN_WHISPER"] or (WOW_PROJECT_ID and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
                self:RegisterEvent("CHAT_MSG_BN_WHISPER")
            end
            self:RegisterEvent("CHAT_MSG_PARTY")
            self:RegisterEvent("CHAT_MSG_PARTY_LEADER")
            self:RegisterEvent("CHAT_MSG_RAID")
            self:RegisterEvent("CHAT_MSG_RAID_LEADER")
            self:RegisterEvent("CHAT_MSG_GUILD")

            print("|cFF00FF00"..addonName.."|r loaded! Type /mbcs to open options.")
            self:UnregisterEvent("ADDON_LOADED")
        end
        return
    end

    -- Chat event handling
    local soundFiles = {
        CHAT_MSG_WHISPER        = "Interface\\AddOns\\MattBetterChatSounds\\Sounds\\whisper.ogg",
        CHAT_MSG_BN_WHISPER     = "Interface\\AddOns\\MattBetterChatSounds\\Sounds\\whisper.ogg",
        CHAT_MSG_PARTY          = "Interface\\AddOns\\MattBetterChatSounds\\Sounds\\bcs.mp3",
        CHAT_MSG_PARTY_LEADER   = "Interface\\AddOns\\MattBetterChatSounds\\Sounds\\text.mp3",
        CHAT_MSG_RAID           = "Interface\\AddOns\\MattBetterChatSounds\\Sounds\\text2.mp3",
        CHAT_MSG_RAID_LEADER    = "Interface\\AddOns\\MattBetterChatSounds\\Sounds\\text.mp3",
        CHAT_MSG_GUILD          = "Interface\\AddOns\\MattBetterChatSounds\\Sounds\\guild.mp3" 
    }

    if soundFiles[event] and MattBetterChatSoundsDB[event] then
        PlaySoundFile(soundFiles[event], "Master")
    end
end)

function MattBetterChatSounds:ToggleOptions()
    -- Toggle if already open
    if self.optionsFrame then
        if self.optionsFrame:IsShown() then
            self.optionsFrame:Hide()
        else
            self.optionsFrame:Show()
        end
        return
    end

    local events = {
        { key = "CHAT_MSG_WHISPER", label = "Whisper Messages" },
        { key = "CHAT_MSG_PARTY", label = "Party Chat" },
        { key = "CHAT_MSG_PARTY_LEADER", label = "Party Leader Chat" },
        { key = "CHAT_MSG_RAID", label = "Raid Chat" },
        { key = "CHAT_MSG_RAID_LEADER", label = "Raid Leader Chat" },
        { key = "CHAT_MSG_GUILD", label = "Guild Chat" }  
    }
    
    -- Add Battle.net whisper only if it exists (retail/modern versions)
    if _G["CHAT_MSG_BN_WHISPER"] or (WOW_PROJECT_ID and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
        table.insert(events, 2, { key = "CHAT_MSG_BN_WHISPER", label = "Battle.net Whisper Messages" })
    end

    -- Create UI frame with error handling
    local success, result = pcall(function()
            -- Use more compatible frame template
            local template = "BasicFrameTemplateWithInset"
            if not _G[template] then
                template = "BasicFrameTemplate" -- Fallback for older versions
            end
            
            local f = CreateFrame("Frame", "MattBetterChatSoundsOptionsFrame", UIParent, template)
            f:SetSize(450, 450)
            f:SetPoint("CENTER")
            f:SetMovable(true)
            f:EnableMouse(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", f.StopMovingOrSizing)

            -- Title text
            local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            title:SetPoint("TOP", f, "TOP", 0, -35)
            title:SetText("Matt's Better Chat Sounds")
            title:SetTextColor(1, 0.82, 0) -- Gold color
            
            -- Description text
            local description = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            description:SetPoint("TOP", title, "BOTTOM", 0, -20)
            description:SetWidth(400)
            description:SetJustifyH("CENTER")
            description:SetText("Customize chat sounds for different message types.\nEnable or disable sounds by checking the boxes below.")
            description:SetTextColor(0.9, 0.9, 0.9)
            
            -- Separator line
            local separator = f:CreateTexture(nil, "ARTWORK")
            separator:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
            separator:SetSize(380, 8)
            separator:SetPoint("TOP", description, "BOTTOM", 0, -20)
            
            return f
    end)

    if success and result then
        local frame = result
        self.optionsFrame = frame

        local yOffset = -130 -- Start below the separator with generous space
        for i, eventData in ipairs(events) do
            local checkButtonName = "MBChS_CheckButton_" .. eventData.key
            local checkbox = CreateFrame("CheckButton", checkButtonName, frame, "ChatConfigCheckButtonTemplate")
            checkbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, yOffset)
            checkbox:SetScale(1.1) -- Make checkboxes slightly larger
            
            -- Access the check button's text region (named "Text" with an uppercase "T")
            local label = _G[checkButtonName.."Text"]
            label:SetText(eventData.label or eventData.key)
            label:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            label:SetTextColor(1, 1, 1) -- White text
            
            checkbox:SetChecked(MattBetterChatSoundsDB[eventData.key] ~= false)
            checkbox:SetScript("OnClick", function(self)
                local checked = self:GetChecked()
                MattBetterChatSoundsDB[eventData.key] = checked
            end)
            
            -- Add hover effect
            checkbox:SetScript("OnEnter", function(self)
                _G[checkButtonName.."Text"]:SetTextColor(1, 0.82, 0) -- Gold on hover
            end)
            checkbox:SetScript("OnLeave", function(self)
                _G[checkButtonName.."Text"]:SetTextColor(1, 1, 1) -- White when not hovering
            end)
            
            yOffset = yOffset - 35
        end

        local closeButton = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
        closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 20)
        closeButton:SetSize(100, 25)
        closeButton:SetText("Close")
        closeButton:SetScript("OnClick", function() frame:Hide() end)
    else
        print("|cFFFF0000"..addonName.."|r: Failed to create options interface:", result)
        return
    end
end


-- Chat command registration for /mbcs to open settings
SLASH_MATTBETTERCHATSOUNDS1 = "/mbcs"
SlashCmdList["MATTBETTERCHATSOUNDS"] = function(msg)
    if MattBetterChatSounds and MattBetterChatSounds.ToggleOptions then
        MattBetterChatSounds:ToggleOptions()
    else
        print("Error: Options not available.")
    end
end
