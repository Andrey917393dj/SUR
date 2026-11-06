local ws = game:GetService("Workspace")
local out = { tools = {} }

local vfx = ws:FindFirstChild("Vfx")
if vfx then
    for _, t in ipairs(vfx:GetChildren()) do
        if t:IsA("Tool") or t:IsA("Model") or t:IsA("MeshPart") or t:IsA("Part") then
            local handle = t:FindFirstChild("Handle")
            local base = handle or t:FindFirstChildWhichIsA("BasePart")
            local e = {
                name = t.Name, class = t.ClassName,
                pos = base and { X = math.floor(base.Position.X), Y = math.floor(base.Position.Y), Z = math.floor(base.Position.Z) } or nil,
                kids = {}
            }
            for _, c in ipairs(t:GetChildren()) do
                e.kids[#e.kids + 1] = c.Name .. ":" .. c.ClassName
            end
            out.tools[#out.tools + 1] = e
        end
    end
end

-- lair spawn points
local lair = ws.Map and ws.Map:FindFirstChild("LairSpawns")
if lair then
    out.lair = {}
    for _, c in ipairs(lair:GetChildren()) do
        local base = c:IsA("BasePart") and c or c:FindFirstChildWhichIsA("BasePart")
        out.lair[#out.lair + 1] = {
            name = c.Name, class = c.ClassName,
            pos = base and { X = math.floor(base.Position.X), Y = math.floor(base.Position.Y), Z = math.floor(base.Position.Z) } or nil
        }
    end
end

-- key map landmarks
local landmarks = {}
for _, name in ipairs({ "Dark Entrance", "EnteringCitySign", "LeavingCitySign", "Storage Sign" }) do
    for _, c in ipairs(ws.Map:GetChildren()) do
        if c.Name == name and c:IsA("BasePart") then
            landmarks[#landmarks + 1] = { name = name, pos = { X = math.floor(c.Position.X), Y = math.floor(c.Position.Y), Z = math.floor(c.Position.Z) } }
        end
    end
end
out.landmarks = landmarks

return out
