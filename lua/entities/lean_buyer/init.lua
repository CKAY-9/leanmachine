AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local LM = LeanMachine

function ENT:SpawnFunction(ply, tr, class)
    if not tr.Hit then return end

    local ent = ents.Create(class)
    ent:SetPos(tr.HitPos)
    ent:SetAngles(Angle(0, (ply:GetPos() - tr.HitPos):Angle().y, 0))
    ent:Spawn()
    ent:Activate()
    return ent
end

function ENT:Initialize()
    local cfg = LM.Config.Buyer

    self:SetModel(cfg.Model)
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionBounds(Vector(-14, -14, 0), Vector(14, 14, 72))
    self:SetUseType(SIMPLE_USE)

    local seq = self:LookupSequence(cfg.Sequence or "")
    if seq < 0 then seq = self:LookupSequence("idle_subtle") end
    if seq >= 0 then
        self:ResetSequence(seq)
        self:SetPlaybackRate(1)
    end

    for boneName, ang in pairs(cfg.Slouch or {}) do
        local bone = self:LookupBone(boneName)
        if bone then self:ManipulateBoneAngles(bone, ang) end
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local ok, reason = LM.CanSell(ply)
    if not ok then
        LM.Notify(ply, reason, 1)
        return
    end

    LM.OpenBuyer(ply, self)
end

function ENT:OnTakeDamage() end

function ENT:Think()
    self:NextThink(CurTime())
    return true
end
