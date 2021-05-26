local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local TextButton = require "widgets/textbutton"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local UIAnimButton = require "widgets/uianimbutton"
local GroundChestItemTiles = require "widgets/groundchestitemtiles"
local searchFunction = require "searchFunction"
local GroundChestUIScreen = require "screens/groundchestuiscreen"
local TEMPLATES = require "widgets/redux/templates"
local PLANT_DEFS = require("prefabs/farm_plant_defs").PLANT_DEFS
local status_announcements_enabled = KnownModIndex:IsModEnabled(KnownModIndex:GetModActualName("Status Announcements"))

local screen_x, screen_y,half_x,half_y,w,h

local update_time = 0

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
local searchrange_num = LoadConfig("searchrange")
local includeskins = LoadConfig("includeskins")
local ignoreocean = LoadConfig("ignoreocean")
local boatmode = LoadConfig("boatmode")
local ignorestacks = LoadConfig("ignorestacks")
local queuetype = LoadConfig("queuetype")
local ui_fading = LoadConfig("uifade")
ui_fading = ui_fading and 1.0-ui_fading or 0.50

local searchrange_list = {6,25,80}
local searchrange_names = {"Short","Medium","Large"}
local searchrange_colours = {{0.6,0.6,0.6,1},{0.8,0.8,0.8,1},{1,1,1,1}}

local function InGame()
	return ThePlayer and ThePlayer.HUD and not ThePlayer.HUD:HasInputFocus()
end

local function CreateButtonInfoHover(self,name,text,offset)
	if not self then return end
	offset = offset or {0,24}
	local identifier = name.."_text"
	self[identifier] = self[name]:AddChild(Text(BUTTONFONT,32))
	self[identifier]:SetPosition(unpack(offset))
	self[identifier]:SetString(text)
	self[identifier]:Hide()
	
	self[name]:SetOnGainFocus(function() self[identifier]:Show() end)
	self[name]:SetOnLoseFocus(function() self[identifier]:Hide() end)
end

