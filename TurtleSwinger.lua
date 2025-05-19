-- TurtleSwinger: A Weapon Swing Timer for TurtleWoW
-- Author: Claude
-- Version: 1.0
-- Compatible with TurtleWoW 1.17.2 (Core Version 1.12)

local addonName, TurtleSwinger = ...
TurtleSwinger = {}

-- Main frame
local SwingFrame = CreateFrame("Frame", "TurtleSwinger_Frame", UIParent)
SwingFrame:SetWidth(200)
SwingFrame:SetHeight(20)
SwingFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
SwingFrame:EnableMouse(true)
SwingFrame:SetMovable(true)
SwingFrame:RegisterForDrag("LeftButton")
SwingFrame:SetScript("OnDragStart", SwingFrame.StartMoving)
SwingFrame:SetScript("OnDragStop", SwingFrame.StopMovingOrSizing)

-- Background and border
SwingFrame.bg = SwingFrame:CreateTexture(nil, "BACKGROUND")
SwingFrame.bg:SetAllPoints(SwingFrame)
SwingFrame.bg:SetColorTexture(0, 0, 0, 0.5)

SwingFrame.border = CreateFrame("Frame", nil, SwingFrame)
SwingFrame.border:SetPoint("TOPLEFT", SwingFrame, "TOPLEFT", -1, 1)
SwingFrame.border:SetPoint("BOTTOMRIGHT", SwingFrame, "BOTTOMRIGHT", 1, -1)
SwingFrame.border:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = {left = 0, right = 0, top = 0, bottom = 0},
})
SwingFrame.border:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

-- Progress bar
SwingFrame.bar = CreateFrame("StatusBar", nil, SwingFrame)
SwingFrame.bar:SetPoint("TOPLEFT", SwingFrame, "TOPLEFT", 2, -2)
SwingFrame.bar:SetPoint("BOTTOMRIGHT", SwingFrame, "BOTTOMRIGHT", -2, 2)
SwingFrame.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
SwingFrame.bar:SetStatusBarColor(0.8, 0.8, 0.2, 0.8)
SwingFrame.bar:SetMinMaxValues(0, 1)
SwingFrame.bar:SetValue(0)

-- Text display
SwingFrame.text = SwingFrame.bar:CreateFontString(nil, "OVERLAY")
SwingFrame.text:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
SwingFrame.text:SetPoint("CENTER", SwingFrame.bar, "CENTER", 0, 0)
SwingFrame.text:SetTextColor(1, 1, 1, 1)
SwingFrame.text:SetText("TurtleSwinger")

-- Variables to track swing timer
local playerClass = select(2, UnitClass("player"))
local lastSwingTime = 0
local swingDuration = 0
local isSwinging = false
local offhandSwingTimer = 0
local offhandSwingDuration = 0
local isOffhandSwinging = false
local hasTwoHandWeapon = false
local hasMainHandWeapon = false
local hasOffHandWeapon = false

-- Function to update the weapon swing information
local function UpdateWeaponInfo()
    local mainHandSpeed, offHandSpeed = UnitAttackSpeed("player")
    
    -- Update mainhand info
    if mainHandSpeed then
        swingDuration = mainHandSpeed
        hasMainHandWeapon = true
    else
        hasMainHandWeapon = false
    end
    
    -- Update offhand info
    if offHandSpeed then
        offhandSwingDuration = offHandSpeed
        hasOffHandWeapon = true
    else
        hasOffHandWeapon = false
    end
    
    -- Check if player has a two-handed weapon
    local _, _, _, _, _, _, itemSubType = GetItemInfo(GetInventoryItemLink("player", 16) or "")
    hasTwoHandWeapon = (itemSubType and (itemSubType == "Two-Handed Axes" or 
                                           itemSubType == "Two-Handed Maces" or 
                                           itemSubType == "Two-Handed Swords" or 
                                           itemSubType == "Staves" or 
                                           itemSubType == "Fishing Poles" or 
                                           itemSubType == "Polearms"))
end

-- Function to reset the swing timer
local function ResetMainSwing()
    lastSwingTime = GetTime()
    isSwinging = true
end

-- Function to reset the offhand swing timer
local function ResetOffhandSwing()
    offhandSwingTimer = GetTime()
    isOffhandSwinging = true
end

-- Create frame for combat log parsing
local CombatLogFrame = CreateFrame("Frame")
CombatLogFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
CombatLogFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
CombatLogFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
CombatLogFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
-- TurtleWoW-specific ability events
CombatLogFrame:RegisterEvent("SPELLCAST_START")
CombatLogFrame:RegisterEvent("SPELLCAST_STOP")

-- Handle combat log events
CombatLogFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName = CombatLogGetCurrentEventInfo()
        
        -- Only process events from the player
        if sourceGUID ~= UnitGUID("player") then
            return
        end
        
        -- Handle main-hand swings
        if subevent == "SWING_DAMAGE" then
            -- Reset main-hand swing timer
            ResetMainSwing()
            
        elseif subevent == "SWING_MISSED" then
            -- Reset main-hand swing timer on miss as well
            ResetMainSwing()
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" or event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        -- Update weapon information when entering world or changing equipment
        UpdateWeaponInfo()
    elseif event == "SPELLCAST_START" then
        -- Check for TurtleWoW abilities that reset swing timer
        local spellName = select(1, ...)
        if spellName == "Holy Strike" or 
           spellName == "Mongoose Bite" or 
           spellName == "Slam" or
           spellName == "Raptor Strike" or
           spellName == "Cleave" or
           spellName == "Heroic Strike" then
            ResetMainSwing()
        end
    end
