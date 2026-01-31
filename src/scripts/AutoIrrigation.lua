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
local modFolder = g_currentModDirectory

---@class AutoIrrigation
---@field modFolder string
AutoIrrigation = {
    irrigation = {
        enabled = true,
        automationLevel = 5,
        waterUsage = 2,
        efficiency = 3,
        autoStart = true,
        autoStop = true,
        showNotifications = true,
        showWarnings = true,
        
        scheduleEnabled = true,
        morningTime = 6,
        eveningTime = 18,
        minMoisture = 30,
        maxMoisture = 80,
        
        debugLevel = 1
    },
    
    debug = {
        enabled = false,
        debugLevel = 1,
        showDebugInfo = false
    },
    
    waterSources = {
        enabled = true,
        wellWaterEnabled = true,
        riverWaterEnabled = true,
        rainwaterEnabled = true,
        waterTankRefill = true,
        maxWaterDistance = 200,
        pumpSpeed = 1.0,
        showWaterInfo = false,
        debugMode = false
    },
    
    delayedMessageTime = 0,
    showDelayedMessage = false,
    needsSave = false,
    saveTime = nil
}

AutoIrrigation.IRRIGATION_STATE = {
    activeIrrigation = nil,
    irrigationStartTime = 0,
    irrigationDuration = 0,
    irrigationData = {},
    history = {},
    cooldownUntil = 0,
    currentMoistureLevels = {},
    activeFields = {}
}

-- =====================
-- IRRIGATION SYSTEM CORE 
-- =====================
AutoIrrigation.FIELDS = {}
AutoIrrigation.fieldCounter = 0  

function AutoIrrigation:getFarmId()
    return g_currentMission and g_currentMission.player and g_currentMission.player.farmId or 0
end

function AutoIrrigation:getFieldInfo(fieldId)
    if g_currentMission and g_currentMission.fieldController then
        local fields = g_currentMission.fieldController.fields
        if fields and fields[fieldId] then
            return fields[fieldId]
        end
    end
    return nil
end

function AutoIrrigation:randomDuration(minMinutes, maxMinutes)
    return (math.random(minMinutes, maxMinutes) * 60000)
end

function AutoIrrigation:registerField(fieldData)
    self.fieldCounter = self.fieldCounter + 1
    self.FIELDS[fieldData.id] = fieldData
    return fieldData.id
end

function AutoIrrigation:checkFieldMoisture(fieldId)
    local field = self:getFieldInfo(fieldId)
    if not field then return 50 end -- Default moisture level
    
    -- Get current moisture from field state
    local currentMoisture = self.IRRIGATION_STATE.currentMoistureLevels[fieldId] or 50
    
    -- Simulate moisture decrease over time
    if g_currentMission and g_currentMission.environment then
        local weather = g_currentMission.environment.weather
        if weather and not weather:getIsRaining() then
            -- Decrease moisture faster on sunny days
            currentMoisture = currentMoisture - 0.1
        elseif weather and weather:getIsRaining() then
            -- Increase moisture when raining
            currentMoisture = currentMoisture + 1.0
        end
    end
    
    -- Clamp moisture between 0-100
    currentMoisture = math.max(0, math.min(100, currentMoisture))
    self.IRRIGATION_STATE.currentMoistureLevels[fieldId] = currentMoisture
    
    return currentMoisture
end