local GroundChestUI = Class(Widget,function(self,owner)
      Widget._ctor(self,"GroundChestUI")

	self.GenerateItemList = searchFunction.GenerateItemList
	self.FetchItemList    = searchFunction.FetchItemList
		
      screen_x,screen_y = TheSim:GetScreenSize()
      half_x = screen_x/2
      half_y = screen_y/2

	on_button_press_fn = function() self:Toggle() end

	self.owner = owner
	self.tiles = {} --Track all tiles that currently exist and aren't deleted.
	self.data_list = {}
	self.item_list = {}
	self.page = 1
	self.total_pages = 1
	self.queue_conditions = {}
	self.searchrange_num = searchrange_num
	self.searchrange = searchrange_list[self.searchrange_num]
	self.option_skins = includeskins
	self.option_ocean = ignoreocean
	self.option_boats = boatmode
    self.option_ignorestacks = ignorestacks
    self.option_respectqueueorder = queuetype

	self.pos_x = half_x--Centered
	self.pos_y = half_y*1.5--At a 0.75/1 position from below.
	self.offset_x = 0
	self.offset_y = 0

	self.size_x = 1/10*half_x+64*7 --Not sure why I use 1/10 of screen size and then add 64's, but it seems like a relatively good size.
	self.size_y = 1/10*half_y+64*5

	self.bg = self:AddChild(Image("images/plantregistry.xml", "backdrop.tex"))
	self:SetPosition(self.pos_x+self.offset_x,self.pos_y+self.offset_y)
	self.bg:SetSize(self.size_x,self.size_y)
	self.itembg = {atlas = "images/quagmire_recipebook.xml", tex = "cookbook_known.tex", scale = 0.4}
    
    --//Options Widgets--
    local options_size = {x = 180+32, y = self.size_y}
    self.optionswindow = self.bg:AddChild(Image("images/plantregistry.xml", "plant_cell_active.tex"))
    self.optionswindow:SetSize(options_size.x,options_size.y)
    self.optionswindow:SetPosition(16+(self.size_x+options_size.x)/2,0)
    self.optionswindow:Hide() -- Visibility should strictly be related to the self.options_shown variable
    
    
    self.options_text = self.optionswindow:AddChild(Text(NUMBERFONT,32))
	self.options_text:SetColour(1,1,1,1)
	self.options_text:SetString("Options")
    
    
    self.optionsbutton = self.bg:AddChild(ImageButton("images/button_icons.xml","mods.tex")) -- mods.tex is the wrench!
    --Toggles the Options Box(optionswindow)
    local optionsbutton_colour_disabled = {0.5,0.5,0.5,0.5}
    local optionsbutton_colour_enabled = {1,1,1,1}
    
    self.optionsbutton:SetNormalScale(0.2)
    self.optionsbutton:SetFocusScale(0.2*1.2)
    self.optionsbutton:SetImageNormalColour(unpack(optionsbutton_colour_disabled))
    self.optionsbutton:SetImageFocusColour(unpack(optionsbutton_colour_disabled))
    self.options_shown = false

    self.optionsbutton_fn = function()
        if not self.options_shown then
            self.optionswindow:Show()
            self.optionsbutton:SetImageNormalColour(unpack(optionsbutton_colour_enabled))
            self.optionsbutton:SetImageFocusColour(unpack(optionsbutton_colour_enabled))
        else
            self.optionswindow:Hide()
            self.optionsbutton:SetImageNormalColour(unpack(optionsbutton_colour_disabled))
            self.optionsbutton:SetImageFocusColour(unpack(optionsbutton_colour_disabled))
        end
        self.options_shown = not self.options_shown 
    end
    self.optionsbutton:SetOnClick(self.optionsbutton_fn)
    
    CreateButtonInfoHover(self,"optionsbutton","Toggle Options")
    --\\Options Widgets--
    
	--//Checkboxes--
	local fn_generateCheckbox = function(cb_def, cb_option, cb_desc)
		self[cb_def] = self.optionswindow:AddChild(TEMPLATES.LabelCheckbox(function(checkbox)
			self[cb_option] = not self[cb_option]
			self:UpdateList()
			checkbox.checked = self[cb_option]
			checkbox:Refresh()
			return true
		end,self[cb_option],cb_desc))
		self[cb_def]:SetFont(NUMBERFONT)
		self[cb_def].text:SetPosition(20 + self[cb_def].text:GetRegionSize()/2, 0)
		return self[cb_def]
	end

	fn_generateCheckbox("skincheckbox", "option_skins","Include Skins")
	fn_generateCheckbox("oceancheckbox","option_ocean","Ignore Ocean")
	fn_generateCheckbox("boatcheckbox", "option_boats","Boat Mode")
    fn_generateCheckbox("stackcheckbox","option_ignorestacks","Ignore stacks")
    fn_generateCheckbox("queuecheckbox","option_respectqueueorder","Respect Queue")

	--\\Checkboxes--

	self.refreshbutton = self.bg:AddChild(ImageButton("images/button_icons.xml","refresh.tex"))
	self.refreshbutton:SetNormalScale(0.2)
	self.refreshbutton:SetFocusScale(0.2*1.2)
	self.refreshbutton_fn = function() self:RefreshList() end
	self.refreshbutton:SetOnClick(self.refreshbutton_fn)

	CreateButtonInfoHover(self,"refreshbutton","Refresh")

	--Just gonna grab the texture names from Klei's plantspage.lua
	local left_textures = {
		normal = "arrow2_left.tex",
		over = "arrow2_left_over.tex",
		disabled = "arrow_left_disabled.tex",
		down = "arrow2_left_down.tex",
	}
	local right_textures = {
		normal = "arrow2_right.tex",
		over = "arrow2_right_over.tex",
		disabled = "arrow_right_disabled.tex",
		down = "arrow2_right_down.tex",
	}
	
	--//Search Range Widgets--
	self.rangetext = self.optionswindow:AddChild(TextButton("searchrange"))
	self.rangetext:SetFont(NUMBERFONT)
--	self.rangetext:SetTextSize(27.5)
	self.rangetext:SetTextSize(30)
	self.rangetext:SetText("Range: "..(searchrange_names[self.searchrange_num] or tostring(self.searchrange)))
	self.rangetext:SetTextColour(searchrange_colours[self.searchrange_num] or {1,1,1,1})
--	self.rangetext:SetTextColour({1,1,1,1})
	self.rangetext:SetTextFocusColour({1,0.8,0.05,1})

	self.rangetext_fn = function()
		self.searchrange_num = (self.searchrange_num % 3) + 1
		self.searchrange = searchrange_list[self.searchrange_num]
		self.rangetext:SetText("Range: "..(searchrange_names[self.searchrange_num] or tostring(self.searchrange)))
		self.rangetext:SetTextColour(searchrange_colours[self.searchrange_num] or {1,1,1,1})
	end
	self.rangetext:SetOnClick(self.rangetext_fn)
	--\\Search Range Widgets--
	

	self.arrow_left = self.bg:AddChild(ImageButton("images/plantregistry.xml",left_textures.normal,left_textures.over,left_textures.disabled,left_textures.down))
	self.arrow_left:SetNormalScale(0.5)
	self.arrow_left:SetFocusScale(0.5)

	self.arrow_left_fn = function () self:RetreatPage() end
	self.arrow_left:SetOnClick(self.arrow_left_fn)

	CreateButtonInfoHover(self,"arrow_left","Previous Page")

	self.arrow_right = self.bg:AddChild(ImageButton("images/plantregistry.xml",right_textures.normal,right_textures.over,right_textures.disabled,right_textures.down))
	self.arrow_right:SetNormalScale(0.5)
	self.arrow_right:SetFocusScale(0.5)

	self.arrow_right_fn = function() self:AdvancePage() end
	self.arrow_right:SetOnClick(self.arrow_right_fn)

	CreateButtonInfoHover(self,"arrow_right","Next Page")

	self.page_text = self.bg:AddChild(Text(BUTTONFONT,32))
--	self.page_text:SetColour(UICOLOURS.GOLD_SELECTED)
	self.page_text:SetColour(1,201/255,14/255,1) -- Gold coloured.
	self.page_text:SetString("Page 1")


	local box_size = 140
	local box_height = 40
	self.searchtext = ""
	self.searchbox_root = self.bg:AddChild(TEMPLATES.StandardSingleLineTextEntry(nil, box_size, box_height, nil, nil, "Search"))
	self.searchbox = self.searchbox_root.textbox
	self.searchbox:SetTextLengthLimit(50)
	self.searchbox:SetForceEdit(true)
	self.searchbox:EnableWordWrap(false)
	self.searchbox:EnableScrollEditWindow(true)
	self.searchbox.prompt:SetHAlign(ANCHOR_MIDDLE)
	self.searchbox.OnTextInputted = function()
--		self.ent_list = self.FetchItemList(self.data_list, self.searchbox:GetString())
		if self.searchtext ~= self.searchbox:GetString() then
			self.searchtext = self.searchbox:GetString()
			self:UpdateList()
		end
--		print(self.searchbox:GetString())
	end
	self.searchbox.OnMouseButton = function(_, button, down) if not down then self:CreateScreen() end end
	--self.searchbox:SetOnGainFocus( function() self.searchbox:OnGainFocus() end )
	--self.searchbox:SetOnLoseFocus( function() self.searchbox:OnLoseFocus() end )

	self.clearbutton = self.bg:AddChild(ImageButton("images/global_redux.xml","close.tex"))
	self.clearbutton:SetNormalScale(0.8)
	self.clearbutton:SetFocusScale(0.8*1.2)
	self.clearbutton_fn = function() self:ClearSearchbox() end
	self.clearbutton:SetOnClick(self.clearbutton_fn)

	CreateButtonInfoHover(self,"clearbutton","Clear Search")
    
    
	local x_range = 10
	local y_range = 5
	for x = 1,x_range do
		for y = 1,y_range do
			local tile = self.bg:AddChild(GroundChestItemTiles(nil,self.itembg))
			self.tiles[x_range*(y-1)+x] = tile

			local min_vx = -8 -- Min distance it has to be from the vertical edges
			local u_x = self.size_x-2*min_vx
			local d_x = u_x/(x_range+1)

			local min_ty = 40 -- Min top
			local min_by = 16 -- Min bot
			local u_y = self.size_y-min_ty-min_by
			local d_y = u_y/(y_range+1)
			tile:SetPosition((-0.5)*u_x+d_x*x,(0.5)*u_y-min_ty-d_y*y)
		end
	end

	local ongainfocus_fn = function() self.focused = true self:Appear() end
	local onlosefocus_fn = function() self.focused = false self:Fade() end
	self.bg:SetOnGainFocus(ongainfocus_fn)
	self.bg:SetOnLoseFocus(onlosefocus_fn)

	self.owner:ListenForEvent("groundchestpickupqueuer_stopped",function() self.queue_conditions = {} self:UpdateTiles() end)
    self.owner:ListenForEvent("groundchestpickupqueuer_queuecycle",function(origin,data) self:ToggleQueueCondition(data.prefab,data.skinned and (data.prefab == data.build and "default" or data.build) or false,not data.non_defaults) self:UpdateTiles() end)
	self.shown = false
	self:Hide()

	--//Button Locations--
--	self.skincheckbox:SetPosition(  self.size_x*-2.95/7,self.size_y*7/20)
	self.searchbox_root:SetPosition(self.size_x*-2.25/7,self.size_y*7/20)
	self.clearbutton:SetPosition(   self.size_x*-1.1 /7,self.size_y*7/20)
	self.arrow_left:SetPosition(    self.size_x*-0.4 /7,self.size_y*7/20)
	self.page_text:SetPosition(     self.size_x* 0.4 /7,self.size_y*7/20)
	self.arrow_right:SetPosition(   self.size_x* 1.2 /7,self.size_y*7/20)
--	self.rangetext:SetPosition(     self.size_x* 2.0 /7,self.size_y*7/20)
	self.optionsbutton:SetPosition( self.size_x* 2.1 /7,self.size_y*7/20)
	self.refreshbutton:SetPosition( self.size_x* 2.9 /7,self.size_y*7/20)
	--\\Button Locations--

	--//Option Locations--
	self.options_text:SetPosition( options_size.x* 0.0 /7,options_size.y* 8.5/20)
	self.rangetext:SetPosition(    options_size.x*-0.0 /7,options_size.y* 5.0/20)
	self.skincheckbox:SetPosition( options_size.x*-2.0 /7,options_size.y* 3.0/20)
	self.oceancheckbox:SetPosition(options_size.x*-2.0 /7,options_size.y* 1.0/20)
	self.boatcheckbox:SetPosition( options_size.x*-2.0 /7,options_size.y*-1.0/20)
    self.stackcheckbox:SetPosition(options_size.x*-2.0 /7,options_size.y*-3.0/20)
    self.queuecheckbox:SetPosition(options_size.x*-2.0 /7,options_size.y*-5.0/20)
	--\\Option Locations--

	self:StartUpdating()
end)

