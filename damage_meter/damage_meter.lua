-- Variáveis globais
local DamageMeterDB = {}
local damageData = {}
local healingData = {}
local lastUpdate = 0
local updateInterval = 1 -- segundos
local combatStartTime = 0

-- Função chamada quando o addon é carregado
function OnLoad()
    -- Log de debug
    print("DamageMeter: Addon carregado")
    
    -- Inicializa o banco de dados se não existir
    if not DamageMeterDB then
        DamageMeterDB = {
            windowPosition = {x = 100, y = 100},
            showHealing = false,
            timeWindow = 60, -- minutos
            targetName = "",
            opacity = 100,
            fontSize = 12
        }
    end
    
    -- Configura a janela principal
    DamageMeterWindow:SetPosition(DamageMeterDB.windowPosition.x, DamageMeterDB.windowPosition.y)
    DamageMeterWindow:SetAlpha(DamageMeterDB.opacity / 100)
    DamageMeterWindow:Show(true)
    
    -- Log de debug
    print("DamageMeter: Janela configurada")
    
    -- Configura a fonte
    TitleLabel:SetFontSize(DamageMeterDB.fontSize)
    DamageList:SetFontSize(DamageMeterDB.fontSize)
    
    -- Registra os eventos
    RegisterEvent("COMBAT_LOG_EVENT")
    RegisterEvent("PLAYER_TARGET_CHANGED")
    RegisterEvent("PLAYER_REGEN_ENABLED")
    RegisterEvent("PLAYER_REGEN_DISABLED")
    
    -- Log de debug
    print("DamageMeter: Eventos registrados")
    
    -- Configura os botões da janela principal
    SettingsButton:SetScript("OnClick", OpenSettings)
    ResetButton:SetScript("OnClick", ResetData)
    
    -- Configura os controles da janela de configurações
    ShowHealingCheckbox:SetChecked(DamageMeterDB.showHealing)
    TimeWindowEdit:SetText(tostring(DamageMeterDB.timeWindow))
    TargetNameEdit:SetText(DamageMeterDB.targetName)
    OpacitySlider:SetValue(DamageMeterDB.opacity)
    FontSizeSlider:SetValue(DamageMeterDB.fontSize)
    
    -- Configura os botões da janela de configurações
    SettingsSaveButton:SetScript("OnClick", SaveSettings)
    SettingsCancelButton:SetScript("OnClick", CloseSettings)
    
    -- Inicia o timer de atualização
    SetTimer(updateInterval * 1000, UpdateDamageList)
    
    -- Log de debug
    print("DamageMeter: Configuração completa")
end

-- Função para abrir as configurações
function OpenSettings()
    DamageMeterSettingsWindow:Show(true)
end

-- Função para fechar as configurações
function CloseSettings()
    DamageMeterSettingsWindow:Show(false)
end

-- Função para salvar as configurações
function SaveSettings()
    DamageMeterDB.showHealing = ShowHealingCheckbox:GetChecked()
    DamageMeterDB.timeWindow = tonumber(TimeWindowEdit:GetText()) or 60
    DamageMeterDB.targetName = TargetNameEdit:GetText()
    DamageMeterDB.opacity = OpacitySlider:GetValue()
    DamageMeterDB.fontSize = FontSizeSlider:GetValue()
    
    -- Aplica as configurações
    DamageMeterWindow:SetAlpha(DamageMeterDB.opacity / 100)
    TitleLabel:SetFontSize(DamageMeterDB.fontSize)
    DamageList:SetFontSize(DamageMeterDB.fontSize)
    
    CloseSettings()
end

-- Função para resetar os dados
function ResetData()
    damageData = {}
    healingData = {}
    combatStartTime = 0
    UpdateDamageList()
end

-- Função para atualizar a lista de dano
function UpdateDamageList()
    DamageList:Clear()
    
    -- Ordena os dados por dano total
    local sortedData = {}
    for name, data in pairs(damageData) do
        table.insert(sortedData, {name = name, total = data.total, isHealing = false})
    end
    
    -- Adiciona dados de cura se configurado
    if DamageMeterDB.showHealing then
        for name, data in pairs(healingData) do
            table.insert(sortedData, {name = name, total = data.total, isHealing = true})
        end
    end
    
    table.sort(sortedData, function(a, b) return a.total > b.total end)
    
    -- Adiciona os itens à lista
    for i, data in ipairs(sortedData) do
        local prefix = data.isHealing and "H" or "D"
        DamageList:AddItem(string.format("%d. [%s] %s - %s", i, prefix, data.name, FormatNumber(data.total)))
    end
end

-- Função para formatar números grandes
function FormatNumber(n)
    if n >= 1000000 then
        return string.format("%.1fM", n/1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n/1000)
    else
        return tostring(n)
    end
end

-- Função chamada quando ocorre um evento de combate
function OnEvent(event, ...)
    if event == "COMBAT_LOG_EVENT" then
        local timestamp, eventType, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, amount = ...
        
        -- Verifica se o evento está dentro da janela de tempo
        if combatStartTime > 0 and timestamp - combatStartTime > DamageMeterDB.timeWindow * 60 then
            return
        end
        
        -- Filtra por alvo específico se configurado
        if DamageMeterDB.targetName ~= "" and destName ~= DamageMeterDB.targetName then
            return
        end
        
        -- Processa eventos de dano
        if eventType == "SPELL_DAMAGE" or eventType == "SWING_DAMAGE" then
            if not damageData[sourceName] then
                damageData[sourceName] = {total = 0}
            end
            damageData[sourceName].total = damageData[sourceName].total + amount
        end
        
        -- Processa eventos de cura
        if eventType == "SPELL_HEAL" then
            if not healingData[sourceName] then
                healingData[sourceName] = {total = 0}
            end
            healingData[sourceName].total = healingData[sourceName].total + amount
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Atualiza o nome do alvo
        DamageMeterDB.targetName = UnitName("target") or ""
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Início do combate
        combatStartTime = GetTime()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Fim do combate
        combatStartTime = 0
    end
end

-- Função chamada quando o addon é desativado
function OnUnload()
    -- Salva a posição da janela
    DamageMeterDB.windowPosition = {
        x = DamageMeterWindow:GetLeft(),
        y = DamageMeterWindow:GetTop()
    }
end 