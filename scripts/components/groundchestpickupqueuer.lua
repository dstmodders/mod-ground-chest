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

function GroundChestPickupQueuer:Start()
    if self.owner[thread_name] then
        print("Queue '"..thread_name.."' already exists")
    else
       self.owner[thread_name] = self.owner:StartThread(function()
            while true do
                Sleep(check_delay)
                if not self.respect_queue_order and #self.queue > 1 then-- If queue order doesn't matter then we can just throw everything into a single queue.
                    local all_queued_items = {}
                    for k,queue in pairs(self.queue) do
                        for _,item in pairs(queue.list) do
                            table.insert(all_queued_items,item)
                        end
                    end
                    self.queue = {{list = all_queued_items}} --prefab, build, skinned, all, non_defaults are all nil.
                end
                
                local item_list = self.queue[1] and self.queue[1].list
                
                if not item_list then
                   self:Stop()
                   return
                end

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
                       table.remove(item_list,1)
                       table.sort(item_list,
                           function(a,b)
                               return a:IsValid() and b:IsValid() and a:GetDistanceSqToInst(self.owner) < b:GetDistanceSqToInst(self.owner)
                           end)
                       self.item_counter = 1 -- self.item_counter = self.item_counter+1
                   end
                end
            end
       end)
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
