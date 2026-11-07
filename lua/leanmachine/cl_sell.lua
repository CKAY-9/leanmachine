--[[
    Lean Machine - Buyer sell & haggle menu
]]

local LM = LeanMachine
local C = LM.Config
local T = C.Theme
local UI = LM.UI
local S = UI.S

local REVEAL_DELAY = 0.9   -- Suspense before showing a haggle result
local TYPE_SPEED = 45      -- Characters per second for the buyer's dialogue

local function cupIcon(x, y, w, h, col)
    local bw = w * 0.36
    draw.NoTexture()
    surface.SetDrawColor(col)
    surface.DrawPoly({
        { x = x,              y = y },
        { x = x + w,          y = y },
        { x = x + w / 2 + bw, y = y + h },
        { x = x + w / 2 - bw, y = y + h },
    })
end

local function wrap(text, font, maxW)
    surface.SetFont(font)
    local lines, cur = {}, ""
    for word in string.gmatch(text, "%S+") do
        local test = cur == "" and word or (cur .. " " .. word)
        if cur ~= "" and surface.GetTextSize(test) > maxW then
            lines[#lines + 1] = cur
            cur = word
        else
            cur = test
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    return lines
end

local function pick(key)
    local list = C.Haggle.Lines[key] or {}
    return list[math.random(math.max(#list, 1))] or ""
end

local function pct(mult)
    return string.format("%s%d%%", mult >= 1 and "+" or "", math.Round((mult - 1) * 100))
end

--------------------------------------------------------------------------------
-- Sell view
--------------------------------------------------------------------------------
local SELL = {}

function SELL:Setup(ent, frame)
    self.ent = ent
    self.frame = frame
    self.shown = 0
    self.flash = 0
    self.flashCol = T.Accent

    local ply = LocalPlayer()
    local attempts = LM.GetHaggle(ply)
    if LM.IsPenalised(ply) then
        self:SetLine(pick("Burned"), T.Error)
    elseif attempts > 0 then
        self:SetLine(pick("Return"), T.Text)
    else
        self:SetLine(pick("Greeting"), T.Text)
    end

    -- Buyer portrait
    local portrait = vgui.Create("Panel", self)
    portrait.Paint = function(_, w, h)
        draw.RoundedBox(S(12), 0, 0, w, h, UI.LerpColor(self.flash, T.Border, self.flashCol))
        draw.RoundedBox(S(11), 1, 1, w - 2, h - 2, T.Panel)
    end
    self.portrait = portrait

    local mdl = vgui.Create("DModelPanel", portrait)
    mdl:Dock(FILL)
    mdl:DockMargin(1, 1, 1, 1)
    mdl:SetModel(C.Buyer.Model)
    mdl:SetFOV(26)
    mdl:SetCamPos(Vector(34, 6, 65))
    mdl:SetLookAt(Vector(0, 0, 63))
    mdl:SetMouseInputEnabled(false)
    if IsValid(mdl.Entity) then
        local seq = mdl.Entity:LookupSequence(C.Buyer.Sequence or "")
        if seq and seq >= 0 then mdl.Entity:ResetSequence(seq) end
    end
    mdl.LayoutEntity = function(pnl) pnl:RunAnimation() end

    -- Buttons
    local row = vgui.Create("Panel", self)
    row:Dock(BOTTOM)
    row:SetTall(S(48))
    row.PerformLayout = function(_, w)
        local gap = S(12)
        local hw = math.floor((w - gap) / 2)
        self.haggleBtn:SetSize(hw, row:GetTall())
        self.haggleBtn:SetPos(0, 0)
        self.sellBtn:SetSize(w - hw - gap, row:GetTall())
        self.sellBtn:SetPos(hw + gap, 0)
    end

    self.haggleBtn = vgui.Create("LeanMachine.Button", row)
    self.haggleBtn.secondary = true
    self.haggleBtn.DoClick = function()
        if self.pending then return end
        net.Start(LM.NET_HAGGLE)
            net.WriteEntity(ent)
        net.SendToServer()
        UI.PlaySound(C.Sounds.Click)
        self.pending = RealTime()
        self.lastHaggle = RealTime()
        self.result = nil
    end

    self.sellBtn = vgui.Create("LeanMachine.Button", row)
    self.sellBtn.DoClick = function()
        net.Start(LM.NET_SELL)
            net.WriteEntity(ent)
        net.SendToServer()
        UI.PlaySound(C.Sounds.Pour)
        frame:Close()
    end
end

function SELL:SetLine(text, col)
    self.line = text
    self.lineCol = col or T.Text
    self.lineStart = RealTime()
    self.lineWrapped = nil
end

function SELL:OnHaggleResult(outcome, lineIdx)
    self.result = { outcome = outcome, line = lineIdx }
end

function SELL:RevealResult()
    local res = self.result
    self.pending, self.result = nil, nil

    local key = LM.HAGGLE_KEYS[res.outcome] or "Fail"
    local lines = C.Haggle.Lines[key] or {}
    local text = lines[res.line] or pick(key)

    if res.outcome == LM.HAGGLE_SUCCESS then
        self:SetLine(text, T.LeanLight)
        self.flashCol = T.Accent
        UI.PlaySound(C.Sounds.HaggleWin)
    else
        self:SetLine(text, T.Error)
        self.flashCol = T.Error
        UI.PlaySound(C.Sounds.HaggleFail)
    end
    self.flash = 1
end

function SELL:PerformLayout(w, h)
    if not IsValid(self.portrait) then return end
    self.portrait:SetPos(0, 0)
    self.portrait:SetSize(S(76), S(76))
end

function SELL:Think()
    local ply = LocalPlayer()
    local cups = LM.GetCups(ply)
    local okSell = LM.CanSell(ply)
    local ft = FrameTime()

    -- Resolve a pending haggle once the suspense delay has passed
    if self.pending then
        if self.result and RealTime() - self.pending >= REVEAL_DELAY then
            self:RevealResult()
        elseif RealTime() - self.pending > 3 then
            self.pending = nil -- server rejected it (it will have sent a notification)
        end
    end

    self.flash = math.Approach(self.flash, 0, ft * 1.2)

    -- Sell button
    local canSell = okSell and cups > 0 and not self.pending
    if self.sellBtn:IsEnabled() ~= canSell then self.sellBtn:SetEnabled(canSell) end
    self.sellBtn:SetLabel((okSell and cups > 0) and ("Sell for " .. LM.FormatMoney(cups * LM.CupPrice(ply))) or "Nothing to sell")

    -- Haggle button
    local canHaggle = okSell and LM.CanHaggle(ply)
    -- Match the server's cooldown so a quick re-click isn't silently dropped
    local cooling = self.lastHaggle and RealTime() - self.lastHaggle < (C.Haggle.Cooldown or 1)
    local enabled = canHaggle and not self.pending and not cooling
    if self.haggleBtn:IsEnabled() ~= enabled then self.haggleBtn:SetEnabled(enabled) end
    if self.pending then
        self.haggleBtn:SetLabel("Haggling" .. string.rep(".", math.floor(RealTime() * 3) % 4))
    elseif canHaggle then
        self.haggleBtn:SetLabel(string.format("Haggle  \194\183  %d%%", math.Round(LM.HaggleChance(ply) * 100)))
    elseif not C.Haggle.Enabled then
        self.haggleBtn:SetLabel("No haggling")
    else
        self.haggleBtn:SetLabel("Can't haggle")
    end

    -- Payout counts toward its current value
    local target = cups * LM.CupPrice(ply)
    self.shown = math.Approach(self.shown, target, math.max(math.abs(target - self.shown), 1) * ft * 5 + 1)
end

function SELL:PaintBubble(x, y, w, h)
    local r = S(12)
    local border = UI.LerpColor(self.flash, T.Border, self.flashCol)
    UI.Glow(x, y, w, h, r, self.flashCol, self.flash * 0.8)
    draw.RoundedBox(r, x, y, w, h, border)
    draw.RoundedBox(r - 1, x + 1, y + 1, w - 2, h - 2, T.Panel)

    -- Speech tail pointing at the portrait
    draw.NoTexture()
    local ty = y + S(26)
    surface.SetDrawColor(border)
    surface.DrawPoly({ { x = x - S(8), y = ty }, { x = x + 1, y = ty - S(7) }, { x = x + 1, y = ty + S(7) } })
    surface.SetDrawColor(T.Panel)
    surface.DrawPoly({ { x = x - S(6), y = ty }, { x = x + 2, y = ty - S(6) }, { x = x + 2, y = ty + S(6) } })

    local pad = S(14)
    draw.SimpleText("LEAN BUYER", "LM.Tag", x + pad, y + pad, T.TextDim)

    local ty2 = y + pad + S(18)
    if self.pending then
        local dots = string.rep(". ", math.floor(RealTime() * 4) % 4 + 1)
        draw.SimpleText(dots, "LM.Card", x + pad, ty2 - S(4), T.TextDim)
        return
    end

    self.lineWrapped = self.lineWrapped or wrap(self.line or "", "LM.Sub", w - pad * 2)
    local remaining = math.floor((RealTime() - self.lineStart) * TYPE_SPEED)
    for _, line in ipairs(self.lineWrapped) do
        if remaining <= 0 then break end
        draw.SimpleText(line:sub(1, remaining), "LM.Sub", x + pad, ty2, self.lineCol)
        remaining = remaining - #line - 1
        ty2 = ty2 + S(18)
    end
end

function SELL:PaintHaggle(x, y, w, h)
    local H = C.Haggle
    local ply = LocalPlayer()
    local attempts, successes, fails = LM.GetHaggle(ply)
    local history = ply:GetNWString("LM_HagH", "")
    local penalised = LM.IsPenalised(ply)
    local r = S(12)
    local pad = S(16)

    draw.RoundedBox(r, x, y, w, h, penalised and UI.Alpha(T.Error, 120) or T.Border)
    draw.RoundedBox(r - 1, x + 1, y + 1, w - 2, h - 2, T.Panel)

    draw.SimpleText("HAGGLE", "LM.Tag", x + pad, y + pad, T.TextDim)
    local left = math.max(H.MaxAttempts - attempts, 0)
    draw.SimpleText(penalised and "LOCKED" or (left .. " LEFT"), "LM.Tag", x + w - pad, y + pad, penalised and T.Error or T.TextDim, TEXT_ALIGN_RIGHT)

    -- Attempt pips: purple = won, red = failed, grey = unused
    local pw, ph, gap = math.floor((w - pad * 2 - S(8) * (H.MaxAttempts - 1)) / H.MaxAttempts), S(6), S(8)
    local py = y + pad + S(22)
    for i = 1, H.MaxAttempts do
        local c = history:sub(i, i)
        local col = (c == "S" and T.Accent) or (c == "F" and T.Error) or T.Border
        draw.RoundedBox(ph / 2, x + pad + (i - 1) * (pw + gap), py, pw, ph, col)
    end

    local text, col
    if not H.Enabled then
        text, col = "This buyer doesn't haggle.", T.TextDim
    elseif penalised then
        text, col = string.format("He's had enough. %s on your next sale.", pct(LM.SaleMultiplier(ply))), T.Error
    elseif fails > 0 and fails == H.FailsForPenalty - 1 then
        text, col = "He's annoyed. Miss again and he'll lowball you.", T.Error
    elseif successes > 0 then
        text, col = string.format("%s locked in for your next sale.", pct(LM.SaleMultiplier(ply))), T.LeanLight
    else
        text, col = string.format("Push for %s per cup.", pct(1 + H.BonusPerSuccess)), T.TextDim
    end
    draw.SimpleText(text, "LM.Small", x + pad, py + S(16), col)
end

function SELL:Paint(w, h)
    if not IsValid(self.haggleBtn) then return end
    local ply = LocalPlayer()
    local cups = LM.GetCups(ply)
    local max = C.Storage.MaxCups
    local base = C.Buyer.PricePerCup
    local mult = LM.SaleMultiplier(ply)
    local ok, reason = LM.CanSell(ply)
    local r = S(12)
    local pad = S(20)

    -- Dialogue
    local bx = S(76) + S(16)
    self:PaintBubble(bx, 0, w - bx, S(76))

    -- Haggle panel sits just above the buttons
    local btnTop = h - self.haggleBtn:GetTall() - S(16)
    local hgH = S(86)
    local hgY = btnTop - hgH
    self:PaintHaggle(0, hgY, w, hgH)

    -- Main card
    local cy = S(76) + S(14)
    local ch = hgY - S(14) - cy
    draw.RoundedBox(r, 0, cy, w, ch, T.Border)
    draw.RoundedBox(r - 1, 1, cy + 1, w - 2, ch - 2, T.Panel)

    local y = cy + pad
    draw.SimpleText("STORED CUPS", "LM.Tag", pad, y, T.TextDim)
    draw.SimpleText(cups, "LM.Huge", pad, y + S(10), T.Text)
    surface.SetFont("LM.Huge")
    local nw = surface.GetTextSize(tostring(cups))
    draw.SimpleText("/ " .. max, "LM.Card", pad + nw + S(8), y + S(30), T.TextDim)

    -- Cup icons
    local iw, ih, gap = S(14), S(18), S(6)
    local perRow = math.max(1, math.floor((w - pad * 2 + gap) / (iw + gap)))
    local iy = y + S(70)
    for i = 1, max do
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        cupIcon(pad + col * (iw + gap), iy + row * (ih + gap), iw, ih, i <= cups and T.Accent or T.Border)
    end
    y = iy + math.ceil(max / perRow) * (ih + gap) + S(10)

    -- Breakdown
    local function row(label, value, col)
        draw.SimpleText(label, "LM.Small", pad, y, T.TextDim)
        draw.SimpleText(value, "LM.Small", w - pad, y, col or T.Text, TEXT_ALIGN_RIGHT)
        y = y + S(22)
    end
    row("Base price", LM.FormatMoney(base))
    if mult ~= 1 then
        row("Haggled", pct(mult), mult > 1 and T.LeanLight or T.Error)
        row("Your price", LM.FormatMoney(LM.CupPrice(ply)), mult > 1 and T.LeanLight or T.Error)
    end
    row("Cups", string.format("\195\151 %d", cups))
    y = y + S(4)

    surface.SetDrawColor(T.Border)
    surface.DrawRect(pad, y, w - pad * 2, 1)
    y = y + S(12)

    draw.SimpleText("Total payout", "LM.Card", pad, y, T.Text)
    draw.SimpleText(LM.FormatMoney(math.Round(self.shown)), "LM.Card", w - pad, y, T.LeanLight, TEXT_ALIGN_RIGHT)

    -- Footer hint
    local hint, hintCol
    if not ok then
        hint, hintCol = reason, T.Error
    elseif cups == 0 then
        hint, hintCol = "Crouch and press E on a cup to store it.", T.TextDim
    end
    if hint then
        draw.SimpleText(hint, "LM.Small", w / 2, cy + ch - S(14), hintCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end
end

vgui.Register("LeanMachine.Sell", SELL, "Panel")

--------------------------------------------------------------------------------
-- Opening & networking
--------------------------------------------------------------------------------
function LM.OpenSellMenu(ent)
    if IsValid(LM.Menu) then LM.Menu:Remove() end
    UI.PlaySound(C.Sounds.Open)

    local frame = vgui.Create("LeanMachine.Frame")
    frame:SetFrameSize(S(480), S(720))
    frame.title = "LEAN BUYER"
    frame.ent = ent
    frame.maxDist = C.Buyer.MaxDistance
    frame:SetView("LeanMachine.Sell", "Haggle for a better price, or sell straight up.")
    LM.Menu = frame
end

net.Receive(LM.NET_BUYER, function()
    local ent = net.ReadEntity()
    if IsValid(ent) then LM.OpenSellMenu(ent) end
end)

net.Receive(LM.NET_HAGGLE, function()
    local outcome = net.ReadUInt(2)
    local line = net.ReadUInt(8)
    local menu = LM.Menu
    if IsValid(menu) and IsValid(menu.view) and menu.view.OnHaggleResult then
        menu.view:OnHaggleResult(outcome, line)
    end
end)
