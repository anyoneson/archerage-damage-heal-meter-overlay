-- Debug function
local function DebugMessage(message)
    -- Try different logging methods
    if X2Log then
        X2Log:Log("DamageMeter", message)
    elseif X2Chat then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("[DamageMeter] %s", message))
    else
        -- Fallback to print if nothing else works
        print(string.format("[DamageMeter] %s", message))
    end
end

-- Try to log immediately to see if we can get any output
DebugMessage("Script started loading")

-- Check if we're in the game environment
if not ADDON then
    DebugMessage("ERROR - Not in game environment, ADDON is nil")
    return
end

-- Import button functions
local buttonFile = io.open("interface/addons/damageMeter/button.lua", "r")
if buttonFile then
    local buttonCode = buttonFile:read("*all")
    buttonFile:close()
    local func = loadstring(buttonCode)
    if func then
        func()
        DebugMessage("Button functions loaded successfully")
    else
        DebugMessage("ERROR - Failed to load button functions")
    end
else
    DebugMessage("ERROR - Could not find button.lua")
end

-- Check if the file is being loaded correctly
local function IsFileLoaded()
    DebugMessage("Checking if file is loaded correctly")
    if not _G then
        DebugMessage("ERROR - _G is nil")
        return false
    end
    
    -- Try to access some global functions
    if not type then
        DebugMessage("ERROR - type function not found")
        return false
    end
    
    if not print then
        DebugMessage("ERROR - print function not found")
        return false
    end
    
    DebugMessage("File appears to be loaded correctly")
    return true
end

-- Run the check
if not IsFileLoaded() then
    DebugMessage("ERROR - File not loaded correctly")
    return
end

-- Try to write to a file to verify we have access
local function WriteDebugFile()
    local file = io.open("DamageMeterDebug.txt", "w")
    if file then
        file:write("DamageMeter debug file created\n")
        file:close()
        DebugMessage("Debug file created successfully")
        return true
    else
        DebugMessage("ERROR - Could not create debug file")
        return false
    end
end

-- Try to write the debug file
WriteDebugFile()

DebugMessage("ADDON exists: " .. tostring(ADDON ~= nil))

-- Game global variables
-- @global RegisterEvent
-- @global SetTimer
-- @global GetTime
-- @global UnitName

DebugMessage("Checking global variables")
DebugMessage("RegisterEvent exists: " .. tostring(RegisterEvent ~= nil))
DebugMessage("SetTimer exists: " .. tostring(SetTimer ~= nil))
DebugMessage("GetTime exists: " .. tostring(GetTime ~= nil))
DebugMessage("UnitName exists: " .. tostring(UnitName ~= nil))

DebugMessage("Starting addon initialization")

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)
ADDON:ImportAPI(API_TYPE.PLAYER.id)
ADDON:ImportAPI(API_TYPE.EQUIPMENT.id)
ADDON:ImportAPI(API_TYPE.BAG.id)
ADDON:ImportAPI(API_TYPE.TIME.id)
ADDON:ImportAPI(API_TYPE.MAP.id)

-- Debug logs
DebugMessage("Starting addon initialization")

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
local mainWindow = nil
local meterButton = nil
local settingsWindow = nil
local titleLabel = nil
local damageList = nil
local settingsButton = nil
local resetButton = nil
local showHealingLabel = nil
local showHealingCheckbox = nil
local timeWindowLabel = nil
local timeWindowEdit = nil
local targetNameLabel = nil
local targetNameEdit = nil
local opacityLabel = nil
local opacitySlider = nil
local fontSizeLabel = nil
local fontSizeSlider = nil
local settingsSaveButton = nil
local settingsCancelButton = nil
local background = nil
local titleLabel = nil

-- Function to apply button skin
function ApplyButtonSkin(button, skin)
    if not button or not skin then return end
    
    -- Set button background
    if skin.drawableType == "ninePart" then
        local bg = button:CreateNinePartDrawable("background")
        bg:SetTexture(skin.path)
        bg:SetCoordsKey(skin.coordsKey)
        bg:SetAutoResize(skin.autoResize)
        button:SetNormalBackground(bg)
        button:SetHighlightBackground(bg)
    end
    
    -- Set font color
    if skin.fontColor then
        local color = skin.fontColor
        button:SetTextColor(color.normal[1], color.normal[2], color.normal[3], color.normal[4])
        button:SetHighlightTextColor(color.highlight[1], color.highlight[2], color.highlight[3], color.highlight[4])
        button:SetPushedTextColor(color.pushed[1], color.pushed[2], color.pushed[3], color.pushed[4])
        button:SetDisabledTextColor(color.disabled[1], color.disabled[2], color.disabled[3], color.disabled[4])
    end
    
    -- Set font inset
    if skin.fontInset then
        button:SetInset(skin.fontInset.left, skin.fontInset.top, skin.fontInset.right, skin.fontInset.bottom)
    end
