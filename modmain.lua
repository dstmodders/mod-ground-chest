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

AddPlayerPostInit(function(inst)
        inst:DoTaskInTime(0,function()
                if inst == _G.ThePlayer then
                    --Use one of these roots: top_root, right_root, left_root, bottom_root; or none.
                    local widget = GroundChestUI(inst)
                    widget:SetModRoot(MODROOT)
					_G.ThePlayer.HUD:AddChild(widget)
                end
            end)
    end)


local function InGame()
	return _G.ThePlayer and _G.ThePlayer.HUD and not _G.ThePlayer.HUD:HasInputFocus()
end


local interrupt_controls = {}
for control = _G.CONTROL_ATTACK, _G.CONTROL_MOVE_RIGHT do
    interrupt_controls[control] = true
end

AddComponentPostInit("playercontroller", function(self, inst)
    if inst ~= _G.ThePlayer then return end
	_G.ThePlayer:AddComponent("groundchestpickupqueuer")
    local mouse_controls = {[_G.CONTROL_PRIMARY] = true, [_G.CONTROL_SECONDARY] = true}

    local PlayerControllerOnControl = self.OnControl
    self.OnControl = function(self, control, down)
        local mouse_control = mouse_controls[control]
        local interrupt_control = interrupt_controls[control]
        if interrupt_control or mouse_control then
            if down and InGame() then
                _G.ThePlayer.components.groundchestpickupqueuer:Stop()
            end
        end
        PlayerControllerOnControl(self, control, down)
    end
end)

