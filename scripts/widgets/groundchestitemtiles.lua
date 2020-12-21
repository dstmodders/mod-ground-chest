local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local UIAnimButton = require "widgets/uianimbutton"


--GroundItemTile Class: Holds all item information, is responsible for removing itself when the item entity can't be found anymore. Is NOT responsible for sorting.
--For optimization and to reduce lag, perhaps all tiles should exist and stay, but be hidden if they don't have any item?
local GroundItemTile = Class(Widget,function(self,item,bg,atlas,tex,count)
        Widget._ctor(self,"GroundItemTile")
		
        self.item = item --To keep track of its existence.
        self.atlas = atlas --Item atlas
        self.tex = tex --Item tex
        self.count = count or 1 --Item count(If it's stackable)
		self.stackable = false --Value gets updated elsewhere.
		self.chestitem = nil--Compatibility with Chest Memory mod.
		self.container = nil--Compatibility with Chest Memory mod.
		self.chestslot = nil--Compatibility with Chest Memory mod.
		
		self.bg = bg or {atlas = "images/quagmire_recipebook.xml", tex = "cookbook_known.tex", scale = 0.4}--Used bg should be something that centers its widgets at (0,0). Value "bg" should hold atlas,tex,scale.
		--global_redux.tex has some nice images, could any of them be used to convey information?
		--[[ Backgrounds: 
		//quagmire_recipebook.xml - ingredient_slot.tex; recipe_known.tex, cookbook_known.tex,cookbook_known_selected.tex --recipe_known looks cool, but doesn't fit bg colour.
		//ui.xml - portrait_bg.tex; in-window_button_tile_disabled.tex ; in-window_button_tile_idle.tex;
		//hud.xml - inv_slot.tex ; 
        --]]
		local focus_scl = 1.2
		self.onhover_scale = {focus_scl,focus_scl,focus_scl}
		
		local normal_scl = 1
		self.nohover_scale = {normal_scl,normal_scl,normal_scl}
		
		self.widget_scale = self.bg.scale or 1 --Overall widget scale
		
		-- color: R,G,B,Opacity
		self.onhover_color = {1,1,1,1}
		self.nohover_color = {1,1,1,1}
		self.disabled_color = {1,1,1,1}
		
		self.focus_sound = nil --Sound which will be played when the tile is hovered over.
		-- I think it's more annoying than useful, so no use.
		
		self.item_bg = self:AddChild(ImageButton(self.bg.atlas,self.bg.tex))
		
		self.item_bg:SetNormalScale(self.nohover_scale[1],self.nohover_scale[2],self.nohover_scale[3])
		self.item_bg:SetFocusScale(self.onhover_scale[1],self.onhover_scale[2],self.onhover_scale[3])
		
		self.item_bg:SetImageNormalColour(unpack(self.nohover_color))
		self.item_bg:SetImageFocusColour(unpack(self.onhover_color))
		self.item_bg:SetImageDisabledColour(unpack(self.disabled_color))
		
		self.item_bg:SetFocusSound(self.focus_sound)
		
		self.item_bg:Show()
		
		self.item_display = self.item_bg:AddChild(ImageButton(self.atlas,self.tex))
		--The settings of scaling, colours, etc. should move over from "self.item_bg" as "self.item_display" is the child.
		
		self.item_display:SetScale(2,2,2) -- The item is rather small compared to the tile itself.
		
		
		self.count_text = self.item_bg:AddChild(Text(NUMBERFONT,42))
		self.count_text:SetPosition(2,16) --Default position for an item that's in an "inventory slot"s.
		
		self.item_bg:SetOnGainFocus(function() self.count_text:SetSize(42*focus_scl) self.count_text:SetPosition(2,16) end)
		self.item_bg:SetOnLoseFocus(function() self.count_text:SetSize(42) self.count_text:SetPosition(2,16*focus_scl) end)

		self:SetOnClickFn(function() print("*Click*") end)
		self:SetScale(self.widget_scale)
		self:Show()
		self:UpdateStackText()
        self:StartUpdating()
		
		
    end
)

function GroundItemTile:SetOnClickFn(fn)
	self.item_bg:SetOnClick(fn)
end

function GroundItemTile:RemoveItem()
	self.item = nil
	self.atlas = nil
	self.tex = nil
	self.count = 1
	self.stackable = false
	self.chestitem = nil
	self.container = nil
	self.chestslot = nil
	self.item_display:SetTextures("images/quagmire_recipebook.xml","coin_unknown.tex")
	self.item_display:Hide()
	self:UpdateStackText()
	self:StopUpdating()
end

function GroundItemTile:SetItem(item,atlas,tex,container,slot)
	if self.item == item then return end
	self.item = item
	self.atlas = atlas
	self.tex = tex
	self.chestitem = container ~= nil
	self.container = container
	self.chestslot = slot
	self.item_display:SetTextures(atlas,tex)
	self.item_display:Show()
	self:StartUpdating()
end
    
function GroundItemTile:UpdateItemStacks()
	if self.item then
		if self.chestitem then
			self.stackable = self.item._stackable
			self.count = self.item.stacksize
		else
			self.stackable = self.item and self.item.components and self.item.components.stackable
			self.count = self.stackable and self.stackable:StackSize() or 1
		end
	end
end
	
function GroundItemTile:UpdateStackText()
	if not self.item then
		self.count_text:SetString("NO ITEM")
		self.count_text:Hide()
	elseif self.item and self.stackable then
		self.count_text:Show()
		self.count_text:SetString(tostring(self.stackable))
	end
end
	
function GroundItemTile:ValidateItem()
	if self.chestitem then
		if self.container and self.container.CS_contents then
			local myitem = self.container.CS_contents[self.chestslot]
			if myitem and myitem.prefab == self.item.prefab then
				self.item = myitem --To update the stackable component.
				return true
			end
		end
		return nil
	else
		return self.item and self.item:IsValid() and not self.item:HasTag("INLIMBO")
	end
end

function GroundItemTile:HasItem()
	return self.item ~= nil
end

function GroundItemTile:OnUpdate(dt)
	if not self:ValidateItem() then
		self:RemoveItem()
	end
	self:UpdateItemStacks()
	self:UpdateStackText()
end

return GroundItemTile
