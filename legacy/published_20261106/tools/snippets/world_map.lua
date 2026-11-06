local ws = game:GetService("Workspace")
local rs = game:GetService("ReplicatedStorage")
local out = {}

local function list(inst, label, depth)
    local res = {}
    for _, c in ipairs(inst:GetChildren()) do
        local e = { name = c.Name, class = c.ClassName }
        if depth and depth > 0 then
            local kids = {}
            for _, k in ipairs(c:GetChildren()) do kids[#kids + 1] = k.Name .. ":" .. k.ClassName end
            if #kids > 0 then e.kids = kids end
        end
        res[#res + 1] = e
    end
    out[label] = { count = #res, items = res }
end

if ws:FindFirstChild("Map") then list(ws.Map, "Map", 1) end
if ws:FindFirstChild("Vfx") then list(ws.Vfx, "Vfx", 0) end
if ws:FindFirstChild("vfx") then list(ws.vfx, "vfx", 0) end
if ws:FindFirstChild("Living") then list(ws.Living, "Living", 0) end
if rs:FindFirstChild("Events") then list(rs.Events, "Events", 0) end
list(rs, "ReplicatedStorage", 0)

-- tools lying in the world (spawned items)
local tools = {}
for _, d in ipairs(ws:GetDescendants()) do
    if d:IsA("Tool") and not d:IsDescendantOf(game:GetService("Players")) then
        local prompt
        for _, p in ipairs(d:GetDescendants()) do
            if p:IsA("ProximityPrompt") then prompt = p.Name break end
        end
        tools[#tools + 1] = { name = d.Name, path = d:GetFullName(), prompt = prompt }
    end
end
out.world_tools = { count = #tools, items = tools }

return out
