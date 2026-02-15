
local addonName = "MattBetterChatSounds"
MattBetterChatSounds = {}
local addon = MattBetterChatSounds


local _, _, _, tocVersion = GetBuildInfo()
local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local isClassicEra = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)  -- Classic Era Anniversary
local isTBC = (WOW_PROJECT_ID == (WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5))  -- TBC Anniversary
local isMoP = (WOW_PROJECT_ID == (WOW_PROJECT_MISTS_OF_PANDARIA_CLASSIC or 17))  -- MoP Remix
local isClassic = isClassicEra or isTBC or isMoP
local hasInstanceChat = isRetail or isMoP  -- Dungeon Finder available in MoP and Retail
local hasBattleNet = isRetail  -- Battle.net whispers only in Retail


local LDB, LDBIcon
local issecretvalue = issecretvalue

local SOUND_PATH = "Interface\\AddOns\\MattBetterChatSounds\\Sounds\\"
local NAO_FONT_PATH = "Interface\\AddOns\\MattBetterChatSounds\\Media\\Naowh.ttf"
local FONT_SIZES = { title = 18, normal = 12, small = 11 }

local function NotSecretValue(value)
    return not issecretvalue or not issecretvalue(value)
end

local soundFiles = {
    CHAT_MSG_WHISPER        = SOUND_PATH .. "whisper.ogg",
    CHAT_MSG_PARTY          = SOUND_PATH .. "bcs.mp3",
    CHAT_MSG_PARTY_LEADER   = SOUND_PATH .. "text.mp3",
    CHAT_MSG_RAID           = SOUND_PATH .. "bcs.mp3",
    CHAT_MSG_RAID_LEADER    = SOUND_PATH .. "text.mp3",
    CHAT_MSG_RAID_WARNING   = SOUND_PATH .. "text2.mp3",
    CHAT_MSG_GUILD          = SOUND_PATH .. "guild.mp3",
}

if hasBattleNet then
    soundFiles.CHAT_MSG_BN_WHISPER              = SOUND_PATH .. "whisper.ogg"
end

if hasInstanceChat then
    soundFiles.CHAT_MSG_INSTANCE_CHAT           = SOUND_PATH .. "bcs.mp3"
    soundFiles.CHAT_MSG_INSTANCE_CHAT_LEADER    = SOUND_PATH .. "text.mp3"
end

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

local function NormalizeIgnoreWord(word)
    if not word then return nil end
    local normalized = strtrim(tostring(word):lower())
    if normalized == "" then
        return nil
    end
    return normalized
end

local function EnsureIgnoreWordsTable()
    MattBetterChatSoundsDB.ignoreWords = MattBetterChatSoundsDB.ignoreWords or {}

    if type(MattBetterChatSoundsDB.ignoreWords) ~= "table" then
        MattBetterChatSoundsDB.ignoreWords = {}
        return
    end

    local hasNumericKeys = false
    for key in pairs(MattBetterChatSoundsDB.ignoreWords) do
        if type(key) == "number" then
            hasNumericKeys = true
            break
        end
    end

    -- Normalize legacy array-style list into a lookup table.
    if hasNumericKeys then
        local lookup = {}
        for _, value in ipairs(MattBetterChatSoundsDB.ignoreWords) do
            local normalized = NormalizeIgnoreWord(value)
            if normalized then
                lookup[normalized] = true
            end
        end
        MattBetterChatSoundsDB.ignoreWords = lookup
    end
end

local function MessageContainsIgnoredWord(message)
    if not NotSecretValue(message) or type(message) ~= "string" or message == "" then
        return false
    end

    EnsureIgnoreWordsTable()

    local lowered = message:lower()
    for ignoredWord, enabled in pairs(MattBetterChatSoundsDB.ignoreWords) do
        if enabled and lowered:find(ignoredWord, 1, true) then
            return true
        end
    end
    return false
end

local function AddIgnoreWord(word)
    local normalized = NormalizeIgnoreWord(word)
    if not normalized then
        return false, "Please provide a word or phrase to ignore."
    end

    EnsureIgnoreWordsTable()
    if MattBetterChatSoundsDB.ignoreWords[normalized] then
        return false, "'" .. normalized .. "' is already ignored."
    end

    MattBetterChatSoundsDB.ignoreWords[normalized] = true
    return true, "'" .. normalized .. "' added to ignore list."