function AutoIrrigation:autoIrrigateField(fieldId)
    if not self.irrigation.enabled then 
        print("[AI-DEBUG] Irrigation disabled")
        return false 
    end
    
    if self.IRRIGATION_STATE.activeIrrigation == fieldId then 
        print("[AI-DEBUG] Field already being irrigated: " .. tostring(fieldId))
        return false 
    end
    
    local moisture = self:checkFieldMoisture(fieldId)
    local minMoisture = self.irrigation.minMoisture
    local maxMoisture = self.irrigation.maxMoisture
    
    -- Check if irrigation is needed
    if moisture >= minMoisture then
        print(string.format("[AI-DEBUG] Field %d moisture OK: %.1f%% (min: %d%%)", 
            fieldId, moisture, minMoisture))
        return false
    end
    
    -- Check time-based scheduling
    if self.irrigation.scheduleEnabled then
        local currentHour = g_currentMission.environment.currentHour
        local morningTime = self.irrigation.morningTime
        local eveningTime = self.irrigation.eveningTime
        
        if currentHour < morningTime or currentHour > eveningTime then
            print(string.format("[AI-DEBUG] Outside irrigation hours: %d (allowed: %d-%d)", 
                currentHour, morningTime, eveningTime))
            return false
        end
    end
    
    print("[AI-DEBUG] Starting irrigation on field: " .. tostring(fieldId))
    
    self.IRRIGATION_STATE.activeIrrigation = fieldId
    self.IRRIGATION_STATE.irrigationStartTime = g_currentMission.time
    
    local duration = self:calculateIrrigationDuration(fieldId, moisture)
    self.IRRIGATION_STATE.irrigationDuration = duration
    
    print("[AI-DEBUG] Irrigation duration: " .. (duration / 60000) .. " minutes")
    
    local message = self:startIrrigation(fieldId, moisture)
    if message and self.irrigation.showNotifications then
        g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, message)
    end
    
    print("[AI-DEBUG] Irrigation started successfully: " .. fieldId)
    return true
end

function AutoIrrigation:calculateIrrigationDuration(fieldId, currentMoisture)
    local targetMoisture = self.irrigation.maxMoisture
    local moistureNeeded = targetMoisture - currentMoisture
    local efficiency = self.irrigation.efficiency or 3
    local waterUsage = self.irrigation.waterUsage or 2
    
    -- Base calculation: 1 minute per 10% moisture needed
    local baseMinutes = moistureNeeded / 10
    
    -- Adjust for efficiency (higher efficiency = faster)
    baseMinutes = baseMinutes * (5 / efficiency)
    
    -- Adjust for water usage (higher usage = faster but more water)
    baseMinutes = baseMinutes * (3 / waterUsage)
    
    -- Convert to milliseconds and add some randomness
    local durationMs = (baseMinutes * 60000) + math.random(-60000, 60000)
    
    return math.max(120000, math.min(3600000, durationMs)) -- 2 min to 60 min
end

function AutoIrrigation:startIrrigation(fieldId, currentMoisture)
    local field = self:getFieldInfo(fieldId)
    if not field then return nil end
    
    local fieldName = field.name or ("Field " .. tostring(fieldId))
    local targetMoisture = self.irrigation.maxMoisture
    
    return string.format("Auto irrigation started on %s: %.0f%% -> %.0f%%", 
        fieldName, currentMoisture, targetMoisture)
end

function AutoIrrigation:stopIrrigation(fieldId)
    local field = self:getFieldInfo(fieldId)
    if not field then return nil end
    
    local fieldName = field.name or ("Field " .. tostring(fieldId))
    local finalMoisture = self.irrigation.maxMoisture
    
    -- Update moisture level
    self.IRRIGATION_STATE.currentMoistureLevels[fieldId] = finalMoisture
    
    return string.format("Auto irrigation completed on %s: %.0f%% moisture", 
        fieldName, finalMoisture)
end

