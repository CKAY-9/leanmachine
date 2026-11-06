--[[
    Lean Machine - Cup storage, selling and buyer persistence
]]

local LM = LeanMachine
local C = LM.Config

util.AddNetworkString(LM.NET_BUYER)
util.AddNetworkString(LM.NET_SELL)
util.AddNetworkString(LM.NET_HAGGLE)

--------------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------------
function LM.SetCups(ply, n)
    ply:SetNWInt("LM_Cups", math.max(0, n))
end

-- Stores a cup entity on the player. Returns true on success.
function LM.StoreCup(ply, cup)
    local max = C.Storage.MaxCups
    local have = LM.GetCups(ply)
    if have >= max then
        LM.Notify(ply, string.format("You can't carry any more lean (%d/%d).", have, max), 1)
        return false
    end
    if hook.Run("LeanMachine.CanStore", ply, cup) == false then return false end

    LM.SetCups(ply, have + 1)
    cup:Remove()

    local snd = C.Sounds.Store
    if snd and snd ~= "" then ply:EmitSound(snd, 60) end
    LM.Notify(ply, string.format("Stored a cup of lean (%d/%d).", have + 1, max), 0)
    hook.Run("LeanMachine.Stored", ply, have + 1)
    return true
end

hook.Add("PlayerDeath", "LeanMachine.StoredCups", function(ply)
    local n = LM.GetCups(ply)
    if n <= 0 then return end

    local mode = C.Storage.OnDeath
    if mode == "keep" then return end
    LM.SetCups(ply, 0)
    if mode ~= "drop" then return end

    local origin = ply:GetPos() + Vector(0, 0, 20)
    for i = 1, n do
        local cup = ents.Create("lean_cup")
        if not IsValid(cup) then break end
        local a = math.rad(i / n * 360)
        cup:SetPos(origin + Vector(math.cos(a) * 12, math.sin(a) * 12, i * 2))
        cup:SetAngles(Angle(0, math.random(0, 359), 0))
        cup:Spawn()
    end
end)

hook.Add("playerArrested", "LeanMachine.Confiscate", function(ply)
    if not C.Storage.ConfiscateOnArrest or LM.GetCups(ply) <= 0 then return end
    LM.SetCups(ply, 0)
    LM.Notify(ply, "Your lean was confiscated.", 1)
end)

--------------------------------------------------------------------------------
-- Buyer menu
--------------------------------------------------------------------------------
function LM.OpenBuyer(ply, buyer)
    net.Start(LM.NET_BUYER)
        net.WriteEntity(buyer)
    net.Send(ply)
end

local function nearBuyer(ply, buyer)
    if not IsValid(ply) or not IsValid(buyer) or buyer:GetClass() ~= "lean_buyer" then return false end
    local maxDist = C.Buyer.MaxDistance
    return ply:GetPos():DistToSqr(buyer:GetPos()) <= maxDist * maxDist
end

--------------------------------------------------------------------------------
-- Haggling
--------------------------------------------------------------------------------
-- history is a string of "S"/"F" per attempt, used by the UI
function LM.SetHaggle(ply, attempts, successes, fails, history)
    ply:SetNWInt("LM_HagA", attempts)
    ply:SetNWInt("LM_HagS", successes)
    ply:SetNWInt("LM_HagF", fails)
    ply:SetNWString("LM_HagH", history or "")
end

function LM.ResetHaggle(ply)
    LM.SetHaggle(ply, 0, 0, 0, "")
end

