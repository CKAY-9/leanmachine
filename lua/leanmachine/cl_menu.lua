--[[
    Lean Machine - Client GUI
]]

local LM = LeanMachine
local C = LM.Config
local T = C.Theme

LM.UI = LM.UI or {}
local UI = LM.UI

--------------------------------------------------------------------------------
-- Scaling & fonts
--------------------------------------------------------------------------------
function UI.Scale()
    return math.Clamp(ScrH() / 1080, 0.65, 2)
end

local function S(v)
    return math.max(1, math.Round(v * UI.Scale()))
end
UI.S = S

local function createFonts()
    local font = T.Font
    surface.CreateFont("LM.Title",    { font = font, size = S(26), weight = 700, extended = true })
    surface.CreateFont("LM.Sub",      { font = font, size = S(15), weight = 400, extended = true })
    surface.CreateFont("LM.Card",     { font = font, size = S(22), weight = 600, extended = true })
    surface.CreateFont("LM.Small",    { font = font, size = S(14), weight = 500, extended = true })
    surface.CreateFont("LM.Tag",      { font = font, size = S(12), weight = 700, extended = true })
    surface.CreateFont("LM.Button",   { font = font, size = S(17), weight = 700, extended = true })
    surface.CreateFont("LM.Huge",     { font = font, size = S(46), weight = 800, extended = true })
    surface.CreateFont("LM.3D2D",     { font = font, size = 64, weight = 700, extended = true })
    surface.CreateFont("LM.3D2DSub",  { font = font, size = 38, weight = 500, extended = true })
    surface.CreateFont("LM.Glow",     { font = font, size = 84, weight = 800, extended = true })
    surface.CreateFont("LM.GlowBlur", { font = font, size = 84, weight = 800, extended = true, blursize = 12 })
    surface.CreateFont("LM.GlowSub",  { font = font, size = 36, weight = 500, extended = true })
end
createFonts()
hook.Add("OnScreenSizeChanged", "LeanMachine.Fonts", createFonts)

--------------------------------------------------------------------------------
-- Drawing helpers
--------------------------------------------------------------------------------
local gradR = Material("vgui/gradient-r")
local gradU = Material("vgui/gradient-u")

function UI.Alpha(col, a)
    return Color(col.r, col.g, col.b, a)
end

function UI.LerpColor(t, a, b)
    return Color(Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b), Lerp(t, a.a or 255, b.a or 255))
end