-- =====================
-- WATER SOURCE SYSTEM
-- =====================
function AutoIrrigation:findWaterSource(fieldId)
    if not self.waterSources.enabled then 
        return nil 
    end
    
    local field = self:getFieldInfo(fieldId)
    if not field then return nil end
    
    -- Check for nearby water sources
    local waterSources = {}
    
    if self.waterSources.wellWaterEnabled then
        table.insert(waterSources, "well")
    end
    
    if self.waterSources.riverWaterEnabled then
        table.insert(waterSources, "river")
    end
    
    if self.waterSources.rainwaterEnabled and g_currentMission.environment.weather:getIsRaining() then
        table.insert(waterSources, "rainwater")
    end
    
    if #waterSources > 0 then
        return waterSources[math.random(1, #waterSources)]
    end
    
    return nil
end

function AutoIrrigation:calculateWaterCost(waterSource, duration)
    local baseCost = duration / 60000 -- €1 per minute
    
    if waterSource == "well" then
        return baseCost * 0.5 -- Well water is cheaper
    elseif waterSource == "river" then
        return baseCost * 0.3 -- River water is cheapest
    elseif waterSource == "rainwater" then
        return 0 -- Rainwater is free
    else
        return baseCost * 1.2 -- Other sources more expensive
    end
end

-- =====================
-- FS22 LIFECYCLE
-- =====================
function AutoIrrigation:loadMap()
    ---@diagnostic disable-next-line: lowercase-global
    g_AutoIrrigation = self
    g_AutoIrrigation.modFolder = modFolder

    self:loadFromXML()
    self:loadGUI()

    if g_currentMission then
        addConsoleCommand(
            "ai",                        
            "Auto Irrigation Command", 
            "onConsoleCommand",            
            AutoIrrigation              
        )
        print("[AutoIrrigation] Console command 'ai' registered")
    end

    if GameSettings ~= nil and GameSettings.saveToXMLFile ~= nil then
        self.originalSaveToXMLFile = GameSettings.saveToXMLFile
        GameSettings.saveToXMLFile = Utils.overwrittenFunction(
            GameSettings.saveToXMLFile, 
            AutoIrrigation.saveToXML
        )
    end

    self.delayedMessageTime = g_currentMission.time + 10000
    self.showDelayedMessage = true

    print("[AutoIrrigation] Core system loaded")
end

function AutoIrrigation:loadGUI()
    local modFolder = g_currentModDirectory
    
    -- Load GUI profiles first
    local guiProfilesPath = Utils.getFilename("src/xml/guiProfiles.xml", modFolder)
    if fileExists(guiProfilesPath) then
        g_gui:loadProfiles(guiProfilesPath)
        print("[AutoIrrigation] GUI profiles loaded")
    else
        print("[AutoIrrigation] WARNING: GUI profiles not found: " .. guiProfilesPath)
    end

    -- Load frames first
    local frameFiles = {
        {xml="src/xml/AutoIrrigationFrame.xml", ref="AutoIrrigationFrame"},
        {xml="src/xml/WaterSourceFrame.xml", ref="WaterSourceFrame"}
    }

    for _, file in ipairs(frameFiles) do
        local xmlPath = Utils.getFilename(file.xml, modFolder)
        if fileExists(xmlPath) then
            -- Load frame without lua (will be handled by screen)
            g_gui:loadGui(xmlPath, file.ref, nil, false)
            print("[AutoIrrigation] Loaded frame: " .. file.ref)
        else
            print("[AutoIrrigation] ERROR: XML file not found: " .. file.xml)
        end
    end

    -- Load the main screen last
    local screenXmlPath = Utils.getFilename("src/xml/AutoIrrigationScreen.xml", modFolder)
    local screenLuaPath = Utils.getFilename("src/gui/AutoIrrigationScreen.lua", modFolder)
    
    if fileExists(screenLuaPath) then
        source(screenLuaPath)
        print("[AutoIrrigation] Screen Lua file loaded")
    else
        print("[AutoIrrigation] ERROR: Screen Lua file not found: " .. screenLuaPath)
        return
    end

    if not fileExists(screenXmlPath) then
        print("[AutoIrrigation] ERROR: Screen XML file not found: " .. screenXmlPath)
        return
    end

    -- Create and register the screen properly
    local screenInstance = AutoIrrigationScreen.new(
        nil,
        AutoIrrigationScreen_mt,
        g_messageCenter,
        g_l10n,
        g_inputManager
    )
    
    -- Register the screen with g_gui
    g_gui:loadGui(screenXmlPath, "AutoIrrigationScreen", screenInstance)
    
    print("[AutoIrrigation] Screen registered: AutoIrrigationScreen")
    
    -- Debug: List all registered screens
    print("[AutoIrrigation] Registered screens:")
    for name, _ in pairs(g_gui.screens) do
        if type(name) == "string" then
            print("  - " .. name)
        end
    end
end

function AutoIrrigation:testGUI()
    print("[AutoIrrigation] Testing GUI system...")
    print("Available screens:")
    
    local count = 0
    for name, screen in pairs(g_gui.screens) do
        if type(name) == "string" then
            count = count + 1
            print(string.format("  %d. %s (class: %s)", count, name, screen.className or "unknown"))
        end
    end
    
    if g_gui.screens["AutoIrrigationScreen"] then
        print("[AutoIrrigation] AutoIrrigationScreen found!")
        g_gui:showGui("AutoIrrigationScreen")
    else
        print("[AutoIrrigation] ERROR: AutoIrrigationScreen not found in g_gui.screens")
    end
end

function AutoIrrigation:openGUI()
    local screenName = "AutoIrrigationScreen"

    if g_gui:showGui(screenName) then
        print("[AutoIrrigation] Showing GUI: " .. screenName)
    else
        print("[AutoIrrigation] ERROR: GUI screen not found: " .. screenName)
        print("[AutoIrrigation] Available screens:")
        for k, v in pairs(g_gui.screens) do
            print("  - key=" .. tostring(k) .. " | class=" .. tostring(v.className))
        end
    end
end
-- =====================
-- XML SETTINGS
-- =====================
local function getXMLSettingBool(xmlFile, type, name, default)
    g_AutoIrrigation:setTypeNameValue(type, name, Utils.getNoNil(getXMLBool(xmlFile, 'AutoIrrigation.' .. type .. '.' .. name), default))
end

local function setXMLSettingBool(xmlFile, type, name)
    local value = g_AutoIrrigation:getTypeNameValue(type, name)
    setXMLBool(xmlFile, 'AutoIrrigation.' .. type .. '.' .. name, value)
end

local function getXMLSettingFloat(xmlFile, type, name, default)
    g_AutoIrrigation:setTypeNameValue(type, name, Utils.getNoNil(getXMLFloat(xmlFile, 'AutoIrrigation.' .. type .. '.' .. name), default))
end

local function setXMLSettingFloat(xmlFile, type, name)
    local value = g_AutoIrrigation:getTypeNameValue(type, name)
    setXMLFloat(xmlFile, 'AutoIrrigation.' .. type .. '.' .. name, value)
end

function AutoIrrigation.saveToXML()
    local filePath = g_modSettingsDirectory .. 'AutoIrrigation.xml'
    print('[AutoIrrigation] Attempting to save to: ' .. filePath)
    
    local xmlFile = createXMLFile('autoIrrigationSetting', filePath, 'AutoIrrigation')

    if xmlFile == nil or xmlFile == 0 then
        print('AutoIrrigation.saveToXML: Failed to create XML file')
        return
    end

    setXMLSettingBool(xmlFile, 'irrigation', 'enabled')
    setXMLSettingFloat(xmlFile, 'irrigation', 'automationLevel')
    setXMLSettingFloat(xmlFile, 'irrigation', 'waterUsage')
    setXMLSettingFloat(xmlFile, 'irrigation', 'efficiency')
    setXMLSettingBool(xmlFile, 'irrigation', 'autoStart')
    setXMLSettingBool(xmlFile, 'irrigation', 'autoStop')
    setXMLSettingBool(xmlFile, 'irrigation', 'showNotifications')
    setXMLSettingBool(xmlFile, 'irrigation', 'showWarnings')
    setXMLSettingBool(xmlFile, 'irrigation', 'scheduleEnabled')
    setXMLSettingFloat(xmlFile, 'irrigation', 'morningTime')
    setXMLSettingFloat(xmlFile, 'irrigation', 'eveningTime')
    setXMLSettingFloat(xmlFile, 'irrigation', 'minMoisture')
    setXMLSettingFloat(xmlFile, 'irrigation', 'maxMoisture')
    setXMLSettingFloat(xmlFile, 'irrigation', 'debugLevel')

    setXMLSettingBool(xmlFile, 'debug', 'enabled')
    setXMLSettingFloat(xmlFile, 'debug', 'debugLevel')
    setXMLSettingBool(xmlFile, 'debug', 'showDebugInfo')

    setXMLSettingBool(xmlFile, 'waterSources', 'enabled')
    setXMLSettingBool(xmlFile, 'waterSources', 'wellWaterEnabled')
    setXMLSettingBool(xmlFile, 'waterSources', 'riverWaterEnabled')
    setXMLSettingBool(xmlFile, 'waterSources', 'rainwaterEnabled')
    setXMLSettingBool(xmlFile, 'waterSources', 'waterTankRefill')
    setXMLSettingFloat(xmlFile, 'waterSources', 'maxWaterDistance')
    setXMLSettingFloat(xmlFile, 'waterSources', 'pumpSpeed')
    setXMLSettingBool(xmlFile, 'waterSources', 'showWaterInfo')
    setXMLSettingBool(xmlFile, 'waterSources', 'debugMode')

    print('AutoIrrigation: Saving XML configuration ..')
    saveXMLFile(xmlFile)
    delete(xmlFile)
    print('[AutoIrrigation] Settings saved successfully')
end

function AutoIrrigation:loadFromXML()
    local filePath = g_modSettingsDirectory .. 'AutoIrrigation.xml'
    print('[AutoIrrigation] Attempting to load from: ' .. filePath)

    if not fileExists(filePath) then
        print('[AutoIrrigation] No settings file found, using defaults')
        return
    end

    local xmlFile = loadXMLFile('AutoIrrigation', filePath)
    if xmlFile == nil or xmlFile == 0 then
        print('AutoIrrigation.loadFromXML: Failed to load XML file')
        return
    end

    getXMLSettingBool(xmlFile, 'irrigation', 'enabled', true)
    getXMLSettingFloat(xmlFile, 'irrigation', 'automationLevel', 5)
    getXMLSettingFloat(xmlFile, 'irrigation', 'waterUsage', 2)
    getXMLSettingFloat(xmlFile, 'irrigation', 'efficiency', 3)
    getXMLSettingBool(xmlFile, 'irrigation', 'autoStart', true)
    getXMLSettingBool(xmlFile, 'irrigation', 'autoStop', true)
    getXMLSettingBool(xmlFile, 'irrigation', 'showNotifications', true)
    getXMLSettingBool(xmlFile, 'irrigation', 'showWarnings', true)
    getXMLSettingBool(xmlFile, 'irrigation', 'scheduleEnabled', true)
    getXMLSettingFloat(xmlFile, 'irrigation', 'morningTime', 6)
    getXMLSettingFloat(xmlFile, 'irrigation', 'eveningTime', 18)
    getXMLSettingFloat(xmlFile, 'irrigation', 'minMoisture', 30)
    getXMLSettingFloat(xmlFile, 'irrigation', 'maxMoisture', 80)
    getXMLSettingFloat(xmlFile, 'irrigation', 'debugLevel', 1)

    getXMLSettingBool(xmlFile, 'debug', 'enabled', false)
    getXMLSettingFloat(xmlFile, 'debug', 'debugLevel', 1)
    getXMLSettingBool(xmlFile, 'debug', 'showDebugInfo', false)

    getXMLSettingBool(xmlFile, 'waterSources', 'enabled', true)
    getXMLSettingBool(xmlFile, 'waterSources', 'wellWaterEnabled', true)
    getXMLSettingBool(xmlFile, 'waterSources', 'riverWaterEnabled', true)
    getXMLSettingBool(xmlFile, 'waterSources', 'rainwaterEnabled', true)
    getXMLSettingBool(xmlFile, 'waterSources', 'waterTankRefill', true)
    getXMLSettingFloat(xmlFile, 'waterSources', 'maxWaterDistance', 200)
    getXMLSettingFloat(xmlFile, 'waterSources', 'pumpSpeed', 1.0)
    getXMLSettingBool(xmlFile, 'waterSources', 'showWaterInfo', false)
    getXMLSettingBool(xmlFile, 'waterSources', 'debugMode', false)

    delete(xmlFile)
    print('[AutoIrrigation] Settings loaded successfully')
end

---@param type string
---@param name string
---@param value any
function AutoIrrigation:setTypeNameValue(type, name, value)
    if self[type] then
        self[type][name] = value
    else
        print("Warning: Type '" .. type .. "' not found in AutoIrrigation")
    end
end

function AutoIrrigation:getTypeNameValue(type, name)
    if self[type] then
        return self[type][name]
    end
    return nil
end

function AutoIrrigation:saveSettings()
    self.needsSave = true
    self.saveTime = g_currentMission.time + 1000
end

-- =====================
-- UPDATE FUNCTION
-- =====================
function AutoIrrigation:update(dt)
    if self.showDelayedMessage and g_currentMission.time > self.delayedMessageTime then
        print("[FS22_AutoIrrigation] >> =============================================================")
        print("[FS22_AutoIrrigation] >>   Successfully loaded `Auto Irrigation v1.0.0.0`")
        print("[FS22_AutoIrrigation] >>   Original Author: TisonK")
        print("[FS22_AutoIrrigation] >>   Controls: `U` to open - Manual trigger available in menu")
        print("[FS22_AutoIrrigation] >>   Automated irrigation system for optimal crop growth")
        print("[FS22_AutoIrrigation] >> =============================================================")

        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_OK,
            "[Auto Irrigation] Mod loaded successfully"
        )

        self.showDelayedMessage = false
    end

    if self.needsSave and self.saveTime and g_currentMission.time > self.saveTime then
        AutoIrrigation.saveToXML()
        self.needsSave = false
        self.saveTime = nil
    end

    if self.irrigation.enabled and self.irrigation.autoStart then
        -- Check all fields periodically for irrigation needs
        if g_currentMission.time % 30000 < dt then  -- Every 30 seconds
            self:checkAllFields()
        end
    end

    if self.IRRIGATION_STATE.activeIrrigation then
        self:updateIrrigation(dt)
    end

    if self.IRRIGATION_STATE.activeIrrigation and 
       g_currentMission.time > (self.IRRIGATION_STATE.irrigationStartTime + self.IRRIGATION_STATE.irrigationDuration) then
        
        local fieldId = self.IRRIGATION_STATE.activeIrrigation
        local message = self:stopIrrigation(fieldId)
        if message and self.irrigation.showNotifications then
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, message)
        end
        
        print("[AI-DEBUG] Irrigation completed: " .. tostring(fieldId))
        self.IRRIGATION_STATE.activeIrrigation = nil
    end