end

local function RemoveIgnoreWord(word)
    local normalized = NormalizeIgnoreWord(word)
    if not normalized then
        return false, "Please provide a word or phrase to remove."
    end

    EnsureIgnoreWordsTable()
    if not MattBetterChatSoundsDB.ignoreWords[normalized] then
        return false, "'" .. normalized .. "' was not in the ignore list."
    end

    MattBetterChatSoundsDB.ignoreWords[normalized] = nil
    return true, "'" .. normalized .. "' removed from ignore list."
end

local function GetIgnoreWordsList()
    EnsureIgnoreWordsTable()
    local words = {}
    for ignoredWord, enabled in pairs(MattBetterChatSoundsDB.ignoreWords) do
        if enabled then
            words[#words + 1] = ignoredWord
        end
    end
    table.sort(words)
    return words
end

local function ClearIgnoreWords()
    MattBetterChatSoundsDB.ignoreWords = {}
end

local function InitializeDatabase()
    MattBetterChatSoundsDB = MattBetterChatSoundsDB or {}
    
    for eventKey in pairs(soundFiles) do
        if MattBetterChatSoundsDB[eventKey] == nil then
            MattBetterChatSoundsDB[eventKey] = true
        end
    end
    
    if MattBetterChatSoundsDB.minimapIcon == nil then
        MattBetterChatSoundsDB.minimapIcon = { hide = false }
    end

    EnsureIgnoreWordsTable()
end
addon.InitializeDatabase = InitializeDatabase

-- ============================================================================
--  SOUND PLAYBACK
-- ============================================================================
local function PlayChatSound(event)
    local soundFile = soundFiles[event]
    if not soundFile then return end
    
    if MattBetterChatSoundsDB[event] == false then
        return
    end
    
    PlaySoundFile(soundFile, "Dialog")
end

-- ============================================================================
--  CHAT EVENT HANDLING
-- ============================================================================
local chatFrame = CreateFrame("Frame")

chatFrame:SetScript("OnEvent", function(self, event, message, sender, ...)

    local playerName = UnitName("player")
    if sender then
        local success, senderName = pcall(Ambiguate, sender, "short")
        if success and NotSecretValue(senderName) and NotSecretValue(playerName) and senderName == playerName then
            return
        end

    end

    if MessageContainsIgnoredWord(message) then
        return
    end

    PlayChatSound(event)
end)

local function RegisterChatEvents()
    for eventKey in pairs(soundFiles) do
        chatFrame:RegisterEvent(eventKey)
    end
end

RegisterChatEvents()


local function InitializeMinimapButton()
    if LibStub then
        LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
        LDBIcon = LibStub:GetLibrary("LibDBIcon-1.0", true)
    end

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


local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    
    InitializeDatabase()
    InitializeMinimapButton()
    
    self:UnregisterEvent("ADDON_LOADED")
end)

