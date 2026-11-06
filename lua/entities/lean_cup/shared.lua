ENT.Type        = "anim"
ENT.Base        = "base_gmodentity"
ENT.PrintName   = "Cup of Lean"
ENT.Author      = "Lean Machine"
ENT.Category    = "Lean Machine"
ENT.Spawnable   = true
ENT.AdminOnly   = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Brewer")
end
