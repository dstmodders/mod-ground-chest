
local function sortByName(a,b)
--	local nameA, nameB = string.lower(a.name), string.lower(b.name)
	return string.lower(a.name) < string.lower(b.name)
end

local sortingFunctions = {
--	["distance"] = nil,
	["name"] = sortByName,
--	["durability"] = sortByDurability,
}


-- GenerateItemList (WIP)
--  matchingText: If not equal nil then the objects name must contain the string in their name to be included
--  sortBy: Insert a string to decide how the list is going to be sorted
--	Currently available possibilities:	
--	- distance: Sort by distance from closest to furthest away
--	- name: Sort alphabetically from A to Z
--
local function GenerateItemList(pos, distance, matchingText, sortBy)
	local entities = TheSim:FindEntities(pos.x, pos.y, pos.z, distance, {"_inventoryitem"}, {"FX", "NOCLICK", "DECOR", "INLIMBO", "catchable", "mineactive", "intense"})
	local durabilityOnly = true
	if matchingText then
		matchingText = string.lower(matchingText)
		for i = #entities,1,-1 do
			local obj = entities[i]
			if not string.find(string.lower(obj.name),matchingText) then
				table.remove(entities,i)
			end
		end
	end
	for i = #entities,1,-1 do
		local obj = entities[i]
		if obj.replica.inventoryitem ~= nil and not obj.replica.inventoryitem:CanBePickedUp() then
			table.remove(entities,i)
		elseif durabilityOnly and not obj.components.finiteuses then
			durabilityOnly = false
		end
	end
	if sortBy == nil then sortBy = "name" end
	if sortingFunctions[sortBy] then
		table.sort(entities,sortingFunctions[sortBy])
	end
	-- Todo: If all found objects have a durability, show every item single with its durability instead of stacked together
	local result = {}
	local prefabToNum = {}
	local num = 1
	if durabilityOnly then -- Display all items with their corresponding durability and skins
		-- Todo: Items with the same skin and no durability should be stacked together
		for i = 1,#entities do
			local obj = entities[i]
			if obj then
				result[num] = {}
				result[num].prefab = obj.prefab
				result[num].name = obj.name
				result[num].amount = nil
				result[num].durability = math.floor(obj.components.finiteuses:GetPercent()*100.0)
				result[num].entity = obj
				result[num].skin_id = obj.skin_id
				result[num].skinname = obj.skinname
				num = num+1
			end
		end
		return result
	end
	for i = 1,#entities do
		local obj = entities[i]
		if obj then
			local prefab = obj.prefab
			if not prefabToNum[prefab] then
				result[num] = {}
				result[num].prefab = prefab
				result[num].name   = obj.name
				if obj.replica.stackable then
					result[num].amount = obj.replica.stackable:StackSize() or 0
				else
					result[num].amount = 1
				end
				prefabToNum[prefab] = num
				num = num+1
			else
				local num = prefabToNum[prefab]
				result[num].amount = result[num].amount + (obj.replica.stackable and obj.replica.stackable:StackSize() or 1)
			end
		end
	end
	return result
end

return {GenerateItemList = GenerateItemList}