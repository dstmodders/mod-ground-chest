local _G = GLOBAL
local TheInput = _G.TheInput
local TheWorld = _G.TheWorld
local RPC = _G.RPC
local SendRPCToServer = _G.SendRPCToServer
local ACTIONS = _G.ACTIONS
local TheNet = _G.TheNet
local TheSim = _G.TheSim
local EQUIPSLOTS = _G.EQUIPSLOTS
local Sleep = _G.Sleep
local FRAMES = _G.FRAMES
local require = _G.require

local GroundChestUI = require "widgets/groundchestui"

--TO ADD: Group elements in the UI to get an accurate number of different item types in the area.
AddPlayerPostInit(function(inst)
        inst:DoTaskInTime(0,function()
                if inst == _G.ThePlayer then
                    --Use one of these roots: top_root, right_root, left_root, bottom_root
                   _G.ThePlayer.HUD:AddChild(GroundChestUI(inst))
                end
            end)
    end)