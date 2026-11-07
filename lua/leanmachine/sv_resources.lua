--[[
    Lean Machine - Client content download (see Config.Content)
]]

local LM = LeanMachine
local cfg = LM.Config.Content

local function dirOf(path)
    return string.match(path, "^(.*)/") or ""
end

local function sendFiles()
    local count = 0

    -- resource.AddFile on a .mdl also sends its .vvd / .vtx / .phy
    for _, pattern in ipairs(cfg.Models or {}) do
        local dir = dirOf(pattern)
        for _, name in ipairs(file.Find(pattern, "GAME") or {}) do
            resource.AddFile(dir .. "/" .. name)
            count = count + 1
        end
    end

    -- Every .vmt / .vtf inside each matching material folder
    for _, pattern in ipairs(cfg.Materials or {}) do
        local parent = dirOf(pattern)
        local _, folders = file.Find(pattern, "GAME")
        for _, folder in ipairs(folders or {}) do
            local path = parent .. "/" .. folder .. "/"
            for _, name in ipairs(file.Find(path .. "*", "GAME") or {}) do
                local ext = string.GetExtensionFromFilename(name)
                if ext == "vmt" or ext == "vtf" then
                    resource.AddSingleFile(path .. name)
                    count = count + 1
                end
            end
        end
    end

    return count
end

if not cfg then return end

if cfg.WorkshopID and cfg.WorkshopID ~= "" then
    resource.AddWorkshop(cfg.WorkshopID)
    print("[Lean Machine] Clients will download Workshop addon " .. cfg.WorkshopID)
elseif cfg.SendFiles then
    print("[Lean Machine] Sending " .. sendFiles() .. " content file(s) to clients")
end