end

function AutoIrrigation:checkAllFields()
    if not g_currentMission or not g_currentMission.fieldController then
        return
    end
    
    local fields = g_currentMission.fieldController.fields
    local farmId = self:getFarmId()
    
    for fieldId, field in pairs(fields) do
        if field and field.farmId == farmId then
            self:autoIrrigateField(fieldId)
        end
    end
end

function AutoIrrigation:updateIrrigation(dt)
    -- Update irrigation progress
    local fieldId = self.IRRIGATION_STATE.activeIrrigation
    if not fieldId then return end
    
    -- Gradually increase moisture during irrigation
    local currentMoisture = self.IRRIGATION_STATE.currentMoistureLevels[fieldId] or 0
    local targetMoisture = self.irrigation.maxMoisture
    
    if currentMoisture < targetMoisture then
        local moistureIncrease = (self.irrigation.efficiency * 0.1) * (dt / 1000)
        self.IRRIGATION_STATE.currentMoistureLevels[fieldId] = 
            math.min(targetMoisture, currentMoisture + moistureIncrease)
    end
end

function AutoIrrigation:keyEvent(unicode, sym, modifier, isDown)
    if not isDown then
        return
    end

    local keyChar = unicode ~= 0 and pcall(string.char, unicode) and string.char(unicode) or "unknown"

    print(string.format(
        "[AutoIrrigation] Key pressed: sym=%s, unicode=%s, key='%s'",
        tostring(sym),
        tostring(unicode),
        keyChar
    ))

    -- U key (ASCII 117)
    if sym == 117 or unicode == 117 then
        print("[AutoIrrigation] Opening GUI with U key...")

        -- Check if the GUI screen exists
        local screen = g_gui.screens["AutoIrrigationScreen"]
        if screen then
            print("[AutoIrrigation] GUI screen found")
            
            if g_gui:getIsGuiVisible() then
                print("[AutoIrrigation] GUI is already visible")

                local currentScreen = g_gui:getCurrentScreen()
                if currentScreen and currentScreen.className == "AutoIrrigationScreen" then
                    print("[AutoIrrigation] AutoIrrigationScreen is already showing")
                else
                    print("[AutoIrrigation] Showing AutoIrrigationScreen...")
                    g_gui:showGui("AutoIrrigationScreen")
                end
            else
                print("[AutoIrrigation] Showing GUI...")
                local success = g_gui:showGui("AutoIrrigationScreen")
                print("[AutoIrrigation] GUI show result: " .. tostring(success))
            end
        else
            -- GUI SCREEN NOT FOUND - SHOW TEMPORARY MESSAGE
            print("=========================================")
            print("[AutoIrrigation] SETTINGS SCREEN TEMPORARILY UNAVAILABLE")
            print("=========================================")
            print("The Auto Irrigation settings screen is currently being updated.")
            print("Please use console commands for now:")
            print("  'ai status' - Show irrigation status")
            print("  'ai start'  - Start irrigation")
            print("  'ai stop'   - Stop irrigation")
            print("  'ai scan'   - Scan fields")
            print("=========================================")
            
            -- Show notification to player
            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_OK,
                "[Auto Irrigation] Settings screen temporarily unavailable. Use 'ai' command in console."
            )
        end

    elseif sym == 114 then -- F3 key
        print("[AutoIrrigation] Opening GUI with F3 key...")
        
        -- Check if GUI screen exists
        if g_gui.screens["AutoIrrigationScreen"] then
            g_gui:showGui("AutoIrrigationScreen")
            print("[AutoIrrigation] GUI show command sent")
        else
            -- GUI NOT FOUND - SHOW TEMPORARY MESSAGE
            print("[AutoIrrigation] ERROR: Settings screen not available")
            print("[AutoIrrigation] Please use console command 'ai' for irrigation control")
            
            g_currentMission:addIngameNotification(
                FSBaseMission.INGAME_NOTIFICATION_OK,
                "[Auto Irrigation] Use console command 'ai' (Settings screen updating)"
            )
        end
    end
