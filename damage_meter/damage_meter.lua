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

-- Function called when the addon is loaded
function OnLoad()
    -- Debug log
    print("DamageMeter: Addon loaded")
    
    -- Configure main window
    DamageMeterWindow:SetPosition(DamageMeterDB.windowPosition.x, DamageMeterDB.windowPosition.y)
    DamageMeterWindow:SetAlpha(DamageMeterDB.opacity / 100)
    DamageMeterWindow:Show(true)
    
    -- Debug log
    print("DamageMeter: Window configured")
    
    -- Configure font
    TitleLabel:SetFontSize(DamageMeterDB.fontSize)
    DamageList:SetFontSize(DamageMeterDB.fontSize)
    
    -- Register events
    RegisterEvent("COMBAT_LOG_EVENT")
    RegisterEvent("PLAYER_TARGET_CHANGED")
    RegisterEvent("PLAYER_REGEN_ENABLED")
    RegisterEvent("PLAYER_REGEN_DISABLED")
    
    -- Debug log
    print("DamageMeter: Events registered")
    
    -- Configure main window buttons
    SettingsButton:SetScript("OnClick", OpenSettings)
    ResetButton:SetScript("OnClick", ResetData)
    
    -- Configure settings window controls
    ShowHealingCheckbox:SetChecked(DamageMeterDB.showHealing)
    TimeWindowEdit:SetText(tostring(DamageMeterDB.timeWindow))
    TargetNameEdit:SetText(DamageMeterDB.targetName)
    OpacitySlider:SetValue(DamageMeterDB.opacity)
    FontSizeSlider:SetValue(DamageMeterDB.fontSize)
    
    -- Configure settings window buttons
    SettingsSaveButton:SetScript("OnClick", SaveSettings)
    SettingsCancelButton:SetScript("OnClick", CloseSettings)
    
    -- Start update timer
    SetTimer(updateInterval * 1000, UpdateDamageList)
    
    -- Debug log
    print("DamageMeter: Configuration complete")
end

-- Function to open settings
function OpenSettings()
    DamageMeterSettingsWindow:Show(true)
end

-- Function to close settings
function CloseSettings()
    DamageMeterSettingsWindow:Show(false)
end

-- Function to save settings
function SaveSettings()
    DamageMeterDB.showHealing = ShowHealingCheckbox:GetChecked()
    DamageMeterDB.timeWindow = tonumber(TimeWindowEdit:GetText()) or 60
    DamageMeterDB.targetName = TargetNameEdit:GetText()
    DamageMeterDB.opacity = OpacitySlider:GetValue()
    DamageMeterDB.fontSize = FontSizeSlider:GetValue()
    
    -- Apply settings
    DamageMeterWindow:SetAlpha(DamageMeterDB.opacity / 100)
    TitleLabel:SetFontSize(DamageMeterDB.fontSize)
    DamageList:SetFontSize(DamageMeterDB.fontSize)
    
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
    DamageList:Clear()
    
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
        DamageList:AddItem(string.format("%d. [%s] %s - %s", i, prefix, data.name, FormatNumber(data.total)))
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
        x = DamageMeterWindow:GetLeft(),
        y = DamageMeterWindow:GetTop()
    }
end 