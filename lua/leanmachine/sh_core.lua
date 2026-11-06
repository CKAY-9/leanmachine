--[[
    Lean Machine - Shared core
]]

local LM = LeanMachine

LM.NET_OPEN   = "LeanMachine.Open"
LM.NET_CLOSE  = "LeanMachine.Close"
LM.NET_ACTION = "LeanMachine.Action"
LM.NET_DRINK  = "LeanMachine.Drink"
LM.NET_BUYER  = "LeanMachine.Buyer"
LM.NET_SELL   = "LeanMachine.Sell"
LM.NET_HAGGLE = "LeanMachine.Haggle"

LM.HAGGLE_SUCCESS = 1
LM.HAGGLE_FAIL    = 2
LM.HAGGLE_PENALTY = 3
LM.HAGGLE_KEYS    = { "Success", "Fail", "Penalty" }

LM.ACT_CLICK       = 1
LM.ACT_HOLD_BEGIN  = 2
LM.ACT_HOLD_CANCEL = 3
LM.ACT_HOLD_END    = 4
LM.ACT_MIX_BEGIN   = 5
LM.ACT_MIX_END     = 6
LM.ACT_CLOSE       = 7
LM.ACT_BITS        = 4

-- Progress value needed for an ingredient to count as added
function LM.Required(ing)
    if ing.type == "click" then
        return math.max(1, math.floor(ing.clicks or 1))
    end
    return 1
end

function LM.ProgressKey(idx)
    return "LM_ing_" .. idx
end

function LM.GetProgress(ent, idx)
    return ent:GetNWInt(LM.ProgressKey(idx), 0)
end

function LM.IsIngredientDone(ent, idx)
    local ing = LM.Config.Ingredients[idx]
    return ing ~= nil and LM.GetProgress(ent, idx) >= LM.Required(ing)
end

function LM.CountDone(ent)
    local n = 0
    for i = 1, #LM.Config.Ingredients do
        if LM.IsIngredientDone(ent, i) then n = n + 1 end
    end
    return n
end

function LM.AllDone(ent)
    return LM.CountDone(ent) >= #LM.Config.Ingredients
end

--------------------------------------------------------------------------------
-- Money
--------------------------------------------------------------------------------
function LM.FormatMoney(n)
    return DarkRP.formatMoney(n)
end

-- Cost of a single action: one click, or one full hold
function LM.ActionCost(ing)
    local price = ing.price or 0
    if ing.type == "click" then return price end
    return price * (ing.seconds or 1)
end

-- Cost of a full batch (every ingredient from scratch)
function LM.BatchCost()
    local total = 0
    for _, ing in ipairs(LM.Config.Ingredients) do
        total = total + LM.ActionCost(ing) * LM.Required(ing)
    end
    return total
end

--------------------------------------------------------------------------------
-- Stored cups & selling
--------------------------------------------------------------------------------
function LM.GetCups(ply)
    return ply:GetNWInt("LM_Cups", 0)
end

-- Returns false + reason if the player's job may not sell
function LM.CanSell(ply)
    local cfg = LM.Config.Buyer
    if not cfg.AllowPolice and ply:isCP() then
        return false, "The buyer won't deal with the police."
    end
    for _, job in ipairs(cfg.BlockedJobs or {}) do
        local team = isnumber(job) and job or _G[job]
        if team and ply:Team() == team then
            return false, "The buyer won't deal with your job."
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- Haggling
--------------------------------------------------------------------------------
-- attempts used, successes, fails
function LM.GetHaggle(ply)
    return ply:GetNWInt("LM_HagA", 0), ply:GetNWInt("LM_HagS", 0), ply:GetNWInt("LM_HagF", 0)
end

function LM.IsPenalised(ply)
    local _, _, fails = LM.GetHaggle(ply)
    return fails >= LM.Config.Haggle.FailsForPenalty
end

-- Multiplier applied to the player's next sale
function LM.SaleMultiplier(ply)
    local H = LM.Config.Haggle
    if not H.Enabled then return 1 end
    if LM.IsPenalised(ply) then return 1 - H.Penalty end
    local _, successes = LM.GetHaggle(ply)
    return 1 + successes * H.BonusPerSuccess
end

-- Price per cup for this player's next sale
function LM.CupPrice(ply)
    return math.floor(LM.Config.Buyer.PricePerCup * LM.SaleMultiplier(ply))
end

-- Success chance of the player's next haggle attempt
function LM.HaggleChance(ply)
    local H = LM.Config.Haggle
    local attempts = LM.GetHaggle(ply)
    return H.Chances[attempts + 1] or H.Chances[#H.Chances] or 0
end

-- Returns false + reason if the player can't haggle right now
function LM.CanHaggle(ply)
    local H = LM.Config.Haggle
    if not H.Enabled then return false, "This buyer doesn't haggle." end
    if LM.IsPenalised(ply) then return false, "The buyer is done negotiating." end
    local attempts = LM.GetHaggle(ply)
    if attempts >= H.MaxAttempts then return false, "You're out of haggles. Sell to reset." end
    if LM.GetCups(ply) <= 0 then return false, "You need lean on you to haggle." end
    return true
end

--------------------------------------------------------------------------------
-- DarkRP entity registration
--------------------------------------------------------------------------------
local function registerDarkRP()
    local cfg = LM.Config.DarkRP
    if not cfg.Register or LM._registered then return end
    LM._registered = true

    local allowed
    if cfg.AllowedJobs and #cfg.AllowedJobs > 0 then
        allowed = {}
        for _, job in ipairs(cfg.AllowedJobs) do
            local team = isnumber(job) and job or _G[job]
            if team then
                allowed[#allowed + 1] = team
            else
                ErrorNoHalt("[Lean Machine] Unknown job in AllowedJobs: " .. tostring(job) .. "\n")
            end
        end
    end

    DarkRP.createEntity(cfg.Name, {
        ent      = "lean_barrel",
        model    = LM.Config.Barrel.Model,
        price    = cfg.Price,
        max      = cfg.Max,
        cmd      = cfg.Command,
        category = cfg.Category,
        allowed  = allowed,
    })
end

hook.Add("loadCustomDarkRPItems", "LeanMachine.Register", registerDarkRP)
