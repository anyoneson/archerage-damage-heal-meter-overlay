-- Game global variables
-- @global RegisterEvent
-- @global SetTimer
-- @global GetTime
-- @global UnitName

-- Addon local variables
local DamageMeterDB = {
    windowPosition = {x = 100, y = 100},
    showHealing = false,
    timeWindow = 60, -- minutes
    targetName = "",
    opacity = 100,
    fontSize = 12
}
local damageData = {}
local healingData = {}
local lastUpdate = 0
local updateInterval = 1 -- seconds
local combatStartTime = 0

-- Create main window
local mainWindow = Window:new("DamageMeterWindow")
mainWindow:SetMovable(true)
mainWindow:SetFrameStrata("HIGH")
mainWindow:SetToplevel(true)
mainWindow:SetWidth(300)
mainWindow:SetHeight(400)

-- Create title label
local titleLabel = Label:new("TitleLabel", mainWindow)
titleLabel:SetText("Damage Meter")
titleLabel:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 10, 10)
titleLabel:SetWidth(280)
titleLabel:SetHeight(30)
titleLabel:SetFont("ChatFontNormal")

-- Create damage list
local damageList = ListBox:new("DamageList", mainWindow)
damageList:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, 10)
damageList:SetWidth(280)
damageList:SetHeight(320)
damageList:SetFont("ChatFontNormal")

-- Create settings button
local settingsButton = Button:new("SettingsButton", mainWindow)
settingsButton:SetText("Settings")
settingsButton:SetPoint("BOTTOMLEFT", mainWindow, "BOTTOMLEFT", 10, 10)
settingsButton:SetWidth(80)
settingsButton:SetHeight(20)
settingsButton:SetFont("ChatFontNormal")

-- Create reset button
local resetButton = Button:new("ResetButton", mainWindow)
resetButton:SetText("Reset")
resetButton:SetPoint("LEFT", settingsButton, "RIGHT", 10, 0)
resetButton:SetWidth(80)
resetButton:SetHeight(20)
resetButton:SetFont("ChatFontNormal")

-- Create settings window
local settingsWindow = Window:new("DamageMeterSettingsWindow")
settingsWindow:SetMovable(true)
settingsWindow:SetFrameStrata("HIGH")
settingsWindow:SetToplevel(true)
settingsWindow:SetWidth(300)
settingsWindow:SetHeight(250)
settingsWindow:Hide()

-- Create settings title label
local settingsTitleLabel = Label:new("SettingsTitleLabel", settingsWindow)
settingsTitleLabel:SetText("Damage Meter Settings")
settingsTitleLabel:SetPoint("TOPLEFT", settingsWindow, "TOPLEFT", 10, 10)
settingsTitleLabel:SetWidth(280)
settingsTitleLabel:SetHeight(30)
settingsTitleLabel:SetFont("ChatFontNormal")

-- Create show healing checkbox
local showHealingLabel = Label:new("ShowHealingLabel", settingsWindow)
showHealingLabel:SetText("Show Healing:")
showHealingLabel:SetPoint("TOPLEFT", settingsTitleLabel, "BOTTOMLEFT", 0, 20)
showHealingLabel:SetWidth(120)
showHealingLabel:SetHeight(20)
showHealingLabel:SetFont("ChatFontNormal")

local showHealingCheckbox = CheckBox:new("ShowHealingCheckbox", settingsWindow)
showHealingCheckbox:SetPoint("LEFT", showHealingLabel, "RIGHT", 10, 0)
showHealingCheckbox:SetWidth(20)
showHealingCheckbox:SetHeight(20)

-- Create time window edit
local timeWindowLabel = Label:new("TimeWindowLabel", settingsWindow)
timeWindowLabel:SetText("Time Window (min):")
timeWindowLabel:SetPoint("TOPLEFT", showHealingLabel, "BOTTOMLEFT", 0, 10)
timeWindowLabel:SetWidth(120)
timeWindowLabel:SetHeight(20)
timeWindowLabel:SetFont("ChatFontNormal")

