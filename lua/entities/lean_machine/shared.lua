ENT.Type        = "anim"
ENT.Base        = "base_gmodentity"
ENT.PrintName   = "Lean Machine"
ENT.Author      = "Lean Machine"
ENT.Category    = "Lean Machine"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "owning_ent") -- set by DarkRP on purchase
    self:NetworkVar("Entity", 1, "User")
    self:NetworkVar("Bool",   0, "Mixed")
    self:NetworkVar("Bool",   1, "Shaking")
    self:NetworkVar("Float",  0, "NextUse")
    self:NetworkVar("Int",    0, "Batches")
end
