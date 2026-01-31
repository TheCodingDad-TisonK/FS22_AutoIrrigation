AutoIrrigationScreen = {}
local AutoIrrigationScreen_mt = Class(AutoIrrigationScreen, TabbedMenu)

AutoIrrigationScreen.CONTROLS = {
    'pageOptionsIrrigation',
    'pageOptionsWaterSources',
}

function AutoIrrigationScreen.new(target, customMt, messageCenter, l10n, inputManager)
    local self = TabbedMenu.new(
        target,
        customMt or AutoIrrigationScreen_mt,
        messageCenter,
        l10n,
        inputManager
    )

    self.className = "AutoIrrigationScreen"
    self.returnScreenName = ""

    self:registerControls(AutoIrrigationScreen.CONTROLS)
    return self
end

function AutoIrrigationScreen:onGuiSetupFinished()
    AutoIrrigationScreen:superClass().onGuiSetupFinished(self)

    -- Setup pages
    local pages = {
        {
            self.pageOptionsIrrigation,
            'irrigation.dds',
            'Auto Irrigation Settings'
        },
        {
            self.pageOptionsWaterSources,
            'water.dds',
            'Water Source Settings'
        }
    }

    for i, pageData in ipairs(pages) do
        local page, icon, title = unpack(pageData)
        self:registerPage(page, i)
        
        -- Use placeholder if icon doesn't exist
        local iconPath = g_AutoIrrigation.modFolder .. 'src/icons/' .. icon
        if not fileExists(iconPath) then
            iconPath = nil  -- Will use default
            print("[AutoIrrigation] Icon not found: " .. icon)
        end
        
        self:addPageTab(page, iconPath, title)
    end
    
    -- Setup button actions
    self:setupMenuButtonInfo()
end

function AutoIrrigationScreen:setupMenuButtonInfo()
    self.defaultMenuButtonInfo = {
        {
            inputAction = InputAction.MENU_BACK,
            text = self.l10n:getText("button_back"),
            callback = function()
                self:onClickBack()
            end
        }
    }
end

function AutoIrrigationScreen:onClickBack()
    self:exitMenu()
end

function AutoIrrigationScreen:exitMenu()
    g_gui:closeDialogByName("AutoIrrigationScreen")
end