function MattBetterChatSounds:ToggleOptions()
    if self.optionsFrame then
        self.optionsFrame:SetShown(not self.optionsFrame:IsShown())
        return
    end

    local f = CreateFrame("Frame", "MattBetterChatSoundsOptionsFrame", UIParent)
    f:SetSize(700, 520)
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
    desc:SetWidth(650)
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

    -- Container for chat sound options (left column)
    local container = CreateFrame("Frame", nil, f)
    container:SetPoint("TOPLEFT", 20, -80)
    container:SetPoint("BOTTOMRIGHT", -250, 60)

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

    -- Ignore words panel (right column)
    local ignorePanel = CreateFrame("Frame", nil, f)
    ignorePanel:SetPoint("TOPRIGHT", -20, -80)
    ignorePanel:SetPoint("BOTTOMRIGHT", -20, 60)
    ignorePanel:SetWidth(210)

    local ignoreTitle = ignorePanel:CreateFontString(nil, "OVERLAY")
    ignoreTitle:SetPoint("TOPLEFT", 0, 0)
    ignoreTitle:SetFont(NAO_FONT_PATH, FONT_SIZES.normal, "OUTLINE")
    ignoreTitle:SetTextColor(0.95, 0.18, 0.6)
    ignoreTitle:SetText("Ignored Words")

    local ignoreHint = ignorePanel:CreateFontString(nil, "OVERLAY")
    ignoreHint:SetPoint("TOPLEFT", ignoreTitle, "BOTTOMLEFT", 0, -6)
    ignoreHint:SetWidth(210)
    ignoreHint:SetJustifyH("LEFT")
    ignoreHint:SetFont(NAO_FONT_PATH, FONT_SIZES.small)
    ignoreHint:SetTextColor(0.75, 0.75, 0.75)
    ignoreHint:SetText("Messages containing these words/phrases will not play a sound.")

    local ignoreInput = CreateFrame("EditBox", nil, ignorePanel, "InputBoxTemplate")
    ignoreInput:SetAutoFocus(false)
    ignoreInput:SetSize(140, 24)
    ignoreInput:SetPoint("TOPLEFT", ignoreHint, "BOTTOMLEFT", 0, -10)
    ignoreInput:SetFontObject(GameFontHighlightSmall)
    ignoreInput:SetTextInsets(6, 6, 0, 0)

    local addBtn = CreateFrame("Button", nil, ignorePanel, "UIPanelButtonTemplate")
    addBtn:SetSize(60, 24)
    addBtn:SetPoint("LEFT", ignoreInput, "RIGHT", 8, 0)
    addBtn:SetText("Add")

    local abg = addBtn:CreateTexture(nil, "BACKGROUND")
    abg:SetAllPoints(addBtn)
    abg:SetColorTexture(0.12, 0.12, 0.12, 1)
    local aborder = addBtn:CreateTexture(nil, "BORDER")
    aborder:SetPoint("TOPLEFT", addBtn, "TOPLEFT", -1, 1)
    aborder:SetPoint("BOTTOMRIGHT", addBtn, "BOTTOMRIGHT", 1, -1)
    aborder:SetColorTexture(0.86, 0.14, 0.63, 1)
    if addBtn:GetFontString() then
        addBtn:GetFontString():SetText("")
    end
    local addLabel = addBtn:CreateFontString(nil, "OVERLAY")
    addLabel:SetPoint("CENTER", addBtn, "CENTER", 0, 0)
    addLabel:SetFont(NAO_FONT_PATH, FONT_SIZES.normal)
    addLabel:SetTextColor(1, 1, 1)
    addLabel:SetText("Add")
    addBtn:SetScript("OnEnter", function() abg:SetColorTexture(0.16, 0.16, 0.16, 1); aborder:SetColorTexture(0.98,0.22,0.65,1) end)
    addBtn:SetScript("OnLeave", function() abg:SetColorTexture(0.12, 0.12, 0.12, 1); aborder:SetColorTexture(0.86, 0.14, 0.63, 1) end)

    local listFrame = CreateFrame("Frame", nil, ignorePanel)
    listFrame:SetPoint("TOPLEFT", ignoreInput, "BOTTOMLEFT", 0, -10)
    listFrame:SetSize(210, 246)

    local listBg = listFrame:CreateTexture(nil, "BACKGROUND")
    listBg:SetAllPoints(listFrame)
    listBg:SetColorTexture(0.09, 0.09, 0.09, 1)
    local listBorder = listFrame:CreateTexture(nil, "BORDER")
    listBorder:SetPoint("TOPLEFT", listFrame, "TOPLEFT", -1, 1)
    listBorder:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", 1, -1)
    listBorder:SetColorTexture(0.22, 0.22, 0.22, 1)

    local selectedIgnoredWord
    local ignoredWordRows = {}

    local function RefreshIgnoreWordsUI()
        local words = GetIgnoreWordsList()
        if selectedIgnoredWord and not MattBetterChatSoundsDB.ignoreWords[selectedIgnoredWord] then
            selectedIgnoredWord = nil
        end

        for i = 1, #ignoredWordRows do
            local row = ignoredWordRows[i]
            local word = words[i]
            row.word = word
            if word then
                row.label:SetText(word)
                row:Show()
                if selectedIgnoredWord == word then
                    row.bg:SetColorTexture(0.86, 0.14, 0.63, 0.35)
                else
                    row.bg:SetColorTexture(0, 0, 0, 0)
                end
            else
                row.word = nil
                row.label:SetText("")
                row.bg:SetColorTexture(0, 0, 0, 0)
                row:Hide()
            end
        end
    end

    local y = -6
    for i = 1, 10 do
        local row = CreateFrame("Button", nil, listFrame)
        row:SetPoint("TOPLEFT", 6, y)
        row:SetSize(198, 22)
        y = y - 23

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints(row)
        row.bg:SetColorTexture(0, 0, 0, 0)

        row.label = row:CreateFontString(nil, "OVERLAY")
        row.label:SetPoint("LEFT", 6, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetWidth(186)
        row.label:SetFont(NAO_FONT_PATH, FONT_SIZES.small)
        row.label:SetTextColor(0.9, 0.9, 0.9)

        row:SetScript("OnClick", function(self)
            if not self.word then return end
            selectedIgnoredWord = self.word
            ignoreInput:SetText(self.word)
            RefreshIgnoreWordsUI()
        end)

        ignoredWordRows[#ignoredWordRows + 1] = row
    end

    local removeBtn = CreateFrame("Button", nil, ignorePanel, "UIPanelButtonTemplate")
    removeBtn:SetSize(100, 24)
    removeBtn:SetPoint("TOPLEFT", listFrame, "BOTTOMLEFT", 0, -10)
    removeBtn:SetText("Remove")

    local rbg = removeBtn:CreateTexture(nil, "BACKGROUND")
    rbg:SetAllPoints(removeBtn)
    rbg:SetColorTexture(0.12, 0.12, 0.12, 1)
    local rborder = removeBtn:CreateTexture(nil, "BORDER")
    rborder:SetPoint("TOPLEFT", removeBtn, "TOPLEFT", -1, 1)
    rborder:SetPoint("BOTTOMRIGHT", removeBtn, "BOTTOMRIGHT", 1, -1)
    rborder:SetColorTexture(0.86, 0.14, 0.63, 1)
    removeBtn:GetFontString():SetFont(NAO_FONT_PATH, FONT_SIZES.normal)
    removeBtn:GetFontString():SetTextColor(1, 1, 1)
    removeBtn:SetScript("OnEnter", function() rbg:SetColorTexture(0.16, 0.16, 0.16, 1); rborder:SetColorTexture(0.98,0.22,0.65,1) end)
    removeBtn:SetScript("OnLeave", function() rbg:SetColorTexture(0.12, 0.12, 0.12, 1); rborder:SetColorTexture(0.86, 0.14, 0.63, 1) end)

    local clearBtn = CreateFrame("Button", nil, ignorePanel, "UIPanelButtonTemplate")
    clearBtn:SetSize(100, 24)
    clearBtn:SetPoint("TOPRIGHT", listFrame, "BOTTOMRIGHT", 0, -10)
    clearBtn:SetText("Clear All")

    local clbg = clearBtn:CreateTexture(nil, "BACKGROUND")
    clbg:SetAllPoints(clearBtn)
    clbg:SetColorTexture(0.12, 0.12, 0.12, 1)
    local clborder = clearBtn:CreateTexture(nil, "BORDER")
    clborder:SetPoint("TOPLEFT", clearBtn, "TOPLEFT", -1, 1)
    clborder:SetPoint("BOTTOMRIGHT", clearBtn, "BOTTOMRIGHT", 1, -1)
    clborder:SetColorTexture(0.86, 0.14, 0.63, 1)
    clearBtn:GetFontString():SetFont(NAO_FONT_PATH, FONT_SIZES.normal)
    clearBtn:GetFontString():SetTextColor(1, 1, 1)
    clearBtn:SetScript("OnEnter", function() clbg:SetColorTexture(0.16, 0.16, 0.16, 1); clborder:SetColorTexture(0.98,0.22,0.65,1) end)
    clearBtn:SetScript("OnLeave", function() clbg:SetColorTexture(0.12, 0.12, 0.12, 1); clborder:SetColorTexture(0.86, 0.14, 0.63, 1) end)

    local function AddFromInput()
        local ok, resultMsg = AddIgnoreWord(ignoreInput:GetText())
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: " .. resultMsg)
        if ok then
            selectedIgnoredWord = nil
            ignoreInput:SetText("")
            RefreshIgnoreWordsUI()
        end
    end

    addBtn:SetScript("OnClick", AddFromInput)
    ignoreInput:SetScript("OnEnterPressed", function(self)
        AddFromInput()
        self:ClearFocus()
    end)

    removeBtn:SetScript("OnClick", function()
        local target = selectedIgnoredWord
        if not target or target == "" then
            target = ignoreInput:GetText()
        end
        local ok, resultMsg = RemoveIgnoreWord(target)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: " .. resultMsg)
        if ok then
            selectedIgnoredWord = nil
            ignoreInput:SetText("")
            RefreshIgnoreWordsUI()
        end
    end)

    clearBtn:SetScript("OnClick", function()
        ClearIgnoreWords()
        selectedIgnoredWord = nil
        ignoreInput:SetText("")
        RefreshIgnoreWordsUI()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Ignore list cleared.")
    end)

    RefreshIgnoreWordsUI()

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

    if LDBIcon or addon.minimapButton then
        local minimapCheckbox = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
        minimapCheckbox:SetPoint("BOTTOMLEFT", 22, 18)
        minimapCheckbox.Text:SetText("Show Minimap Button")
        minimapCheckbox.Text:SetFont(NAO_FONT_PATH, FONT_SIZES.normal)
        minimapCheckbox.Text:SetTextColor(0.9,0.9,0.9)


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

        self.minimapCheckbox = minimapCheckbox
    end

    f:Show()
end

--  SLASH COMMANDS
SLASH_MATTBETTERCHATSOUNDS1 = "/mbcs"
SLASH_MATTBETTERCHATSOUNDS2 = "/mattbetterchatsounds"
SlashCmdList["MATTBETTERCHATSOUNDS"] = function(msg)
    local rawMsg = strtrim(msg or "")
    local lowerMsg = rawMsg:lower()

    if lowerMsg == "test" then
        PlaySoundFile(SOUND_PATH .. "bcs.mp3", "Dialog")
    elseif lowerMsg == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Sound Status:")
        for eventKey in pairs(soundFiles) do
            local label = eventLabels[eventKey] or eventKey
            local enabled = MattBetterChatSoundsDB[eventKey] ~= false
            DEFAULT_CHAT_FRAME:AddMessage("  " .. label .. ": " .. (enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
        end
    elseif lowerMsg:find("^ignore") == 1 then
        local ignoreArgs = strtrim(rawMsg:sub(7))
        local subcommand, value = ignoreArgs:match("^(%S+)%s*(.-)$")
        subcommand = (subcommand or ""):lower()

        if subcommand == "" then
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Ignore commands:")
            DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs ignore <word or phrase>|r - Add ignore entry")
            DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs ignore add <word or phrase>|r - Add ignore entry")
            DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs ignore remove <word or phrase>|r - Remove ignore entry")
            DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs ignore list|r - Show ignore entries")
            DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs ignore clear|r - Clear ignore list")
        elseif subcommand == "list" then
            local words = GetIgnoreWordsList()
            if #words == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Ignore list is empty.")
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Ignored words/phrases:")
                for _, word in ipairs(words) do
                    DEFAULT_CHAT_FRAME:AddMessage("  - " .. word)
                end
            end
        elseif subcommand == "clear" then
            ClearIgnoreWords()
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Ignore list cleared.")
        elseif subcommand == "add" then
            local ok, resultMsg = AddIgnoreWord(value)
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: " .. resultMsg)
        elseif subcommand == "remove" or subcommand == "delete" or subcommand == "del" then
            local ok, resultMsg = RemoveIgnoreWord(value)
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: " .. resultMsg)
        else
            local ok, resultMsg = AddIgnoreWord(ignoreArgs)
            DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: " .. resultMsg)
        end
    elseif lowerMsg == "minimap" then
        addon:ToggleMinimapButton()
    elseif lowerMsg == "showminimap" then
        addon:SetMinimapButtonShown(true)
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Minimap button shown.")
    elseif lowerMsg == "hideminimap" then
        addon:SetMinimapButtonShown(false)
    elseif lowerMsg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00MBCS|r: Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs|r - Open settings")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs test|r - Play test sound")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs status|r - Show sound status")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs ignore <word or phrase>|r - Ignore messages containing it")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs ignore list|r - Show ignored words/phrases")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs ignore remove <word or phrase>|r - Stop ignoring it")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs minimap|r - Toggle minimap button")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs showminimap|r - Show minimap button")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffff00/mbcs hideminimap|r - Hide minimap button")
    else
        addon:ToggleOptions()
    end
end
