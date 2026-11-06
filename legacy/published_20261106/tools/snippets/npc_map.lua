local ws = game:GetService("Workspace")
local npcs = ws:FindFirstChild("Map") and ws.Map:FindFirstChild("NPCs")
if not npcs then return { err = "no Map.NPCs" } end

local out = {}
for _, npc in ipairs(npcs:GetChildren()) do
    local entry = { name = npc.Name, class = npc.ClassName, kids = {}, remotes = {} }
    for _, c in ipairs(npc:GetChildren()) do
        entry.kids[#entry.kids + 1] = c.Name .. ":" .. c.ClassName
        if c:IsA("RemoteEvent") or c:IsA("RemoteFunction") then
            entry.remotes[#entry.remotes + 1] = c.Name .. ":" .. c.ClassName
        end
    end
    -- nested remotes (e.g. Head.QuestDone)
    for _, d in ipairs(npc:GetDescendants()) do
        if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and d.Parent ~= npc then
            entry.remotes[#entry.remotes + 1] = d:GetFullName():gsub("^Workspace%.Map%.NPCs%.", "") .. ":" .. d.ClassName
        end
    end
    out[#out + 1] = entry
end
return { count = #out, npcs = out }
