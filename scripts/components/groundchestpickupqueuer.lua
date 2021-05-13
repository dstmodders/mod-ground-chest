local check_delay = 1/30 -- Lower check delay makes it feel more responsive.
local thread_name = "mod_groundchestpickupqueuer_thread"
local GetTrueSkinName = require "searchFunction".GetTrueSkinName

local GroundChestPickupQueuer = Class(function(self,inst)
        self.owner = inst
        self.queue = {}
        self.item_counter = 1
        self.ignore_stacks = false
        self.respect_queue_order = true
    end)


function GroundChestPickupQueuer:SetIgnoreMaxedStacks(bool)
   self.ignore_stacks = bool 
   --print("self.ignore_stacks set to",bool)
end

function GroundChestPickupQueuer:SetRespectQueue(bool)
    self.respect_queue_order = bool
end

function GroundChestPickupQueuer:PickupItem(item)
    if not item then return nil end
    local pos = ThePlayer:GetPosition() --item:GetPosition()
    if (TheWorld and TheWorld.ismastersim) or self.owner.components.locomotor then -- Locomotor for an animation when Lag Compensation is on.
        local action = item:HasTag("trapsprung") and ACTIONS.CHECKTRAP or ACTIONS.PICKUP
        local buffed_act = BufferedAction(self.owner,item,action,nil,pos)
        buffed_act.preview_cb = function() SendRPCToServer(RPC.LeftClick,action.code,pos.x,pos.z,item,true) end
        self.owner.components.playercontroller:DoAction(buffed_act)
    else
        SendRPCToServer(RPC.LeftClick,ACTIONS.PICKUP.code,pos.x,pos.z,item,true)
        SendRPCToServer(RPC.LeftClick,ACTIONS.CHECKTRAP.code,pos.x,pos.z,item,true)
    end
end

function GroundChestPickupQueuer:CheckItemValid(item)
    return item and item:IsValid() and not item:HasTag("INLIMBO")
end