end

-- Function to get button skin
function GetButtonSkin()
    local color = {
        normal = UIParent:GetFontColor("btn_df"),
        highlight = UIParent:GetFontColor("btn_ov"),
        pushed = UIParent:GetFontColor("btn_on"),
        disabled = UIParent:GetFontColor("btn_dis"),
        active = UIParent:GetFontColor("lime")
    }

    return {
        drawableType = "ninePart",
        path = "ui/common/default.dds",
        coordsKey = "btn",
        autoResize = true,
        fontColor = color,
        fontInset = {
            left = 11,
            right = 11,
            top = 0,
            bottom = 0
        }
    }
end

-- Function to create a button
function CreateButton(text, x, y, handler)
    local button = UIParent:CreateWidget("button", text, "UIParent", "")
    button:SetText(text)
    ApplyButtonSkin(button, GetButtonSkin())
    button:AddAnchor("TOPRIGHT", "UIParent", x, y)
    button:Show(true)
    button:EnableDrag(true)
    if handler then
        button:SetHandler("OnClick", handler)
    end
    return button
end

function CreateMeterWindow()
    if mainWindow then
        return mainWindow
    end

    -- Create main window
    local mainWindow = CreateEmptyWindow("mainWindow", "UIParent") --("DamageMeterWindow")
    mainWindow:SetMovable(true)
    mainWindow:SetFrameStrata("HIGH")
    mainWindow:SetToplevel(true)
    mainWindow.SetExtend(300, 150)
    mainWindow:AddAnchor("CENTER", "UIParent", 0, 0)
    mainWindow:SetWidth(300)
    mainWindow:SetHeight(400)
    mainWindow:Show(false) -- Hide by default

    -- Create background
    --local background = CreateBackground(mainWindow, 300, 400) 
    background = mainWindow:CreateColorDrawable(0, 0, 0, 0.8, "background")
    background:AddAnchor("TOPLEFT", mainWindow, 0, 0)
    background:AddAnchor("BOTTOMRIGHT", mainWindow, 0, 0)

    -- Create title label
    local titleLabel = mainWindow:CreateChildWidget("label", "titleLabel", 0, false)
    titleLabel:SetText("Damage Meter")
    titleLabel:SetPoint("TOPLEFT", mainWindow, "TOPLEFT", 10, 10)
    titleLabel:SetWidth(280)
    titleLabel:SetHeight(30)
    titleLabel:SetFont("ChatFontNormal")

    -- Create damage list
    -- local damageList = ListBox:new("DamageList", mainWindow)
    local damageList = mainWindow:CreateChildWidget("listBox", "DamageList", 0, false)
    damageList:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, 10)
    damageList:SetWidth(280)
    damageList:SetHeight(320)
    damageList:SetFont("ChatFontNormal")

    -- Create settings button
    local settingsButton = CreateButton("Settings", -300, 15, OpenSettings)
    settingsButton:SetText("Settings")
    settingsButton:SetPoint("BOTTOMLEFT", mainWindow, "BOTTOMLEFT", 10, 10)
    settingsButton:SetWidth(80)
    settingsButton:SetHeight(20)
    settingsButton:SetFont("ChatFontNormal")

    -- Create reset button
    local resetButton = CreateButton("Reset", -300, 15, ResetData)
    resetButton:SetText("Reset")
    resetButton:SetPoint("LEFT", settingsButton, "RIGHT", 10, 0)
    resetButton:SetWidth(80)
    resetButton:SetHeight(20)
    resetButton:SetFont("ChatFontNormal")
    return mainWindow
end

-- Function to toggle meter window
function ToggleMeterWindow()
    if mainWindow then
        DebugMessage("Toggling meter window")
        if mainWindow:IsVisible() then
            mainWindow:Show(false)
        else
            mainWindow:Show(true)
        end
    else
        mainWindow = CreateMeterWindow()
    end
end

-- Create meter button
local function CreateMeterButton()
    DebugMessage("Creating meter button")
    local button = CreateButton("Meter", 1400, 200, ToggleMeterWindow)
    if not button then
        DebugMessage("ERROR - Failed to create meter button")
        return nil
    end
    DebugMessage("Meter button created")
    
    button:SetWidth(80)
    button:SetHeight(25)
    DebugMessage("Meter button size set")
    
    return button
end

