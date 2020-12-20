local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local UIAnimButton = require "widgets/uianimbutton"
local GroundChestItemTiles = require "widgets/groundchestitemtiles"
local screen_x, screen_z,half_x,half_z

local function LoadConfig(name)
    local mod = "Ground Chest"
    return GetModConfigData(name,mod) or GetModConfigData(name,KnownModIndex:GetModActualName(mod))
end

local GroundChestUI = Class(Widget,function(self,owner)
        Widget._ctor(self,"GroundChestUI")
		
        screen_x,screen_z = TheSim:GetScreenSize()
        half_x = screen_x/2
        half_z = screen_z/2
		
        self.owner = owner
		
        --self:StartUpdating()
    end
    )
    
function GroundChestUI:OnUpdate(dt)

end

return GroundChestUI

    