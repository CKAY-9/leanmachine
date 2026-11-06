--[[
    Lean Machine - DarkRP drug production addon
    Loader
]]

LeanMachine = LeanMachine or {}

local function shared(path)
    if SERVER then AddCSLuaFile(path) end
    include(path)
end

local function client(path)
    if SERVER then AddCSLuaFile(path) else include(path) end
end

local function server(path)
    if SERVER then include(path) end
end

shared("leanmachine/sh_config.lua")
shared("leanmachine/sh_core.lua")
server("leanmachine/sv_core.lua")
server("leanmachine/sv_buyer.lua")
client("leanmachine/cl_menu.lua")
client("leanmachine/cl_sell.lua")
client("leanmachine/cl_effects.lua")
