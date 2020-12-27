local Widget = require "widgets/widget"
local Screen = require "widgets/screen"
local TextEdit = require "widgets/textedit"

local GroundChestUIScreen = Class(Screen,function(self, textbox)
        Screen._ctor(self,"GroundChestUIScreen")
        self.textbox = textbox
        self:OnBecomeActive()
    end)

function GroundChestUIScreen:OnBecomeActive()
	TheFrontEnd:LockFocus(true)
    self.textbox:SetForceEdit(true)
    self.textbox:SetEditing(true)
    self.textbox:SetFocus()
end

function GroundChestUIScreen:OnBecomeInactive()
    self.textbox:SetEditing(false)
end

function GroundChestUIScreen:OnControl(control, down)
    --Ways to escape the screen: Escape key, Enter key, Clicking anything with your mouse.
	if not down and (control == CONTROL_PAUSE or control == CONTROL_ACCEPT or control == CONTROL_CANCEL) then
		self:Close()
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