end

-- =====================
-- CONSOLE COMMANDS
-- =====================

---@usage ai_status
---@param self AutoIrrigation
function AutoIrrigation:consoleShowStatus()
    print("=========================================")
    print("Auto Irrigation - Status")
    print("=========================================")
    print("Irrigation enabled: " .. tostring(self.irrigation.enabled))
    print("Automation level: " .. self.irrigation.automationLevel)
    print("Active irrigation: " .. (self.IRRIGATION_STATE.activeIrrigation or "None"))
    
    if self.IRRIGATION_STATE.activeIrrigation then
        local elapsed = (g_currentMission.time - self.IRRIGATION_STATE.irrigationStartTime) / 60000
        local remaining = (self.IRRIGATION_STATE.irrigationDuration / 60000) - elapsed
        print(string.format("Irrigation progress: %.1f / %.1f minutes", elapsed, self.IRRIGATION_STATE.irrigationDuration / 60000))
        print(string.format("Time remaining: %.1f minutes", remaining))
    end
    
    -- Show field moisture levels
    print("Field moisture levels:")
    for fieldId, moisture in pairs(self.IRRIGATION_STATE.currentMoistureLevels) do
        print(string.format("  Field %d: %.1f%%", fieldId, moisture))
    end
    
    print("=========================================")
