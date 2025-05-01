-- Icons and backgrounds for DamageMeter
local icons = {
    ["Background"] = "addon/damage_meter/images/background.dds",
    ["MeterIcon"] = "addon/damage_meter/images/meter_icon.dds"
}

-- Function to create background
function CreateBackground(parent, width, height)
    local background = parent:CreateIconDrawable("background")
    if background then
        background:AddAnchor("TOPLEFT", parent, 0, 0)
        background:SetExtent(width, height)
        background:ClearAllTextures()
        background:AddTexture(icons["Background"])
        background:SetVisible(true)
        background:Show(true)
        return background
    end
    return nil
end

-- Function to create icon
function CreateIcon(parent, iconName, x, y, width, height)
    local icon = parent:CreateIconDrawable(iconName)
    if icon then
        icon:AddAnchor("TOPLEFT", parent, x, y)
        icon:SetExtent(width, height)
        icon:ClearAllTextures()
        icon:AddTexture(icons[iconName])
        icon:SetVisible(true)
        icon:Show(true)
        return icon
    end
    return nil
end 