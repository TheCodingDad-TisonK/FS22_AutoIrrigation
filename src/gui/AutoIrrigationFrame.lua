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
---@class AutoIrrigationFrame
---@field irrigationEnabled CheckedOptionElement
---@field irrigationAutomationLevel TextInputElement
---@field irrigationWaterUsage TextInputElement
---@field irrigationEfficiency TextInputElement
---@field irrigationAutoStart CheckedOptionElement
---@field irrigationAutoStop CheckedOptionElement
---@field irrigationShowNotifications CheckedOptionElement
---@field irrigationShowWarnings CheckedOptionElement
---@field irrigationScheduleEnabled CheckedOptionElement
---@field irrigationMorningTime TextInputElement
---@field irrigationEveningTime TextInputElement
---@field irrigationMinMoisture TextInputElement
---@field irrigationMaxMoisture TextInputElement
---@field startIrrigationButtonWrapper GuiElement
---@field boxLayout BoxLayoutElement
AutoIrrigationFrame = {}

local AutoIrrigationFrame_mt = Class(AutoIrrigationFrame, TabbedMenuFrameElement)

AutoIrrigationFrame.CONTROLS = {
    'irrigationEnabled',
    'irrigationAutomationLevel',
    'irrigationWaterUsage',
    'irrigationEfficiency',
    'irrigationAutoStart',
    'irrigationAutoStop',
    'irrigationShowNotifications',
    'irrigationShowWarnings',
    'irrigationScheduleEnabled',
    'irrigationMorningTime',
    'irrigationEveningTime',
    'irrigationMinMoisture',
    'irrigationMaxMoisture',
    'startIrrigationButtonWrapper',
    'boxLayout'
}

function AutoIrrigationFrame.new(target, customMt)
    local self = TabbedMenuFrameElement.new(target, customMt or AutoIrrigationFrame_mt)

    self:registerControls(AutoIrrigationFrame.CONTROLS)

    return self
end

function AutoIrrigationFrame:initialize()
    self.backButtonInfo = {
        inputAction = InputAction.MENU_BACK
    }
end

function AutoIrrigationFrame:onFrameOpen()
    AutoIrrigationFrame:superClass().onFrameOpen(self)
    self:updateAutoIrrigation()

    self.boxLayout:invalidateLayout()

    if FocusManager:getFocusedElement() == nil then
        self:setSoundSuppressed(true)
        FocusManager:setFocus(self.boxLayout)
        self:setSoundSuppressed(false)
    end
end

function AutoIrrigationFrame:updateAutoIrrigation()
    self.irrigationEnabled:setIsChecked(g_AutoIrrigation:getTypeNameValue('irrigation', 'enabled'))
    self.irrigationAutoStart:setIsChecked(g_AutoIrrigation:getTypeNameValue('irrigation', 'autoStart'))
    self.irrigationAutoStop:setIsChecked(g_AutoIrrigation:getTypeNameValue('irrigation', 'autoStop'))
    self.irrigationShowNotifications:setIsChecked(g_AutoIrrigation:getTypeNameValue('irrigation', 'showNotifications'))
    self.irrigationShowWarnings:setIsChecked(g_AutoIrrigation:getTypeNameValue('irrigation', 'showWarnings'))
    self.irrigationScheduleEnabled:setIsChecked(g_AutoIrrigation:getTypeNameValue('irrigation', 'scheduleEnabled'))

    self:setElementText(self.irrigationAutomationLevel, g_AutoIrrigation:getTypeNameValue('irrigation', 'automationLevel'))
    self:setElementText(self.irrigationWaterUsage, g_AutoIrrigation:getTypeNameValue('irrigation', 'waterUsage'))
    self:setElementText(self.irrigationEfficiency, g_AutoIrrigation:getTypeNameValue('irrigation', 'efficiency'))
    self:setElementText(self.irrigationMorningTime, g_AutoIrrigation:getTypeNameValue('irrigation', 'morningTime'))
    self:setElementText(self.irrigationEveningTime, g_AutoIrrigation:getTypeNameValue('irrigation', 'eveningTime'))
    self:setElementText(self.irrigationMinMoisture, g_AutoIrrigation:getTypeNameValue('irrigation', 'minMoisture'))
    self:setElementText(self.irrigationMaxMoisture, g_AutoIrrigation:getTypeNameValue('irrigation', 'maxMoisture'))
end

function AutoIrrigationFrame:setElementText(element, value)
    element:setText(string.format('%.0f', value))
end

---@param state number
---@param element CheckedOptionElement
function AutoIrrigationFrame:onCheckClick(state, element)
    local value = state == CheckedOptionElement.STATE_CHECKED

    if element.id == "irrigationEnabled" then
        g_AutoIrrigation:setTypeNameValue("irrigation", "enabled", value)
    else
        g_AutoIrrigation:setTypeNameValue("irrigation", element.id, value)
    end

    g_AutoIrrigation:saveSettings()
end

---@param element TextInputElement
function AutoIrrigationFrame:onEnterPressedTextInput(element)
    local value = tonumber(element.text)
    if value == nil then return end

    if element.id == 'irrigationAutomationLevel' then
        value = math.max(1, math.min(10, value))
        g_AutoIrrigation.irrigation.automationLevel = value

    elseif element.id == 'irrigationWaterUsage' then
        value = math.max(1, math.min(5, value))
        g_AutoIrrigation.irrigation.waterUsage = value

    elseif element.id == 'irrigationEfficiency' then
        value = math.max(1, math.min(5, value))
        g_AutoIrrigation.irrigation.efficiency = value
        
    elseif element.id == 'irrigationMorningTime' then
        value = math.max(0, math.min(23, value))
        g_AutoIrrigation.irrigation.morningTime = value
        
    elseif element.id == 'irrigationEveningTime' then
        value = math.max(0, math.min(23, value))
        g_AutoIrrigation.irrigation.eveningTime = value
        
    elseif element.id == 'irrigationMinMoisture' then
        value = math.max(0, math.min(100, value))
        g_AutoIrrigation.irrigation.minMoisture = value
        
    elseif element.id == 'irrigationMaxMoisture' then
        value = math.max(0, math.min(100, value))
        g_AutoIrrigation.irrigation.maxMoisture = value
    end

    g_AutoIrrigation:saveSettings()
    self:setElementText(element, value)
end

function AutoIrrigationFrame:onStartIrrigationClick()
    g_AutoIrrigation:checkAllFields()
end
