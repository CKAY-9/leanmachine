--[[
    Lean Machine - Server core
    All progress is validated here; the client only displays it.
]]

local LM = LeanMachine
local C = LM.Config

util.AddNetworkString(LM.NET_OPEN)
util.AddNetworkString(LM.NET_CLOSE)
util.AddNetworkString(LM.NET_ACTION)
util.AddNetworkString(LM.NET_DRINK)

function LM.Notify(ply, msg, kind)
    if not IsValid(ply) then return end
    DarkRP.notify(ply, kind or 0, 4, msg)
end

-- Checks the player can afford `cost`, notifying them if not
local function canPay(ply, cost)
    if cost <= 0 or ply:canAfford(cost) then return true end
    LM.Notify(ply, "You can't afford that (" .. LM.FormatMoney(cost) .. ").", 1)
    return false
end

function LM.OpenMenu(ply, ent)
    net.Start(LM.NET_OPEN)
        net.WriteEntity(ent)
    net.Send(ply)
end

function LM.CloseMenu(ply)
    net.Start(LM.NET_CLOSE)
    net.Send(ply)
end

local function tolerance()
    return C.LatencyTolerance or 0.35
end

local function ingredientAdded(ent, ply, idx)
    ent:UpdateModel()
    hook.Run("LeanMachine.IngredientAdded", ply, ent, C.Ingredients[idx])
end

--------------------------------------------------------------------------------
-- Action handlers
--------------------------------------------------------------------------------
local handlers = {}

handlers[LM.ACT_CLICK] = function(ent, ply, idx)
    local ing = C.Ingredients[idx]
    if not ing or ing.type ~= "click" then return end

    local cur, req = LM.GetProgress(ent, idx), LM.Required(ing)
    if cur >= req then return end

    local now = CurTime()
    if now - (ent.LM_LastClick or 0) < (C.MinClickInterval or 0.05) then return end

    local cost = LM.ActionCost(ing)
    if not canPay(ply, cost) then return end

    ent.LM_LastClick = now
    if cost > 0 then ply:addMoney(-cost) end
    ent:SetNWInt(LM.ProgressKey(idx), cur + 1)
    if cur + 1 >= req then ingredientAdded(ent, ply, idx) end
end

handlers[LM.ACT_HOLD_BEGIN] = function(ent, ply, idx)
    local ing = C.Ingredients[idx]
    if not ing or ing.type ~= "hold" or LM.IsIngredientDone(ent, idx) then return end
    if not canPay(ply, LM.ActionCost(ing)) then return end
    ent.LM_Holds[idx] = CurTime()
end

handlers[LM.ACT_HOLD_CANCEL] = function(ent, ply, idx)
    ent.LM_Holds[idx] = nil
end

handlers[LM.ACT_HOLD_END] = function(ent, ply, idx)
    local ing = C.Ingredients[idx]
    local start = ent.LM_Holds[idx]
    ent.LM_Holds[idx] = nil
    if not ing or ing.type ~= "hold" or not start or LM.IsIngredientDone(ent, idx) then return end
    if CurTime() - start < (ing.seconds or 1) - tolerance() then return end

    local cost = LM.ActionCost(ing)
    if not canPay(ply, cost) then return end
    if cost > 0 then ply:addMoney(-cost) end

    ent:SetNWInt(LM.ProgressKey(idx), 1)
    ingredientAdded(ent, ply, idx)
end

handlers[LM.ACT_MIX_BEGIN] = function(ent, ply)
    if ent:GetMixed() or not LM.AllDone(ent) then return end
    ent.LM_MixStart = CurTime()
end

handlers[LM.ACT_MIX_END] = function(ent, ply)
    local start = ent.LM_MixStart
    if not start or ent:GetMixed() or not LM.AllDone(ent) then return end
    if CurTime() - start < C.Mix.Time - tolerance() then return end

    ent.LM_MixStart = nil
    ent:SetShaking(false)
    ent:SetMixed(true)
end

handlers[LM.ACT_SHAKE] = function(ent, ply, on)
    ent:SetShaking(on == 1 and ent.LM_MixStart ~= nil and not ent:GetMixed())
end

handlers[LM.ACT_CLOSE] = function(ent, ply)
    ent:EndSession(false)
end

net.Receive(LM.NET_ACTION, function(_, ply)
    local ent = net.ReadEntity()
    local act = net.ReadUInt(LM.ACT_BITS)
    local idx = net.ReadUInt(8)

    if not IsValid(ply) or not IsValid(ent) or ent:GetClass() ~= "lean_machine" then return end
    if ent:GetUser() ~= ply then return end

    local handler = handlers[act]
    if handler then handler(ent, ply, idx) end
end)

--------------------------------------------------------------------------------
-- Drinking
--------------------------------------------------------------------------------
local function timerName(ply)
    return "LeanMachine.Drink." .. ply:UserID()
end

function LM.ClearDrink(ply, restoreSpeed)
    timer.Remove(timerName(ply))
    if restoreSpeed and ply.LM_SpeedBackup then
        ply:SetWalkSpeed(ply.LM_SpeedBackup.walk)
        ply:SetRunSpeed(ply.LM_SpeedBackup.run)
    end
    ply.LM_SpeedBackup = nil
end

function LM.ApplyDrink(ply)
    local cfg = C.Cup

    if cfg.HealthGain and cfg.HealthGain ~= 0 then
        ply:SetHealth(math.min(ply:Health() + cfg.HealthGain, ply:GetMaxHealth()))
    end

    if C.Sounds.Drink ~= "" then ply:EmitSound(C.Sounds.Drink) end

    -- Only back up / apply the speed once so repeat drinks extend rather than stack
    if cfg.SpeedMultiplier and cfg.SpeedMultiplier ~= 1 and not ply.LM_SpeedBackup then
        ply.LM_SpeedBackup = { walk = ply:GetWalkSpeed(), run = ply:GetRunSpeed() }
        ply:SetWalkSpeed(ply.LM_SpeedBackup.walk * cfg.SpeedMultiplier)
        ply:SetRunSpeed(ply.LM_SpeedBackup.run * cfg.SpeedMultiplier)
    end

    timer.Create(timerName(ply), cfg.Duration, 1, function()
        if IsValid(ply) then LM.ClearDrink(ply, true) end
    end)

    net.Start(LM.NET_DRINK)
        net.WriteFloat(cfg.Duration)
    net.Send(ply)

    hook.Run("LeanMachine.Drank", ply)
end

local function resetOnSpawnOrDeath(ply)
    if not ply.LM_SpeedBackup and not timer.Exists(timerName(ply)) then return end
    LM.ClearDrink(ply, false) -- DarkRP resets speeds itself on spawn
    net.Start(LM.NET_DRINK)
        net.WriteFloat(0)
    net.Send(ply)
end

hook.Add("PlayerSpawn", "LeanMachine.ResetDrink", resetOnSpawnOrDeath)
hook.Add("PostPlayerDeath", "LeanMachine.ResetDrink", resetOnSpawnOrDeath)