function GroundChestPickupQueuer:GetItemList(prefab,build,all,skinned,non_defaults)
    local pos = self.owner:GetPosition()
    local ent_list = TheSim:FindEntities(pos.x,0,pos.z,80,{"_inventoryitem"}, {"FX", "NOCLICK", "DECOR", "INLIMBO"})
    local valid_ents = {}
    local empty = true
    local ignore_stacks = function(item)
        return (not self.ignore_stacks) or item and ((not item.replica.stackable) or not item.replica.stackable:IsFull())
    end
    for k,ent in pairs(ent_list) do
        local ent_build = ent.AnimState and ent.AnimState:GetBuild()
        if ent.prefab == prefab and ((not skinned) and (non_defaults or STRINGS.SKIN_NAMES[ent_build] == nil) or (ent_build == build or GetTrueSkinName(ent_build,prefab) == build)) and (not ent:IsOnOcean()) and ignore_stacks(ent) then
            table.insert(valid_ents,#valid_ents+1,ent)
            empty = false
            if not all then
               break 
            end
        end
    end
    return valid_ents,empty
end

function GroundChestPickupQueuer:AddToQueue(prefab,build,all,skinned,non_defaults)
    local ent_list,empty = self:GetItemList(prefab,build,all,skinned,non_defaults)
    --if empty then print("Item List empty") return nil end
    --print("Added to queue: ","{",prefab,build,all,skinned,non_defaults,"}")
    self.queue[#self.queue+1] = {list = ent_list, prefab = prefab, build = build, skinned = skinned, all = all, non_defaults = non_defaults}
    if not self.owner[thread_name] then self:Start() end
end

function GroundChestPickupQueuer:RemoveFromQueue(prefab,build,skinned)
    for k,queue in pairs(self.queue) do
        if queue.prefab == prefab and queue.build == build and queue.skinned == skinned then
           --print("Removed from queue: ","{",prefab,build,skinned,"}")
           table.remove(self.queue,k)
           break
        end
    end
end

function GroundChestPickupQueuer:FindClosestItemIndex(list,list_sizes)
   if not list then return 1 end
   if list and type(list) == "table" then
       local mindist, mindist_item
       local item_index = 1
      for k,item in pairs(list) do
        if item:IsValid() then
            local distance = item:GetDistanceSqToInst(self.owner)
            if (not mindist) or (distance < mindist) then
                mindist = distance
                --mindist_item = item
                item_index = k
            end
        else -- While this function shouldn't be responsible for removing items, they won't get referenced => they'll be ignored.
            self:RemoveNonValidItem(list_sizes,k)
        end
      end
      return item_index
   end
end

local function GetQueueIndexFromAssignedSizeList(size_list,index)
    --Given a table of sizes and an index, return the array to which the index belongs to
    --And what that index would be in that specific array.
    local range = 0
    local list_index
    for k,index_size in pairs(size_list) do
        if index_size+range < index then
            range = range+index_size
        else
            list_index = k
            break
        end
    end
    return list_index,index-range
end

function GroundChestPickupQueuer:RemoveNonValidItem(list_sizes,item_index)
    local array,index = GetQueueIndexFromAssignedSizeList(list_sizes,item_index)
    local queue_table = self.queue[array]
    if queue_table then
        table.remove(queue_table.list,index)
        if #queue_table.list == 0 then
            self.owner:PushEvent("groundchestpickupqueuer_queuecycle",queue_table)
            table.remove(self.queue,array) 
        end
    end
end

function GroundChestPickupQueuer:GetQueueFunction(queue)
    local queues = {
        ["ordered"] = function() 
                        while true do
                            Sleep(check_delay)
                            local item_list = self.queue[1] and self.queue[1].list
                            if not item_list then
                                self:Stop()
                                return
                            end
                            self.item_counter = self:FindClosestItemIndex(item_list)
                            local item = item_list[self.item_counter]
                            if not item then
                                self.owner:PushEvent("groundchestpickupqueuer_queuecycle",self.queue[1])
                                table.remove(self.queue,1)
                                self.item_counter = 1
                            else
                                if self:CheckItemValid(item) then
                                    if not self.owner.components.playercontroller:IsDoingOrWorking() then
                                        self:PickupItem(item)
                                    end
                                else
                                    table.remove(item_list,self.item_counter)
                                    self.item_counter = 1
                                end
                            end
                        end
                    end,
        ["closest"] = function()
                        while true do
                            Sleep(check_delay)
                            local list_sizes = {}
                            local queued_items = {}
                            for k,list in pairs(self.queue) do
                                list_sizes[k] = #list.list 
                                for _,item in pairs(list.list) do
                                    table.insert(queued_items,item) 
                                end
                            end
                            if not queued_items[1] then
                                self:Stop()
                                return
                            end
                            self.item_counter = self:FindClosestItemIndex(queued_items,list_sizes)
                            local item = queued_items[self.item_counter]
                            if self:CheckItemValid(item) then
                                if not self.owner.components.playercontroller:IsDoingOrWorking() then
                                    self:PickupItem(item) 
                                end
                            else
                                self:RemoveNonValidItem(list_sizes,self.item_counter)
                                self.item_counter = 1
                            end
                        end
                    end,
    }
    return queues[queue]
end

function GroundChestPickupQueuer:Start()
    if self.owner[thread_name] then
        print("Queue '"..thread_name.."' already exists")
    else
        local queue = self.respect_queue_order and "ordered" or "closest"
       self.owner[thread_name] = self.owner:StartThread(self:GetQueueFunction(queue))
        self.owner[thread_name].id = thread_name
    end
end

function GroundChestPickupQueuer:ResetQueue()
    self.queue = {}
    self.item_counter = 1 
end

function GroundChestPickupQueuer:Stop() -- Full stop, including removing the entire queue.
    if self.owner[thread_name] then
        KillThreadsWithID(self.owner[thread_name].id)
        self.owner[thread_name]:SetList(nil)
        self.owner[thread_name] = nil
        self:ResetQueue()
        self.owner:PushEvent("groundchestpickupqueuer_stopped")
        --print("GroundChestPickupQueuer stopped")
   end
end

return GroundChestPickupQueuer
