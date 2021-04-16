local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local GetTrueSkinName = require "searchFunction".GetTrueSkinName
local StatusAnnouncer = KnownModIndex:IsModEnabled(KnownModIndex:GetModActualName("Status Announcements")) and require "statusannouncer" -- Support for rezecib's mod 'Status Announcements'
StatusAnnouncer = StatusAnnouncer and StatusAnnouncer() or nil

--GroundItemTile Class: Holds some item information, widget clickable for some other functionality.
local GroundItemTile = Class(Widget,function(self,item,bg,atlas,tex,count)
	Widget._ctor(self,"GroundItemTile")

	self.item = item -- Item prefab
	self.atlas = atlas or "images/quagmire_recipebook.xml" -- Item atlas
	self.tex = tex or "coin_unknown.tex"--Item tex
	self.count = count
	self.queued = false
	self.global_highlight = false
	self.skinned = false

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
	
	self.item_display_bg = self.item_display:AddChild(ImageButton()) -- This will usually be hidden.
	-- self.item_display_bg can be visible when there's a special background(Spiced food, known freshness, etc.)
	self.item_display_bg:SetScale(1,1,1)
	self.item_display_bg:Hide()


	self.text_upper = self.item_bg:AddChild(Text(NUMBERFONT,64))
	self.text_upper:SetPosition(4,32) -- Default position for the available amount of that item
	self.text_lower = self.item_bg:AddChild(Text(NUMBERFONT,64))
	self.text_lower:SetPosition(4,-32) --Default position for the durability of an item
--	self.count_text:SetPosition(0,16) --Default position for an item that's in an "inventory slot"s.

	self.item_bg:SetOnGainFocus(function() self.text_upper:SetScale(focus_scl) self.text_lower:SetScale(focus_scl) end)
	self.item_bg:SetOnLoseFocus(function() self.text_upper:SetScale(1) self.text_lower:SetScale(1) end)

--	self:SetStackText(self.count)
	if not item then self:RemoveItem() end

	self.item_display:SetOnGainFocus(function() self:SpawnTrackerArrow(true) self:HighlightSelf(true) end)
	self.item_display:SetOnLoseFocus(function() self:SpawnTrackerArrow(false) self:HighlightSelf(false) end)
	self:SetScale(self.widget_scale)
	self:Show()
	--self:StartUpdating() -- Currently no reason to be updating.
end)

function GroundItemTile:SetOnClickFn(fn)
	self.item_bg:SetOnClick(fn)
end

function GroundItemTile:SetGlobalHighlight(global)
	self.global_highlight = global or false
end

function GroundItemTile:ToggleQueue()
	self:SetQueue(not self.queued)
end

function GroundItemTile:SetQueue(queue,visual,all)
	if self:GetPingKeysPressed() then return nil end
	local build
	local isheld_shift = TheInput:IsKeyDown(KEY_SHIFT)
	if self.tex then
		build = string.match(self.tex,"(%S+)%.tex") -- Pattern (%w+).tex is bad because 1. The dot is a magic character; 2. %w+ will only grab the last word and not the entire string.
	end
	if queue then
		self.item_bg:SetTextures("images/quagmire_recipebook.xml","recipe_known.tex")
		if (not visual and isheld_shift) or (visual and all) then
			local shifted_colour = {1,1,0,1}
			self.item_bg:SetImageNormalColour(unpack(shifted_colour))
			self.item_bg:SetImageFocusColour(unpack(shifted_colour))
		end
		self.queued = true
		if visual then return true end
        ThePlayer.components.groundchestpickupqueuer:AddToQueue(self.item,build,isheld_shift,self.skinned,self.global_highlight)
	else
		self.item_bg:SetTextures(self.bg.atlas,self.bg.tex)
		self.item_bg:SetImageNormalColour(1,1,1,1)
		self.item_bg:SetImageFocusColour(1,1,1,1)
		self.queued = false
		if visual then return true end
        ThePlayer.components.groundchestpickupqueuer:RemoveFromQueue(self.item,build,self.skinned,self.global_highlight)
	end
end

function GroundItemTile:GetPingKeysPressed()
	return StatusAnnouncer and TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) and TheInput:IsKeyDown(KEY_LSHIFT)
end

function GroundItemTile:Ping()
	if not self:GetPingKeysPressed() then return nil end
	local whisper = TheInput:IsKeyDown(KEY_CTRL)
	if self:HasItem() then
		local vowels = {"a","e","i","o","u"}
		local item_name = not self.skinned and self.hover_text or STRINGS.SKIN_NAMES[string.sub(self.tex,1,-5)]
		local cant_be_pluralized = string.match(item_name,"%a+(s)$") -- Last words letter is 's'
		local item_name_many = cant_be_pluralized and item_name or item_name.."s"
		local item_count = self.text_upper:GetString()
		local message = ""--STRINGS.LMB.." "
		local article = string.match(item_name,"^[AEIOUaeiou]") and "an" or "a" 
		if item_count == "1"  or item_count == "" then
			message = message.."There is "..article.." "..item_name.." in the area."
		else
			message = message.."There are "..item_count.." "..item_name_many.." in the area."
		end
		--TheNet:Say(message, whisper)
		StatusAnnouncer:Announce(message)
	end
end