end

---@usage ai_start [field_id]
---@param self AutoIrrigation
function AutoIrrigation:consoleStartIrrigation(fieldIdStr)
    if not self.irrigation.enabled then
        print("[AI-Console] Irrigation is disabled. Enable it in settings first.")
        return
    end
    
    local fieldId = tonumber(fieldIdStr)
    if not fieldId then
        print("[AI-Console] Starting irrigation on all fields...")
        self:checkAllFields()
        return
    end
    
    if self.IRRIGATION_STATE.activeIrrigation then
        print("[AI-Console] Irrigation already active on field " .. self.IRRIGATION_STATE.activeIrrigation)
        return
    end
    
    local success = self:autoIrrigateField(fieldId)
    if success then
        print("[AI-Console] Irrigation started on field " .. fieldId)
    else
        print("[AI-Console] Failed to start irrigation on field " .. fieldId)
    end
end

---@usage ai_stop
---@param self AutoIrrigation
function AutoIrrigation:consoleStopIrrigation()
    if not self.IRRIGATION_STATE.activeIrrigation then
        print("[AI-Console] No active irrigation to stop")
        return
    end
    
    local fieldId = self.IRRIGATION_STATE.activeIrrigation
    print(string.format("[AI-Console] Stopping irrigation on field: %s", fieldId))
    
    local message = self:stopIrrigation(fieldId)
    if message then
        print("[AI-Console] " .. message)
    end
    
    self.IRRIGATION_STATE.activeIrrigation = nil
    print("[AI-Console] Irrigation stopped")