function CreateSettingsWindow()
    if settingsWindow then
        return settingsWindow
    else
        -- Create settings window
        local settingsWindow = CreateEmptyWindow("DamageMeterSettingsWindow", "UIParent")
        settingsWindow:SetMovable(true)
        settingsWindow:SetFrameStrata("HIGH")
        settingsWindow:SetToplevel(true)
        settingsWindow:SetWidth(300)
        settingsWindow:SetHeight(250)
        settingsWindow:Hide()

        -- Create settings title label
        local settingsTitleLabel = settingsWindow:CreateChildWidget("label", "SettingsTitleLabel", 0, false)
        settingsTitleLabel:SetText("Damage Meter Settings")
        settingsTitleLabel:SetPoint("TOPLEFT", settingsWindow, "TOPLEFT", 10, 10)
        settingsTitleLabel:SetWidth(280)
        settingsTitleLabel:SetHeight(30)
        settingsTitleLabel:SetFont("ChatFontNormal")

        -- Create show healing checkbox
        local showHealingLabel = settingsWindow:CreateChildWidget("label", "ShowHealingLabel", 0, false)
        showHealingLabel:SetText("Show Healing:")
        showHealingLabel:SetPoint("TOPLEFT", settingsTitleLabel, "BOTTOMLEFT", 0, 20)
        showHealingLabel:SetWidth(120)
        showHealingLabel:SetHeight(20)
        showHealingLabel:SetFont("ChatFontNormal")

        -- local showHealingCheckbox = CheckBox:new("ShowHealingCheckbox", settingsWindow)
        local showHealingCheckbox = settingsWindow:CreateChildWidget("checkBox", "ShowHealingCheckbox", 0, false)
        showHealingCheckbox:SetPoint("LEFT", showHealingLabel, "RIGHT", 10, 0)
        showHealingCheckbox:SetWidth(20)
        showHealingCheckbox:SetHeight(20)

        -- Create time window edit
        local timeWindowLabel = settingsWindow:CreateChildWidget("label", "TimeWindowLabel", 0, false)
        timeWindowLabel:SetText("Time Window (min):")
        timeWindowLabel:SetPoint("TOPLEFT", showHealingLabel, "BOTTOMLEFT", 0, 10)
        timeWindowLabel:SetWidth(120)
        timeWindowLabel:SetHeight(20)
        timeWindowLabel:SetFont("ChatFontNormal")

        -- local timeWindowEdit = EditBox:new("TimeWindowEdit", settingsWindow)
        local timeWindowEdit = settingsWindow:CreateChildWidget("editBox", "TimeWindowEdit", 0, false)
        timeWindowEdit:SetPoint("LEFT", timeWindowLabel, "RIGHT", 10, 0)
        timeWindowEdit:SetWidth(50)
        timeWindowEdit:SetHeight(20)
        timeWindowEdit:SetFont("ChatFontNormal")

        -- Create target name edit
        local targetNameLabel = settingsWindow:CreateChildWidget("label", "TargetNameLabel", 0, false)
        targetNameLabel:SetText("Target Name:")
        targetNameLabel:SetPoint("TOPLEFT", timeWindowLabel, "BOTTOMLEFT", 0, 10)
        targetNameLabel:SetWidth(120)
        targetNameLabel:SetHeight(20)
        targetNameLabel:SetFont("ChatFontNormal")

        -- local targetNameEdit = EditBox:new("TargetNameEdit", settingsWindow)
        local targetNameEdit = settingsWindow:CreateChildWidget("editBox", "TargetNameEdit", 0, false)
        targetNameEdit:SetPoint("LEFT", targetNameLabel, "RIGHT", 10, 0)
        targetNameEdit:SetWidth(120)
        targetNameEdit:SetHeight(20)
        targetNameEdit:SetFont("ChatFontNormal")

        -- Create opacity slider
        local opacityLabel = settingsWindow:CreateChildWidget("label", "OpacityLabel", 0, false)
        opacityLabel:SetText("Window Opacity:")
        opacityLabel:SetPoint("TOPLEFT", targetNameLabel, "BOTTOMLEFT", 0, 10)
        opacityLabel:SetWidth(120)
        opacityLabel:SetHeight(20)
        opacityLabel:SetFont("ChatFontNormal")

        -- local opacitySlider = Slider:new("OpacitySlider", settingsWindow)
        local opacitySlider = settingsWindow:CreateChildWidget("slider", "OpacitySlider", 0, false)
        opacitySlider:SetPoint("LEFT", opacityLabel, "RIGHT", 10, 0)
        opacitySlider:SetWidth(120)
        opacitySlider:SetHeight(20)
        opacitySlider:SetMinMaxValues(0, 100)
        opacitySlider:SetValue(100)

        -- Create font size slider
        local fontSizeLabel = settingsWindow:CreateChildWidget("label", "FontSizeLabel", 0, false)
        fontSizeLabel:SetText("Font Size:")
        fontSizeLabel:SetPoint("TOPLEFT", opacityLabel, "BOTTOMLEFT", 0, 10)
        fontSizeLabel:SetWidth(120)
        fontSizeLabel:SetHeight(20)
        fontSizeLabel:SetFont("ChatFontNormal")

        -- local fontSizeSlider = Slider:new("FontSizeSlider", settingsWindow)
        local fontSizeSlider = settingsWindow:CreateChildWidget("slider", "FontSizeSlider", 0, false)
        fontSizeSlider:SetPoint("LEFT", fontSizeLabel, "RIGHT", 10, 0)
        fontSizeSlider:SetWidth(120)
        fontSizeSlider:SetHeight(20)
        fontSizeSlider:SetMinMaxValues(8, 20)
        fontSizeSlider:SetValue(12)

        -- Create save button
        local settingsSaveButton = CreateButton("Save", -300, 15, SaveSettings) -- Button:new("SettingsSaveButton", settingsWindow)
        settingsSaveButton:SetText("Save")
        settingsSaveButton:SetPoint("BOTTOMLEFT", settingsWindow, "BOTTOMLEFT", 10, 10)
        settingsSaveButton:SetWidth(80)
        settingsSaveButton:SetHeight(20)
        settingsSaveButton:SetFont("ChatFontNormal")

        -- Create cancel button
        local settingsCancelButton = CreateButton("Cancel", -300, 15, CloseSettings) -- Button:new("SettingsCancelButton", settingsWindow)
        settingsCancelButton:SetText("Cancel")
        settingsCancelButton:SetPoint("LEFT", settingsSaveButton, "RIGHT", 10, 0)
        settingsCancelButton:SetWidth(80)
        settingsCancelButton:SetHeight(20)
        settingsCancelButton:SetFont("ChatFontNormal")

        return settingsWindow
    end