function UI.PlaySound(snd)
    if istable(snd) then snd = snd[math.random(#snd)] end
    if snd and snd ~= "" then surface.PlaySound(snd) end
end

-- Clockwise polygon for a rounded rectangle (used as an exact stencil mask)
local polyCache, polyCacheSize = {}, 0
function UI.RoundedPoly(x, y, w, h, r, seg)
    seg = seg or 6
    local key = x .. ":" .. y .. ":" .. w .. ":" .. h .. ":" .. r
    if polyCache[key] then return polyCache[key] end

    r = math.min(r, w / 2, h / 2)
    local pts = {}
    local corners = {
        { x + w - r, y + r,     -90,   0 },
        { x + w - r, y + h - r,   0,  90 },
        { x + r,     y + h - r,  90, 180 },
        { x + r,     y + r,     180, 270 },
    }
    for _, c in ipairs(corners) do
        for i = 0, seg do
            local a = math.rad(c[3] + (c[4] - c[3]) * i / seg)
            pts[#pts + 1] = { x = c[1] + math.cos(a) * r, y = c[2] + math.sin(a) * r }
        end
    end

    if polyCacheSize > 512 then polyCache, polyCacheSize = {}, 0 end
    polyCache[key] = pts
    polyCacheSize = polyCacheSize + 1
    return pts
end

-- Runs drawFn with drawing clipped to the given polygon
function UI.MaskPoly(poly, drawFn)
    render.ClearStencil()
    render.SetStencilEnable(true)
    render.SetStencilWriteMask(0xFF)
    render.SetStencilTestMask(0xFF)
    render.SetStencilReferenceValue(1)
    render.SetStencilCompareFunction(STENCIL_ALWAYS)
    render.SetStencilPassOperation(STENCIL_REPLACE)
    render.SetStencilFailOperation(STENCIL_KEEP)
    render.SetStencilZFailOperation(STENCIL_KEEP)

    render.OverrideColorWriteEnable(true, false)
    draw.NoTexture()
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawPoly(poly)
    render.OverrideColorWriteEnable(false)

    render.SetStencilCompareFunction(STENCIL_EQUAL)
    render.SetStencilPassOperation(STENCIL_KEEP)
    drawFn()
    render.SetStencilEnable(false)
end

function UI.Masked(x, y, w, h, r, drawFn)
    UI.MaskPoly(UI.RoundedPoly(x, y, w, h, r), drawFn)
end

-- Soft outer glow around a rounded rect (draws outside the panel bounds)
function UI.Glow(x, y, w, h, r, col, strength, layers)
    if strength <= 0.01 then return end
    layers = layers or 6
    local old = DisableClipping(true)
    for i = layers, 1, -1 do
        local spread = S(i * 2)
        local a = 70 * strength * (1 - (i - 1) / layers) / layers * 2
        draw.RoundedBox(r + spread, x - spread, y - spread, w + spread * 2, h + spread * 2, UI.Alpha(col, a))
    end
    DisableClipping(old)
end

-- Horizontal two-colour gradient (colA on the left -> colB on the right)
function UI.HGradient(x, y, w, h, colA, colB)
    surface.SetDrawColor(colA)
    surface.DrawRect(x, y, w, h)
    surface.SetMaterial(gradR)
    surface.SetDrawColor(colB)
    surface.DrawTexturedRect(x, y, w, h)
end

function UI.Circle(x, y, radius, col)
    draw.RoundedBox(radius, x - radius, y - radius, radius * 2, radius * 2, col)
end

-- Floating 3D2D label above an entity
function UI.DrawWorldLabel(ent, title, sub, height, maxDist)
    local pos = ent:WorldSpaceCenter() + Vector(0, 0, height)
    local dist = EyePos():Distance(pos)
    if dist > maxDist then return end

    local alpha = 1 - math.Clamp((dist - maxDist * 0.6) / (maxDist * 0.4), 0, 1)
    local ang = Angle(0, EyeAngles().y - 90, 90)

    cam.Start3D2D(pos, ang, 0.05)
        surface.SetFont("LM.3D2D")
        local tw, th = surface.GetTextSize(title)
        local sw, sh = 0, 0
        if sub then
            surface.SetFont("LM.3D2DSub")
            sw, sh = surface.GetTextSize(sub)
        end

        local pad = 36
        local w = math.max(tw, sw) + pad * 2
        local h = th + (sub and sh + 6 or 0) + pad * 1.4
        local x, y = -w / 2, -h

        for i = 4, 1, -1 do
            local s = i * 5
            draw.RoundedBox(18 + s, x - s, y - s, w + s * 2, h + s * 2, UI.Alpha(T.Accent, 10 * alpha))
        end
        draw.RoundedBox(18, x, y, w, h, UI.Alpha(T.Border, 240 * alpha))
        draw.RoundedBox(16, x + 3, y + 3, w - 6, h - 6, UI.Alpha(T.Background, 245 * alpha))
        surface.SetDrawColor(T.Accent.r, T.Accent.g, T.Accent.b, 255 * alpha)
        surface.DrawRect(x + w * 0.3, y + h - 7, w * 0.4, 3)

        local ty = y + pad * 0.7
        draw.SimpleText(title, "LM.3D2D", 0, ty, UI.Alpha(T.Text, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        if sub then
            draw.SimpleText(sub, "LM.3D2DSub", 0, ty + th + 6, UI.Alpha(T.TextDim, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    cam.End3D2D()
end

-- Floating 3D2D name with a soft purple glow behind it (used by the buyer)
function UI.DrawGlowLabel(pos, title, sub, maxDist)
    local dist = EyePos():Distance(pos)
    if dist > maxDist then return end

    local alpha = 1 - math.Clamp((dist - maxDist * 0.6) / (maxDist * 0.4), 0, 1)
    local pulse = 0.75 + 0.25 * math.sin(RealTime() * 2)
    local ang = Angle(0, EyeAngles().y - 90, 90)

    cam.Start3D2D(pos, ang, 0.05)
        for _ = 1, 2 do
            draw.SimpleText(title, "LM.GlowBlur", 0, 0, UI.Alpha(T.Accent, 255 * alpha * pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end
        draw.SimpleText(title, "LM.Glow", 0, 0, UI.Alpha(T.Text, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        if sub then
            draw.SimpleText(sub, "LM.GlowSub", 0, 8, UI.Alpha(T.LeanLight, 220 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    cam.End3D2D()
end

-- Error feedback when the player can't afford something
function UI.Deny(msg)
    UI.PlaySound(C.Sounds.Deny)
    notification.AddLegacy(msg, NOTIFY_ERROR, 3)
end

function LM.SendAction(ent, act, idx)
    if not IsValid(ent) then return end
    net.Start(LM.NET_ACTION)
        net.WriteEntity(ent)
        net.WriteUInt(act, LM.ACT_BITS)
        net.WriteUInt(idx or 0, 8)
    net.SendToServer()
end

--------------------------------------------------------------------------------
-- Button
--------------------------------------------------------------------------------
local BUTTON = {}

function BUTTON:Init()
    self:SetText("")
    self.label = ""
    self.hov = 0
    self.en = 0
end

function BUTTON:SetLabel(text) self.label = text end

function BUTTON:Paint(w, h)
    local ft = FrameTime()
    local enabled = self:IsEnabled()
    self.hov = Lerp(ft * 12, self.hov, (enabled and self:IsHovered()) and 1 or 0)
    self.en = Lerp(ft * 8, self.en, enabled and 1 or 0)

    local r = S(10)
    local pulse = (math.sin(RealTime() * 3) + 1) * 0.5
    local glow = self.secondary and (0.35 * self.hov) or (0.45 + 0.4 * self.hov + 0.15 * pulse)
    UI.Glow(0, 0, w, h, r, T.Accent, self.en * glow)

    -- Secondary buttons are outlined instead of filled
    if self.secondary then
        draw.RoundedBox(r, 0, 0, w, h, UI.LerpColor(self.en * (0.5 + 0.5 * self.hov), T.Border, T.Accent))
        draw.RoundedBox(r - 1, 1, 1, w - 2, h - 2, UI.LerpColor(self.hov, T.Panel, T.PanelHover))
        draw.SimpleText(self.label, "LM.Button", w / 2, h / 2, UI.LerpColor(self.en, T.TextDim, T.Text), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    draw.RoundedBox(r, 0, 0, w, h, T.Border)
    draw.RoundedBox(r - 1, 1, 1, w - 2, h - 2, T.Panel)

    if self.en > 0.01 then
        UI.Masked(0, 0, w, h, r, function()
            UI.HGradient(0, 0, w, h, UI.Alpha(T.AccentDark, 255 * self.en), UI.Alpha(T.Accent, 255 * self.en))
            surface.SetDrawColor(255, 255, 255, 18 * self.hov)
            surface.DrawRect(0, 0, w, h)
        end)
    end

    draw.SimpleText(self.label, "LM.Button", w / 2, h / 2, UI.LerpColor(self.en, T.TextDim, color_white), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("LeanMachine.Button", BUTTON, "DButton")

--------------------------------------------------------------------------------
-- Ingredient card
--------------------------------------------------------------------------------
local CARD = {}

function CARD:Init()
    self:SetCursor("hand")
    self:SetMouseInputEnabled(true)
    self.glow = 0
    self.deny = 0
    self.hover = 0
    self.fill = 0
    self.doneAnim = 0
    self.count = 0
    self.lastAction = 0
    self.holding = false
end

function CARD:Setup(ent, idx)
    self.ent = ent
    self.idx = idx
    self.ing = C.Ingredients[idx]
    self.count = LM.GetProgress(ent, idx)
    if self:IsDone() then
        self.fill = 1
        self.doneAnim = 1
        self:SetCursor("arrow")
    end
end

function CARD:Required() return LM.Required(self.ing) end
function CARD:IsDone() return self.count >= self:Required() end

function CARD:Complete()
    self.glow = 1
    UI.PlaySound(C.Sounds.IngredientDone)
    self:SetCursor("arrow")
end

function CARD:OnMousePressed(code)
    if code ~= MOUSE_LEFT or self:IsDone() or not IsValid(self.ent) then return end

    local cost = LM.ActionCost(self.ing)
    if cost > 0 and not LocalPlayer():canAfford(cost) then
        self.deny = 1
        UI.Deny("You can't afford " .. self.ing.name .. " (" .. LM.FormatMoney(cost) .. ")")
        return
    end

    self.lastAction = RealTime()

    if self.ing.type == "click" then
        self.count = math.min(self.count + 1, self:Required())
        self.glow = 1
        UI.PlaySound(self.ing.sound or C.Sounds.Click)
        LM.SendAction(self.ent, LM.ACT_CLICK, self.idx)
        if self:IsDone() then self:Complete() end
    else
        self.holding = true
        self.holdStart = RealTime()
        self:MouseCapture(true)
        UI.PlaySound(C.Sounds.HoldStart)
        LM.SendAction(self.ent, LM.ACT_HOLD_BEGIN, self.idx)
    end
end

function CARD:StopHold()
    if not self.holding then return end
    self.holding = false
    self:MouseCapture(false)
    LM.SendAction(self.ent, LM.ACT_HOLD_CANCEL, self.idx)
end

function CARD:OnMouseReleased(code)
    if code == MOUSE_LEFT then self:StopHold() end
end

function CARD:Think()
    local ft = FrameTime()
    self.glow = math.Approach(self.glow, 0, ft * 2.2)
    self.deny = math.Approach(self.deny or 0, 0, ft * 2)
    self.hover = Lerp(ft * 12, self.hover, (self:IsHovered() and not self:IsDone()) and 1 or 0)
    self.doneAnim = math.Approach(self.doneAnim, self:IsDone() and 1 or 0, ft * 2.5)

    if self.ing.type == "hold" then
        if self.holding then
            self.lastAction = RealTime()
            if not input.IsMouseDown(MOUSE_LEFT) then
                self:StopHold()
            else
                local p = (RealTime() - self.holdStart) / (self.ing.seconds or 1)
                self.fill = math.min(p, 1)
                if p >= 1 then
                    self.holding = false
                    self:MouseCapture(false)
                    self.count = 1
                    LM.SendAction(self.ent, LM.ACT_HOLD_END, self.idx)
                    self:Complete()
                end
            end
        elseif not self:IsDone() then
            self.fill = Lerp(ft * 8, self.fill, 0)
        end
    end

    -- Reconcile with the server's authoritative value once input settles
    if IsValid(self.ent) and not self.holding and RealTime() - self.lastAction > 0.75 then
        local srv = LM.GetProgress(self.ent, self.idx)
        if srv ~= self.count then
            self.count = srv
            if not self:IsDone() then
                self.fill = 0
                self:SetCursor("hand")
            end
        end
    end
end

function CARD:Paint(w, h)
    local ing = self.ing
    local col = ing.color or T.Accent
    local r = S(12)
    local pad = S(18)
    local done = self:IsDone()

    -- Outer glow: click flash, hover hint, or settled "done" glow
    UI.Glow(0, 0, w, h, r, col, math.max(self.glow, self.hover * 0.3, self.doneAnim * 0.25, self.holding and self.fill * 0.6 or 0))

    -- Border + body
    local borderT = math.max(self.hover * 0.4, self.glow, self.doneAnim * 0.6, self.holding and 0.6 or 0)
    draw.RoundedBox(r, 0, 0, w, h, UI.LerpColor(borderT, T.Border, col))
    draw.RoundedBox(r - 1, 1, 1, w - 2, h - 2, UI.LerpColor(self.hover, T.Panel, T.PanelHover))

    -- Gradient fill (hold progress, or the sweep once an ingredient is complete)
    local fill = math.max(self.fill, self.doneAnim)
    if fill > 0.002 then
        local alpha = 200 - 140 * self.doneAnim
        UI.Masked(1, 1, w - 2, h - 2, r - 1, function()
            local fw = (w - 2) * fill
            UI.HGradient(1, 1, fw, h - 2, UI.Alpha(T.AccentDark, alpha), UI.Alpha(col, alpha))
            if self.holding then
                surface.SetDrawColor(255, 255, 255, 160)
                surface.DrawRect(1 + fw - S(2), 1, S(2), h - 2)
            end
        end)
    end

    -- Click flash
    if self.glow > 0.01 then
        draw.RoundedBox(r - 1, 1, 1, w - 2, h - 2, UI.Alpha(col, 40 * self.glow))
    end

    -- Can't-afford flash
    if self.deny > 0.01 then
        UI.Glow(0, 0, w, h, r, T.Error, self.deny)
        draw.RoundedBox(r - 1, 1, 1, w - 2, h - 2, UI.Alpha(T.Error, 45 * self.deny))
    end

    -- Header
    local dot = S(6)
    UI.Circle(pad + dot, pad + S(12), dot + S(3), UI.Alpha(col, 50))
    UI.Circle(pad + dot, pad + S(12), dot, col)
    draw.SimpleText(ing.name, "LM.Card", pad + S(24), pad, T.Text)
    draw.SimpleText(ing.desc or "", "LM.Small", pad, pad + S(34), T.TextDim)

    if self.doneAnim > 0.01 then
        surface.SetFont("LM.Tag")
        local tw, th = surface.GetTextSize("ADDED")
        local pw, ph = tw + S(16), th + S(8)
        local px = w - pad - pw
        draw.RoundedBox(ph / 2, px, pad, pw, ph, UI.Alpha(col, 60 * self.doneAnim))
        draw.SimpleText("ADDED", "LM.Tag", px + pw / 2, pad + ph / 2, UI.Alpha(T.Text, 255 * self.doneAnim), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Footer: instruction + progress
    local hint = ing.type == "click"
        and string.format("CLICK \195\151%d", self:Required())
        or string.format("HOLD %ss", ing.seconds)
    surface.SetFont("LM.Tag")
    local hw = surface.GetTextSize(hint)
    draw.SimpleText(hint, "LM.Tag", pad, h - pad, done and T.Text or T.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

    if (ing.price or 0) > 0 then
        local price = LM.FormatMoney(ing.price) .. (ing.type == "click" and " EACH" or " / SEC")
        local priceCol = UI.LerpColor(self.deny, done and T.TextDim or T.LeanLight, T.Error)
        draw.SimpleText(price, "LM.Tag", pad + hw + S(10), h - pad, priceCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    end

    if ing.type == "click" then
        local req = self:Required()
        local size, gap = S(10), S(6)
        local x = w - pad - req * size - (req - 1) * gap
        local y = h - pad - size
        for i = 1, req do
            local filled = i <= self.count
            draw.RoundedBox(size / 2, x, y, size, size, filled and col or T.Border)
            x = x + size + gap
        end
    else
        local pct = done and 100 or math.floor(self.fill * 100)
        draw.SimpleText(pct .. "%", "LM.Button", w - pad, h - pad + S(2), (self.holding or done) and T.Text or T.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    end
end

vgui.Register("LeanMachine.Card", CARD, "Panel")

--------------------------------------------------------------------------------
-- Ingredients view
--------------------------------------------------------------------------------
local INGREDIENTS = {}

function INGREDIENTS:Setup(ent, frame)
    self.ent = ent
    self.cards = {}

    local footer = vgui.Create("Panel", self)
    footer:Dock(BOTTOM)
    footer:SetTall(S(48))
    footer:DockMargin(0, S(20), 0, 0)
    footer.Paint = function(_, w, h)
        local total, done = #self.cards, 0
        for _, c in ipairs(self.cards) do if c:IsDone() then done = done + 1 end end

        local text = string.format("%d / %d ingredients added", done, total)
        local batch = LM.BatchCost()
        if batch > 0 then text = text .. "   \194\183   Batch cost " .. LM.FormatMoney(batch) end
        draw.SimpleText(text, "LM.Small", 0, S(4), T.TextDim)

        local segW = math.max(S(10), math.min(S(56), (w - S(240)) / math.max(total, 1) - S(6)))
        for i = 1, total do
            local c = self.cards[i]
            local x = (i - 1) * (segW + S(6))
            draw.RoundedBox(S(3), x, h - S(14), segW, S(6), T.Border)
            if c.doneAnim > 0 then
                draw.RoundedBox(S(3), x, h - S(14), segW * c.doneAnim, S(6), c.ing.color or T.Accent)
            end
        end
    end

    self.mixBtn = vgui.Create("LeanMachine.Button", footer)
    self.mixBtn:Dock(RIGHT)
    self.mixBtn:SetWide(S(210))
    self.mixBtn:SetLabel("Start Mixing")
    self.mixBtn:SetEnabled(false)
    self.mixBtn.DoClick = function()
        frame:ShowMixer()
    end

    local grid = vgui.Create("Panel", self)
    grid:Dock(FILL)
    grid.PerformLayout = function(_, w, h)
        local n = #self.cards
        local cols = 2
        local rows = math.ceil(n / cols)
        local gap = S(16)
        local cw = math.floor((w - gap * (cols - 1)) / cols)
        local ch = math.floor((h - gap * (rows - 1)) / rows)
        for i, card in ipairs(self.cards) do
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            card:SetPos(col * (cw + gap), row * (ch + gap))
            card:SetSize(cw, ch)
        end
    end

    for i = 1, #C.Ingredients do
        local card = vgui.Create("LeanMachine.Card", grid)
        card:Setup(ent, i)
        self.cards[i] = card
    end
end

function INGREDIENTS:Think()
    local all = #self.cards > 0
    for _, c in ipairs(self.cards) do
        if not c:IsDone() then all = false break end
    end
    if self.mixBtn:IsEnabled() ~= all then self.mixBtn:SetEnabled(all) end
end

vgui.Register("LeanMachine.Ingredients", INGREDIENTS, "Panel")

--------------------------------------------------------------------------------
-- Mixing view
--------------------------------------------------------------------------------
local MIXER = {}

local function xf(cx, cy, ang, x, y)
    local s, c = math.sin(ang), math.cos(ang)
    return { x = cx + x * c - y * s, y = cy + x * s + y * c }
end

function MIXER:Init()
    self.progress = 0
    self.speed = 0
    self.tilt = 0
    self.slosh = 0
    self.shakeGlow = 0
    self.doneGlow = 0
    self.nextSlosh = 0
    self.bubbles = {}

    self.pourBtn = vgui.Create("LeanMachine.Button", self)
    self.pourBtn:SetLabel("Pour Cup")
    self.pourBtn:SetVisible(false)
    self.pourBtn:SetEnabled(false)
end

function MIXER:Setup(ent, frame)
    self.ent = ent
    self.frame = frame
    self.pourBtn.DoClick = function()
        UI.PlaySound(C.Sounds.Pour)
        frame:Close()
    end
    LM.SendAction(ent, LM.ACT_MIX_BEGIN, 0)
end

function MIXER:PerformLayout(w, h)
    self.topH = S(68)
    self.bottomH = S(44)
    self.arena = { x = 0, y = self.topH, w = w, h = h - self.topH - self.bottomH - S(20) }
    self.cupW, self.cupH = S(78), S(104)

    self.pourBtn:SetSize(S(210), self.bottomH)
    self.pourBtn:SetPos(w - S(210), h - self.bottomH)

    if not self.cupX then
        self.cupX = self.arena.x + self.arena.w / 2
        self.cupY = self.arena.y + self.arena.h / 2
    end
end

function MIXER:InArena(x, y)
    local A = self.arena
    return A and x >= A.x and x <= A.x + A.w and y >= A.y and y <= A.y + A.h
end

function MIXER:OnMousePressed(code)
    if code ~= MOUSE_LEFT or self.finished then return end
    local mx, my = self:CursorPos()
    if not self:InArena(mx, my) then return end

    -- Grabbing the cup keeps the offset; clicking elsewhere pulls the cup to the cursor
    local onCup = math.abs(mx - self.cupX) < self.cupW * 0.7 and math.abs(my - self.cupY) < self.cupH * 0.7
    self.grabX = onCup and (mx - self.cupX) or 0
    self.grabY = onCup and (my - self.cupY) or 0
    self.dragging = true
    self:MouseCapture(true)
    UI.PlaySound(C.Sounds.HoldStart)
end

function MIXER:Release()
    if not self.dragging then return end
    self.dragging = false
    self:MouseCapture(false)
end

function MIXER:OnMouseReleased(code)
    if code == MOUSE_LEFT then self:Release() end
end

function MIXER:Think()
    local ft = FrameTime()
    local A = self.arena
    if ft <= 0 or not A or not self.cupX then return end

    local mx, my = self:CursorPos()
    self:SetCursor(self.finished and "arrow" or (self.dragging and "sizeall" or (self:InArena(mx, my) and "hand" or "arrow")))

    local px, py = self.cupX, self.cupY
    local hw, hh = self.cupW / 2, self.cupH / 2

    if self.dragging then
        if not input.IsMouseDown(MOUSE_LEFT) then self:Release() end
        local tx = math.Clamp(mx - self.grabX, A.x + hw + S(8), A.x + A.w - hw - S(8))
        local ty = math.Clamp(my - self.grabY, A.y + hh + S(8), A.y + A.h - hh - S(8))
        local k = math.min(ft * 30, 1)
        self.cupX = Lerp(k, self.cupX, tx)
        self.cupY = Lerp(k, self.cupY, ty)
    else
        local k = math.min(ft * 6, 1)
        self.cupX = Lerp(k, self.cupX, A.x + A.w / 2)
        self.cupY = Lerp(k, self.cupY, A.y + A.h / 2)
    end

    local vx, vy = (self.cupX - px) / ft, (self.cupY - py) / ft
    self.speed = Lerp(math.min(ft * 6, 1), self.speed, math.sqrt(vx * vx + vy * vy))
    self.tilt = Lerp(math.min(ft * 10, 1), self.tilt, math.Clamp(vx * 0.02, -22, 22))
    self.slosh = Lerp(math.min(ft * 5, 1), self.slosh, math.Clamp(-vx * 0.035, -30, 30))

    self.shaking = self.dragging and not self.finished and self.speed > C.Mix.ShakeSpeed * UI.Scale()
    self.shakeGlow = math.Approach(self.shakeGlow, self.shaking and 1 or 0, ft * 3)
    self.doneGlow = math.Approach(self.doneGlow, 0, ft * 0.8)

    if not self.finished then
        if self.shaking then
            self.progress = math.min(self.progress + ft / C.Mix.Time, 1)
            if RealTime() >= self.nextSlosh then
                self.nextSlosh = RealTime() + 0.32
                local snds = C.Sounds.Shake
                local snd = istable(snds) and snds[math.random(#snds)] or snds
                if snd and snd ~= "" then LocalPlayer():EmitSound(snd, 60, math.random(95, 120), 0.25) end
            end
            if math.random() < ft * 14 and #self.bubbles < 10 then
                self.bubbles[#self.bubbles + 1] = {
                    x = math.Rand(-0.3, 0.3) * self.cupW,
                    y = hh - S(10),
                    r = math.Rand(S(2), S(4)),
                    v = math.Rand(S(40), S(90)),
                }
            end
        elseif (C.Mix.Decay or 0) > 0 then
            self.progress = math.max(self.progress - C.Mix.Decay * ft, 0)
        end

        if self.progress >= 1 then
            self.finished = true
            self.finishTime = RealTime()
            self.doneGlow = 1
            self:Release()
            LM.SendAction(self.ent, LM.ACT_MIX_END, 0)
            UI.PlaySound(C.Sounds.MixDone)
            self.pourBtn:SetVisible(true)
        end
    else
        local ready = IsValid(self.ent) and self.ent:GetMixed()
        if self.pourBtn:IsEnabled() ~= ready then self.pourBtn:SetEnabled(ready) end
        -- Server rejected the mix (e.g. desync): send the player back to the ingredients
        if not ready and RealTime() - self.finishTime > 3 and IsValid(self.frame) then
            chat.AddText(T.Accent, "[Lean Machine] ", T.Text, "The mix didn't take. Check your ingredients and try again.")
            self.frame:ShowIngredients()
            return
        end
    end

    -- Bubbles rise to the liquid surface
    local level = -hh + self.cupH * 0.32
    for i = #self.bubbles, 1, -1 do
        local b = self.bubbles[i]
        b.y = b.y - b.v * ft
        b.x = b.x + math.sin(RealTime() * 6 + i) * ft * S(10)
        if b.y < level then table.remove(self.bubbles, i) end
    end
end

function MIXER:GetHint()
    if self.finished then
        if IsValid(self.ent) and self.ent:GetMixed() then
            return "Your lean is ready", "Pour it out to collect your cup."
        end
        return "Finishing up...", ""
    end
    if self.shaking then return "Mixing...", "Keep it moving." end
    if self.dragging then return "Shake harder!", "Move the cup faster to keep mixing." end
    if self.progress > 0 then return "Don't stop now", "Grab the cup and keep shaking." end
    return "Grab the cup", "Click and shake it around the box until it hits 100%."
end

function MIXER:DrawCup(cx, cy)
    local cw, ch = self.cupW, self.cupH
    local ang = math.rad(self.tilt)
    local tw, bw, hh = cw / 2, cw * 0.36, ch / 2

    local function shape(inset)
        return {
            xf(cx, cy, ang, -tw + inset, -hh + inset),
            xf(cx, cy, ang,  tw - inset, -hh + inset),
            xf(cx, cy, ang,  bw - inset * 0.8, hh - inset),
            xf(cx, cy, ang, -bw + inset * 0.8, hh - inset),
        }
    end

    local outer = shape(0)
    draw.NoTexture()
    surface.SetDrawColor(T.CupBody)
    surface.DrawPoly(outer)

    -- Liquid: surface stays near-level in screen space and sloshes against motion
    local level = -hh + ch * 0.32
    local sp = xf(cx, cy, ang, 0, level)
    local sl = math.rad(self.slosh)
    local liquid = {
        xf(sp.x, sp.y, sl, -cw * 1.5, 0),
        xf(sp.x, sp.y, sl,  cw * 1.5, 0),
        xf(sp.x, sp.y, sl,  cw * 1.5, ch * 2),
        xf(sp.x, sp.y, sl, -cw * 1.5, ch * 2),
    }
    local foam = {
        liquid[1], liquid[2],
        xf(sp.x, sp.y, sl,  cw * 1.5, S(5)),
        xf(sp.x, sp.y, sl, -cw * 1.5, S(5)),
    }

    UI.MaskPoly(shape(S(4)), function()
        draw.NoTexture()
        surface.SetDrawColor(T.Lean)
        surface.DrawPoly(liquid)
        surface.SetDrawColor(T.LeanLight.r, T.LeanLight.g, T.LeanLight.b, 140)
        surface.DrawPoly(foam)

        for _, b in ipairs(self.bubbles) do
            local p = xf(cx, cy, ang, b.x, b.y)
            UI.Circle(p.x, p.y, b.r, UI.Alpha(T.LeanLight, 120))
        end
    end)

    -- Glass highlight
    draw.NoTexture()
    surface.SetDrawColor(255, 255, 255, 28)
    surface.DrawPoly({
        xf(cx, cy, ang, -tw + S(9),  -hh + S(12)),
        xf(cx, cy, ang, -tw + S(15), -hh + S(12)),
        xf(cx, cy, ang, -bw + S(10),  hh - S(12)),
        xf(cx, cy, ang, -bw + S(6),   hh - S(12)),
    })

    -- Outline
    surface.SetDrawColor(T.CupEdge)
    for _, poly in ipairs({ outer, shape(1) }) do
        for i = 1, #poly do
            local a, b = poly[i], poly[i % #poly + 1]
            surface.DrawLine(a.x, a.y, b.x, b.y)
        end
    end

    -- Double-cup rims
    for _, off in ipairs({ 0, S(12) }) do
        local inset = off * (tw - bw) / ch
        surface.SetDrawColor(T.CupEdge)
        surface.DrawPoly({
            xf(cx, cy, ang, -tw + inset,  -hh + off),
            xf(cx, cy, ang,  tw - inset,  -hh + off),
            xf(cx, cy, ang,  tw - inset - S(1), -hh + off + S(4)),
            xf(cx, cy, ang, -tw + inset + S(1), -hh + off + S(4)),
        })
    end
end

function MIXER:Paint(w, h)
    local A = self.arena
    if not A or not self.cupX then return end

    -- Header
    local title, sub = self:GetHint()
    draw.SimpleText(title, "LM.Card", 0, S(6), T.Text)
    draw.SimpleText(sub, "LM.Small", 0, S(38), T.TextDim)
    draw.SimpleText(math.floor(self.progress * 100) .. "%", "LM.Huge", w, self.topH / 2 - S(4),
        UI.LerpColor(self.progress, T.Text, T.LeanLight), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- Arena
    local r = S(12)
    UI.Glow(A.x, A.y, A.w, A.h, r, T.Accent, self.shakeGlow * 0.5 + self.doneGlow)
    draw.RoundedBox(r, A.x, A.y, A.w, A.h, UI.LerpColor(math.max(self.shakeGlow * 0.5, self.doneGlow), T.Border, T.Accent))
    draw.RoundedBox(r - 1, A.x + 1, A.y + 1, A.w - 2, A.h - 2, T.Panel)

    UI.Masked(A.x + 1, A.y + 1, A.w - 2, A.h - 2, r - 1, function()
        local step, dot = S(26), S(2)
        surface.SetDrawColor(T.Accent.r, T.Accent.g, T.Accent.b, 16)
        for x = A.x + step / 2, A.x + A.w, step do
            for y = A.y + step / 2, A.y + A.h, step do
                surface.DrawRect(x, y, dot, dot)
            end
        end

        local g = 0.35 + self.shakeGlow * 0.65 + self.doneGlow
        for i = 1, 6 do
            UI.Circle(self.cupX, self.cupY, S(30 + i * 20), UI.Alpha(T.Accent, 7 * g))
        end
    end)

    self:DrawCup(self.cupX, self.cupY)

    -- Progress bar
    local barH = S(10)
    local barW = self.finished and (w - S(210) - S(20)) or w
    local by = h - self.bottomH / 2 - barH / 2
    draw.RoundedBox(barH / 2, 0, by, barW, barH, T.Border)
    if self.progress > 0 then
        UI.Masked(0, by, barW, barH, barH / 2, function()
            UI.HGradient(0, by, barW * self.progress, barH, T.AccentDark, T.LeanLight)
        end)
    end
end

vgui.Register("LeanMachine.Mixer", MIXER, "Panel")

--------------------------------------------------------------------------------
-- Frame
--------------------------------------------------------------------------------
local FRAME = {}

function FRAME:Init()
    self:SetFrameSize(S(780), S(580))
    self:MakePopup()
    self:SetAlpha(0)
    self:AlphaTo(255, 0.18, 0)

    self.openTime = SysTime()
    self.headerH = S(84)
    self.title = "LEAN MACHINE"
    self.subtitle = ""

    self.closeBtn = vgui.Create("DButton", self)
    self.closeBtn:SetText("")
    self.closeBtn.hov = 0
    self.closeBtn.Paint = function(btn, w, h)
        btn.hov = Lerp(FrameTime() * 12, btn.hov, btn:IsHovered() and 1 or 0)
        draw.RoundedBox(S(8), 0, 0, w, h, UI.Alpha(T.Accent, 35 * btn.hov))
        surface.SetDrawColor(UI.LerpColor(btn.hov, T.TextDim, T.Text))
        local p = S(11)
        for o = 0, 1 do
            surface.DrawLine(p + o, p, w - p + o, h - p)
            surface.DrawLine(w - p + o, p, p + o, h - p)
        end
    end
    self.closeBtn.DoClick = function()
        UI.PlaySound(C.Sounds.Close)
        self:Close()
    end

    self.body = vgui.Create("Panel", self)
    self.body:Dock(FILL)
    self.body:DockMargin(S(28), self.headerH, S(28), S(28))
end

function FRAME:SetFrameSize(w, h)
    self:SetSize(math.min(w, ScrW() - 40), math.min(h, ScrH() - 40))
    self:Center()
end

function FRAME:PerformLayout(w, h)
    local size = S(32)
    self.closeBtn:SetSize(size, size)
    self.closeBtn:SetPos(w - size - S(22), S(24))
end

function FRAME:Setup(ent)
    self.ent = ent
    self:ShowIngredients()
end

function FRAME:SetView(class, subtitle)
    if IsValid(self.view) then self.view:Remove() end
    local view = vgui.Create(class, self.body)
    view:Dock(FILL)
    view:SetAlpha(0)
    view:AlphaTo(255, 0.2, 0)
    view:Setup(self.ent, self)
    self.view = view
    self.subtitle = subtitle
end

function FRAME:ShowIngredients()
    self:SetView("LeanMachine.Ingredients", "Add every ingredient to the barrel.")
end

function FRAME:ShowMixer()
    UI.PlaySound(C.Sounds.Open)
    self:SetView("LeanMachine.Mixer", "Shake the cup until it's fully mixed.")
end

-- Fires the OnUserClose callback once, when the player (not the server) closes the frame
function FRAME:SendClose()
    if self.sentClose then return end
    self.sentClose = true
    if self.OnUserClose then self:OnUserClose() end
end

function FRAME:Close(fromServer)
    if self.closing then return end
    self.closing = true
    if not fromServer then self:SendClose() end
    self:SetMouseInputEnabled(false)
    self:SetKeyboardInputEnabled(false)
    self:AlphaTo(0, 0.15, 0, function()
        if IsValid(self) then self:Remove() end
    end)
end

function FRAME:OnRemove()
    if not self.closing then self:SendClose() end
    if LM.Menu == self then LM.Menu = nil end
end

function FRAME:Think()
    if self.closing then return end
    if not IsValid(self.ent) then
        self:Close(true)
        return
    end
    if self.maxDist and LocalPlayer():GetPos():DistToSqr(self.ent:GetPos()) > self.maxDist * self.maxDist then
        self:Close()
        return
    end
    if input.IsKeyDown(KEY_ESCAPE) then
        gui.HideGameUI()
        self:Close()
    end
end

function FRAME:Paint(w, h)
    Derma_DrawBackgroundBlur(self, self.openTime)

    local r = S(14)
    UI.Glow(0, 0, w, h, r, T.Accent, 0.6, 8)
    draw.RoundedBox(r, 0, 0, w, h, T.Border)
    draw.RoundedBox(r - 1, 1, 1, w - 2, h - 2, T.Background)

    -- Purple wash from the top
    UI.Masked(1, 1, w - 2, h - 2, r - 1, function()
        surface.SetMaterial(gradU)
        surface.SetDrawColor(T.Accent.r, T.Accent.g, T.Accent.b, 22)
        surface.DrawTexturedRect(0, 0, w, h * 0.45)
    end)

    local x = S(28)
    UI.Circle(x + S(5), S(38), S(9), UI.Alpha(T.Accent, 50))
    UI.Circle(x + S(5), S(38), S(5), T.Accent)
    draw.SimpleText(self.title, "LM.Title", x + S(22), S(38), T.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    draw.SimpleText(self.subtitle, "LM.Sub", x + S(22), S(42), T.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    surface.SetDrawColor(T.Border)
    surface.DrawRect(x, self.headerH - S(16), w - x * 2, 1)
end

vgui.Register("LeanMachine.Frame", FRAME, "EditablePanel")

--------------------------------------------------------------------------------
-- Networking
--------------------------------------------------------------------------------
function LM.OpenMenu(ent)
    if IsValid(LM.Menu) then
        if LM.Menu.ent == ent and not LM.Menu.closing then return end
        LM.Menu:Remove()
    end
    UI.PlaySound(C.Sounds.Open)
    local frame = vgui.Create("LeanMachine.Frame")
    frame.OnUserClose = function() LM.SendAction(ent, LM.ACT_CLOSE, 0) end
    frame:Setup(ent)
    LM.Menu = frame
end

net.Receive(LM.NET_OPEN, function()
    local ent = net.ReadEntity()
    if IsValid(ent) then LM.OpenMenu(ent) end
end)

net.Receive(LM.NET_CLOSE, function()
    if IsValid(LM.Menu) then LM.Menu:Close(true) end
end)