end

---@usage ai_debug [on|off]
---@param self AutoIrrigation
function AutoIrrigation:consoleToggleDebug(mode)
    if mode == "on" or mode == "true" or mode == "1" then
        self.debug.enabled = true
        self.debug.showDebugInfo = true
        print("[AI-Console] Debug mode ENABLED")
    elseif mode == "off" or mode == "false" or mode == "0" then
        self.debug.enabled = false
        self.debug.showDebugInfo = false
        print("[AI-Console] Debug mode DISABLED")
    else
        self.debug.enabled = not self.debug.enabled
        self.debug.showDebugInfo = self.debug.enabled
        
        local status = self.debug.enabled and "ENABLED" or "DISABLED"
        print("[AI-Console] Debug mode: " .. status)
    end
end

---@usage ai_scan
---@param self AutoIrrigation
function AutoIrrigation:consoleScanFields()
    if not g_currentMission or not g_currentMission.fieldController then
        print("[AI-Console] Field controller not available")
        return
    end
    
    local fields = g_currentMission.fieldController.fields
    local farmId = self:getFarmId()
    
    print("=========================================")
    print("Auto Irrigation - Field Scan")
    print("=========================================")
    print("Farm ID: " .. farmId)
    print("Total fields found: " .. (table.count(fields) or 0))
    
    local myFieldCount = 0
    for fieldId, field in pairs(fields) do
        if field and field.farmId == farmId then
            myFieldCount = myFieldCount + 1
            local moisture = self:checkFieldMoisture(fieldId)
            local needsWater = moisture < self.irrigation.minMoisture
            local status = needsWater and "NEEDS WATER" or "OK"
            
            print(string.format("Field %d: %.1f%% moisture - %s", 
                fieldId, moisture, status))
        end
    end
    
    print("My fields: " .. myFieldCount)
    print("=========================================")