function GroundChestUI:Fade()
	if self.can_fade_alpha then
		self:SetFadeAlpha(ui_fading,false)
	end
end

function GroundChestUI:Appear()
	if self.can_fade_alpha then
		self:SetFadeAlpha(1.0,false)
	end
end

function GroundChestUI:ClearSearchbox()
	self.searchbox:SetString("")
	self.searchtext = ""
	self:UpdateList()
end

function GroundChestUI:CreateScreen()
	if self.textscreen then self.textscreen:Kill() end
	self.textscreen = self:AddChild(GroundChestUIScreen(self.searchbox))
	TheFrontEnd:PushScreen(self.textscreen)
end

function GroundChestUI:Toggle()
	if self.shown then
		if not TheInput:IsKeyDown(KEY_SHIFT) then
			self.shown = false
			self:Hide()
			if ThePlayer and ThePlayer.components.groundchestpickupqueuer then
				ThePlayer.components.groundchestpickupqueuer:Stop()
			end
		end
	else
		self.shown = true
		self.page = 1
		self.queue_conditions = {}
		self:ClearSearchbox()
		self:RefreshList()
		self:Appear()
		self:Show()
	end
	if TheInput:IsKeyDown(KEY_SHIFT) then
		local item = ThePlayer.replica.inventory:GetActiveItem()
		if item then
			local name = item and item.prefab and STRINGS.NAMES[string.upper(item.prefab)]
			if name then
				self.searchbox:SetString(name)
				self.searchbox:OnTextInputted()
			end
		else
			self.searchbox:OnMouseButton()
		end
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