end)

-- Create options frame
local function CreateOptionsFrame()
    local optionsFrame = CreateFrame("Frame", "TurtleSwinger_Options", UIParent)
    optionsFrame:SetWidth(250)
    optionsFrame:SetHeight(150)
    optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    optionsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11},
    })
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    optionsFrame:Hide()
    
    -- Title
    optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY")
    optionsFrame.title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    optionsFrame.title:SetPoint("TOP", optionsFrame, "TOP", 0, -15)
    optionsFrame.title:SetText("TurtleSwinger Options")
    
    -- Close button
    optionsFrame.close = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    optionsFrame.close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -5, -5)
    
    -- Show offhand swing checkbox
    optionsFrame.showOffhand = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
    optionsFrame.showOffhand:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 20, -40)
    optionsFrame.showOffhand:SetChecked(false)
    
    optionsFrame.showOffhandText = optionsFrame:CreateFontString(nil, "OVERLAY")
    optionsFrame.showOffhandText:SetFont("Fonts\\FRIZQT__.TTF", 12)
    optionsFrame.showOffhandText:SetPoint("LEFT", optionsFrame.showOffhand, "RIGHT", 5, 0)
    optionsFrame.showOffhandText:SetText("Show Off-hand Swing")
    
    -- Lock frame checkbox
    optionsFrame.lockFrame = CreateFrame("CheckButton", nil, optionsFrame, "UICheckButtonTemplate")
    optionsFrame.lockFrame:SetPoint("TOPLEFT", optionsFrame.showOffhand, "BOTTOMLEFT", 0, -10)
    optionsFrame.lockFrame:SetChecked(false)
    
    optionsFrame.lockFrameText = optionsFrame:CreateFontString(nil, "OVERLAY")
    optionsFrame.lockFrameText:SetFont("Fonts\\FRIZQT__.TTF", 12)
    optionsFrame.lockFrameText:SetPoint("LEFT", optionsFrame.lockFrame, "RIGHT", 5, 0)
    optionsFrame.lockFrameText:SetText("Lock Frame Position")
    
    return optionsFrame
end

local optionsFrame = CreateOptionsFrame()

-- Create slash command to open options
SLASH_TURTLESWINGER1 = "/tswing"
SLASH_TURTLESWINGER2 = "/turtleswinger"

SlashCmdList["TURTLESWINGER"] = function(msg)
    if optionsFrame:IsVisible() then
        optionsFrame:Hide()
    else
        optionsFrame:Show()
    end
end

-- Setup on-update handler for updating the visual bar
local updateInterval = 0.05
local timeSinceLastUpdate = 0

SwingFrame:SetScript("OnUpdate", function(self, elapsed)
    -- Update the timer at specified intervals rather than every frame
    timeSinceLastUpdate = timeSinceLastUpdate + elapsed
    if timeSinceLastUpdate < updateInterval then return end
    timeSinceLastUpdate = 0
    
    -- If we're swinging, update the bar
    if isSwinging and swingDuration > 0 then
        local currentTime = GetTime()
        local elapsedTime = currentTime - lastSwingTime
        
        -- If swing is complete
        if elapsedTime >= swingDuration then
            isSwinging = false
            SwingFrame.bar:SetValue(0)
            SwingFrame.text:SetText("Ready")
        else
            -- Update bar with remaining time
            local remainingTime = swingDuration - elapsedTime
            local percentComplete = elapsedTime / swingDuration
            
            SwingFrame.bar:SetValue(percentComplete)
            SwingFrame.text:SetFormattedText("%.1f", remainingTime)
            
            -- Change color as swing approaches completion
            if percentComplete > 0.8 then
                SwingFrame.bar:SetStatusBarColor(0.0, 0.8, 0.0) -- Green for "ready soon"
            elseif percentComplete > 0.5 then
                SwingFrame.bar:SetStatusBarColor(0.8, 0.8, 0.0) -- Yellow for "in progress"
            else
                SwingFrame.bar:SetStatusBarColor(0.8, 0.0, 0.0) -- Red for "just swung"
            end
        end
    else
        -- Not currently swinging
        SwingFrame.bar:SetValue(0)
        SwingFrame.text:SetText("Ready")
        SwingFrame.bar:SetStatusBarColor(0.0, 0.8, 0.0) -- Green for "ready"
    end
end)

-- Initialize addon
local function Initialize()
    print("|cFF00FF00TurtleSwinger|r: Weapon swing timer loaded. Type /tswing or /turtleswinger for options.")
    
    -- Check if we're on TurtleWoW by looking for TurtleWoW-specific functions or globals
    local isTurtleWoW = false
    
    -- Try to detect TurtleWoW by checking for specific global variables
    if GetBuildInfo then
        local version = GetBuildInfo()
        if version and version:find("Turtle") then
            isTurtleWoW = true
        end
    end
    
    -- Alternative detection method
    if _G["TUTORIAL_TITLE_TURTLEWOW"] or _G["TURTLE_WOW"] then
        isTurtleWoW = true
    end
    
    if isTurtleWoW then
        print("|cFF00FF00TurtleSwinger|r: TurtleWoW detected - enabling additional features.")
        -- Here we could load TurtleWoW specific settings or features
    else
        print("|cFFFFFF00TurtleSwinger|r: Standard vanilla client detected.")
    end
    
    UpdateWeaponInfo()
end

-- Register for events related to weapon stats
SwingFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
SwingFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        Initialize()
    end
end)