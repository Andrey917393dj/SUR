-- Mock Roblox runtime for offline smoke-testing the script.
-- Not a Roblox emulator: it covers only the API surface this script touches.
-- With click_all=true it also fires every button/toggle/textbox handler, each
-- inside a bounded coroutine, so handler bodies get exercised too.

local REAL = _ENV

local M = {}

-- ── bounded coroutine runner ──────────────────────────────────────────────
local MAX_STEPS = 400

local function runBounded(f, ...)
    if type(f) ~= "function" then return true end
    local co = coroutine.create(f)
    local ok, err = coroutine.resume(co, ...)
    local steps = 0
    while coroutine.status(co) == "suspended" and steps < MAX_STEPS do
        steps = steps + 1
        ok, err = coroutine.resume(co)
    end
    if not ok then return false, err end
    return true
end

-- ── tokens ────────────────────────────────────────────────────────────────
local function tokenFactory(prefix)
    local cache = {}
    return setmetatable({}, {
        __index = function(_, k)
            if not cache[k] then
                cache[k] = { Name = k, FullName = prefix .. "." .. k, __isEnum = true }
            end
            return cache[k]
        end,
    })
end

-- ── values ────────────────────────────────────────────────────────────────
local Vector3 = {}
local function v3(x, y, z)
    return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__mul = function(a, b)
    if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
    return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3.__index = function(t, k)
    if k == "Magnitude" then
        return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
    end
    return rawget(t, k)
end

local Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }

local CFrame = {}
local function cf(x, y, z)
    return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, CFrame)
end
CFrame.__mul = function(a, b)
    if getmetatable(b) == CFrame then
        return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
    end
    return cf(a.X, a.Y, a.Z)
end
CFrame.__add = function(a, b) return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
CFrame.__index = function(t, k)
    if k == "Position" then return v3(t.X, t.Y, t.Z) end
    return rawget(t, k)
end

local UDim = { new = function(s, o) return { Scale = s or 0, Offset = o or 0 } end }
local UDim2 = { new = function(xs, xo, ys, yo)
    return { X = { Scale = xs or 0, Offset = xo or 0 },
             Y = { Scale = ys or 0, Offset = yo or 0 } }
end }

local Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end }

-- ── instance model ────────────────────────────────────────────────────────
local METHODS = {}
local EVENTS = {
    MouseButton1Down = true, MouseButton1Click = true, MouseButton2Down = true,
    FocusLost = true, InputBegan = true, InputChanged = true, InputEnded = true,
    Idled = true, Changed = true, MoveToFinished = true, Activated = true,
    ChildAdded = true, ChildRemoved = true, AncestryChanged = true,
    OnClientEvent = true, Touch = true, Touched = true, Focused = true,
}

