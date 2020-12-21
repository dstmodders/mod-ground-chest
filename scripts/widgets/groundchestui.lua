local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local UIAnimButton = require "widgets/uianimbutton"
local GroundChestItemTiles = require "widgets/groundchestitemtiles"

local screen_x, screen_y,half_x,half_y,w,h

local min_seen = 8 --How much of the widget can minimally be seen when it's moved out of your screen at x or y coordinates?
--I think 8 is around the size where you might not be able to drag it out.
local items_page = 50--10x wide and 5x tall seems balanced to both see the item and its number. And it leaves space up top for the additional controls.
--Additional controls like: Switch views, Switch pages, etc.

local on_button_press_fn

local function LoadConfig(name)
    local mod = "Ground Chest"
    return GetModConfigData(name,mod) or GetModConfigData(name,KnownModIndex:GetModActualName(mod))
end



local ui_button = LoadConfig("ui_button")



local function InGame()
	return ThePlayer and ThePlayer.HUD and not ThePlayer.HUD:HasInputFocus()
end

--Some features:
--Clicking on an item tile: Will queue up for the item to be picked up, several tiles can be clicked at once and they will be picked up based on clicking order.
--There are several variants for the background of the item tile.

local GroundChestUI = Class(Widget,function(self,owner)
        Widget._ctor(self,"GroundChestUI")
		
        screen_x,screen_y = TheSim:GetScreenSize()
        half_x = screen_x/2
        half_y = screen_y/2
		
		on_button_press_fn = function() self:Toggle() end
		
        self.owner = owner
		self.tiles = {} --Track all tiles that currently exist and aren't deleted.
		
		self.pos_x = half_x--Centered
		self.pos_y = half_y*1.5--At a 0.75/1 position from below.
		self.offset_x = 0
		self.offset_y = 0
		
		self.size_x = 1/10*half_x+64*7 --Not sure why I use 1/10 of screen size and then add 64's, but it seems like a relatively good size.
		self.size_y = 1/10*half_y+64*5
		
		self.bg = self:AddChild(Image("images/plantregistry.xml", "backdrop.tex"))
		self:SetPosition(self.pos_x+self.offset_x,self.pos_y+self.offset_y)
		self.bg:SetSize(self.size_x,self.size_y)
		
		self.test_tile = self.bg:AddChild(GroundChestItemTiles())
		--self:FillBoard(0.4)--Test function, to be removed when adding tiles in proper way.
		--Should be replaced via the Widget GroundChestItemTiles.
		
		local ongainfocus_fn = function() self.focused = true end
		local onlosefocus_fn = function() self.focused = false end
		self.bg:SetOnGainFocus(ongainfocus_fn)
		self.bg:SetOnLoseFocus(onlosefocus_fn)
		
		self.shown = false
		self:Hide()
		
		
        self:StartUpdating()
    end)

function GroundChestUI:FillBoard(scale)--Function for testing, use as reference, do not use for anything other than testing.
		self.bgitem = self.bg:AddChild(ImageButton("images/quagmire_recipebook.xml","cookbook_known.tex"))
		self.bgitem:SetPosition(0,0)
		self.bgitem:SetOnClick(function() print("Clickity Click") end)
		self.bgitem:Hide()
		w,h = self.bgitem:GetSize()
		w = w*scale
		h = h*scale
		for x = 1,math.floor(self.size_x/w) do
			for y = 1,math.floor(self.size_y/h)-2 do
			self.bgitem = self.bg:AddChild(ImageButton("images/quagmire_recipebook.xml","recipe_known.tex"))
			self.bgitem:SetScale(scale)
			
			local min_vx = -8 -- Min distance it has to be from the vertical edges
            local u_x = self.size_x-2*min_vx
            local d_x = u_x/(math.floor(self.size_x/w+1))
			
            local min_tz = 32 -- Min top
            local min_bz = 8 -- Min bot
            local u_z = self.size_y-min_tz-min_bz
            local d_z = u_z/(math.floor(self.size_y/h-2)+1)
            self.bgitem:SetPosition((-0.5)*u_x+d_x*x,(0.5)*u_z-min_tz-d_z*y)
			
			self.bgitem:SetOnClick(function() print("Clickity Click") end)
			self.bgitem:Show()
		
			self.testitem = self.bgitem:AddChild(ImageButton(GetInventoryItemAtlas("cane_ancient.tex"),"cane_ancient.tex"))
			self.testitem:SetScale(2)
			self.testitem:Show()
			self.testitemcount = self.bgitem:AddChild(Text(NUMBERFONT,72))
			self.testitemcount:SetPosition(0,-30)
			self.testitemcount:SetString(tostring(math.random(1,40)))
			self.testitemcount:MoveToFront()
			self.testitemcount:Show()
			self.bgitem:SetOnGainFocus(function() self.testitemcount:SetSize(72*1.2) self.testitemcount:SetPosition(0,-30*1.2) end)
			self.bgitem:SetOnLoseFocus(function() self.testitemcount:SetSize(72) self.testitemcount:SetPosition(0,-30) end)
			end
		end
end

function GroundChestUI:Toggle()
	if self.shown then
		self.shown = false
		self:Hide()
	else
		self.shown = true
		self:Show()
	end
end
	
function GroundChestUI:AddItem(prefab)
	
	if not prefab or prefab == "" then return nil end
	
	
	
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

function GroundChestUI:GetNearestItem()
	local pos = ThePlayer:GetPosition()
	return TheSim:FindEntities(pos.x,0,pos.z,70,{"_inventoryitem"},{"INLIMBO","flying"})[1]
end


function GroundChestUI:OnUpdate(dt)
	self:HandleMouseMovement()
	local item = self:GetNearestItem()
	if item then
		local item_atlas = GetInventoryItemAtlas(item.prefab..".tex")
		self.test_tile:SetItem(item,item_atlas,item.prefab..".tex")
	end
end

if ui_button and ui_button ~= 0 then
	TheInput:AddKeyDownHandler(ui_button,function() if not InGame() then return else on_button_press_fn() end end)
end

return GroundChestUI

    