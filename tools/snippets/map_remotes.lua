-- Map every remote reachable on the client, with its real class.
local function collect(root, label, out)
    pcall(function()
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction")
               or d:IsA("UnreliableRemoteEvent") or d:IsA("BindableEvent")
               or d:IsA("BindableFunction") then
                out[#out + 1] = { path = d:GetFullName(), class = d.ClassName, group = label }
            end
        end
    end)
end

local out = {}
collect(game:GetService("ReplicatedStorage"), "ReplicatedStorage", out)

local ws = game:GetService("Workspace")
if ws:FindFirstChild("Map") and ws.Map:FindFirstChild("NPCs") then
    collect(ws.Map.NPCs, "Map.NPCs", out)
end
if ws:FindFirstChild("Living") then
    collect(ws.Living, "Living", out)
end

local lp = game:GetService("Players").LocalPlayer
if lp.Character then
    collect(lp.Character, "Character", out)
end

return { total = #out, remotes = out }