local function signal()
    local handlers = {}
    local s = {}
    function s:Connect(f)
        handlers[#handlers + 1] = f
        return { Disconnect = function() end }
    end
    function s:Once(f) handlers[#handlers + 1] = f; return { Disconnect = function() end } end
    function s:Wait(t) return nil end
    function s:Fire(...)
        for _, h in ipairs(handlers) do runBounded(h, ...) end
    end
    function s:Count() return #handlers end
    return s
end

local DEFAULTS = {
    TextLabel = { Text = "" },
    TextButton = { Text = "" },
    TextBox = { Text = "" },
    StringValue = { Value = "" },
    Frame = {},
}

local function newInstance(className, name)
    local obj = { __isInstance = true, ClassName = className, Name = name or className }
    local kids = {}
    local props = {}
    local events = {}
    rawset(obj, "__kids", kids)
    rawset(obj, "__props", props)
    for k, v in pairs(DEFAULTS[className] or {}) do props[k] = v end

    local mt = {}
    mt.__index = function(t, k)
        local m = METHODS[k]
        if m then return m end
        for _, ch in ipairs(kids) do
            if ch.Name == k then return ch end
        end
        if EVENTS[k] then
            if not events[k] then events[k] = signal() end
            return events[k]
        end
        local p = props[k]
        if p ~= nil then return p end
        return nil
    end
    mt.__newindex = function(t, k, v)
        if k == "Parent" then
            local old = props.Parent
            if old and old.__isInstance then
                local okids = rawget(old, "__kids")
                for i = #okids, 1, -1 do
                    if okids[i] == t then table.remove(okids, i) end
                end
            end
            props.Parent = v
            if v and v.__isInstance then
                table.insert(rawget(v, "__kids"), t)
            end
            return
        end
        props[k] = v
    end
    mt.__tostring = function(t)
        return "Instance<" .. tostring(t.ClassName) .. ":" .. tostring(t.Name) .. ">"
    end
    return setmetatable(obj, mt)
end

function METHODS:IsA(cls)
    if self.ClassName == cls then return true end
    local base = {
        TextButton = { "GuiButton", "GuiObject", "Instance" },
        TextLabel = { "GuiObject", "Instance" },
        TextBox = { "GuiObject", "Instance" },
        Frame = { "GuiObject", "Instance" },
        ImageButton = { "GuiButton", "GuiObject", "Instance" },
        ScrollingFrame = { "GuiObject", "Instance" },
        Tool = { "Instance" },
        RemoteEvent = { "Instance" },
        RemoteFunction = { "Instance" },
        StringValue = { "ValueBase", "Instance" },
        Model = { "Instance" },
        Part = { "BasePart", "Instance" },
        MeshPart = { "BasePart", "Instance" },
    }
    for _, b in ipairs(base[self.ClassName] or {}) do
        if b == cls then return true end
    end
    return false
end

function METHODS:GetChildren()
    local out = {}
    for i, v in ipairs(rawget(self, "__kids")) do out[i] = v end
    return out
end

function METHODS:GetDescendants()
    local out = {}
    local function walk(o)
        for _, ch in ipairs(rawget(o, "__kids")) do
            out[#out + 1] = ch
            walk(ch)
        end
    end
    walk(self)
    return out
end

function METHODS:FindFirstChild(n, recursive)
    for _, ch in ipairs(rawget(self, "__kids")) do
        if ch.Name == n then return ch end
    end
    return nil
end

function METHODS:FindFirstChildOfClass(cls)
    for _, ch in ipairs(rawget(self, "__kids")) do
        if ch.ClassName == cls then return ch end
    end
    return nil
end

function METHODS:FindFirstChildWhichIsA(cls)
    for _, ch in ipairs(rawget(self, "__kids")) do
        if ch:IsA(cls) then return ch end
    end
    return nil
end

function METHODS:WaitForChild(n, t)
    local c = self:FindFirstChild(n)
    if c then return c end
    if t then return nil end
    error("WaitForChild('" .. tostring(n) .. "') would block forever in mock", 2)
end

function METHODS:Destroy()
    self.Parent = nil
    rawset(self, "__kids", {})
end

function METHODS:GetFullName()
    local parts = {}
    local o = self
    while o and o.__isInstance do
        table.insert(parts, 1, o.Name)
        o = rawget(o, "__props").Parent
    end
    return table.concat(parts, ".")
end

function METHODS:IsDescendantOf(other)
    local o = rawget(self, "__props").Parent
    while o do
        if o == other then return true end
        o = rawget(o, "__props").Parent
    end
    return false
end

function METHODS:GetPropertyChangedSignal(n) return signal() end
function METHODS:Clone() return newInstance(self.ClassName, self.Name) end
function METHODS:GetAttribute(n) return nil end
function METHODS:SetAttribute(n, v) end
function METHODS:PivotTo(c) end
function METHODS:Activate() end
function METHODS:EquipTool(t) end
function METHODS:FireServer(...) end
function METHODS:InvokeServer(...) return {} end
function METHODS:LoadAnimation(a) return { Play = function() end, Stop = function() end } end
function METHODS:MoveTo(p) end
function METHODS:ChangeState(s) end
function METHODS:TakeDamage(n) end
function METHODS:InputHoldBegin() end
function METHODS:InputHoldEnd() end
function METHODS:Play() end
function METHODS:Stop() end

-- ── services / game tree ──────────────────────────────────────────────────
local function build()
    local workspace = newInstance("Workspace", "Workspace")
    local rs = newInstance("ReplicatedStorage", "ReplicatedStorage")
    local coreGui = newInstance("CoreGui", "CoreGui")
    local starterGui = newInstance("StarterGui", "StarterGui")
    local players = newInstance("Players", "Players")

    local map = newInstance("Folder", "Map")
    map.Parent = workspace
    local npcs = newInstance("Folder", "NPCs")
    npcs.Parent = map

    local function addNPC(name, label, sub)
        local m = newInstance("Model", name)
        m.Parent = npcs
        local root = newInstance("Part", "HumanoidRootPart")
        root.Position = v3(0, 0, 0)
        root.Parent = m
        local head = newInstance("Part", "Head")
        head.Position = v3(0, 5, 0)
        head.Parent = m
        local main = newInstance("BillboardGui", "Main")
        main.Parent = head
        local t = newInstance("TextLabel", "Text")
        t.Text = label or name
        t.Parent = main
        local subGui = newInstance("BillboardGui", "Sub")
        subGui.Parent = head
        local st = newInstance("TextLabel", "Text")
        st.Text = sub or ""
        st.Parent = subGui
        local done = newInstance("RemoteEvent", "Done")
        done.Parent = m
        local qdone = newInstance("RemoteEvent", "QuestDone")
        qdone.Parent = m
        return m
    end

    addNPC("admpn", "Admpn")
    addNPC("StockMarket", "Stock Market")
    addNPC("MerchantAU", "Merchant")
    addNPC("Merchant120", "Merchant 120")
    addNPC("LairNPC", "Lair Host")
    for i = 1, 6 do addNPC("QuestNPC" .. i, "Quest NPC " .. i) end

    local boards = newInstance("Folder", "ChancesBoards")
    boards.Parent = map
    local chances = newInstance("Model", "AttributeChances")
    chances.Parent = boards
    local surf = newInstance("Part", "newSurface")
    surf.Parent = chances
    local scroll = newInstance("ScrollingFrame", "ScrollFrame")
    scroll.Parent = surf
    for _, name in ipairs({ "Glass Cannon 1%", "Power 5%", "Speed 4%", "Power 5%" }) do
        local tl = newInstance("TextLabel", name)
        tl.Text = name
        tl.Parent = scroll
    end

    local livingFolder = newInstance("Folder", "Living")
    livingFolder.Parent = workspace
    local items = newInstance("Folder", "Items")
    items.Parent = workspace
    local vfx = newInstance("Folder", "Vfx")
    vfx.Parent = workspace

    local events = newInstance("Folder", "Events")
    events.Parent = rs
    for _, n in ipairs({ "UseItem", "SellKetchup", "BuyItem", "SM_Event", "SwitchStand",
                         "GetStandTier", "CoolDownGUI", "CheckCMD", "LairStart", "LairClear",
                         "NpcPrompt", "PressedPlay" }) do
        local r = newInstance("RemoteEvent", n)
        r.Parent = events
    end
    local convert = newInstance("Folder", "StandNameConvert")
    convert.Parent = rs
    for _, code in ipairs({ "SPTW_R", "SP", "TW", "CD", "GE", "KC", "MIH" }) do
        local sv = newInstance("StringValue", code)
        sv.Value = code
        sv.Parent = convert
    end

    local lp = newInstance("Player", "TestPlayer")
    lp.Parent = players
    players.LocalPlayer = lp

    local data = newInstance("Folder", "Data")
    data.Parent = lp
    local stand = newInstance("StringValue", "Stand"); stand.Value = "None"; stand.Parent = data
    local attri = newInstance("StringValue", "Attri"); attri.Value = "None"; attri.Parent = data
    local guid  = newInstance("StringValue", "GUID");  guid.Value = "0000";  guid.Parent = data
    local bp = newInstance("Backpack", "Backpack"); bp.Parent = lp

    local charModel = newInstance("Model", "TestPlayer")
    local hum = newInstance("Humanoid", "Humanoid")
    hum.Health = 100; hum.MaxHealth = 100; hum.WalkSpeed = 16
    hum.Parent = charModel
    local root = newInstance("Part", "HumanoidRootPart")
    root.Position = v3(0, 0, 0)
    root.Parent = charModel
    local se = newInstance("Folder", "StandEvents")
    se.Parent = charModel
    local input = newInstance("RemoteEvent", "Input"); input.Parent = se
    local info = newInstance("RemoteFunction", "Info"); info.Parent = se
    charModel.Parent = workspace
    lp.Character = charModel

    local pg = newInstance("PlayerGui", "PlayerGui")
    pg.Parent = lp

    local services = {
        Workspace = workspace,
        ReplicatedStorage = rs,
        CoreGui = coreGui,
        StarterGui = starterGui,
        Players = players,
        Debris = { AddItem = function() end },
        TweenService = { Create = function() return { Play = function() end } end },
        UserInputService = { InputBegan = signal(), InputChanged = signal() },
        PathfindingService = {
            CreatePath = function()
                return {
                    ComputeAsync = function() end,
                    GetWaypoints = function() return {} end,
                }
            end,
        },
        HttpService = { JSONEncode = function() return "{}" end },
        VirtualUser = { Button2Down = function() end, Button2Up = function() end },
        RunService = { Heartbeat = signal(), RenderStepped = signal() },
        Lighting = newInstance("Lighting", "Lighting"),
    }

    local game = {
        PlaceId = 8540168650,
        Workspace = workspace,
        Players = players,
        GetService = function(_, n)
            if services[n] then return services[n] end
            local s = newInstance(n, n)
            services[n] = s
            return s
        end,
    }

    return game, workspace, lp
end

-- ── runner ────────────────────────────────────────────────────────────────
function M.run(src, clickAll)
    local game, workspace, lp = build()
    M.workspace = workspace   -- for targeted tests
    M.env = nil               -- filled in once the sandbox env exists

    local errors = {}

    local task = {}
    function task.wait(t)
        if coroutine.isyieldable() then coroutine.yield() end
    end
    function task.spawn(f, ...)
        local ok, err = runBounded(f, ...)
        if not ok then errors[#errors + 1] = type(err) .. " | " .. tostring(err) end
        return { cancel = function() end }
    end
    function task.delay(t, f, ...) return task.spawn(f, ...) end
    function task.defer(f, ...) return task.spawn(f, ...) end

    local env
    env = setmetatable({
        game = game,
        workspace = workspace,
        Workspace = workspace,
        table = setmetatable({
            find = function(t, v, init)
                for i = init or 1, #t do
                    if t[i] == v then return i end
                end
                return nil
            end,
        }, { __index = REAL.table }),
        string = setmetatable({
            split = function(s, sep)
                local out = {}
                for piece in REAL.string.gmatch(s, "([^" .. sep .. "]+)") do
                    out[#out + 1] = piece
                end
                return out
            end,
        }, { __index = REAL.string }),
        Enum = {
            KeyCode = tokenFactory("KeyCode"),
            UserInputType = tokenFactory("UserInputType"),
            Font = tokenFactory("Font"),
            TextXAlignment = tokenFactory("TextXAlignment"),
            TextYAlignment = tokenFactory("TextYAlignment"),
            AutomaticSize = tokenFactory("AutomaticSize"),
            SortOrder = tokenFactory("SortOrder"),
            HorizontalAlignment = tokenFactory("HorizontalAlignment"),
            VerticalAlignment = tokenFactory("VerticalAlignment"),
            EasingStyle = tokenFactory("EasingStyle"),
            EasingDirection = tokenFactory("EasingDirection"),
            HumanoidStateType = tokenFactory("HumanoidStateType"),
            PathWaypointAction = tokenFactory("PathWaypointAction"),
            ZIndexBehavior = tokenFactory("ZIndexBehavior"),
            SizeConstraint = tokenFactory("SizeConstraint"),
        },
        Instance = { new = function(cls, parent)
            local o = newInstance(cls, cls)
            if parent then o.Parent = parent end
            return o
        end },
        Vector3 = { new = v3, zero = v3(0, 0, 0) },
        Vector2 = Vector2,
        CFrame = { new = cf },
        UDim = UDim,
        UDim2 = UDim2,
        Color3 = Color3,
        TweenInfo = { new = function(...) return { args = { ... } } end },
        task = task,
        tick = function() return 0 end,
        warn = function(...) end,
        print = function(...) end,
        getgenv = function() return env end,
        fireproximityprompt = function() end,
        firesignal = function() end,
        request = function() return {} end,
        http_request = function() return {} end,
        syn = { request = function() return {} end },
        gethui = nil,
        setclipboard = function() end,
        loadstring = function() return function() end end,
        typeof = function(v)
            if type(v) == "table" and v.__isInstance then return "Instance" end
            return type(v)
        end,
    }, { __index = REAL })

    M.env = env

    local chunk, err = load(src, "SUR", "t", env)
    if not chunk then return false, err, errors end

    local ok, runErr = pcall(chunk)
    if not ok then return false, runErr, errors end

    if clickAll then
        local gui = env.getgenv().ArcticScreenGui
        if gui then
            local fired = 0
            for _, d in ipairs(gui:GetDescendants()) do
                if d.ClassName == "TextButton" then
                    local sig = d.MouseButton1Down
                    if sig and sig.Count and sig:Count() > 0 then
                        fired = fired + 1
                        sig:Fire()
                        sig:Fire()   -- second click = toggle back off
                    end
                elseif d.ClassName == "TextBox" then
                    local sig = d.FocusLost
                    if sig and sig.Count and sig:Count() > 0 then
                        fired = fired + 1
                        sig:Fire(true)
                    end
                end
            end
            M.clicked = fired
        end
    end

    return true, nil, errors
end

-- exported so targeted tests can build their own NPCs inside Workspace.Living
M.newInstance = newInstance

return M