--[[
    Lean Machine - Drink screen effects
]]

local LM = LeanMachine
local C = LM.Config

local startTime, endTime = 0, 0

net.Receive(LM.NET_DRINK, function()
    local duration = net.ReadFloat()
    local now = CurTime()
    if duration <= 0 then
        endTime = 0
        return
    end
    if now >= endTime then startTime = now end -- don't restart the fade-in when topping up
    endTime = now + duration
end)

hook.Add("RenderScreenspaceEffects", "LeanMachine.Drink", function()
    local cfg = C.Cup
    local now = CurTime()
    if not cfg.ScreenEffects or now >= endTime then return end

    local fadeIn = math.Clamp((now - startTime) / 3, 0, 1)
    local fadeOut = math.Clamp((endTime - now) / 4, 0, 1)
    local k = math.min(fadeIn, fadeOut) * (cfg.EffectStrength or 1)
    local wave = (math.sin(now * 1.2) + 1) * 0.5

    DrawColorModify({
        ["$pp_colour_addr"]       = 0.05 * k,
        ["$pp_colour_addg"]       = 0,
        ["$pp_colour_addb"]       = (0.07 + 0.03 * wave) * k,
        ["$pp_colour_brightness"] = -0.02 * k,
        ["$pp_colour_contrast"]   = 1 + 0.08 * k,
        ["$pp_colour_colour"]     = 1 + 0.35 * k,
        ["$pp_colour_mulr"]       = 0.4 * k,
        ["$pp_colour_mulg"]       = 0,
        ["$pp_colour_mulb"]       = 0.7 * k,
    })
    DrawMotionBlur(0.12, (0.6 + 0.2 * wave) * k, 0.01)
end)
