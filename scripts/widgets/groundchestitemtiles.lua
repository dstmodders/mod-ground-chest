local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local UIAnimButton = require "widgets/uianimbutton"


--GroundItemTile Class: Holds some item information, widget clickable for some other functionality.
local GroundItemTile = Class(Widget,function(self,item,name,bg,atlas,tex,count)
	Widget._ctor(self,"GroundItemTile")

	self.item = item -- Item prefab
	self.name = name
	self.atlas = atlas or "images/quagmire_recipebook.xml" -- Item atlas
	self.tex = tex or "coin_unknown.tex"--Item tex
	self.count = count
	self.queued = false
	self.global_highlight = false
	self.skinned = false
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

	-- For your Salty Meatballs
	self.item_display_bg = self.item_bg:AddChild(ImageButton())
	self.item_display_bg:SetScale(2,2,2)

	self.item_display = self.item_bg:AddChild(ImageButton(self.atlas,self.tex))
	self.item_display.item_bg = self.item_display_bg
	-- The settings of scaling, colours, etc. should move over from "self.item_bg" as "self.item_display" is the child.
	self.item_display:SetScale(2,2,2) -- The item is rather small compared to the tile itself.

	self.text_upper = self.item_bg:AddChild(Text(NUMBERFONT,64))
	self.text_upper:SetPosition(4,32) -- Default position for the available amount of that item
	self.text_lower = self.item_bg:AddChild(Text(NUMBERFONT,64))
	self.text_lower:SetPosition(4,-32) --Default position for the durability of an item
--	self.count_text:SetPosition(0,16) --Default position for an item that's in an "inventory slot"s.

	self.item_bg:SetOnGainFocus(function() self.text_upper:SetScale(focus_scl) self.text_lower:SetScale(focus_scl) end)
	self.item_bg:SetOnLoseFocus(function() self.text_upper:SetScale(1)         self.text_lower:SetScale(1)         end)

--	self:SetStackText(self.count)
	if not item then self:RemoveItem() end

	self.item_display:SetOnGainFocus(function() self:HighlightSelf(true)  end)
	self.item_display:SetOnLoseFocus(function() self:HighlightSelf(false) end)
	self.item_display:SetHoverText(name)
--	self.item_display_bg:SetOnGainFocus(function() self:HighlightSelf(true) end)
--	self.item_display_bg:SetOnLoseFocus(function() self:HighlightSelf(false) end)

	self:SetScale(self.widget_scale)
	self:Show()
	--self:StartUpdating() -- Currently no reason to be updating.
end)

function GroundItemTile:SetOnClickFn(fn)
	self.item_bg:SetOnClick(fn)
end

function GroundItemTile:SetGlobalHighlight(global)
	if global then
		self.global_highlight = true
	else
		self.global_highlight = false
	end
end

function GroundItemTile:ToggleQueue()
	self:SetQueue(not self.queued)
end

function GroundItemTile:SetQueue(queue,visual)
	local build
	local isheld_shift = TheInput:IsKeyDown(KEY_SHIFT)
	if self.tex then
		build = string.sub(self.tex,1,-5)
	end
	if queue then
		self.item_bg:SetTextures("images/quagmire_recipebook.xml","recipe_known.tex")
		self.queued = true
		if not visual then
			ThePlayer.components.groundchestpickupqueuer:AddToQueue(self.item,build,isheld_shift,self.skinned,self.global_highlight)
		end
	else
		self.item_bg:SetTextures(self.bg.atlas,self.bg.tex)
		self.queued = false
		if not visual then
			ThePlayer.components.groundchestpickupqueuer:RemoveFromQueue(self.item,build,self.skinned,self.global_highlight)
		end
	end
end

function GroundItemTile:RemoveItem()
	self.item = nil
	self.atlas = nil
	self.tex = nil
	self.count = nil
	self.skinned = nil
	self.chestitem = nil
	self.container = nil
	self.chestslot = nil
	self.item_display:SetTextures("images/quagmire_recipebook.xml","coin_unknown.tex")
	self.item_display:Hide()
	self.item_display_bg:Hide()
	self:SetQueue(false)
	self:SetText(nil)
	self:StopUpdating()
end

function GroundItemTile:SetItem(item,name,atlas,tex,skinned,bg_atlas,bg_tex,container,slot)
	if (self.item == item and self.atlas == atlas and self.tex == tex and self.bg_atlas == atlas and self.bg_tex == tex) then return end
	self.item = item
	self.name = name
	self.atlas = atlas
	self.tex = tex
	self.bg_atlas = bg_atlas
	self.bg_tex = bg_tex
	self.skinned = skinned
	self.chestitem = container ~= nil
	self.container = container
	self.chestslot = slot
	self.item_display:SetTextures(atlas,tex)
	self.item_display:Show()
	self.item_display:SetHoverText(name)
	if bg_atlas then
		print(item,name,atlas,tex,bg_atlas,bg_tex)
		self.item_display_bg:SetTextures(bg_atlas,bg_tex)
		self.item_display_bg:Show()
	else
		self.item_display_bg:Hide()
	end
--	self.item_display:SetHoverText(item and STRINGS.NAMES[string.upper(item)] or "")
	--self:StartUpdating()--Currently no reason to be updating.
end

local function IsMatchingTex(entity,tex)
	local entity_skin = entity.AnimState and STRINGS.SKIN_NAMES[entity.AnimState:GetBuild()] and entity.AnimState:GetBuild()
	local entity_tex = entity_skin and entity_skin..".tex" or entity.prefab..".tex"
	if entity_tex == tex then
		return true
	end
	return false
end

function GroundItemTile:GetSelfItemList()
	if not self.item then return {} end
	local pos = ThePlayer:GetPosition()
	local ent_list = TheSim:FindEntities(pos.x,0,pos.z,80,{"_inventoryitem"}, {"FX", "NOCLICK", "DECOR"})
	local valid_ent_list = {}
	for k,ent in pairs(ent_list) do
		if ent.prefab == self.item and (self.global_highlight or IsMatchingTex(ent,self.tex)) then
			table.insert(valid_ent_list,#valid_ent_list+1,ent)
		end
	end
	return valid_ent_list
end

function GroundItemTile:HighlightSelf(highlight,colour)
	local valid_ents = self:GetSelfItemList()
	local rgb = type(colour) == "table" and colour or {32/255,128/255,255/255,1}
	if highlight then
		for k,ent in pairs(valid_ents) do
			if ent.AnimState then
				ent.AnimState:SetAddColour(unpack(rgb))
			end
		end
	else
		for k,ent in pairs(valid_ents) do
			if ent.AnimState then
				ent.AnimState:SetAddColour(0,0,0,1)
			end
		end
	end
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

--[[
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
]]

function GroundItemTile:HasItem()
	return self.item ~= nil
end

function GroundItemTile:OnUpdate(dt)
	
end

return GroundItemTile
