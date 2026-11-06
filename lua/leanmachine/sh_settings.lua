--[[
    Lean Machine - In-game settings (shared)
    The subset of the config that admins can edit live from the Q menu
    (Utilities > Lean Machine > Settings). Overrides are saved to
    data/leanmachine/settings.json and layered on top of sh_config.lua.
]]

local LM = LeanMachine
local C = LM.Config

LM.NET_SETTINGS = "LeanMachine.Settings"
LM.MAX_HAGGLE_ATTEMPTS = 10

-- Snapshot of every editable value
function LM.GetSettings()
    local H = C.Haggle
    local s = {
        PricePerCup = C.Buyer.PricePerCup,
        Ingredients = {},
        Haggle = {
            Enabled         = H.Enabled,
            MaxAttempts     = H.MaxAttempts,
            Chances         = table.Copy(H.Chances),
            BonusPerSuccess = H.BonusPerSuccess,
            FailsForPenalty = H.FailsForPenalty,
            Penalty         = H.Penalty,
        },
    }
    for _, ing in ipairs(C.Ingredients) do
        s.Ingredients[ing.id] = ing.price or 0
    end
    return s
end

local function num(v, fallback, min, max, int)
    v = tonumber(v)
    if not v or v ~= v then return fallback end -- nil / NaN
    if int then v = math.floor(v) end
    return math.Clamp(v, min, max)
end

-- Validates `s` and writes it into LM.Config. Missing keys keep their current value.
function LM.ApplySettings(s)
    if not istable(s) then return end

    C.Buyer.PricePerCup = num(s.PricePerCup, C.Buyer.PricePerCup, 0, 1e9, true)

    if istable(s.Ingredients) then
        for _, ing in ipairs(C.Ingredients) do
            ing.price = num(s.Ingredients[ing.id], ing.price or 0, 0, 1e9, true)
        end
    end

    local H, h = C.Haggle, s.Haggle
    if istable(h) then
        if h.Enabled ~= nil then H.Enabled = tobool(h.Enabled) end
        H.MaxAttempts     = num(h.MaxAttempts, H.MaxAttempts, 1, LM.MAX_HAGGLE_ATTEMPTS, true)
        H.BonusPerSuccess = num(h.BonusPerSuccess, H.BonusPerSuccess, 0, 10)
        H.FailsForPenalty = num(h.FailsForPenalty, H.FailsForPenalty, 1, LM.MAX_HAGGLE_ATTEMPTS, true)
        H.Penalty         = num(h.Penalty, H.Penalty, 0, 1)

        if istable(h.Chances) then
            local chances = {}
            for i = 1, H.MaxAttempts do
                local fallback = H.Chances[i] or H.Chances[#H.Chances] or 0.5
                chances[i] = num(h.Chances[i], fallback, 0, 1)
            end
            H.Chances = chances
        end
    end
end

-- Values from sh_config.lua, before any saved overrides are applied
LM.SettingsDefaults = LM.GetSettings()
