AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local LM = LeanMachine

function ENT:Initialize()
    local cfg = LM.Config.Barrel

    self:SetModel(cfg.Model)
    if cfg.AngleOffset then self:SetAngles(self:LocalToWorldAngles(cfg.AngleOffset)) end
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    if cfg.Color then self:SetColor(cfg.Color) end
    if cfg.Material and cfg.Material ~= "" then self:SetMaterial(cfg.Material) end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        if cfg.Mass and cfg.Mass > 0 then phys:SetMass(cfg.Mass) end
        phys:Wake()
    end

    self.LM_Health = cfg.Health
    self:ResetBatch()
end

function ENT:ResetBatch()
    for i = 1, #LM.Config.Ingredients do
        self:SetNWInt(LM.ProgressKey(i), 0)
    end
    self.LM_Holds = {}
    self.LM_MixStart = nil
    self:SetMixed(false)
    self:SetShaking(false)
    self:UpdateBodygroups()
end

-- Shows each bodygroup once all of its ingredients have been added
function ENT:UpdateBodygroups()
    for name, ids in pairs(LM.Config.Barrel.Bodygroups or {}) do
        local idx = self:FindBodygroupByName(name)
        if idx >= 0 then
            local done = true
            for _, id in ipairs(ids) do
                local ingIdx = LM.IngredientIndex(id)
                if not ingIdx or not LM.IsIngredientDone(self, ingIdx) then done = false break end
            end
            self:SetBodygroup(idx, done and 1 or 0)
        end
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local cfg = LM.Config.Barrel

    local user = self.LM_UserRef
    if IsValid(user) then
        if user == ply then
            LM.OpenMenu(ply, self)
        else
            LM.Notify(ply, "Someone else is using this machine.", 1)
        end
        return
    end

    local owner = self:Getowning_ent()
    if cfg.OwnerOnly and IsValid(owner) and owner ~= ply then
        LM.Notify(ply, "Only the owner can use this machine.", 1)
        return
    end

    local wait = self:GetNextUse() - CurTime()
    if wait > 0 then
        LM.Notify(ply, string.format("The machine needs %d more second(s).", math.ceil(wait)), 1)
        return
    end

    if hook.Run("LeanMachine.CanUse", ply, self) == false then return end

    self.LM_UserRef = ply
    self:SetUser(ply)
    self.LM_Holds = {}
    self.LM_MixStart = nil

    LM.OpenMenu(ply, self)
end

-- Ends the current brewing session. Drops a cup if the batch was fully mixed.
function ENT:EndSession(notifyClient)
    local ply = self.LM_UserRef
    self.LM_UserRef = nil
    self:SetUser(NULL)
    self:SetShaking(false)
    self.LM_Holds = {}
    self.LM_MixStart = nil

    if notifyClient and IsValid(ply) then LM.CloseMenu(ply) end
    if self:GetMixed() then self:DropCup(ply) end
end

function ENT:DropCup(ply)
    local cfg = LM.Config.Barrel

    local cup = ents.Create("lean_cup")
    if not IsValid(cup) then return end

    -- Drop it on the side of the barrel facing the player
    local center = self:WorldSpaceCenter()
    local dir = IsValid(ply) and (ply:GetPos() - self:GetPos()) or self:GetForward()
    dir.z = 0
    if dir:LengthSqr() < 1 then dir = Vector(1, 0, 0) end
    dir:Normalize()

    local maxs = self:OBBMaxs()
    local target = center + dir * (math.max(maxs.x, maxs.y) + 12)
    local tr = util.TraceLine({ start = center, endpos = target, filter = self })
    if tr.Hit then target = tr.HitPos - dir * 8 end

    cup:SetPos(target)
    cup:SetAngles(Angle(0, dir:Angle().y, 0))
    cup:Spawn()

    if IsValid(ply) then
        cup:SetBrewer(ply)
        if cup.CPPISetOwner then cup:CPPISetOwner(ply) end
    end

    local snd = LM.Config.Sounds.Drop
    if snd and snd ~= "" then self:EmitSound(snd, 65) end

    self:ResetBatch()
    self:SetBatches(self:GetBatches() + 1)
    self:SetNextUse(CurTime() + cfg.Cooldown)

    hook.Run("LeanMachine.CupCreated", ply, cup, self)

    if cfg.MaxBatches > 0 and self:GetBatches() >= cfg.MaxBatches then
        LM.Notify(ply, "Your lean machine has worn out.", 0)
        timer.Simple(0, function()
            if IsValid(self) then self:Remove() end
        end)
    end
end

function ENT:Think()
    local user = self.LM_UserRef
    if user ~= nil then
        local maxDist = LM.Config.Barrel.MaxDistance
        if not IsValid(user) then
            self:EndSession(false)
        elseif not user:Alive() or user:GetPos():DistToSqr(self:GetPos()) > maxDist * maxDist then
            self:EndSession(true)
        end
    end

    self:NextThink(CurTime() + 0.25)
    return true
end

function ENT:OnTakeDamage(dmg)
    self:TakePhysicsDamage(dmg)

    if LM.Config.Barrel.Health <= 0 or self.LM_Destroyed then return end
    self.LM_Health = self.LM_Health - dmg:GetDamage()
    if self.LM_Health > 0 then return end

    self.LM_Destroyed = true
    local ed = EffectData()
    ed:SetOrigin(self:WorldSpaceCenter())
    util.Effect("cball_explode", ed)
    self:EmitSound("physics/metal/metal_barrel_impact_hard1.wav")
    self:Remove()
end

function ENT:OnRemove()
    if IsValid(self.LM_UserRef) then LM.CloseMenu(self.LM_UserRef) end
end
