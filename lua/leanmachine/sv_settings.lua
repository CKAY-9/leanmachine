--[[
    Lean Machine - In-game settings (server)
]]

local LM = LeanMachine

util.AddNetworkString(LM.NET_SETTINGS)

local SAVE_PATH = "leanmachine/settings.json"

-- Client -> server actions
local REQ_SYNC   = 0
local REQ_UPDATE = 1
local REQ_RESET  = 2

local function canEdit(ply)
    return IsValid(ply) and ply:IsAdmin() -- true for superadmins too
end

local function load()
    local data = file.Read(SAVE_PATH, "DATA")
    local s = data and util.JSONToTable(data)
    if s then LM.ApplySettings(s) end
end

local function save()
    file.CreateDir("leanmachine")
    file.Write(SAVE_PATH, util.TableToJSON(LM.GetSettings(), true))
end

local function send(target)
    net.Start(LM.NET_SETTINGS)
    net.WriteTable(LM.GetSettings())
    if target then net.Send(target) else net.Broadcast() end
end

local function notify(ply, msg, isError)
    if DarkRP and DarkRP.notify then
        DarkRP.notify(ply, isError and 1 or 0, 4, msg)
    else
        ply:ChatPrint(msg)
    end
end

net.Receive(LM.NET_SETTINGS, function(len, ply)
    if (ply.LM_NextSettings or 0) > CurTime() then return end
    ply.LM_NextSettings = CurTime() + 0.5

    local action = net.ReadUInt(2)

    if action == REQ_SYNC then
        send(ply)
        return
    end

    if not canEdit(ply) then
        notify(ply, "Only admins can change Lean Machine settings.", true)
        return
    end

    local wasRegistered = LM.Config.DarkRP.Register

    if action == REQ_UPDATE then
        if len > 64 * 1024 then return end
        LM.ApplySettings(net.ReadTable())
    elseif action == REQ_RESET then
        LM.ApplySettings(table.Copy(LM.SettingsDefaults))
    else
        return
    end

    save()
    send()
    notify(ply, action == REQ_RESET and "Lean Machine settings reset to defaults." or "Lean Machine settings saved.")

    if LM.Config.DarkRP.Register ~= wasRegistered and not LM.SyncDarkRPEntity() then
        local msg = "The Lean Machine F4 entry couldn't be " .. (LM.Config.DarkRP.Register and "added" or "removed")
            .. " live. Change the map or restart the server to apply it."
        notify(ply, msg, true)
        ply:ChatPrint("[Lean Machine] " .. msg)
    end
    ServerLog(string.format("[Lean Machine] %s (%s) %s settings\n", ply:Nick(), ply:SteamID(),
        action == REQ_RESET and "reset" or "updated"))
end)

load()