end

-- =====================
-- CONSOLE COMMAND HANDLER
-- =====================
function AutoIrrigation:onConsoleCommand(...)
    local args = {...}
    if #args == 0 then
        print("=========================================")
        print("AUTO IRRIGATION COMMANDS (v1.0.0.0)")
        print("=========================================")
        print("Settings screen is temporarily unavailable for updates.")
        print("Use these console commands instead:")
        print("")
        print("  ai status     - Show irrigation status")
        print("  ai start [id] - Start irrigation (optional: field id)")
        print("  ai stop       - Stop current irrigation")
        print("  ai debug [on|off] - Toggle debug mode")
        print("  ai scan       - Scan all fields")
        print("  ai help       - Show this help message")
        print("=========================================")
        return true
    end
    
    local command = args[1]:lower()
    
    if command == "status" then
        self:consoleShowStatus()
    elseif command == "start" then
        local fieldId = args[2] or ""
        self:consoleStartIrrigation(fieldId)
    elseif command == "stop" then
        self:consoleStopIrrigation()
    elseif command == "debug" then
        local mode = args[2] or ""
        self:consoleToggleDebug(mode)
    elseif command == "scan" then
        self:consoleScanFields()
    elseif command == "testgui" then
        print("[AI-Console] WARNING: GUI is temporarily unavailable")
        print("[AI-Console] Settings screen is being updated. Use console commands.")
    elseif command == "gui" then
        print("[AI-Console] =========================================")
        print("[AI-Console] SETTINGS SCREEN TEMPORARILY UNAVAILABLE")
        print("[AI-Console] =========================================")
        print("[AI-Console] The settings interface is currently being")
        print("[AI-Console] updated for better user experience.")
        print("[AI-Console]")
        print("[AI-Console] Please use console commands instead:")
        print("[AI-Console]   'ai status' - View current irrigation")
        print("[AI-Console]   'ai start'  - Start irrigation")
        print("[AI-Console]   'ai scan'   - Check field moisture")
        print("[AI-Console] =========================================")
        
        -- Show notification
        g_currentMission:addIngameNotification(
            FSBaseMission.INGAME_NOTIFICATION_INFO,
            "[Auto Irrigation] Use 'ai' in console (GUI updating)"
        )
    elseif command == "help" then
        print("=========================================")
        print("AUTO IRRIGATION HELP")
        print("=========================================")
        print("Settings screen is currently unavailable.")
        print("Working commands:")
        print("")
        print("  ai status - Check system status")
        print("  ai start  - Start irrigation on all fields")
        print("  ai start 5 - Start on specific field")
        print("  ai stop   - Stop irrigation")
        print("  ai scan   - Check field moisture levels")
        print("  ai debug on - Enable debug mode")
        print("=========================================")
    else
        print(string.format("[AI-Console] Unknown command: %s", command))
        print("[AI-Console] Use 'ai help' for available commands.")
        print("[AI-Console] Note: GUI is temporarily unavailable.")
    end
    
    return true
end

addModEventListener(AutoIrrigation)
