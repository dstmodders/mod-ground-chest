
local function GetSkin(obj)
	local skin = obj.skinname or obj.AnimState and obj.AnimState:GetBuild()
	return STRINGS.SKIN_NAMES[skin] and skin or nil
end

local function AdjustTex(tex)
	local a,b
--	string.gsub(tex,"_spice_(%a+).",".") -- Removes "_spice_salt" from "meatballs_spice_salt.tex"
	-- For spiced crockpot dishes, get the spice and use spice.."_over.tex"
	a,b = string.find(tex,"_spice_(%a+).")
	if a and b then
		tex = string.sub(tex,a+1,b-1).."_over.tex"
	end
	-- If there's a number at the end of the tex, change it to the highest number possible
	a,b = string.find(tex,"(%d+).tex")
	if a and b then
--		b = b - 4
		local str = string.sub(tex,1,a-1)
--		local strright = string.sub(tex,1,a-1)
		local num = 50
		for i = 2,50 do -- Added an upper limit in case of errors
			if not GetInventoryItemAtlas(str..i..".tex", true) then
				num = i
				break
			end
		end
		if num == 50 then num = 2 else num = num-1 end
		tex = str..num..".tex"
	end
--	if a and b then
--		string.
--	end
	return GetInventoryItemAtlas(tex,true) and tex or nil
end

local function GenerateItemList(pos, distance)
	local platform = TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z)
	local entities = TheSim:FindEntities(pos.x, pos.y, pos.z, distance, {"_inventoryitem"}, {"FX", "NOCLICK", "DECOR", "INLIMBO", "catchable", "mineactive", "intense"})
	for i = #entities,1,-1 do
		local obj = entities[i]
		if obj.replica.inventoryitem == nil or not obj.replica.inventoryitem:CanBePickedUp() then
			table.remove(entities,i)
		elseif obj:GetCurrentPlatform() ~= platform or obj:IsOnOcean(false) then -- Objects located not in the same boat or in the ocean are excluded from the list
			table.remove(entities,i)
		end
	end
	local result = {}
	local num = 1
	local prefabToNum = {}
	for i = 1,#entities do
		local obj = entities[i]
		if obj then
			local prefab = obj.prefab
			if not prefabToNum[prefab] then -- New Prefab for the list
				result[num] = {}
				result[num].groups = {}
				result[num].prefab = prefab
				result[num].name   = obj:GetBasicDisplayName() -- required for e.g. Salty Meatballs since obj.name returns nil for them
				result[num].tex    = obj.replica.inventoryitem and obj.replica.inventoryitem:GetImage()
				if result[num].tex then
					result[num].tex = AdjustTex(result[num].tex)
				end
				if obj.replica.stackable then -- Stackable
					result[num].amount = obj.replica.stackable:StackSize() or 0
				else -- Not Stackable
					result[num].amount = 1
				end
				result[num].durability = obj.components.finiteuses ~= nil
				if result[num].durability then -- Only for caveless solo servers: Shows the durability of items
					result[num].groups[#result[num].groups + 1] = obj
				else -- Items are divided depending on their skin
					result[num].groups[GetSkin(obj) or "none"] = result[num].amount
				end
				if obj.inv_image_bg then
					result[num].bg_tex   = obj.inv_image_bg.image
					result[num].bg_atlas = obj.inv_image_bg.atlas
				end
				prefabToNum[prefab] = num
				num = num+1
			else
				local num = prefabToNum[prefab]
				local amount = obj.replica.stackable and obj.replica.stackable:StackSize() or 1
				result[num].amount = result[num].amount + amount
				if result[num].durability then
					result[num].groups[#result[num].groups + 1] = obj
				else
					local skin = GetSkin(obj) or "none"
					result[num].groups[skin] = (result[num].groups[skin] or 0) + amount
				end
			end
		end
	end
	return result
end

local function sortResult(a,b)
	if a.prefab ~= b.prefab then
		return a.name < b.name
	elseif a.durability and b.durability then
		return a.durability > b.durability
	elseif a.skin or b.skin then
		return a.skin == nil and true or b.skin ~= nil and a.skin < b.skin or false
	end
	return a.prefab < b.prefab
end
--GetInventoryItemAtlas(name, true)
local function FetchItemList(datalist, matchingText)
	if not datalist then return nil end
	local result = {}
	local num = 1
	local advanced = matchingText and matchingText ~= ""
	matchingText = string.lower(matchingText)
	for i = 1,#datalist do
		if not matchingText or string.find(string.lower(datalist[i].name),matchingText) then
			if advanced then
				local name = datalist[i].name
				local prefab = datalist[i].prefab
				if datalist[i].durability then
					for k,v in pairs(datalist[i].groups) do
						result[num] = {}
						result[num].name   = name
						result[num].prefab = prefab
						--result[num].amount = nil
						result[num].obj    = v
						result[num].durability = math.max(math.floor(v.components.finiteuses:GetPercent()*100 + 0.5),1)
						result[num].skin   = GetSkin(v)
						result[num].tex    = datalist[i].tex
						result[num].bg_tex = datalist[i].bg_tex
						result[num].bg_atlas = datalist[i].bg_atlas
						num = num + 1
					end
				else
					for k,v in pairs(datalist[i].groups) do
						result[num] = {}
						result[num].name   = name
						result[num].prefab = prefab
						result[num].amount = v
						result[num].skin   = k ~= "none" and k or nil
						result[num].tex    = datalist[i].tex
						result[num].bg_tex = datalist[i].bg_tex
						result[num].bg_atlas = datalist[i].bg_atlas
						num = num + 1
					end
				end
			else
				result[num] = {}
				result[num].name   = datalist[i].name
				result[num].prefab = datalist[i].prefab
				result[num].amount = datalist[i].amount
				result[num].tex    = datalist[i].tex
				result[num].bg_tex = datalist[i].bg_tex
				result[num].bg_atlas = datalist[i].bg_atlas
				num = num + 1
			end
		end
	end
	table.sort(result,sortResult)
	return result
end

return {GenerateItemList = GenerateItemList,
	FetchItemList = FetchItemList}
