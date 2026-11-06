include("shared.lua")

local LM = LeanMachine

function ENT:Draw()
    self:DrawModel()
end

function ENT:GetStatusText()
    local user = self:GetUser()
    if IsValid(user) then
        return user == LocalPlayer() and "Brewing..." or "In use"
    end

    local wait = self:GetNextUse() - CurTime()
    if wait > 0 then
        return string.format("Ready in %ds", math.ceil(wait))
    end

    return string.format("%d / %d ingredients  -  Press E", LM.CountDone(self), #LM.Config.Ingredients)
end

function ENT:DrawTranslucent()
    LM.UI.DrawWorldLabel(self, "Lean Machine", self:GetStatusText(), self:BoundingRadius() * 0.75 + 8, LM.Config.Barrel.LabelDistance)
end
