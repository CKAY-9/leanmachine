--[[
    Lean Machine - Configuration
    Edit the values below to tune the addon. Changes need a map change / server restart.
]]

LeanMachine = LeanMachine or {}
LeanMachine.Config = {}
local C = LeanMachine.Config

--------------------------------------------------------------------------------
-- DarkRP F4 shop entry
--------------------------------------------------------------------------------
C.DarkRP = {
    Register    = false,            -- Set false if you add lean_machine yourself in darkrpmodification. Also toggleable in Q menu > Utilities > Lean Machine
    Name        = "Lean Machine",
    Command     = "buyleanmachine",
    Price       = 2500,
    Max         = 2,                -- Max machines per player
    Category    = "Other",          -- Must be an existing DarkRP entity category
    AllowedJobs = {},               -- e.g. { "TEAM_GANG", "TEAM_MOB" }. Empty = every job
}

--------------------------------------------------------------------------------
-- Barrel
--------------------------------------------------------------------------------
C.Barrel = {
    Model         = "models/props_borealis/bluebarrel001.mdl",
    Color         = Color(110, 80, 150),
    Material      = "",             -- Optional material override
    Health        = 200,            -- 0 = indestructible
    OwnerOnly     = false,          -- Only the purchaser can brew
    MaxDistance   = 160,            -- Menu closes if the player walks further than this
    Cooldown      = 5,              -- Seconds between batches
    MaxBatches    = 0,              -- Machine breaks after this many cups. 0 = unlimited
    LabelDistance = 300,            -- Floating label draw distance
}

--------------------------------------------------------------------------------
-- Ingredients (shown in this order, in a 2-column grid)
--   type = "click" -> click `clicks` times, `price` is charged per click
--   type = "hold"  -> hold the mouse for `seconds`, `price` is per second
--                     (the full price * seconds is charged when the hold completes)
--------------------------------------------------------------------------------
C.Ingredients = {
    { id = "candy",   name = "Candy",   desc = "A handful of hard candy", type = "click", clicks  = 5, price = 5,  color = Color(255, 100, 160) },
    { id = "sprite",  name = "Sprite",  desc = "The soda base",           type = "hold",  seconds = 3, price = 10, color = Color(110, 225, 150) },
    { id = "ice",     name = "Ice",     desc = "Keep it cold",            type = "click", clicks  = 3, price = 3,  color = Color(140, 205, 255) },
    { id = "codeine", name = "Codeine", desc = "Cough syrup",             type = "hold",  seconds = 4, price = 50, color = Color(175, 115, 255) },
}

--------------------------------------------------------------------------------
-- Mixing
--------------------------------------------------------------------------------
C.Mix = {
    Time       = 10,     -- Seconds of active shaking needed to reach 100%
    ShakeSpeed = 500,    -- Minimum cup speed (pixels/sec at 1080p) that counts as shaking
    Decay      = 0,      -- Progress lost per second while NOT shaking (0.02 = 2%/s). 0 = none
}

--------------------------------------------------------------------------------
-- Cup
--------------------------------------------------------------------------------
C.Cup = {
    Model          = "models/props_junk/garbage_coffeemug001a.mdl",
    Color          = Color(200, 160, 255),
    DespawnTime    = 0,      -- Seconds before an untouched cup is removed. 0 = never
    Drinkable      = true,   -- Press E on the cup to drink it
    Duration       = 30,     -- Effect duration in seconds
    HealthGain     = 10,
    SpeedMultiplier = 0.85,  -- Walk/run speed multiplier while under the effect (1 = no change)
    ScreenEffects  = true,
    EffectStrength = 1,      -- 0..1 strength of the purple screen effect
}

--------------------------------------------------------------------------------
-- Cup storage (crouch + E on a cup to store it)
--------------------------------------------------------------------------------
C.Storage = {
    MaxCups            = 10,
    OnDeath            = "drop",  -- "drop" = spill stored cups on the ground, "lose" = delete them, "keep"
    ConfiscateOnArrest = true,    -- Stored cups are removed when the player is arrested
}

--------------------------------------------------------------------------------
-- Buyer NPC
--   Spawn buyers from the Q menu (Entities > Lean Machine), then run
--   `leanmachine_savebuyers` (superadmin) to make them persist on this map.
--------------------------------------------------------------------------------
C.Buyer = {
    Model       = "models/Humans/Group01/male_07.mdl",
    Sequence    = "LineIdle02",   -- Idle animation. Alternatives: LineIdle01, LineIdle03, idle_subtle
    -- Extra bone tweaks layered on the animation for a slouch. Set to {} to disable.
    Slouch = {
        ["ValveBiped.Bip01_Spine1"] = Angle(0, 6, 0),
        ["ValveBiped.Bip01_Spine2"] = Angle(0, 6, 0),
        ["ValveBiped.Bip01_Head1"]  = Angle(0, -8, 0),
    },
    PricePerCup   = 1000,
    MaxDistance   = 140,
    AllowPolice   = false,        -- Can civil protection jobs sell lean?
    BlockedJobs   = {},           -- e.g. { "TEAM_MAYOR" }
    Light         = true,         -- Subtle purple light around the buyer
    LabelDistance = 600,
}

