include("shared.lua")

local LM = LeanMachine

function ENT:Draw()
    self:DrawModel()
end

-- Subtle purple splash over the top of the machine while it's being shaken
function ENT:Think()
    local cfg = LM.Config.Splash
    if not cfg or not cfg.Enabled or not self:GetShaking() or self:IsDormant() then
        self.LM_SplashAcc = 0
        return
    end

    local ft = FrameTime()
    if ft <= 0 then return end
    self.LM_SplashAcc = (self.LM_SplashAcc or 0) + ft * cfg.Rate
    if self.LM_SplashAcc < 1 then return end

    if not self.LM_Emitter then
        self.LM_Emitter = ParticleEmitter(self:GetPos())
    end
    local emitter = self.LM_Emitter
    if not emitter then return end

    local mins, maxs = self:OBBMins(), self:OBBMaxs()
    local center = (mins + maxs) * 0.5
    local height = maxs.z - mins.z
    local lo, hi = cfg.MinHeight or 0.8, cfg.MaxHeight or 0.9
    local radius = math.min(maxs.x - mins.x, maxs.y - mins.y) * 0.25
    local col = cfg.Color
    emitter:SetPos(self:LocalToWorld(Vector(center.x, center.y, mins.z + height * hi)))

    while self.LM_SplashAcc >= 1 do
        self.LM_SplashAcc = self.LM_SplashAcc - 1

        local z = mins.z + height * math.Rand(lo, hi)
        local offset = Vector(center.x + math.Rand(-radius, radius), center.y + math.Rand(-radius, radius), z)
        local p = emitter:Add(cfg.Material, self:LocalToWorld(offset))
        if p then
            p:SetVelocity(Vector(math.Rand(-20, 20), math.Rand(-20, 20), math.Rand(40, 80)))
            p:SetGravity(Vector(0, 0, -300))
            p:SetDieTime(math.Rand(0.4, 0.7))
            p:SetStartAlpha(170)
            p:SetEndAlpha(0)
            p:SetStartSize(cfg.Size * math.Rand(0.7, 1.2))
            p:SetEndSize(cfg.Size * 0.3)
            p:SetRoll(math.Rand(0, 360))
            p:SetRollDelta(math.Rand(-2, 2))
            p:SetColor(col.r, col.g, col.b)
            p:SetCollide(true)
            p:SetBounce(0.1)
        end
    end
end

function ENT:OnRemove()
    if self.LM_Emitter then
        self.LM_Emitter:Finish()
        self.LM_Emitter = nil
    end
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
