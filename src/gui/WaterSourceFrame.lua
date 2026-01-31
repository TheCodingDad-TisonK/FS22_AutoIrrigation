-- =========================================================
-- Auto Irrigation (version 1.0.0.0)
-- =========================================================
-- Automated irrigation system for your fields
-- =========================================================
-- Author: TisonK
-- =========================================================
-- COPYRIGHT NOTICE:
-- All rights reserved. Unauthorized redistribution, copying,
-- or claiming this code as your own is strictly prohibited.
-- Original author: TisonK
-- =========================================================
---@class WaterSourceFrame
---@field waterSourcesEnabled CheckedOptionElement
---@field waterSourcesWellWaterEnabled CheckedOptionElement
---@field waterSourcesRiverWaterEnabled CheckedOptionElement
---@field waterSourcesRainwaterEnabled CheckedOptionElement
---@field waterSourcesWaterTankRefill CheckedOptionElement
---@field waterSourcesMaxWaterDistance TextInputElement
---@field waterSourcesPumpSpeed TextInputElement
---@field waterSourcesShowWaterInfo CheckedOptionElement
---@field waterSourcesDebugMode CheckedOptionElement
---@field boxLayout BoxLayoutElement
WaterSourceFrame = {}

local WaterSourceFrame_mt = Class(WaterSourceFrame, TabbedMenuFrameElement)

WaterSourceFrame.CONTROLS = {
    'waterSourcesEnabled',
    'waterSourcesWellWaterEnabled',
    'waterSourcesRiverWaterEnabled',
    'waterSourcesRainwaterEnabled',
    'waterSourcesWaterTankRefill',
    'waterSourcesMaxWaterDistance',
    'waterSourcesPumpSpeed',
    'waterSourcesShowWaterInfo',
    'waterSourcesDebugMode',
    'boxLayout'
}

function WaterSourceFrame.new(target, customMt)
    local self = TabbedMenuFrameElement.new(target, customMt or WaterSourceFrame_mt)

    self:registerControls(WaterSourceFrame.CONTROLS)

    return self
end

function WaterSourceFrame:initialize()
    self.backButtonInfo = {
        inputAction = InputAction.MENU_BACK
    }
end

function WaterSourceFrame:onFrameOpen()
    WaterSourceFrame:superClass().onFrameOpen(self)
    self:updateWaterSources()

    self.boxLayout:invalidateLayout()

    if FocusManager:getFocusedElement() == nil then
        self:setSoundSuppressed(true)
        FocusManager:setFocus(self.boxLayout)
        self:setSoundSuppressed(false)
    end
end

function WaterSourceFrame:updateWaterSources()
    self.waterSourcesEnabled:setIsChecked(g_AutoIrrigation:getTypeNameValue('waterSources', 'enabled'))
    self.waterSourcesWellWaterEnabled:setIsChecked(g_AutoIrrigation:getTypeNameValue('waterSources', 'wellWaterEnabled'))
    self.waterSourcesRiverWaterEnabled:setIsChecked(g_AutoIrrigation:getTypeNameValue('waterSources', 'riverWaterEnabled'))
    self.waterSourcesRainwaterEnabled:setIsChecked(g_AutoIrrigation:getTypeNameValue('waterSources', 'rainwaterEnabled'))
    self.waterSourcesWaterTankRefill:setIsChecked(g_AutoIrrigation:getTypeNameValue('waterSources', 'waterTankRefill'))
    self.waterSourcesShowWaterInfo:setIsChecked(g_AutoIrrigation:getTypeNameValue('waterSources', 'showWaterInfo'))
    self.waterSourcesDebugMode:setIsChecked(g_AutoIrrigation:getTypeNameValue('waterSources', 'debugMode'))

    self:setElementText(self.waterSourcesMaxWaterDistance, g_AutoIrrigation:getTypeNameValue('waterSources', 'maxWaterDistance'))
    self:setElementText(self.waterSourcesPumpSpeed, g_AutoIrrigation:getTypeNameValue('waterSources', 'pumpSpeed'))
end

function WaterSourceFrame:setElementText(element, value)
    if element.id == 'waterSourcesPumpSpeed' then
        element:setText(string.format('%.1f', value))
    else
        element:setText(string.format('%.0f', value))
    end
end

---@param state number
---@param element CheckedOptionElement
function WaterSourceFrame:onCheckClick(state, element)
    local value = state == CheckedOptionElement.STATE_CHECKED

    if element.id == "waterSourcesEnabled" then
        g_AutoIrrigation:setTypeNameValue("waterSources", "enabled", value)
    else
        g_AutoIrrigation:setTypeNameValue("waterSources", element.id, value)
    end

    g_AutoIrrigation:saveSettings()
end

---@param element TextInputElement
function WaterSourceFrame:onEnterPressedTextInput(element)
    local value = tonumber(element.text)
    if value == nil then return end

    if element.id == 'waterSourcesMaxWaterDistance' then
        value = math.max(50, math.min(500, value))
        g_AutoIrrigation.waterSources.maxWaterDistance = value

    elseif element.id == 'waterSourcesPumpSpeed' then
        value = math.max(0.1, math.min(5.0, value))
        g_AutoIrrigation.waterSources.pumpSpeed = value
    end

    g_AutoIrrigation:saveSettings()
    self:setElementText(element, value)
end
