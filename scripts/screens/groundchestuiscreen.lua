local Widget = require "widgets/widget"
local Screen = require "widgets/screen"
local TextEdit = require "widgets/textedit"

local GroundChestUIScreen = Class(Screen,function(self, textbox)
        Screen._ctor(self,"GroundChestUIScreen")
        self.textbox = textbox
    end)

function GroundChestUIScreen:OnBecomeActive()
	GroundChestUIScreen._base.OnBecomeActive(self)
	TheFrontEnd:LockFocus(true)
    self.textbox:SetForceEdit(true)
    self.textbox:SetEditing(true)
end

function GroundChestUIScreen:OnControl(control, down)
	if GroundChestUIScreen._base.OnControl(self, control, down) then return true end
    --Ways to escape the screen: Escape key, Enter key, Clicking anything with your mouse.
	if not down and (control == CONTROL_PAUSE or control == CONTROL_ACCEPT) then
		self:Close()
		return true
	end
	
	if control == CONTROL_OPEN_DEBUG_CONSOLE or control == CONTROL_TOGGLE_DEBUGRENDER then
		-- Don't allow the debug console or debug render to open while the screen is active
        return true
    end
end

function GroundChestUIScreen:OnMouseButton()
    self:Close()
end

function GroundChestUIScreen:Close()
    TheFrontEnd:PopScreen(self)
    TheFrontEnd:LockFocus(false)
    self:Kill()
end

return GroundChestUIScreen

