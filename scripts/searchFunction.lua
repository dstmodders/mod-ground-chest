
local function GetSkin(obj)
	local skin = obj.skinname or obj.AnimState and obj.AnimState:GetBuild()
	return STRINGS.SKIN_NAMES[skin] and skin or nil
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
			if not prefabToNum[prefab] then
				result[num] = {}
				result[num].groups = {}
				result[num].prefab = prefab
				result[num].name   = obj:GetBasicDisplayName()
				result[num].durability = obj.components.finiteuses ~= nil
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
	table.sort(result,sortResult)
	return result
end

return {GenerateItemList = GenerateItemList,
	FetchItemList = FetchItemList}
