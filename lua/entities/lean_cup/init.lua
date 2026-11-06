AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local LM = LeanMachine

function ENT:Initialize()
    local cfg = LM.Config.Cup

    self:SetModel(cfg.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    if cfg.Color then self:SetColor(cfg.Color) end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    if cfg.DespawnTime and cfg.DespawnTime > 0 then
        self.LM_DieTime = CurTime() + cfg.DespawnTime
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    if ply:Crouching() then
        LM.StoreCup(ply, self)
        return
    end

    if not LM.Config.Cup.Drinkable then
        LM.Notify(ply, "Crouch and press E to store this cup.", 0)
        return
    end
    if hook.Run("LeanMachine.CanDrink", ply, self) == false then return end

    LM.ApplyDrink(ply)
    self:Remove()
end

function ENT:Think()
    if self.LM_DieTime and CurTime() >= self.LM_DieTime then
        self:Remove()
        return
    end
    self:NextThink(CurTime() + 1)
    return true
end
