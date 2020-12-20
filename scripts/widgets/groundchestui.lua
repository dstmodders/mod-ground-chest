local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local UIAnimButton = require "widgets/uianimbutton"
local GroundChestItemTiles = require "widgets/groundchestitemtiles"

local screen_x, screen_y,half_x,half_y

local min_seen = 8 --How much of the widget can minimally be seen when it's moved out of your screen at x or y coordinates?
--I think 8 is around the size where you might not be able to drag it out.

local on_button_press_fn

local function LoadConfig(name)
    local mod = "Ground Chest"
    return GetModConfigData(name,mod) or GetModConfigData(name,KnownModIndex:GetModActualName(mod))
end



local ui_button = LoadConfig("ui_button")



local function InGame()
	return ThePlayer and ThePlayer.HUD and not ThePlayer.HUD:HasInputFocus()
end



local GroundChestUI = Class(Widget,function(self,owner)
        Widget._ctor(self,"GroundChestUI")
		
        screen_x,screen_y = TheSim:GetScreenSize()
        half_x = screen_x/2
        half_y = screen_y/2
		
		on_button_press_fn = function() self:Toggle() end
		
        self.owner = owner
		
		self.pos_x = half_x--Centered
		self.pos_y = half_y*1.5--75% up
		self.offset_x = 0
		self.offset_y = 0
		
		self.size_x = 1/10*half_x+64*6
		self.size_y = 1/10*half_y+64*5
		
		self.bg = self:AddChild(Image("images/plantregistry.xml", "backdrop.tex"))
		self:SetPosition(self.pos_x+self.offset_x,self.pos_y+self.offset_y)
		self.bg:SetSize(self.size_x,self.size_y)
		
		local ongainfocus_fn = function() self.focused = true end
		local onlosefocus_fn = function() self.focused = false end
		self.bg:SetOnGainFocus(ongainfocus_fn)
		self.bg:SetOnLoseFocus(onlosefocus_fn)
		
		self.shown = false
		self:Hide()
		
		
        self:StartUpdating()
    end)

function GroundChestUI:Toggle()
	if self.shown then
		self.shown = false
		self:Hide()
	else
		self.shown = true
		self:Show()
	end
end
    
function GroundChestUI:UpdatePosition()
	self:SetPosition(self.pos_x+self.offset_x,self.pos_y+self.offset_y)
end

function GroundChestUI:HandleMouseMovement()
	if TheInput:IsControlPressed(CONTROL_PRIMARY) and self.focused then
		local pos = TheInput:GetScreenPosition()
		self.start_pos = self.start_pos or pos
		self.offset_x = pos.x-self.start_pos.x
		self.offset_y = pos.y-self.start_pos.y
		self:UpdatePosition()
	else
		local new_x = self.pos_x+self.offset_x
		local new_y = self.pos_y+self.offset_y
		
		local neg_out_x = -self.size_x/2+min_seen
		local neg_out_y = -self.size_y/2+min_seen
		local out_x = screen_x+self.size_x/2-min_seen
		local out_y = screen_y+self.size_y/2-min_seen
		self.pos_x = new_x > neg_out_x and new_x < out_x and new_x or (new_x < 0 and neg_out_x or out_x)
		self.pos_y = new_y > neg_out_y and new_y < out_y and new_y or (new_y < 0 and neg_out_y or out_y)
		self.offset_x = 0
		self.offset_y = 0
		self.start_pos = nil
		self:UpdatePosition()
	end	
end


function GroundChestUI:OnUpdate(dt)
	self:HandleMouseMovement()
end

if ui_button and ui_button ~= 0 then
	TheInput:AddKeyDownHandler(ui_button,function() if not InGame() then return else on_button_press_fn() end end)
end

return GroundChestUI

    