end

-- Function called when the addon is loaded
function OnLoad()
    DebugMessage("OnLoad called")
    
    -- Configure main window
    DebugMessage("Configuring main window")
    mainWindow:SetPosition(DamageMeterDB.windowPosition.x, DamageMeterDB.windowPosition.y)
    mainWindow:SetAlpha(DamageMeterDB.opacity / 100)
    mainWindow:Show()
    DebugMessage("Main window configured")
    
    -- Configure font
    DebugMessage("Configuring fonts")
    titleLabel:SetFontSize(DamageMeterDB.fontSize)
    damageList:SetFontSize(DamageMeterDB.fontSize)
    DebugMessage("Fonts configured")
    
    -- Register events
    DebugMessage("Registering events")
    RegisterEvent("COMBAT_LOG_EVENT")
    RegisterEvent("PLAYER_TARGET_CHANGED")
    RegisterEvent("PLAYER_REGEN_ENABLED")
    RegisterEvent("PLAYER_REGEN_DISABLED")
    DebugMessage("Events registered")
    
    -- Configure buttons
    DebugMessage("Configuring buttons")
    settingsButton:SetScript("OnClick", OpenSettings)
    resetButton:SetScript("OnClick", ResetData)
    settingsSaveButton:SetScript("OnClick", SaveSettings)
    settingsCancelButton:SetScript("OnClick", CloseSettings)
    DebugMessage("Buttons configured")
    
    -- Configure settings window controls
    DebugMessage("Configuring settings window")
    showHealingCheckbox:SetChecked(DamageMeterDB.showHealing)
    timeWindowEdit:SetText(tostring(DamageMeterDB.timeWindow))
    targetNameEdit:SetText(DamageMeterDB.targetName)
    opacitySlider:SetValue(DamageMeterDB.opacity)
    fontSizeSlider:SetValue(DamageMeterDB.fontSize)
    DebugMessage("Settings window configured")
    
    -- Start update timer
    DebugMessage("Starting update timer")
    SetTimer(updateInterval * 1000, UpdateDamageList)
    DebugMessage("Update timer started")
    
    DebugMessage("OnLoad completed")
end

-- Function to open settings
function OpenSettings()
    settingsWindow:Show(true)
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

-- Function to create the main button when entering the world
local function EnteredWorld()
    DebugMessage("EnteredWorld called")
    CreateMeterButton()
    CreateSettingsWindow()
end

-- Register the EnteredWorld event
UIParent:SetEventHandler(UIEVENT_TYPE.ENTERED_WORLD, EnteredWorld)