local Widget = require "widgets/widget"
local Text = require "widgets/text"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local UIAnim = require "widgets/uianim"
local UIAnimButton = require "widgets/uianimbutton"

local GroundItemTile = Class(Widget,function(self,owner,atlas,tex,count,bg)
        Widget._ctor(self,"GroundItemTile")
		
        self.owner = owner
        self.atlas = atlas
        self.tex = tex
        self.count = count or 1
		self.bg = bg
        
        --self:StartUpdating()
    end
    )
    
function GroundItemTile:OnUpdate(dt)

end

return GroundItemTile