function GroundChestUI:IsQueued(prefab,skin,skinned)
	local is_global_queue,is_skin_queue,all
    skin = skin or (skinned and "default")
	for k,info in pairs(self.queue_conditions) do
        if info.prefab == prefab then
            --print(k,info.prefab,info.skin,info.all)
            if not info.skin then
                is_global_queue = true
            end
            if info.skin == skin then
                is_skin_queue = true
            end
            if info.all then
                all = true
            end
        end
	end
	return is_global_queue,is_skin_queue,all
end

function GroundChestUI:ToggleQueueCondition(prefab,skin,skinned)
    local shift_down = TheInput:IsKeyDown(KEY_SHIFT)
    skin = skin or (skinned and "default")
	if status_announcements_enabled and TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) and TheInput:IsKeyDown(KEY_LSHIFT) then return nil end
	local was_condition
	for k,info in pairs(self.queue_conditions) do
		if info.prefab == prefab and info.skin == skin then
			table.remove(self.queue_conditions,k)
			was_condition = true
			break
		end
	end
	if not was_condition then
		table.insert(self.queue_conditions,#self.queue_conditions+1,{prefab = prefab, skin = skin, all = shift_down})
	end
end

local GetTrueSkinName = searchFunction.GetTrueSkinName

function GroundChestUI:UpdateTiles()
	for num,tile in pairs(self.tiles) do
		local entity = self.item_list[num+items_page*(self.page-1)] or {} -- 50 is the current number of items supported per page.
		local prefab = entity.prefab
		local name   = entity.name
		local amount = entity.amount
		local durability = entity.durability
		local skin   = entity.skin
--		local AnimState = entity.AnimState

		local tex = skin and skin..".tex" or prefab and prefab..".tex" or nil
--		local tex = prefab and prefab..".tex" or nil
		local atlas = tex and GetInventoryItemAtlas(tex,true) or nil
		
		local real_prefab = string.gsub(prefab or "","_cooked","")
		if skin then --While atlas may exist, it could be the wrong atlas simply due to a mixed build
            --(Eg. Radiant Star Caller has the same build as Prismatic Moon Caller)
			skin = GetTrueSkinName(skin,prefab)
			tex = skin..".tex"
			atlas = GetInventoryItemAtlas(tex,true)
		elseif (not atlas or PLANT_DEFS[real_prefab]) and (not skin) and prefab then
			for k,asset_list in pairs(Prefabs[prefab] and Prefabs[prefab].assets or {}) do
				for _,asset in pairs(asset_list) do
					if asset == "INV_IMAGE" then
						tex = asset_list.file..".tex"
						atlas = GetInventoryItemAtlas(tex,true)
						if (not PLANT_DEFS[real_prefab]) or (PLANT_DEFS[real_prefab] and string.match(asset_list.file,"quagmire")) then
							break
						end
					end
				end
			end
		end
		local option_skins = self.option_skins == nil and self.searchtext ~= "" or self.option_skins or false
		local global_queue,skin_queue,all = self:IsQueued(prefab,skin,option_skins)
		tile:SetQueue(false,true)
		if option_skins then -- Items get seperated by their skins while searching, that means highlighting should also change to be based on skin.
			tile:SetGlobalHighlight(false)
			tile:SetQueue(skin_queue,true,all)
		else -- If the string is empty, then items aren't seperated into skins and highlight should highlight all of that item with no respect to the skin.
			tile:SetGlobalHighlight(true)
			tile:SetQueue(global_queue,true,all)
		end

		tile:SetOnClickFn(function()
			if tile:HasItem() then 
				tile:ToggleQueue() 
				self:ToggleQueueCondition(prefab,skin,option_skins)
				tile:Ping()
			end 
		end)
	
		if prefab then
	--		if atlas or string.match(prefab,"%w+_spice_%w+") then
				tile:SetItem(prefab,atlas,tex,skin ~= nil)
				tile:SetName(name)
	--			tile:SetAnimItem(prefab,tex,AnimState) -- I really dislike using the Anim Items and I much prefer seeing no-texture icon than nothing or the animation.
			if amount then
				tile:SetText(amount > 1 and amount or nil, nil)
			elseif durability then
				tile:SetText(nil, tostring(durability).."%")
			end
		else
			tile:RemoveItem()
			tile:SetText(nil)
		end
	end
	if not self.focused then
		self:Fade()
	end
end

function GroundChestUI:RefreshList()
	local x,y,z = ThePlayer.Transform:GetWorldPosition()
	self.data_list = self.GenerateItemList({x = x, y = y, z = z},self.searchrange,{ocean = self.option_ocean, boats = self.option_boats})
	print("list refreshed", #self.data_list)
	self:UpdateList()
end

function GroundChestUI:UpdateList()
	self.item_list = self.FetchItemList(self.data_list, self.searchbox:GetString(), self.option_skins)
	print("list updated", #self.item_list, self.searchbox:GetString())
    self.owner.components.groundchestpickupqueuer:SetIgnoreMaxedStacks(self.option_ignorestacks)
    self.owner.components.groundchestpickupqueuer:SetRespectQueue(self.option_respectqueueorder)
	self:UpdatePages()
	self:UpdatePageText()
	self:UpdateTiles()
end

function GroundChestUI:AdvancePage()
	local page = self.page
	if page+1 > self.total_pages then --Loop or do nothing.
		
	else
		self.page = self.page+1
	end
	
	self:UpdateTiles()
	self:UpdatePageText()
end

function GroundChestUI:RetreatPage()
	local page = self.page
	if page-1 < 1 then --Loop or do nothing.
		
	else
		self.page = self.page-1
	end
	
	self:UpdateTiles()
	self:UpdatePageText()
end

function GroundChestUI:UpdatePageText()
	self.page_text:SetString("Page "..self.page)
	--Also update the widgets to be clickable/non-clickable:
	if self.page == 1 then
		self.arrow_left:Disable()
	else
		self.arrow_left:Enable()
	end
	if self.page == self.total_pages then
		self.arrow_right:Disable()
	else
		self.arrow_right:Enable()
	end
end


function GroundChestUI:UpdatePages()
	self.total_pages = math.max(math.ceil(#self.item_list/50),1)
	if self.page > self.total_pages then -- Don't move them from their current page unless it doesn't have anything left.
		self.page = self.total_pages
		self:UpdateTiles()
		self:UpdatePageText()
	end
end

function GroundChestUI:OnUpdate(dt)
	self:HandleMouseMovement()
end

if ui_button and ui_button ~= 0 then
	TheInput:AddKeyUpHandler(ui_button,function() if not InGame() then return else on_button_press_fn() end end)
end

return GroundChestUI   