local timeWindowEdit = EditBox:new("TimeWindowEdit", settingsWindow)
timeWindowEdit:SetPoint("LEFT", timeWindowLabel, "RIGHT", 10, 0)
timeWindowEdit:SetWidth(50)
timeWindowEdit:SetHeight(20)
timeWindowEdit:SetFont("ChatFontNormal")

-- Create target name edit
local targetNameLabel = Label:new("TargetNameLabel", settingsWindow)
targetNameLabel:SetText("Target Name:")
targetNameLabel:SetPoint("TOPLEFT", timeWindowLabel, "BOTTOMLEFT", 0, 10)
targetNameLabel:SetWidth(120)
targetNameLabel:SetHeight(20)
targetNameLabel:SetFont("ChatFontNormal")

local targetNameEdit = EditBox:new("TargetNameEdit", settingsWindow)
targetNameEdit:SetPoint("LEFT", targetNameLabel, "RIGHT", 10, 0)
targetNameEdit:SetWidth(120)
targetNameEdit:SetHeight(20)
targetNameEdit:SetFont("ChatFontNormal")

-- Create opacity slider
local opacityLabel = Label:new("OpacityLabel", settingsWindow)
opacityLabel:SetText("Window Opacity:")
opacityLabel:SetPoint("TOPLEFT", targetNameLabel, "BOTTOMLEFT", 0, 10)
opacityLabel:SetWidth(120)
opacityLabel:SetHeight(20)
opacityLabel:SetFont("ChatFontNormal")

local opacitySlider = Slider:new("OpacitySlider", settingsWindow)
opacitySlider:SetPoint("LEFT", opacityLabel, "RIGHT", 10, 0)
opacitySlider:SetWidth(120)
opacitySlider:SetHeight(20)
opacitySlider:SetMinMaxValues(0, 100)
opacitySlider:SetValue(100)

-- Create font size slider
local fontSizeLabel = Label:new("FontSizeLabel", settingsWindow)
fontSizeLabel:SetText("Font Size:")
fontSizeLabel:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, 10)
fontSizeLabel:SetWidth(120)
fontSizeLabel:SetHeight(20)
fontSizeLabel:SetFont("ChatFontNormal")

local fontSizeSlider = Slider:new("FontSizeSlider", settingsWindow)
fontSizeSlider:SetPoint("LEFT", fontSizeLabel, "RIGHT", 10, 0)
fontSizeSlider:SetWidth(120)
fontSizeSlider:SetHeight(20)
fontSizeSlider:SetMinMaxValues(8, 20)
fontSizeSlider:SetValue(12)

-- Create save button
local settingsSaveButton = Button:new("SettingsSaveButton", settingsWindow)
settingsSaveButton:SetText("Save")
settingsSaveButton:SetPoint("BOTTOMLEFT", settingsWindow, "BOTTOMLEFT", 10, 10)
settingsSaveButton:SetWidth(80)
settingsSaveButton:SetHeight(20)
settingsSaveButton:SetFont("ChatFontNormal")

-- Create cancel button
local settingsCancelButton = Button:new("SettingsCancelButton", settingsWindow)
settingsCancelButton:SetText("Cancel")
settingsCancelButton:SetPoint("LEFT", settingsSaveButton, "RIGHT", 10, 0)
settingsCancelButton:SetWidth(80)
settingsCancelButton:SetHeight(20)
settingsCancelButton:SetFont("ChatFontNormal")

-- Function called when the addon is loaded
function OnLoad()
    -- Debug log
    print("DamageMeter: Addon loaded")
    
    -- Configure main window
    mainWindow:SetPosition(DamageMeterDB.windowPosition.x, DamageMeterDB.windowPosition.y)
    mainWindow:SetAlpha(DamageMeterDB.opacity / 100)
    mainWindow:Show()
    
    -- Configure font
    titleLabel:SetFontSize(DamageMeterDB.fontSize)
    damageList:SetFontSize(DamageMeterDB.fontSize)
    
    -- Register events
    RegisterEvent("COMBAT_LOG_EVENT")
    RegisterEvent("PLAYER_TARGET_CHANGED")
    RegisterEvent("PLAYER_REGEN_ENABLED")
    RegisterEvent("PLAYER_REGEN_DISABLED")
    
    -- Debug log
    print("DamageMeter: Events registered")
    
    -- Configure buttons
    settingsButton:SetScript("OnClick", OpenSettings)
    resetButton:SetScript("OnClick", ResetData)
    settingsSaveButton:SetScript("OnClick", SaveSettings)
    settingsCancelButton:SetScript("OnClick", CloseSettings)
    
    -- Configure settings window controls
    showHealingCheckbox:SetChecked(DamageMeterDB.showHealing)
    timeWindowEdit:SetText(tostring(DamageMeterDB.timeWindow))
    targetNameEdit:SetText(DamageMeterDB.targetName)
    opacitySlider:SetValue(DamageMeterDB.opacity)
    fontSizeSlider:SetValue(DamageMeterDB.fontSize)
    
    -- Start update timer
    SetTimer(updateInterval * 1000, UpdateDamageList)
    
    -- Debug log
    print("DamageMeter: Configuration complete")
