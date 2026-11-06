include("shared.lua")

local LM = LeanMachine

function ENT:Draw()
    self:DrawModel()
end

function ENT:GetHeadPos()
    local bone = self:LookupBone("ValveBiped.Bip01_Head1")
    local pos = bone and self:GetBonePosition(bone)
    if not pos or pos == self:GetPos() then
        pos = self:GetPos() + Vector(0, 0, 64)
    end
    return pos
end

function ENT:DrawTranslucent()
    local cfg = LM.Config.Buyer
    local cups = LM.GetCups(LocalPlayer())
    local sub = LM.FormatMoney(cfg.PricePerCup) .. " per cup"
    if cups > 0 then
        sub = sub .. "  -  You have " .. cups
    end
    LM.UI.DrawGlowLabel(self:GetHeadPos() + Vector(0, 0, 16), "Lean Buyer", sub, cfg.LabelDistance)
end

function ENT:Think()
    if not LM.Config.Buyer.Light then return end
    if EyePos():DistToSqr(self:GetPos()) > 1000 * 1000 then return end

    local accent = LM.Config.Theme.Accent
    local light = DynamicLight(self:EntIndex())
    if light then
        light.pos = self:GetHeadPos() + Vector(0, 0, 10)
        light.r, light.g, light.b = accent.r, accent.g, accent.b
        light.brightness = 1
        light.decay = 1000
        light.size = 110
        light.dietime = CurTime() + 0.2
    end
end