function GroundItemTile:RemoveItem()
	self.item = nil
	self.atlas = nil
	self.tex = nil
	self.count = nil
	self.skinned = nil
	self.item_display:SetTextures("images/quagmire_recipebook.xml","coin_unknown.tex")
	self.item_display:Hide()
	self.item_display_bg:SetTextures("images/quagmire_recipebook.xml","coin_unknown.tex") -- A "debug" texture
	self.item_display_bg:SetPosition(-4,-32)
	self.item_display_bg:Hide()
	self.item_display:ClearHoverText()
	self.hover_text = nil
--	self:SetQueue(false) -- Changed to be handled at groundchestui.lua due to code order.
	self:SetText(nil)
    self:SpawnTrackerArrow(false)
	self:StopUpdating()
end

function GroundItemTile:CheckForSpicedFood()
	if not self.item then -- item display background shouldn't be visible
		self.item_display_bg:SetTextures("images/quagmire_recipebook.xml","coin_unknown.tex")
		self.item_display_bg:SetPosition(-4,-32)
		self.item_display_bg:Hide()
		return nil
	end
	local spiced_food = string.match(self.item,"%w+_spice_%w+")
	if spiced_food then -- Time to use the item display background
		local spice = string.match(self.item,"_spice_(%w+)")
		local food = string.match(self.item,"(%w+)_spice")
		local spice_tex = "spice_"..spice.."_over.tex"
		local spice_atlas = GetInventoryItemAtlas(spice_tex)
		self.tex = food..".tex"
		self.atlas = GetInventoryItemAtlas(self.tex)
		self.item_display_bg:SetTextures(spice_atlas,spice_tex)
		self.item_display_bg:SetPosition(0,0)
		self.item_display_bg:MoveToFront()
		self.item_display_bg:Show()
		local spiced_name = string.gsub(STRINGS.NAMES["SPICE_"..string.upper(spice).."_FOOD"],"{food}",STRINGS.NAMES[string.upper(food)])
		return spiced_name
	else
		self.item_display_bg:SetTextures("images/quagmire_recipebook.xml","coin_unknown.tex")
		self.item_display_bg:SetPosition(-4,-32)
		self.item_display_bg:Hide()
	end
end

function GroundItemTile:SetItem(item,atlas,tex,skinned)
	if (self.item == item and self.atlas == atlas and self.tex == tex) then return end
	self:RemoveItem()
	self.item = item
	self.atlas = atlas or "images/quagmire_recipebook.xml"
	self.tex = tex or "coin_unknown.tex"
	local name = self:CheckForSpicedFood()
	self.skinned = skinned
	self.item_display:SetTextures(self.atlas,self.tex)
	self.item_display:Show()
    self.hover_text = name or (item and STRINGS.NAMES[string.upper(item)]) or ""
	self.item_display:SetHoverText(self.hover_text)
	--self:StartUpdating()--Currently no reason to be updating.
end

function GroundItemTile:SetName(name)
	if not self.hover_text or self.hover_text == "" then
        self.hover_text = name
		self.item_display:SetHoverText(self.hover_text)
	end
end

local function IsMatchingTex(entity,tex,prefab)
	local entity_skin = entity.AnimState and STRINGS.SKIN_NAMES[entity.AnimState:GetBuild()] and entity.AnimState:GetBuild()
	local entity_tex = entity_skin and entity_skin..".tex" or entity.prefab..".tex"
	if entity_tex == tex or GetTrueSkinName(entity_skin,prefab)..".tex" == tex then
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
        local _isspiced_or_quagmire = string.match(self.item,"%w+_spice_%w+") or string.match(self.tex,"quagmire")
		if ent.prefab == self.item and (self.global_highlight or IsMatchingTex(ent,self.tex,self.item) or _isspiced_or_quagmire) then
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

function GroundItemTile:SpawnTrackerArrow(track)
    if track then
        self.tracker = SpawnPrefab("archive_resonator_base")
        self.tracker.Light:Enable(false) -- The arrow is too heavy.
        --Note: the tracker has a timer component, which forces it to remove itself after one in-game day.
        --self.tracker.entity:SetParent(ThePlayer.entity) --Assuming ThePlayer isn't a nil value -- Too lazy to account for player rotation too :p
        self:UpdateTracker()
        self:StartUpdating()
    elseif self.tracker then
        self.tracker:Remove()
        self.tracker = nil
        self:StopUpdating()
    end
end

function GroundItemTile:UpdateTracker()
    if not self.tracker then
        self:StopUpdating()
        print("Stopped updating: no tracker arrow")
        return
    end
    local closest_item = self:GetSelfItemList()[1]
    if not closest_item then
        print("Cannot find the item to track with an arrow!")
        self:SpawnTrackerArrow(false)
        return
    else
        local arrow = self.tracker
        local pos = closest_item:GetPosition()
        local player_pos = ThePlayer:GetPosition()
        local difx, difz = player_pos.x-pos.x, player_pos.z-pos.z
        local angle = arrow:GetAngleToPoint(pos.x,pos.y,pos.z)
        local scaler = math.sqrt((difx*difx+difz*difz))/3.0 --The arrow feels to be around 2.7 units long
        arrow.Transform:SetRotation(angle+270)
        arrow.Transform:SetPosition(player_pos.x-difx/6.5,player_pos.y,player_pos.z-difz/6.5)
        arrow.Transform:SetScale(1,scaler,1)
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

function GroundItemTile:HasItem()
	return self.item ~= nil
end

function GroundItemTile:OnUpdate(dt)
	self:UpdateTracker()
end

return GroundItemTile
