local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local UIAnimButton = require "widgets/uianimbutton"


--GroundItemTile Class: Holds some item information, widget clickable for some other functionality.
local GroundItemTile = Class(Widget,function(self,item,bg,atlas,tex,count)
	Widget._ctor(self,"GroundItemTile")

	self.item = item -- Item prefab
	self.atlas = atlas or "images/quagmire_recipebook.xml" -- Item atlas
	self.tex = tex or "coin_unknown.tex"--Item tex
	self.count = count
	self.chestitem = nil -- Compatibility with Chest Memory mod.
	self.container = nil -- Compatibility with Chest Memory mod.
	self.chestslot = nil -- Compatibility with Chest Memory mod.

	self.bg = bg or {atlas = "images/quagmire_recipebook.xml", tex = "cookbook_known.tex", scale = 0.4}--Used bg should be something that centers its widgets at (0,0). Value "bg" should hold atlas,tex,scale.
	--global_redux.tex has some nice images, could any of them be used to convey information?
	-- Backgrounds: 
	--  quagmire_recipebook.xml - ingredient_slot.tex; recipe_known.tex, cookbook_known.tex,cookbook_known_selected.tex --recipe_known looks cool, but doesn't fit bg colour.
	--  ui.xml - portrait_bg.tex; in-window_button_tile_disabled.tex ; in-window_button_tile_idle.tex;
	--  hud.xml - inv_slot.tex ; 

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


	self.text_upper = self.item_bg:AddChild(Text(NUMBERFONT,64))
	self.text_upper:SetPosition(4,32) -- Default position for the available amount of that item
	self.text_lower = self.item_bg:AddChild(Text(NUMBERFONT,64))
	self.text_lower:SetPosition(4,-32) --Default position for the durability of an item
--	self.count_text:SetPosition(0,16) --Default position for an item that's in an "inventory slot"s.

	self.item_bg:SetOnGainFocus(function() self.text_upper:SetScale(focus_scl) self.text_lower:SetScale(focus_scl) end)
	self.item_bg:SetOnLoseFocus(function() self.text_upper:SetScale(1) self.text_lower:SetScale(1) end)

--	self:SetStackText(self.count)
	if not item then self:RemoveItem() end

	self:SetOnClickFn(function() print("*Click*") end)
	self:SetScale(self.widget_scale)
	self:Show()
	--self:StartUpdating() --Currently no reason to be updating.
end)

function GroundItemTile:SetOnClickFn(fn)
	self.item_bg:SetOnClick(fn)
end

function GroundItemTile:RemoveItem()
	self.item = nil
	self.atlas = nil
	self.tex = nil
	self.count = nil
	self.chestitem = nil
	self.container = nil
	self.chestslot = nil
	self.item_display:SetTextures("images/quagmire_recipebook.xml","coin_unknown.tex")
	self.item_display:Hide()
	self:SetText(nil)
	self:StopUpdating()
end

function GroundItemTile:SetItem(item,atlas,tex,container,slot)
	if (self.item == item and self.atlas == atlas and self.tex == tex) then return end
	self.item = item
	self.atlas = atlas
	self.tex = tex
	self.chestitem = container ~= nil
	self.container = container
	self.chestslot = slot
	self.item_display:SetTextures(atlas,tex)
	self.item_display:Show()
	self.item_display:SetHoverText(item and STRINGS.NAMES[string.upper(item)] or "")
	--self:StartUpdating()--Currently no reason to be updating.
end

function GroundItemTile:SetText(amount, durability)
	if not self.item then
		self.text_upper:Hide()
		self.text_lower:Hide()
	else
		self.text_upper:Show()
		self.text_upper:SetString(amount and tostring(amount) or "")
		self.text_lower:Show()
		self.text_lower:SetString(durability and tostring(durability) or "")
	end
end

--[[
function GroundItemTile:SetStackText(text)
	if not self.item then
		self.count_text:SetString("NO ITEM")
		self.count_text:Hide()
	else
		self.count = text
		self.count_text:Show()
		self.count_text:SetString(text and tostring(text) or "")
	end
end
]]

function GroundItemTile:GetAtlasAndTex()
	if self.item and self.item.replica and self.item.replica.inventoryitem then
		local atlas = self.item.replica.inventoryitem:GetAtlas()
		local tex = self.item.replica.inventoryitem:GetImage()
		local build = self.item.AnimState:GetBuild()
		if string.match(build,self.item.prefab) then
			return atlas,build..".tex"
		end
		return atlas,tex
	end
	return nil,nil
end


function GroundItemTile:HasItem()
	return self.item ~= nil
end

function GroundItemTile:OnUpdate(dt)
	
end

return GroundItemTile