--------------------------------------------------------------------------------
-- Haggling (from the buyer's sell menu)
--   Each attempt rolls server-side. A success adds a bonus to your NEXT sale and
--   you may push your luck again. Fail once and the buyer gets annoyed; fail
--   `FailsForPenalty` times and any bonus is replaced by a penalty and haggling
--   locks. The bonus/penalty is used up (and haggling resets) when you sell.
--------------------------------------------------------------------------------
C.Haggle = {
    Enabled         = true,
    MaxAttempts     = 3,
    Chances         = { 0.65, 0.45, 0.30 },  -- Success chance for attempt 1, 2, 3...
    BonusPerSuccess = 0.10,                  -- +10% sale value per successful haggle
    FailsForPenalty = 2,
    Penalty         = 0.20,                  -- -20% sale value once penalised
    Cooldown        = 1,                     -- Seconds between attempts

    Lines = {
        Greeting = { "What you got for me?", "Make it quick.", "You bringing the good stuff?" },
        Return   = { "Back again? Deal's still on the table.", "Same deal as before. Ready?" },
        Burned   = { "You already burned me. Take it or leave it.", "Price is what it is now." },
        Success  = { "Alright, alright. You drive a hard bargain.", "Fine. But don't push your luck.", "Hm. I can do that." },
        Fail     = { "Nah. That's my price.", "You think I'm stupid?", "Don't test me." },
        Penalty  = { "Now you're insulting me. Price just dropped.", "Keep wasting my time and you get less." },
    },

    -- Voice lines played from the buyer ("" or {} to disable)
    Voice = {
        Success = { "vo/npc/male01/ok01.wav", "vo/npc/male01/ok02.wav", "vo/npc/male01/fine01.wav" },
        Fail    = { "vo/npc/male01/no01.wav", "vo/npc/male01/no02.wav" },
        Penalty = { "vo/npc/male01/gethellout.wav" },
    },
}

--------------------------------------------------------------------------------
-- Anti-exploit
--------------------------------------------------------------------------------
C.LatencyTolerance = 0.35   -- Seconds of leeway allowed on server-side timing checks
C.MinClickInterval = 0.05   -- Fastest accepted click rate (seconds between clicks)

--------------------------------------------------------------------------------
-- Sounds ("" to disable)
--------------------------------------------------------------------------------
C.Sounds = {
    Open           = "garrysmod/ui_click.wav",
    Close          = "garrysmod/ui_return.wav",
    Click          = "buttons/lightswitch2.wav",
    HoldStart      = "garrysmod/ui_hover.wav",
    IngredientDone = "garrysmod/content_downloaded.wav",
    Shake          = { "ambient/water/water_splash1.wav", "ambient/water/water_splash2.wav", "ambient/water/water_splash3.wav" },
    MixDone        = "garrysmod/save_load1.wav",
    Pour           = "garrysmod/ui_click.wav",
    Drop           = "ambient/water/water_splash1.wav",
    Drink          = "npc/barnacle/barnacle_gulp1.wav",
    Store          = "physics/plastic/plastic_box_impact_soft1.wav",
    Deny           = "buttons/button10.wav",
    Sell           = "garrysmod/save_load2.wav",
    HaggleWin      = "garrysmod/content_downloaded.wav",
    HaggleFail     = "buttons/button10.wav",
}

--------------------------------------------------------------------------------
-- Theme
--------------------------------------------------------------------------------
C.Theme = {
    Font       = "Roboto",
    Background = Color(15, 13, 21, 250),
    Panel      = Color(24, 21, 33),
    PanelHover = Color(31, 27, 43),
    Border     = Color(46, 40, 62),
    Accent     = Color(160, 100, 255),
    AccentDark = Color(86, 46, 168),
    Text       = Color(238, 234, 248),
    TextDim    = Color(150, 140, 172),
    Error      = Color(255, 85, 110),
    Lean       = Color(130, 58, 220),
    LeanLight  = Color(200, 155, 255),
    CupBody    = Color(235, 232, 245, 30),
    CupEdge    = Color(235, 232, 245, 170),
}
