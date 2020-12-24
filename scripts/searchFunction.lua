
local function sortByName(a,b)
	return string.lower(a.name) > string.lower(b.name)
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
	local entities = TheSim:FindEntities(pos.x, pos.y, pos.z, distance, {"_inventoryitem"})
	if matchingText then
		for k,v in pairs(entities) do
			if not string.find(v.name,matchingText) then
				v = nil
			end
		end
	end
	if sortingFunctions[sortBy] then
		table.sort(entities,sortingFunctions[sortBy])
	end
	-- Todo: If all found objects have a durability, show every item single with its durability instead of stacked together
	local result = {}
	local prefabToNum = {}
	local num = 1
	for i = 1,#entities do
		local obj = entities[i]
		if obj then
			local prefab = obj.prefab
			if not prefabToNum[prefab] then
				result[num] = {}
				result[num].prefab = prefab
				result[num].name   = obj.name
				result[num].amount = obj.replica.stackable and obj.replica.stackable:StackSize() or 1
				result[num].stackable = obj.replica.stackable
--				result.skin_id = obj.skin_id
--				result.skinname = obj.skinname
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