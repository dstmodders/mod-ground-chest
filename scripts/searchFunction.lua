local skinprefabs
local function GetSkin(obj)
	local skin = obj.skinname or obj.AnimState and obj.AnimState:GetBuild()
	return STRINGS.SKIN_NAMES[skin] and skin or nil
end

local function GetTrueSkinName(build,prefab)
    if not skinprefabs then --somewhat an "init" function
        skinprefabs = {}
       for k,data in pairs(Prefabs) do -- while prefabs/skinprefabs.lua can't unfortunately be accessed for all skin prefabs
    --we can exclude tables by the variable is_skin and further reduce table size by checking the skin type
            if data.is_skin and data.type == "item" then
                skinprefabs[k] = {base_prefab = data.base_prefab, build_name_override = data.build_name_override}
            end
        end 
    end
    local item_skins = {}
    local true_skin_name = nil
    for p,data in pairs(skinprefabs) do
        if data.base_prefab == prefab then
           item_skins[p] = data 
        end
    end
    for skin_name,skin_data in pairs(item_skins) do
       if build == skin_name or build == skin_data.build_name_override then
           true_skin_name = skin_name
           --print(true_skin_name)
           break
       end
    end
    return true_skin_name
end

local function GenerateItemList(pos, distance, data)
	data = type(data) == "table" and data or {}
	local ignoreOcean = data.ocean
	local includePlatforms = data.boats
	local platform = TheWorld.Map:GetPlatformAtPoint(pos.x, pos.z)
	local entities = TheSim:FindEntities(pos.x, pos.y, pos.z, distance, {"_inventoryitem"}, {"FX", "NOCLICK", "DECOR", "INLIMBO", "catchable", "mineactive", "intense"})
	for i = #entities,1,-1 do
		local obj = entities[i]
		if obj.replica.inventoryitem == nil or not obj.replica.inventoryitem:CanBePickedUp() then
			table.remove(entities,i)
		elseif ignoreOcean and obj:IsOnOcean(false) or includePlatforms and obj:GetCurrentPlatform() ~= platform and not obj:IsOnOcean(false) then
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
			local adj_fn = obj.displayadjectivefn
			local adj_fn_str = adj_fn and type(adj_fn()) == "string" and adj_fn()
			local adjective = adj_fn_str and adj_fn_str.." " or ""
			if not prefabToNum[prefab] then
				result[num] = {}
				result[num].groups = {}
				result[num].prefab = prefab
				result[num].name   = adjective..obj:GetBasicDisplayName()
				--result[num].durability = obj.components.finiteuses ~= nil
				result[num].durability = false -- durability removed for now sinec it only affects caveless solo worlds, I might reintroduce it another time, perhaps.
				if obj.replica.stackable then
					result[num].amount = obj.replica.stackable:StackSize() or 0
				else
					result[num].amount = 1
				end
				if result[num].durability then
					result[num].groups[#result[num].groups + 1] = obj
				else
					result[num].groups[GetSkin(obj) or "none"] = result[num].amount
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

local highlightText
local function sortResult(a,b)
	if a.prefab ~= b.prefab then
		if highlightText then
			local result
			result = string.lower(string.sub(a.name,1,#highlightText)) == highlightText
			if result ~= (string.lower(string.sub(b.name,1,#highlightText)) == highlightText) then
				return result
			end
		end
		return a.name < b.name
	elseif a.durability and b.durability then
		return a.durability > b.durability
	elseif a.skin or b.skin then
		return a.skin == nil and true or b.skin ~= nil and a.skin < b.skin or false
	end
	return a.prefab < b.prefab
end

local function FetchItemList(datalist, matchingText, includeSkins)
	if not datalist then return nil end
	matchingText = type(matchingText) ~= "string" and "" or string.lower(matchingText)
	local result = {}
	local num = 1
	local advanced = includeSkins == nil and matchingText ~= "" or includeSkins
	for i = 1,#datalist do
		if matchingText == "" or string.find(string.lower(datalist[i].name),matchingText,1,true) then
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
						num = num + 1
					end
				else
					for k,v in pairs(datalist[i].groups) do
						result[num] = {}
						result[num].name   = name
						result[num].prefab = prefab
						result[num].amount = v
						result[num].skin   = k ~= "none" and k or nil
						num = num + 1
					end
				end
			else
				result[num] = {}
				result[num].name   = datalist[i].name
				result[num].prefab = datalist[i].prefab
				result[num].amount = datalist[i].amount
				num = num + 1
			end
		end
	end
	highlightText = matchingText ~= "" and matchingText or nil
	table.sort(result,sortResult)
	return result
end

return {GenerateItemList = GenerateItemList,
	FetchItemList = FetchItemList,
	GetTrueSkinName = GetTrueSkinName,
	}
