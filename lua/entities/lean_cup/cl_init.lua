include("shared.lua")

local LM = LeanMachine

function ENT:Draw()
    self:DrawModel()
end

function ENT:DrawTranslucent()
    local sub = LM.Config.Cup.Drinkable and "E to drink  -  Crouch + E to store" or "Crouch + E to store"
    LM.UI.DrawWorldLabel(self, "Cup of Lean", sub, self:BoundingRadius() + 6, 180)
end