end

-- Function to open settings
function OpenSettings()
    settingsWindow:Show()
end

-- Function to close settings
function CloseSettings()
    settingsWindow:Hide()
end

-- Function to save settings
function SaveSettings()
    DamageMeterDB.showHealing = showHealingCheckbox:GetChecked()
    DamageMeterDB.timeWindow = tonumber(timeWindowEdit:GetText()) or 60
    DamageMeterDB.targetName = targetNameEdit:GetText()
    DamageMeterDB.opacity = opacitySlider:GetValue()
    DamageMeterDB.fontSize = fontSizeSlider:GetValue()
    
    -- Apply settings
    mainWindow:SetAlpha(DamageMeterDB.opacity / 100)
    titleLabel:SetFontSize(DamageMeterDB.fontSize)
    damageList:SetFontSize(DamageMeterDB.fontSize)
    
    CloseSettings()
end

-- Function to reset data
function ResetData()
    damageData = {}
    healingData = {}
    combatStartTime = 0
    UpdateDamageList()
end

-- Function to update damage list
function UpdateDamageList()
    damageList:Clear()
    
    -- Sort data by total damage
    local sortedData = {}
    for name, data in pairs(damageData) do
        table.insert(sortedData, {name = name, total = data.total, isHealing = false})
    end
    
    -- Add healing data if configured
    if DamageMeterDB.showHealing then
        for name, data in pairs(healingData) do
            table.insert(sortedData, {name = name, total = data.total, isHealing = true})
        end
    end
    
    table.sort(sortedData, function(a, b) return a.total > b.total end)
    
    -- Add items to list
    for i, data in ipairs(sortedData) do
        local prefix = data.isHealing and "H" or "D"
        damageList:AddItem(string.format("%d. [%s] %s - %s", i, prefix, data.name, FormatNumber(data.total)))
    end
end

-- Function to format large numbers
function FormatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n/1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n/1000)
    else
        return tostring(n)
    end
end

-- Function called when a combat event occurs
function OnEvent(event, ...)
    if event == "COMBAT_LOG_EVENT" then
        local timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, amount = ...
        
        -- Check if event is within time window
        if combatStartTime > 0 and timestamp - combatStartTime > DamageMeterDB.timeWindow * 60 then
            return
        end
        
        -- Filter by specific target if configured
        if DamageMeterDB.targetName ~= "" and destName ~= DamageMeterDB.targetName then
            return
        end
        
        -- Process damage events
        if eventType == "SPELL_DAMAGE" or eventType == "SWING_DAMAGE" then
            if not damageData[sourceName] then
                damageData[sourceName] = {total = 0}
            end
            damageData[sourceName].total = damageData[sourceName].total + amount
        end
        
        -- Process healing events
        if eventType == "SPELL_HEAL" then
            if not healingData[sourceName] then
                healingData[sourceName] = {total = 0}
            end
            healingData[sourceName].total = healingData[sourceName].total + amount
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Update target name
        DamageMeterDB.targetName = UnitName("target") or ""
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat start
        combatStartTime = GetTime()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat end
        combatStartTime = 0
    end
end

-- Function called when the addon is unloaded
function OnUnload()
    -- Save window position
    DamageMeterDB.windowPosition = {
        x = mainWindow:GetLeft(),
        y = mainWindow:GetTop()
    }
end 