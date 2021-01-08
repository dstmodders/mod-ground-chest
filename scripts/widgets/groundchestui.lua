local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local UIAnimButton = require "widgets/uianimbutton"
local GroundChestItemTiles = require "widgets/groundchestitemtiles"
local searchFunction = require "searchFunction"
local GroundChestUIScreen = require "screens/groundchestuiscreen"
local TEMPLATES = require "widgets/redux/templates"
local PLANT_DEFS = require("prefabs/farm_plant_defs").PLANT_DEFS

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



local function InGame()
	return ThePlayer and ThePlayer.HUD and not ThePlayer.HUD:HasInputFocus()
end

local function CreateButtonInfoHover(self,name,text)
	if not self then return end
	local identifier = name.."_text"
	self[identifier] = self[name]:AddChild(Text(BUTTONFONT,32))
	self[identifier]:SetPosition(0,24)
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

	self.refreshbutton = self.bg:AddChild(ImageButton("images/button_icons.xml","refresh.tex"))
	self.refreshbutton:SetPosition(self.size_x*2.9/7,self.size_y*7/20)
	self.refreshbutton:SetNormalScale(0.2)
	self.refreshbutton:SetFocusScale(0.2*1.1)
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

	self.arrow_left = self.bg:AddChild(ImageButton("images/plantregistry.xml",left_textures.normal,left_textures.over,left_textures.disabled,left_textures.down))
	self.arrow_left:SetPosition(self.size_x*-1/7,self.size_y*7/20)
	self.arrow_left:SetNormalScale(0.5)
	self.arrow_left:SetFocusScale(0.5)

	self.arrow_left_fn = function () self:RetreatPage() end
	self.arrow_left:SetOnClick(self.arrow_left_fn)

	CreateButtonInfoHover(self,"arrow_left","Previous Page")

	self.arrow_right = self.bg:AddChild(ImageButton("images/plantregistry.xml",right_textures.normal,right_textures.over,right_textures.disabled,right_textures.down))
	self.arrow_right:SetPosition(self.size_x*1/7,self.size_y*7/20)
	self.arrow_right:SetNormalScale(0.5)
	self.arrow_right:SetFocusScale(0.5)

	self.arrow_right_fn = function() self:AdvancePage() end
	self.arrow_right:SetOnClick(self.arrow_right_fn)

	CreateButtonInfoHover(self,"arrow_right","Next Page")

	self.page_text = self.bg:AddChild(Text(BUTTONFONT,32))
	self.page_text:SetPosition(0,self.size_y*7/20)
--	self.page_text:SetColour(UICOLOURS.GOLD_SELECTED)
	self.page_text:SetColour(1,201/255,14/255,1) -- Gold coloured.
	self.page_text:SetString("Page 1")


	local box_size = 140
	local box_height = 40
	self.searchtext = ""
	self.searchbox_root = self.bg:AddChild(TEMPLATES.StandardSingleLineTextEntry(nil, box_size, box_height, nil, nil, "Search"))
	self.searchbox_root:SetPosition(self.size_x*-2.25/7,self.size_y*7/20)
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

	local ongainfocus_fn = function() self.focused = true end
	local onlosefocus_fn = function() self.focused = false end
	self.bg:SetOnGainFocus(ongainfocus_fn)
	self.bg:SetOnLoseFocus(onlosefocus_fn)

	ThePlayer:ListenForEvent("groundchestpickupqueuer_stopped",function() self.queue_conditions = {} self:UpdateTiles() end)
	self.shown = false
	self:Hide()

	self:StartUpdating()
end)

function GroundChestUI:ClearSearchbox()
	self.searchbox:SetString("")
	self.searchtext = ""
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

function GroundChestUI:IsQueued(prefab,skin)
	local is_global_queue,is_skin_queue
	for k,info in pairs(self.queue_conditions) do
		if info.prefab == prefab then
			is_global_queue = true
		end
		if info.prefab == prefab and info.skin == skin then
			is_skin_queue = true
		end
	end
	return is_global_queue,is_skin_queue
end

function GroundChestUI:ToggleQueueCondition(prefab,skin)
	if TheInput:IsControlPressed(CONTROL_FORCE_INSPECT) and TheInput:IsKeyDown(KEY_LSHIFT) then return nil end
	local was_condition
	for k,info in pairs(self.queue_conditions) do
		if info.prefab == prefab and info.skin == skin then
			table.remove(self.queue_conditions,k)
			was_condition = true
			break
		end
	end
	if not was_condition then
		table.insert(self.queue_conditions,#self.queue_conditions+1,{prefab = prefab, skin = skin})
	end
end

local GetTrueSkinName = searchFunction.GetTrueSkinName

function GroundChestUI:UpdateTiles()
	for num,tile in pairs(self.tiles) do
		local entity = self.item_list[num+50*(self.page-1)] or {} -- 50 is the current number of items supported per page.
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
		if not atlas and skin then
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
		--Issue with queue coloring: Items that seperate into skins won't get coloured if the selected queued item was their combined part.
		local global_queue,skin_queue = self:IsQueued(prefab,skin)
		tile:SetQueue(false,true)
		if self.searchtext ~= "" then -- Items get seperated by their skins while searching, that means highlighting should also change to be based on skin.
			tile:SetGlobalHighlight(false)
			tile:SetQueue(skin_queue,true)
		else -- If the string is empty, then items aren't seperated into skins and highlight should highlight all of that item with no respect to the skin.
			tile:SetGlobalHighlight(true)
			tile:SetQueue(global_queue or skin_queue,true)
		end

		tile:SetOnClickFn(function()
			if tile:HasItem() then 
				tile:ToggleQueue() 
				self:ToggleQueueCondition(prefab,skin)
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
end

function GroundChestUI:RefreshList()
	local x,y,z = ThePlayer.Transform:GetWorldPosition()
	self.data_list = self.GenerateItemList({x = x, y = y, z = z},80)
	print("list refreshed", #self.data_list)
	self:UpdateList()
end

function GroundChestUI:UpdateList()
	self.item_list = self.FetchItemList(self.data_list, self.searchbox:GetString())
	print("list updated", #self.item_list, self.searchbox:GetString())
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
	TheInput:AddKeyDownHandler(ui_button,function() if not InGame() then return else on_button_press_fn() end end)
end

return GroundChestUI   