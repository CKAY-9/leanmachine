--[[
    Lean Machine - In-game settings (client)
    Q menu > Utilities > Lean Machine > Settings
]]

local LM = LeanMachine
local C = LM.Config

local REQ_SYNC   = 0
local REQ_UPDATE = 1
local REQ_RESET  = 2

local settingsPanel -- the ControlPanel, once the tab has been opened
local builtAsAdmin

local function request(action, data)
    net.Start(LM.NET_SETTINGS)
    net.WriteUInt(action, 2)
    if data then net.WriteTable(data) end
    net.SendToServer()
end

hook.Add("InitPostEntity", "LeanMachine.Settings", function()
    request(REQ_SYNC)
end)

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------
local function section(parent, title)
    local form = vgui.Create("DForm", parent)
    form:SetName(title)
    parent:AddItem(form)
    return form
end

local function moneyField(form, label, value, onChange)
    local wang = form:NumberWang(label, nil, 0, 1e9, 0)
    wang:SetValue(value)
    wang.OnValueChanged = function(_, v) onChange(math.floor(tonumber(v) or 0)) end
    return wang
end

local function percentSlider(form, label, max, value, onChange)
    local slider = form:NumSlider(label, nil, 0, max, 0)
    slider:SetValue(math.Round(value * 100))
    slider.OnValueChanged = function(_, v) onChange(math.Round(v) / 100) end
    return slider
end

local function build(panel)
    panel:Clear()

    local ply = LocalPlayer()
    builtAsAdmin = IsValid(ply) and ply:IsAdmin()
    if not builtAsAdmin then
        panel:Help("Only server admins can change Lean Machine settings.")
        return
    end

    panel:Help("Changes apply to everyone once you press Save, and persist across restarts.")

    -- Working copy, sent to the server on Save
    local draft = LM.GetSettings()
    local chances = draft.Haggle.Chances
    for i = #chances + 1, LM.MAX_HAGGLE_ATTEMPTS do
        chances[i] = chances[i - 1] or 0.5
    end

    -- DarkRP -----------------------------------------------------------------
    local darkrp = section(panel, "DarkRP")
    local register = darkrp:CheckBox("Sell Lean Machine in the F4 menu")
    register:SetChecked(draft.DarkRPRegister)
    register.OnChange = function(_, v) draft.DarkRPRegister = v end
    darkrp:ControlHelp("Turn off if you add lean_machine yourself in darkrpmodification.")

    -- Prices -----------------------------------------------------------------
    local prices = section(panel, "Prices")
    for _, ing in ipairs(C.Ingredients) do
        local unit = ing.type == "click" and "per click" or "per second"
        moneyField(prices, string.format("%s (%s)", ing.name, unit), draft.Ingredients[ing.id] or 0, function(v)
            draft.Ingredients[ing.id] = v
        end)
    end
    moneyField(prices, "Cup of Lean (sell price)", draft.PricePerCup, function(v)
        draft.PricePerCup = v
    end)

    -- Haggling ---------------------------------------------------------------
    local H = draft.Haggle
    local haggle = section(panel, "Haggling")

    local enabled = haggle:CheckBox("Enable haggling")
    enabled:SetChecked(H.Enabled)
    enabled.OnChange = function(_, v) H.Enabled = v end

    local rows = {}
    local function refreshChanceRows()
        for i, row in ipairs(rows) do
            row:SetVisible(i <= H.MaxAttempts)
        end
        haggle:InvalidateLayout()
        panel:InvalidateLayout()
    end

    local attempts = haggle:NumSlider("Max attempts", nil, 1, LM.MAX_HAGGLE_ATTEMPTS, 0)
    attempts:SetValue(H.MaxAttempts)
    attempts.OnValueChanged = function(_, v)
        local n = math.Clamp(math.Round(v), 1, LM.MAX_HAGGLE_ATTEMPTS)
        if n == H.MaxAttempts then return end
        H.MaxAttempts = n
        refreshChanceRows()
    end

    for i = 1, LM.MAX_HAGGLE_ATTEMPTS do
        local slider = percentSlider(haggle, string.format("Attempt %d chance %%", i), 100, chances[i], function(v)
            chances[i] = v
        end)
        rows[i] = slider:GetParent() -- the DForm row wrapping the slider
    end
    refreshChanceRows()

    percentSlider(haggle, "Bonus per success %", 100, H.BonusPerSuccess, function(v) H.BonusPerSuccess = v end)

    local fails = haggle:NumSlider("Fails before penalty", nil, 1, LM.MAX_HAGGLE_ATTEMPTS, 0)
    fails:SetValue(H.FailsForPenalty)
    fails.OnValueChanged = function(_, v) H.FailsForPenalty = math.Round(v) end

    percentSlider(haggle, "Penalty %", 100, H.Penalty, function(v) H.Penalty = v end)

    -- Actions ----------------------------------------------------------------
    local saveBtn = panel:Button("Save")
    saveBtn.DoClick = function()
        local out = table.Copy(draft)
        for i = #out.Haggle.Chances, out.Haggle.MaxAttempts + 1, -1 do
            out.Haggle.Chances[i] = nil
        end
        request(REQ_UPDATE, out)
    end

    local revertBtn = panel:Button("Discard changes")
    revertBtn.DoClick = function() build(panel) end

    local resetBtn = panel:Button("Reset to config defaults")
    local armed = 0
    resetBtn.DoClick = function()
        if armed < RealTime() then
            armed = RealTime() + 3
            resetBtn:SetText("Click again to confirm reset")
            timer.Simple(3, function()
                if IsValid(resetBtn) then resetBtn:SetText("Reset to config defaults") end
            end)
            return
        end
        armed = 0
        request(REQ_RESET)
    end
end

hook.Add("PopulateToolMenu", "LeanMachine.Settings", function()
    spawnmenu.AddToolMenuOption("Utilities", "Lean Machine", "LeanMachineSettings", "Settings", "", "", function(panel)
        settingsPanel = panel
        build(panel)
    end)
end)

-- Pick up admin status changes (e.g. promoted mid-session) when the menu opens
hook.Add("OnSpawnMenuOpen", "LeanMachine.Settings", function()
    if IsValid(settingsPanel) and LocalPlayer():IsAdmin() ~= builtAsAdmin then
        build(settingsPanel)
    end
end)

--------------------------------------------------------------------------------
-- Sync from server
--------------------------------------------------------------------------------
net.Receive(LM.NET_SETTINGS, function()
    LM.ApplySettings(net.ReadTable())
    LM.SyncDarkRPEntity()
    if IsValid(settingsPanel) then build(settingsPanel) end
end)