local function randomFrom(list)
    if istable(list) then return list[math.random(#list)] end
    return list
end

net.Receive(LM.NET_HAGGLE, function(_, ply)
    local buyer = net.ReadEntity()
    if not nearBuyer(ply, buyer) then return end

    local H = C.Haggle
    if (ply.LM_NextHaggle or 0) > CurTime() then return end
    ply.LM_NextHaggle = CurTime() + (H.Cooldown or 1)

    local ok, reason = LM.CanSell(ply)
    if not ok then LM.Notify(ply, reason, 1) return end

    local can, why = LM.CanHaggle(ply)
    if not can then LM.Notify(ply, why, 1) return end
    if hook.Run("LeanMachine.CanHaggle", ply, buyer) == false then return end

    local attempts, successes, fails = LM.GetHaggle(ply)
    local success = math.random() < LM.HaggleChance(ply)
    local outcome

    attempts = attempts + 1
    if success then
        successes = successes + 1
        outcome = LM.HAGGLE_SUCCESS
    else
        fails = fails + 1
        outcome = fails >= H.FailsForPenalty and LM.HAGGLE_PENALTY or LM.HAGGLE_FAIL
    end
    LM.SetHaggle(ply, attempts, successes, fails, ply:GetNWString("LM_HagH", "") .. (success and "S" or "F"))

    local key = LM.HAGGLE_KEYS[outcome]
    local voice = randomFrom(H.Voice and H.Voice[key])
    if voice and voice ~= "" then buyer:EmitSound(voice, 70) end

    local lines = H.Lines[key] or {}
    net.Start(LM.NET_HAGGLE)
        net.WriteUInt(outcome, 2)
        net.WriteUInt(math.random(math.max(#lines, 1)), 8)
    net.Send(ply)

    hook.Run("LeanMachine.Haggled", ply, buyer, outcome, LM.SaleMultiplier(ply))
end)

--------------------------------------------------------------------------------
-- Selling
--------------------------------------------------------------------------------
net.Receive(LM.NET_SELL, function(_, ply)
    local buyer = net.ReadEntity()
    if not nearBuyer(ply, buyer) then return end

    if (ply.LM_NextSell or 0) > CurTime() then return end
    ply.LM_NextSell = CurTime() + 1

    local ok, reason = LM.CanSell(ply)
    if not ok then
        LM.Notify(ply, reason, 1)
        return
    end

    local n = LM.GetCups(ply)
    if n <= 0 then
        LM.Notify(ply, "You don't have any lean to sell.", 1)
        return
    end
    if hook.Run("LeanMachine.CanSell", ply, buyer, n) == false then return end

    local mult = LM.SaleMultiplier(ply)
    local payout = n * LM.CupPrice(ply)
    LM.SetCups(ply, 0)
    LM.ResetHaggle(ply)
    ply:addMoney(payout)

    local note = ""
    if mult ~= 1 then
        note = string.format(" (%s%d%% haggled)", mult > 1 and "+" or "", math.Round((mult - 1) * 100))
    end
    LM.Notify(ply, string.format("Sold %d cup%s of lean for %s%s.", n, n == 1 and "" or "s", LM.FormatMoney(payout), note), 0)
    local snd = C.Sounds.Sell
    if snd and snd ~= "" then buyer:EmitSound(snd, 60) end

    hook.Run("LeanMachine.Sold", ply, buyer, n, payout, mult)
end)

--------------------------------------------------------------------------------
-- Buyer persistence (per map)
--------------------------------------------------------------------------------
local function savePath()
    return "leanmachine/buyers_" .. game.GetMap() .. ".json"
end

function LM.SaveBuyers()
    local out = {}
    for _, ent in ipairs(ents.FindByClass("lean_buyer")) do
        out[#out + 1] = { pos = ent:GetPos(), ang = ent:GetAngles() }
        ent.LM_Persistent = true
    end
    file.CreateDir("leanmachine")
    file.Write(savePath(), util.TableToJSON(out, true))
    return #out
end

function LM.SpawnBuyers()
    for _, ent in ipairs(ents.FindByClass("lean_buyer")) do
        if ent.LM_Persistent then ent:Remove() end
    end

    local data = file.Read(savePath(), "DATA")
    local list = data and util.JSONToTable(data)
    if not list then return end

    for _, info in ipairs(list) do
        local ent = ents.Create("lean_buyer")
        if IsValid(ent) then
            ent:SetPos(info.pos)
            ent:SetAngles(info.ang)
            ent:Spawn()
            ent.LM_Persistent = true
        end
    end
end

hook.Add("InitPostEntity", "LeanMachine.SpawnBuyers", LM.SpawnBuyers)
hook.Add("PostCleanupMap", "LeanMachine.SpawnBuyers", LM.SpawnBuyers)

concommand.Add("leanmachine_savebuyers", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local n = LM.SaveBuyers()
    local msg = string.format("[Lean Machine] Saved %d buyer(s) for %s.", n, game.GetMap())
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end)
