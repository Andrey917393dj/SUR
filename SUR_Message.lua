-- Built by Olivia — https://discord.gg/ojailbreaks
-- ARCTIC SUR — message.txt port (single file)
-- Original menus retained. UI embedded; no external downloads.
-- Offline checks do not prove server damage, rewards or anti-cheat behavior.

-- ============================================================
-- Arctic UI Library (Lib.txt) — FIXED VERSION
-- Fixes: nil-check for B, deprecated KeyDown, missing EditString,
--        missing Fill, missing Delete alias, broken CreateSearchBar
--        fake LocalScript, table.find on dict in CreateTextBoxToggle,
--        Toggle tween loop efficiency, Sound memory leak.
-- ============================================================

-- ══ module scope: Start() fills these, API functions read them ══
local ScreenGui, Frame, Hotbar, CloseButton, MinimizeButton, TitleLabel, Buttons, Handler, Menus
local DefaultColor = Color3.fromRGB(124, 106, 255)
local TweenServ = game:GetService("TweenService")
local UIS       = game:GetService("UserInputService")
local UIConnections = {}
local ToggleStates = {}
local UIBusy = {}
local UIThreads = {}
local UIClosed = false
local UIGeneration = 0
local UIConnectionOwners = {}
local UIConnectionsByOwner = {}
local UIDestroy

local function UIReport(label, err)
    warn("[Arctic SUR] " .. tostring(label) .. ": " .. tostring(err))
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Arctic", Text = tostring(label) .. ": " .. tostring(err), Duration = 5,
        })
    end)
end

local function UIDisconnect(connection)
    if not connection then return end
    pcall(function() connection:Disconnect() end)
    UIConnections[connection] = nil
    local owner = UIConnectionOwners[connection]
    UIConnectionOwners[connection] = nil
    local owned = owner and UIConnectionsByOwner[owner]
    if owned then owned[connection] = nil end
end

local function UIForget(owner)
    local owned = UIConnectionsByOwner[owner]
    if owned then
        local connections = {}
        for connection in pairs(owned) do connections[#connections + 1] = connection end
        for _, connection in ipairs(connections) do UIDisconnect(connection) end
        UIConnectionsByOwner[owner] = nil
    end
    for _, states in pairs(ToggleStates) do
        for name, state in pairs(states) do if state.owner == owner then states[name] = nil end end
    end
end

local function UIConnect(event, callback, owner)
    local generation = UIGeneration
    local connection = event:Connect(function(...)
        if UIClosed or generation ~= UIGeneration then return end
        local ok, err = pcall(callback, ...)
        if not ok and not UIClosed and generation == UIGeneration then UIReport("UI", err) end
    end)
    UIConnections[connection] = true
    if owner then
        UIConnectionOwners[connection] = owner
        if not UIConnectionsByOwner[owner] then
            UIConnectionsByOwner[owner] = {}
            local destroying = owner.Destroying:Connect(function() UIForget(owner) end)
            UIConnections[destroying] = true
            UIConnectionOwners[destroying] = owner
            UIConnectionsByOwner[owner][destroying] = true
        end
        UIConnectionsByOwner[owner][connection] = true
    end
    return connection
end

local function UICall(callback, ...)
    if UIClosed or type(callback) ~= "function" or UIBusy[callback] then return false end
    local generation = UIGeneration
    local thread = coroutine.running()
    UIThreads[thread] = true
    UIBusy[callback] = true
    local ok, result = pcall(callback, ...)
    UIBusy[callback] = nil
    UIThreads[thread] = nil
    if generation ~= UIGeneration or UIClosed then return false end
    if not ok then UIReport("Action", result) end
    return ok, result
end

local function SetToggle(Name, MenuName, value)
    local states = ToggleStates[MenuName]
    local state = states and states[Name]
    if state then
        state.value = value == true
        if state.paint then state.paint(state.value) end
    end
    return value == true
end

UIDestroy = function()
    if UIClosed then return end
    UIClosed = true
    UIGeneration = UIGeneration + 1
    for connection in pairs(UIConnections) do pcall(function() connection:Disconnect() end) end
    UIConnections, UIConnectionOwners, UIConnectionsByOwner = {}, {}, {}
    ToggleStates, UIBusy = {}, {}
    for thread in pairs(UIThreads) do
        if thread ~= coroutine.running() and task.cancel then pcall(task.cancel, thread) end
    end
    UIThreads = {}
    local gui = ScreenGui
    ScreenGui = nil
    Frame, Hotbar, CloseButton, MinimizeButton, TitleLabel, Buttons, Handler, Menus = nil, nil, nil, nil, nil, nil, nil, nil
    pcall(function() if gui then gui:Destroy() end end)
    local g = getgenv and getgenv()
    if g and g.ArcticScreenGui == gui then g.ArcticScreenGui = nil end
end

local function Start(A, B)
    -- Reinjection must stop the old runtime, not merely delete its window.
    local g = getgenv and getgenv()
    if g and type(g.SUR_unload) == "function" then pcall(g.SUR_unload) end
    if ScreenGui then UIDestroy() end
    UIGeneration = UIGeneration + 1
    UIClosed = false
    local IgnoreDuplicates = false

    -- FIX: was pcall(function() if B["ColorTheme"]... end) which silently
    -- swallowed ALL errors. Replaced with proper type-check.
    if type(B) == "table" then
        if B["ColorTheme"] then
            DefaultColor = B["ColorTheme"]
        end
        if B["IgnoreDuplicates"] then
            IgnoreDuplicates = true
        end
    end

    if not IgnoreDuplicates then
        pcall(function()
            for _, v in ipairs(game:GetService("CoreGui"):GetChildren()) do
                if v.Name == A and v:IsA("ScreenGui") then v:Destroy() end
            end
        end)
    end

    -- ── UI Construction ──────────────────────────────────────
    ScreenGui    = Instance.new("ScreenGui")
    Frame        = Instance.new("Frame")
    Hotbar       = Instance.new("Frame")
    CloseButton  = Instance.new("ImageButton")
    MinimizeButton = Instance.new("ImageButton")
    TitleLabel   = Instance.new("TextLabel")
    local UICorner     = Instance.new("UICorner")
    Buttons      = Instance.new("Frame")
    Handler      = Instance.new("ScrollingFrame")
    local UICorner_2   = Instance.new("UICorner")
    Menus        = Instance.new("Frame")
    local UICorner_3   = Instance.new("UICorner")
    local UIListLayout = Instance.new("UIListLayout")

    ScreenGui.Name = A
    ScreenGui.ResetOnSpawn = false
    local function tryParent(parent)
        if not parent then return false end
        return pcall(function() ScreenGui.Parent = parent end)
    end
    local parented = false
    if gethui then
        local ok, parent = pcall(gethui)
        if ok then parented = tryParent(parent) end
    end
    if not parented then
        local ok, parent = pcall(function() return game:GetService("CoreGui") end)
        if ok then parented = tryParent(parent) end
    end
    if not parented then
        local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui", 5)
        parented = tryParent(playerGui)
    end
    if not parented then error("No writable GUI parent") end
    if not IgnoreDuplicates then
        for _, other in ipairs(ScreenGui.Parent:GetChildren()) do
            if other ~= ScreenGui and other.Name == A and other:IsA("ScreenGui") then other:Destroy() end
        end
    end
    pcall(function() getgenv().ArcticScreenGui = ScreenGui end)
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    Frame.Parent = ScreenGui
    Frame.BackgroundColor3 = Color3.fromRGB(13, 13, 16)
    Frame.BorderSizePixel = 0
    Frame.Position = UDim2.new(0.311278194, 0, 0.288372099, 0)
    Frame.Size = UDim2.new(0, 501, 0, 273)

    Hotbar.Name = "Hotbar"
    Hotbar.Parent = Frame
    Hotbar.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    Hotbar.BorderSizePixel = 0
    Hotbar.Size = UDim2.new(0, 501, 0, 27)

    CloseButton.Name = "CloseButton"
    CloseButton.Parent = Hotbar
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.BackgroundTransparency = 1.000
    CloseButton.BorderSizePixel = 0
    CloseButton.Position = UDim2.new(0.944111764, 0, 0.111111104, 0)
    CloseButton.Size = UDim2.new(0, 20, 0, 20)
    CloseButton.Image = "rbxassetid://3944676352"

    -- minimize: hides the window only. Close kills the whole script.
    MinimizeButton.Name = "MinimizeButton"
    MinimizeButton.Parent = Hotbar
    MinimizeButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeButton.BackgroundTransparency = 1.000
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.Position = UDim2.new(0.893218, 0, 0.111111104, 0)
    MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
    MinimizeButton.Image = "rbxassetid://3944680095"


    TitleLabel.Parent = Hotbar
    TitleLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.BackgroundTransparency = 1.000
    TitleLabel.BorderSizePixel = 0
    TitleLabel.Position = UDim2.new(0.021956088, 0, 0, 0)
    TitleLabel.Size = UDim2.new(0, 159, 0, 27)
    TitleLabel.Font = Enum.Font.Gotham
    TitleLabel.Text = A
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 14.000
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    UICorner.CornerRadius = UDim.new(0, 2)
    UICorner.Parent = Hotbar

    Buttons.Name = "Buttons"
    Buttons.Parent = Frame
    Buttons.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
    Buttons.BorderSizePixel = 0
    Buttons.Position = UDim2.new(0, 0, 0.0989011005, 0)
    Buttons.Size = UDim2.new(0, 149, 0, 246)

    Handler.Name = "Handler"
    Handler.Parent = Buttons
    Handler.Active = true
    Handler.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Handler.BackgroundTransparency = 1.000
    Handler.BorderSizePixel = 0
    Handler.Position = UDim2.new(0, 0, 0.0243902449, 0)
    Handler.Size = UDim2.new(0, 149, 0, 240)
    Handler.ScrollBarThickness = 0
    Handler.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Handler.CanvasSize = UDim2.new(0, 0, 0, 0)
    Handler.ScrollBarThickness = 4

    UIListLayout.Parent = Handler
    UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 4)

    UICorner_2.CornerRadius = UDim.new(0, 2)
    UICorner_2.Parent = Buttons

    Menus.Name = "Menus"
    Menus.Parent = Frame
    Menus.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Menus.BackgroundTransparency = 1.000
    Menus.BorderSizePixel = 0
    Menus.Position = UDim2.new(0.297405183, 0, 0.0989011005, 0)
    Menus.Size = UDim2.new(0, 352, 0, 246)

    UICorner_3.CornerRadius = UDim.new(0, 2)
    UICorner_3.Parent = Frame

    -- ── Drag Logic (attached to Hotbar so content area stays clickable) ──
    local dragging  = false
    local dragInput, dragStart, startPos

    local function updateDrag(input)
        local delta = input.Position - dragStart
        TweenServ:Create(Frame, TweenInfo.new(0.01, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                 startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        }):Play()
    end

    -- FIX: drag on Hotbar only (was on whole Frame which ate clicks on content)
    UIConnect(Hotbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = Frame.Position
            local ended
            ended = UIConnect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    UIDisconnect(ended)
                end
            end)
        end
    end)

    UIConnect(Hotbar.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UIConnect(UIS.InputChanged, function(input)
        if input == dragInput and dragging then
            updateDrag(input)
        end
    end)

    -- CLOSE = full unload: stop every farm loop, then destroy the GUI.
    -- Hiding it (the old behaviour) left the farms running in the dark.
    UIConnect(CloseButton.MouseButton1Down, function()
        pcall(function()
            local g = getgenv and getgenv()
            if g and g.SUR_unload then g.SUR_unload() end
        end)
        UIDestroy()
    end)

    -- MINIMIZE = hide only
    UIConnect(MinimizeButton.MouseButton1Down, function()
        if Frame and ScreenGui and ScreenGui.Parent then Frame.Visible = false end
    end)

    -- Toggle UI: default L; override with getgenv().ArcticUiHotkey = "Semicolon" etc. (Enum.KeyCode name)
    UIConnect(UIS.InputBegan, function(input, gameProcessed)
        if gameProcessed or not (Frame and ScreenGui and ScreenGui.Parent) then return end
        if UIS:GetFocusedTextBox() then return end
        local key = Enum.KeyCode.L
        pcall(function()
            local g = getgenv and getgenv() or nil
            local name = g and g.ArcticUiHotkey
            if type(name) == "string" and Enum.KeyCode[name] then
                key = Enum.KeyCode[name]
            end
        end)
        if input.KeyCode == key then
            Frame.Visible = not Frame.Visible
        end
    end)

    if g then g.SUR_unload = UIDestroy end
    -- ── Helper: build a colour-tracking indicator tween loop ──
end

local function MakeIndicatorLoop(indicator, getFlagFn)
    -- State changes paint directly; no coroutine per toggle survives deletion.
    local function paint()
        if UIClosed or not indicator.Parent then return end
        indicator.BackgroundColor3 = getFlagFn() and DefaultColor or Color3.fromRGB(10, 10, 13)
    end
    paint()
    return paint
end

-- ── Public API functions ──────────────────────────────────

-- Destroy an element inside the GUI by name (case-insensitive)
local function Destroy(Name)
    if UIClosed or not ScreenGui then return end
    local lower = string.lower(Name)
    for _, v in pairs(ScreenGui:GetDescendants()) do
        if string.lower(v.Name) == lower then
            UIForget(v)
            for _, child in ipairs(v:GetDescendants()) do UIForget(child) end
            v:Destroy()
            return
        end
    end
end

-- FIX: main script calls Delete() but lib only defined Destroy() — alias added
local function Delete(Name)
    Destroy(Name)
end

-- FIX: EditString was called in main script but never defined in lib.
-- Finds a Note element by its current name and renames both the container
-- and the inner TextLabel text so the display updates correctly.
local function EditString(OldText, NewText)
    if UIClosed or not ScreenGui then return end
    for _, v in pairs(ScreenGui:GetDescendants()) do
        if v.Name == OldText then
            v.Name = NewText
            -- Notes store the visible text in their first TextLabel child
            local inner = v:FindFirstChildOfClass("TextLabel")
            if inner then
                inner.Text = NewText
            end
            return
        end
    end
end

-- FIX: Fill() was called in main script (Teleport TextBoxes) but never defined.
-- Returns the full player name matching the given partial prefix (case-insensitive).
local function Fill(Partial)
    Partial = tostring(Partial or ""):match("^%s*(.-)%s*$")
    if Partial == "" then return Partial end
    local lower = string.lower(Partial)
    for _, player in pairs(game:GetService("Players"):GetPlayers()) do
        if string.lower(player.Name):sub(1, #Partial) == lower then
            return player.Name
        end
    end
    return Partial  -- fallback: return as-is
end

local function CreateMenu(Name)
    if UIClosed or not Menus or not Handler then return end
    ToggleStates[Name] = ToggleStates[Name] or {}
    local ScrollingFrame = Instance.new("ScrollingFrame")
    local MenuList       = Instance.new("UIListLayout")

    ScrollingFrame.Parent = Menus
    ScrollingFrame.Name = Name
    ScrollingFrame.Active = true
    ScrollingFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ScrollingFrame.BackgroundTransparency = 1.000
    ScrollingFrame.BorderSizePixel = 0
    ScrollingFrame.Position = UDim2.new(0, 0, 0.024390243, 0)
    ScrollingFrame.Size = UDim2.new(0, 352, 0, 240)
    ScrollingFrame.ScrollBarThickness = 0
    ScrollingFrame.Visible = false
    ScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollingFrame.ScrollBarThickness = 4

    MenuList.Parent = ScrollingFrame
    MenuList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    MenuList.SortOrder = Enum.SortOrder.LayoutOrder
    MenuList.Padding = UDim.new(0, 4)

    local TextButton = Instance.new("TextButton")
    local BtnCorner  = Instance.new("UICorner")

    TextButton.Name = Name
    TextButton.Parent = Handler
    TextButton.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
    TextButton.BorderSizePixel = 0
    TextButton.Position = UDim2.new(0.0604026839, 0, 0, 0)
    TextButton.Size = UDim2.new(0, 131, 0, 23)
    TextButton.Font = Enum.Font.Gotham
    TextButton.Text = Name
    TextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextButton.TextSize = 12.000

    BtnCorner.CornerRadius = UDim.new(0, 2)
    BtnCorner.Parent = TextButton

    local isFirst = true
    for _, ch in pairs(Menus:GetChildren()) do
        if ch:IsA("ScrollingFrame") and ch ~= ScrollingFrame then
            isFirst = false
            break
        end
    end
    ScrollingFrame.Visible = isFirst
    if isFirst then
        TextButton.BackgroundColor3 = DefaultColor
    end

    UIConnect(TextButton.MouseButton1Down, function()
        for _, v in pairs(Menus:GetChildren()) do
            if v:IsA("ScrollingFrame") then
                v.Visible = (v.Name == TextButton.Text)
            end
        end
        for _, b in pairs(Handler:GetChildren()) do
            if b:IsA("TextButton") then
                b.BackgroundColor3 = (b == TextButton and DefaultColor or Color3.fromRGB(17, 17, 17))
            end
        end
    end, TextButton)
    return ScrollingFrame
end

local function CreateButton(Name, MenuName, Callback)
    if UIClosed or not Menus then return end
    local Regular  = Instance.new("TextButton")
    local Corner   = Instance.new("UICorner")
    local BtnLabel = Instance.new("TextLabel")

    Regular.Name = Name
    Regular.Parent = Menus[MenuName]
    Regular.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
    Regular.BorderSizePixel = 0
    Regular.Position = UDim2.new(0.0454545468, 0, 0, 0)
    Regular.Size = UDim2.new(0, 336, 0, 23)
    Regular.Font = Enum.Font.SourceSans
    Regular.Text = ""
    Regular.TextColor3 = Color3.fromRGB(255, 255, 255)
    Regular.TextSize = 12.000

    Corner.CornerRadius = UDim.new(0, 2)
    Corner.Parent = Regular

    BtnLabel.Parent = Regular
    BtnLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    BtnLabel.BackgroundTransparency = 1.000
    BtnLabel.BorderColor3 = Color3.fromRGB(27, 42, 53)
    BtnLabel.BorderSizePixel = 0
    BtnLabel.Position = UDim2.new(0.0386904776, 0, 0, 0)
    BtnLabel.Size = UDim2.new(0, 310, 0, 23)
    BtnLabel.Font = Enum.Font.Gotham
    BtnLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    BtnLabel.Text = Name
    BtnLabel.TextSize = 12.000
    BtnLabel.TextXAlignment = Enum.TextXAlignment.Left

    UIConnect(Regular.MouseButton1Down, function()
        UICall(Callback)
    end, Regular)
    return Regular
end

local function CreateTextBox(Name, MenuName, Options, Callback)
    if UIClosed or not Menus then return end
    Options = Options or {}

    local Container = Instance.new("TextButton")
    local CornerA   = Instance.new("UICorner")
    local LabelEl   = Instance.new("TextLabel")
    local InputBox  = Instance.new("TextBox")
    local CornerB   = Instance.new("UICorner")

    Container.Name = Name
    Container.Parent = Menus[MenuName]
    Container.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
    Container.BorderSizePixel = 0
    Container.Position = UDim2.new(0.0454545468, 0, 0, 0)
    Container.Size = UDim2.new(0, 336, 0, 23)
    Container.Font = Enum.Font.SourceSans
    Container.Text = ""
    Container.TextColor3 = Color3.fromRGB(255, 255, 255)
    Container.TextSize = 12.000

    CornerA.CornerRadius = UDim.new(0, 2)
    CornerA.Parent = Container

    LabelEl.Parent = Container
    LabelEl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    LabelEl.BackgroundTransparency = 1.000
    LabelEl.BorderColor3 = Color3.fromRGB(27, 42, 53)
    LabelEl.BorderSizePixel = 0
    LabelEl.Position = UDim2.new(0.0386904776, 0, 0, 0)
    LabelEl.Size = UDim2.new(0, 148, 0, 23)
    LabelEl.Font = Enum.Font.Gotham
    LabelEl.TextColor3 = Color3.fromRGB(255, 255, 255)
    LabelEl.Text = Name
    LabelEl.TextSize = 12.000
    LabelEl.TextXAlignment = Enum.TextXAlignment.Left

    InputBox.Parent = Container
    InputBox.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    InputBox.Position = UDim2.new(0.565547585, 0, 0.130000234, 0)
    InputBox.Size = UDim2.new(0, 137, 0, 16)
    InputBox.Font = Enum.Font.Gotham
    InputBox.PlaceholderColor3 = Color3.fromRGB(255, 255, 255)
    -- FIX: was C["CustomText"] which would error when C is {} — safe indexing
    InputBox.PlaceholderText = Options["CustomText"] or "Text Here"
    InputBox.Text = ""
    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    InputBox.TextSize = 10.000
    InputBox.TextWrapped = true

    CornerB.CornerRadius = UDim.new(0, 4)
    CornerB.Parent = InputBox

    -- FIX: was table.find(C, "AutoUpdate") which searches array values,
    -- not dict keys — correct check is Options["AutoUpdate"]
    UIConnect(InputBox.FocusLost, function(enterPressed)
        UICall(Callback, InputBox.Text)
    end, Container)
    if Options["AutoUpdate"] then
        UIConnect(InputBox:GetPropertyChangedSignal("Text"), function()
            UICall(Callback, InputBox.Text)
        end, Container)
    else
        UIConnect(Container.MouseButton1Down, function()
            UICall(Callback, InputBox.Text)
        end, Container)
    end
    return Container
end

local function CreateToggle(Name, MenuName, Callback)
    if UIClosed or not Menus then return end
    local ToggleBtn   = Instance.new("TextButton")
    local CornerA     = Instance.new("UICorner")
    local ToggleLabel = Instance.new("TextLabel")
    local Indicator   = Instance.new("Frame")
    local CornerB     = Instance.new("UICorner")

    ToggleBtn.Name = Name
    ToggleBtn.Parent = Menus[MenuName]
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
    ToggleBtn.BorderSizePixel = 0
    ToggleBtn.Position = UDim2.new(0.0454545468, 0, 0, 0)
    ToggleBtn.Size = UDim2.new(0, 336, 0, 23)
    ToggleBtn.Font = Enum.Font.SourceSans
    ToggleBtn.Text = ""
    ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleBtn.TextSize = 12.000

    CornerA.CornerRadius = UDim.new(0, 2)
    CornerA.Parent = ToggleBtn

    ToggleLabel.Parent = ToggleBtn
    ToggleLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ToggleLabel.BackgroundTransparency = 1.000
    ToggleLabel.BorderColor3 = Color3.fromRGB(27, 42, 53)
    ToggleLabel.BorderSizePixel = 0
    ToggleLabel.Position = UDim2.new(0.0386904776, 0, 0, 0)
    ToggleLabel.Size = UDim2.new(0, 148, 0, 23)
    ToggleLabel.Font = Enum.Font.Gotham
    ToggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleLabel.TextSize = 12.000
    ToggleLabel.Text = Name
    ToggleLabel.TextXAlignment = Enum.TextXAlignment.Left

    Indicator.Parent = ToggleBtn
    Indicator.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    Indicator.Position = UDim2.new(0.758928597, 0, 0.130434781, 0)
    Indicator.Size = UDim2.new(0, 72, 0, 16)

    CornerB.CornerRadius = UDim.new(0, 2)
    CornerB.Parent = Indicator

    local state = { value = false, owner = ToggleBtn }
    ToggleStates[MenuName] = ToggleStates[MenuName] or {}
    ToggleStates[MenuName][Name] = state
    -- FIX: was an always-running loop that tweened every task.wait() frame.
    -- Direct painting keeps the indicator in sync with automatic stops.
    state.paint = MakeIndicatorLoop(Indicator, function() return state.value end)

    UIConnect(ToggleBtn.MouseButton1Down, function()
        local requested = not state.value
        local ok, actual = UICall(Callback, requested)
        if ok then
            local value = requested
            if type(actual) == "boolean" then value = actual end
            SetToggle(Name, MenuName, value)
        end
    end, ToggleBtn)
    return ToggleBtn
end

local function CreateNote(Text, MenuName)
    if UIClosed or not Menus then return end
    local UseScaled = string.len(Text) >= 42

    local Container  = Instance.new("TextLabel")
    local InnerLabel = Instance.new("TextLabel")
    local NoteCorner = Instance.new("UICorner")

    Container.Name = Text
    Container.Parent = Menus[MenuName]
    Container.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
    Container.Size = UDim2.new(0, 336, 0, 23)
    Container.Font = Enum.Font.SourceSans
    Container.Text = ""
    Container.TextColor3 = Color3.fromRGB(0, 0, 0)
    Container.TextSize = 14.000

    InnerLabel.Parent = Container
    InnerLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    InnerLabel.BackgroundTransparency = 1.000
    InnerLabel.BorderColor3 = Color3.fromRGB(27, 42, 53)
    InnerLabel.BorderSizePixel = 0
    InnerLabel.Position = UDim2.new(0.039, 0, 0, 0)
    InnerLabel.Size = UDim2.new(0, 310, 0, 23)
    InnerLabel.Font = Enum.Font.Gotham
    InnerLabel.Text = Text
    InnerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    InnerLabel.TextSize = 12.000
    InnerLabel.TextWrapped = true
    InnerLabel.TextScaled = UseScaled
    InnerLabel.TextXAlignment = Enum.TextXAlignment.Left
    InnerLabel.TextYAlignment = Enum.TextYAlignment.Center

    NoteCorner.CornerRadius = UDim.new(0, 2)
    NoteCorner.Parent = Container
    return Container
end

local function CreateTextBoxToggle(Name, MenuName, Options, Callback)
    if UIClosed or not Menus then return end
    Options = Options or {}

    local Container = Instance.new("TextButton")
    local CornerA   = Instance.new("UICorner")
    local LabelEl   = Instance.new("TextLabel")
    local InputBox  = Instance.new("TextBox")
    local CornerB   = Instance.new("UICorner")
    local Indicator = Instance.new("Frame")
    local CornerC   = Instance.new("UICorner")

    Container.Name = Name
    Container.Parent = Menus[MenuName]
    Container.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
    Container.BorderSizePixel = 0
    Container.Position = UDim2.new(0.0454545468, 0, 0, 0)
    Container.Size = UDim2.new(0, 336, 0, 23)
    Container.Font = Enum.Font.SourceSans
    Container.Text = ""
    Container.TextColor3 = Color3.fromRGB(255, 255, 255)
    Container.TextSize = 12.000

    CornerA.CornerRadius = UDim.new(0, 2)
    CornerA.Parent = Container

    LabelEl.Parent = Container
    LabelEl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    LabelEl.BackgroundTransparency = 1.000
    LabelEl.BorderColor3 = Color3.fromRGB(27, 42, 53)
    LabelEl.BorderSizePixel = 0
    LabelEl.Position = UDim2.new(0.0386904776, 0, 0, 0)
    LabelEl.Size = UDim2.new(0, 148, 0, 23)
    LabelEl.Font = Enum.Font.Gotham
    LabelEl.Text = Name
    LabelEl.TextColor3 = Color3.fromRGB(255, 255, 255)
    LabelEl.TextSize = 12.000
    LabelEl.TextXAlignment = Enum.TextXAlignment.Left

    InputBox.Parent = Container
    InputBox.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    InputBox.Position = UDim2.new(0.416738063, 0, 0.129999578, 0)
    InputBox.Size = UDim2.new(0, 108, 0, 16)
    InputBox.Font = Enum.Font.Gotham
    InputBox.PlaceholderColor3 = Color3.fromRGB(255, 255, 255)
    InputBox.PlaceholderText = Options["CustomText"] or "Text Here"
    InputBox.Text = ""
    InputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    InputBox.TextSize = 10.000
    InputBox.TextWrapped = true

    CornerB.CornerRadius = UDim.new(0, 2)
    CornerB.Parent = InputBox

    Indicator.Parent = Container
    Indicator.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    Indicator.Position = UDim2.new(0.758928597, 0, 0.130434781, 0)
    Indicator.Size = UDim2.new(0, 72, 0, 16)

    CornerC.CornerRadius = UDim.new(0, 2)
    CornerC.Parent = Indicator

    local state = { value = false, owner = Container }
    ToggleStates[MenuName] = ToggleStates[MenuName] or {}
    ToggleStates[MenuName][Name] = state
    state.paint = MakeIndicatorLoop(Indicator, function() return state.value end)

    -- FIX: was table.find(C, "AutoUpdate") — wrong for dict tables.
    if Options["AutoUpdate"] then
        UIConnect(Container.MouseButton1Down, function()
            local requested = not state.value
            local ok, actual = UICall(Callback, InputBox.Text, requested)
            if ok then
                local value = requested
                if type(actual) == "boolean" then value = actual end
                SetToggle(Name, MenuName, value)
            end
        end, Container)
        UIConnect(InputBox:GetPropertyChangedSignal("Text"), function()
            UICall(Callback, InputBox.Text)
        end, Container)
    else
        UIConnect(Container.MouseButton1Down, function()
            local requested = not state.value
            local ok, actual = UICall(Callback, InputBox.Text, requested)
            if ok then
                local value = requested
                if type(actual) == "boolean" then value = actual end
                SetToggle(Name, MenuName, value)
            end
        end, Container)
    end
    return Container
end

local function CreateSearchBar(MenuName)
    if UIClosed or not Menus then return end
    local SearchBar  = Instance.new("TextLabel")
    local CornerA    = Instance.new("UICorner")
    local SearchLbl  = Instance.new("TextLabel")
    local SearchBox  = Instance.new("TextBox")
    local CornerB    = Instance.new("UICorner")

    SearchBar.Name = "SearchBar"
    SearchBar.Parent = Menus[MenuName]
    SearchBar.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
    SearchBar.BorderSizePixel = 0
    SearchBar.Size = UDim2.new(0, 336, 0, 23)
    SearchBar.Font = Enum.Font.SourceSans
    SearchBar.Text = ""
    SearchBar.TextColor3 = Color3.fromRGB(0, 0, 0)
    SearchBar.TextSize = 14.000

    CornerA.CornerRadius = UDim.new(0, 2)
    CornerA.Parent = SearchBar

    SearchLbl.Parent = SearchBar
    SearchLbl.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    SearchLbl.BackgroundTransparency = 1.000
    SearchLbl.BorderColor3 = Color3.fromRGB(27, 42, 53)
    SearchLbl.BorderSizePixel = 0
    SearchLbl.Position = UDim2.new(0.0386904776, 0, 0, 0)
    SearchLbl.Size = UDim2.new(0, 148, 0, 23)
    SearchLbl.Font = Enum.Font.Gotham
    SearchLbl.Text = "Search"
    SearchLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    SearchLbl.TextSize = 12.000
    SearchLbl.TextXAlignment = Enum.TextXAlignment.Left

    SearchBox.Parent = SearchBar
    SearchBox.BackgroundColor3 = Color3.fromRGB(6, 6, 6)
    SearchBox.Position = UDim2.new(0.187571391, 0, 0.129999578, 0)
    SearchBox.Size = UDim2.new(0, 264, 0, 16)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.PlaceholderColor3 = Color3.fromRGB(255, 255, 255)
    SearchBox.PlaceholderText = "Search Here"
    SearchBox.Text = ""
    SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    SearchBox.TextSize = 10.000

    CornerB.CornerRadius = UDim.new(0, 4)
    CornerB.Parent = SearchBox

    -- FIX: original code created a fake LocalScript via Instance.new('LocalScript')
    -- which is completely non-functional in an executor (scripts can't run that way).
    -- Replaced with a direct signal connection that actually works.
    UIConnect(SearchBox:GetPropertyChangedSignal("Text"), function()
        local query      = string.lower(SearchBox.Text)
        local targetMenu = Menus[MenuName]
        if not targetMenu then return end
        for _, item in pairs(targetMenu:GetChildren()) do
            if item:IsA("GuiButton") and item ~= SearchBar then
                local lbl = item:FindFirstChildOfClass("TextLabel")
                if lbl then
                    if query ~= "" then
                        item.Visible = string.find(string.lower(lbl.Text), query, 1, true) ~= nil
                    else
                        item.Visible = true
                    end
                end
            end
        end
    end, SearchBar)
    return SearchBar
end

local function CreateNotification(Title, Text, Options)
    if UIClosed then return end
    local Sound    = "rbxassetid://4835664238"
    local Duration = 5

    if type(Options) == "table" then
        if Options["CustomSound"] then
            Sound = "rbxassetid://" .. tostring(Options["CustomSound"])
        end
        if Options["Duration"] then
            Duration = Options["Duration"]
        end
    end

    -- FIX: Sound instance was created but never cleaned up → memory leak
    local snd = Instance.new("Sound", game:GetService("Workspace"))
    snd.SoundId = Sound
    snd:Play()
    game:GetService("Debris"):AddItem(snd, Duration + 2)

    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title    = Title,
        Text     = Text,
        Duration = Duration,
    })
end

-- ══════════════════════════════════════════════════════════════════════════
-- Arctic — SUR (порт message.txt, доведённый до рабочего состояния)
--
-- ВАЖНО: это НЕ новый скрипт. Это ровно message.txt:
--   • те же меню в том же порядке;
--   • те же кнопки, тогглы, поля и подписи, один в один;
--   • та же библиотека Arctic (встроена выше, без HttpGet).
-- Изменена только внутренняя реализация — там, где игра переехала и старый
-- код молча не работал.
--
-- Что было мертво и почему (подробно — в docs/MESSAGE_FIXES.md):
--   1. loadstring(HttpGet("icebear.lol/.../LIB.txt")) — домен мёртв, скрипт не
--      запускался вообще. Библиотека теперь внутри файла.
--   2. StandEvents.M1 / Summon / <Move>:FireServer() — этих ремоутов в игре
--      больше НЕТ. Боевая часть (Boss Farm, Lair Farm, Quest Farm) не наносила
--      ни одного удара. Переведено на живой протокол StandEvents.Input.
--   3. Цикл "for i, v in pairs(CDgui.fortnite) ... else M1:FireServer()" —
--      на каждый НЕ-Punch элемент кулдаун-ги (десятки) летел отдельный удар.
--      Это был спам в пустоту, а не удар. Теперь один удар за тик.
--   4. firesignal(game.Players["polar_eXDAVH"]...) — чужой захардкоженный ник,
--      из-за него падало закрытие биржи. Теперь LP.PlayerGui + pcall.
--   5. NextMove(): "if UseArrow then" — глобал UseArrow не существует (есть
--      UseStandArrows), поэтому автопокупка стрел не срабатывала НИКОГДА.
--      Плюс UseChargedArrow vs UseChargedArrows — та же опечатка.
--   6. repeat task.wait() until Character:FindFirstChild(Tool) — вечное
--      зависание, если экипировка не удалась. Теперь с таймаутом.
--   7. Lair/Quest/Item: EditString("... "..Text, "... "..New) ломался, как
--      только текст расходился. Теперь подпись ищется по префиксу.
--   8. Тогглы фармов блокировали свой же колбэк (бесконечный while внутри
--      callback). Циклы вынесены в task.spawn.
--   9. Item Farm дёргал fireproximityprompt(nil), когда промпта нет — pcall
--      глотал ошибку, и луп крутился вхолостую. Теперь проверка + фолбэк.
--  10. Stand Farm: "break" выходил из while, оставляя тоггл включённым и
--      мёртвым. Теперь стоп с уведомлением.
--  11. Биржа: Item захватывался замыканием в task.spawn — покупка могла уйти
--      не тем предметом. Теперь локальная копия.
--
-- Оригинальная попытка мгновенного убийства оставлена за переключателем:
--      Workspace.Living.Boss.Humanoid.Health = 0
--   Это клиентская запись свойства. Серверный урон и награда ею не доказаны.
--   Переключатель "Instant Boss Kill (HP = 0)" по умолчанию ВЫКЛЮЧЕН.
-- ══════════════════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local PathfindingService= game:GetService("PathfindingService")
local Workspace         = game.Workspace
local UIS               = game:GetService("UserInputService")

local LP = Players.LocalPlayer

Start("Arctic")

-- Every asynchronous action belongs to this injection and one generation.
-- Turning OFF invalidates sleeping workers before another ON can start.
local Runtime = {
    alive = true, jobs = {}, connections = {}, cleanup = {},
    errors = {}, movement = nil, tasks = {}, heldInputs = {}, heldPrompts = {}, idleRelease = nil,
    equipment = nil, movementRevision = 0,
}

local function recordError(label, err)
    local text = tostring(label) .. ": " .. tostring(err)
    Runtime.errors[#Runtime.errors + 1] = text
    if #Runtime.errors > 20 then table.remove(Runtime.errors, 1) end
    UIReport(label, err)
end

local function jobActive(job)
    return Runtime.alive and (not job or (job.active and Runtime.jobs[job.name] == job))
end

local function runAsync(callback, ...)
    if not Runtime.alive then return nil end
    local args = { ... }
    local thread = task.spawn(function()
        if not Runtime.alive then return end
        local ok, err = pcall(callback, table.unpack(args))
        Runtime.tasks[coroutine.running()] = nil
        if not ok and Runtime.alive then recordError("Task", err) end
    end)
    if thread and coroutine.status(thread) ~= "dead" then Runtime.tasks[thread] = true end
    return thread
end

local function runConnect(event, callback)
    local connection = event:Connect(function(...)
        if not Runtime.alive then return end
        local thread = coroutine.running()
        Runtime.tasks[thread] = true
        local ok, err = pcall(callback, ...)
        Runtime.tasks[thread] = nil
        if not ok and Runtime.alive then recordError("Event", err) end
    end)
    for i = #Runtime.connections, 1, -1 do
        if not Runtime.connections[i].Connected then table.remove(Runtime.connections, i) end
    end
    Runtime.connections[#Runtime.connections + 1] = connection
    return connection
end

local function addCleanup(callback)
    Runtime.cleanup[#Runtime.cleanup + 1] = callback
end

local function jobStop(name)
    local job = Runtime.jobs[name]
    if not job then return end
    job.active = false
    if Runtime.equipment and Runtime.equipment.job == job then Runtime.equipment = nil end
    for held in pairs(Runtime.heldInputs) do
        if held.job == job then
            pcall(function()
                held.remote:FireServer({ State = "End", Key = held.key, Type = held.utype })
            end)
            Runtime.heldInputs[held] = nil
        end
    end
    for prompt, owner in pairs(Runtime.heldPrompts) do
        if owner == job then
            pcall(function() prompt:InputHoldEnd() end)
            Runtime.heldPrompts[prompt] = nil
        end
    end
    Runtime.jobs[name] = nil
    for connection in pairs(job.connections or {}) do pcall(function() connection:Disconnect() end) end
    job.connections = {}
    if Runtime.movement == job then Runtime.movement = nil end
    if job.onStop then
        local ok, err = pcall(job.onStop, job)
        if not ok then recordError(name .. " stop", err) end
    end
    local thread = job.thread
    if thread and thread ~= coroutine.running() and task.cancel then
        pcall(task.cancel, thread)
        Runtime.tasks[thread] = nil
    end
end

local function jobStart(name, moves, onStop, callback)
    local existing = Runtime.jobs[name]
    if existing and jobActive(existing) then return existing end
    jobStop(name)
    if not Runtime.alive then return nil end
    if moves and Runtime.movement then jobStop(Runtime.movement.name) end
    local job = { name = name, active = true, onStop = onStop, connections = {} }
    Runtime.jobs[name] = job
    if moves then
        Runtime.movementRevision = Runtime.movementRevision + 1
        Runtime.movement = job
        if Runtime.onMovementChanged then pcall(Runtime.onMovementChanged, name) end
    end
    job.thread = runAsync(function()
        local ok, err = pcall(callback, job)
        if not ok and jobActive(job) then recordError(name, err) end
        if Runtime.jobs[name] == job then jobStop(name) end
    end)
    return job
end

local function waitActive(seconds, job)
    local deadline = os.clock() + math.max(0, seconds or 0)
    repeat
        if not jobActive(job) then return false end
        task.wait(math.min(0.1, math.max(0, deadline - os.clock())))
    until os.clock() >= deadline
    return jobActive(job)
end

local function finiteNumber(value, minimum, maximum)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    if minimum and n < minimum then return nil end
    if maximum and n > maximum then return nil end
    return n
end

-- ══════════════════════════════════════════════════════════════════════════
-- CORE
-- ══════════════════════════════════════════════════════════════════════════

local function char() return LP.Character end
local function hum()
    local c = char()
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function hrp()
    local c = char()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function backpack() return LP:FindFirstChildOfClass("Backpack") end
local function events() return ReplicatedStorage:FindFirstChild("Events") end

local function living()
    return Workspace:FindFirstChild("Living")
end

local function npcFolder()
    local m = Workspace:FindFirstChild("Map")
    return m and m:FindFirstChild("NPCs")
end

local function notify(text, dur)
    if not Runtime.alive then return end
    pcall(function()
        CreateNotification("Arctic", tostring(text), { Duration = dur or 4 })
    end)
end

-- Подписи-статусы ("Selected Lair NPC: ...") ищем по префиксу, а не по
-- точному имени: EditString ломался, как только текст расходился на символ.
local function setNote(prefix, newText)
    local gui = ScreenGui
    if not Runtime.alive or not (gui and gui.Parent) then return false end
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text ~= ""
           and string.sub(tostring(d.Text), 1, #prefix) == prefix then
            d.Text = newText
            return true
        end
    end
    return false
end

-- ── БОЕВОЙ ПРОТОКОЛ ───────────────────────────────────────────────────────
-- Игра принимает только {State, Key, Type} через StandEvents.Input.
-- Старые StandEvents.M1 / Summon / <MoveName> удалены из игры.
local KEYMAP = {
    M1 = Enum.UserInputType.MouseButton1,
    M2 = Enum.UserInputType.MouseButton2,
    Q  = Enum.KeyCode.Q,
    E  = Enum.KeyCode.E,
    R  = Enum.KeyCode.R,
    F  = Enum.KeyCode.F,
    T  = Enum.KeyCode.T,
    Y  = Enum.KeyCode.Y,
    H  = Enum.KeyCode.H,
    X  = Enum.KeyCode.X,
    Z  = Enum.KeyCode.Z,
    G  = Enum.KeyCode.G,
    J  = Enum.KeyCode.J,
    N  = Enum.KeyCode.N,
}

local function standEvents()
    local c = char()
    return c and c:FindFirstChild("StandEvents")
end

-- Сервер берёт точку удара из клиентского "MousePos" (StandEvents.Info).
-- Пока фарм держит цель, отвечаем позицией её HumanoidRootPart — иначе удар
-- уходит в курсор и по боссу не попадает вообще.
local AimTarget = nil
local AimInfo = nil
local function setAimTarget(model)
    AimTarget = model
end
local function ensureAim()
    local se = standEvents()
    local info = se and se:FindFirstChild("Info")
    if not info or not info:IsA("RemoteFunction") then return false end
    if AimInfo == info then return true end
    AimInfo = info
    pcall(function()
        info.OnClientInvoke = function(what)
            if what == "MousePos" then
                local t = AimTarget
                local root = t and t.Parent and t:FindFirstChild("HumanoidRootPart")
                if root and root:IsA("BasePart") then return root.Position end
            end
            return nil
        end
    end)
    return AimInfo == info
end

local function press(key, hold, job)
    if not jobActive(job) then return false end
    ensureAim()
    local se = standEvents()
    local input = se and se:FindFirstChild("Input")
    if not (input and input:IsA("RemoteEvent")) then return false end
    local isMouse = (key == Enum.UserInputType.MouseButton1
                  or key == Enum.UserInputType.MouseButton2)
    local utype = isMouse and key or Enum.UserInputType.Keyboard
    local packetKey = isMouse and Enum.KeyCode.Unknown or key
    local held = { remote = input, key = packetKey, utype = utype, job = job }
    Runtime.heldInputs[held] = true
    local ok = pcall(function()
        input:FireServer({ State = "Begin", Key = packetKey, Type = utype })
    end)
    if ok and hold and hold > 0 then waitActive(hold, job) end
    pcall(function()
        input:FireServer({ State = "End", Key = packetKey, Type = utype })
    end)
    Runtime.heldInputs[held] = nil
    return ok and jobActive(job)
end

local function moveset()
    local se = standEvents()
    local info = se and se:FindFirstChild("Info")
    if not info then return {} end
    local ok, res = pcall(function() return info:InvokeServer("Moveset") end)
    if not (ok and type(res) == "table") then return {} end

    -- Accept only known keys, not arbitrary move names mapped to E.
    local out, seen, tables = {}, {}, {}
    local function add(value)
        local name
        if type(value) == "string" then
            name = value:match("([%w]+)$")
        elseif typeof(value) == "EnumItem" then
            name = value.Name
        elseif type(value) == "table" then
            if tables[value] then return end
            tables[value] = true
            add(value.Key or value.key)
            return
        end
        if name == "MouseButton1" then name = "M1" end
        if name == "MouseButton2" then name = "M2" end
        if name and KEYMAP[name] and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    for k, v in pairs(res) do
        if type(k) == "number" then add(v) else add(k); add(v) end
    end
    table.sort(out)
    return out
end

local function standCode()
    local d = LP:FindFirstChild("Data")
    local s = d and d:FindFirstChild("Stand")
    return s and tostring(s.Value) or nil
end

local function standName()
    local code = standCode()
    if code then
        local convert = ReplicatedStorage:FindFirstChild("StandNameConvert")
        local entry = convert and convert:FindFirstChild(code)
        return entry and entry:IsA("StringValue") and tostring(entry.Value) or code
    end
    -- фолбэк на HUD, как в оригинале
    local ok, txt = pcall(function()
        return LP.PlayerGui.PlayerGUI.ingame.Stats.StandName.Name_.TextLabel.Text
    end)
    if ok and txt and txt ~= "" then return txt end
    return "None"
end

local function standAttri()
    local d = LP:FindFirstChild("Data")
    local a = d and d:FindFirstChild("Attri")
    if a then return tostring(a.Value) end
    return "None"
end

local function hasStand()
    local n = standCode()
    return n ~= nil and n ~= "" and n ~= "None"
end

-- Оригинал проверял Character.Aura.Value и падал, если Aura нет.
-- Троттлинг: Q имеет кулдаун 1.5с, спамить его каждый тик бессмысленно.
local lastSummon = -math.huge
local function summonIfNeeded(job)
    local c = char()
    if not c then return end
    if c:FindFirstChild("Stand") then return end
    if not jobActive(job) or os.clock() - lastSummon < 1.7 then return end
    lastSummon = os.clock()
    press(Enum.KeyCode.Q, 0.1, job)
end

-- ══════════════════════════════════════════════════════════════════════════
-- FARM TIMING
-- Ограничения частоты операций уменьшают повторные записи и запросы.
-- По одному клиентскому дампу нельзя установить правила серверного античита.
-- Эти интервалы не гарантируют обход проверок или отсутствие кика.
-- ══════════════════════════════════════════════════════════════════════════
local STEALTH = {
    RepositionGap  = 0.85,   -- мин. пауза между записями CFrame
    RepositionDist = 1,      -- допуск позиции; не игнорирует Underneath на 4 студa
    UnderDepth     = 3,      -- максимум, на сколько закапываемся под босса
    TriggerMin     = 2.6,    -- рандомный интервал дёрганья Done
    TriggerMax     = 4.4,
    AttackMin      = 0.22,   -- рандомный интервал M1
    AttackMax      = 0.38,
    SessionMaxMin  = 25,     -- авто-стоп сессии
}

local lastReposition = 0
local lastTriggerAt  = 0
local nextTriggerAt  = 0
local sessionStart   = 0

-- Клиентская попытка HP=0. Успех здесь означает только локальный Health.
-- Репликация на сервер, награда и причина кика отдельно не подтверждены.
local lastKillAt = -math.huge
local function killTarget(model)
    if not Runtime.alive or not (model and model.Parent) then return false end
    if Players:GetPlayerFromCharacter(model) then return false end
    local h = model:FindFirstChildOfClass("Humanoid")
    if not h then return false end
    if os.clock() - lastKillAt < 0.35 then return false end
    lastKillAt = os.clock()

    pcall(function() h.Health = 0 end)                     -- ← ядро эксплойта
    if h.Health and h.Health > 0 then
        pcall(function() h:TakeDamage((h.MaxHealth or 100) * 100) end)
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Dead) end)
    end
    return (h.Health == 0)
end

-- Позиционирование. Главное отличие от message.txt: двигаемся ТОЛЬКО когда
-- реально отъехали, не чаще раза в 0.85с, и НЕ трогаем AssemblyLinearVelocity
-- Частые записи скорости не нужны для удержания позиции.
-- Закапываемся максимум на UnderDepth, иначе проваливаемся под пол карты.
local lastPositionModel, lastPositionDistance, lastPositionUnderneath
local function holdPosition(model, distance, underneath, job)
    local p, h = hrp(), hum()
    if not jobActive(job) or not (model and model.Parent and p and h and h.Health > 0) then return false end
    local t = model:FindFirstChild("HumanoidRootPart")
    if not (t and t:IsA("BasePart")) then return false end
    distance = finiteNumber(distance, 0.5, 100) or 4
    local depth = underneath and math.min(distance, STEALTH.UnderDepth) or 0
    local want = t.CFrame * CFrame.new(0, -depth, distance)
    local modeChanged = lastPositionModel ~= model or lastPositionDistance ~= distance or lastPositionUnderneath ~= underneath
    local facing = (p.CFrame.LookVector - want.LookVector).Magnitude < 0.1
    if not modeChanged and facing and (p.Position - want.Position).Magnitude < STEALTH.RepositionDist then return true end
    if not modeChanged and os.clock() - lastReposition < STEALTH.RepositionGap then return false end
    lastReposition = os.clock()
    lastPositionModel, lastPositionDistance, lastPositionUnderneath = model, distance, underneath
    local ok = pcall(function() p.CFrame = want end)
    return ok and jobActive(job)
end

-- One bounded approach, never a guessed or stale NPC destination.
local lastApproach = -math.huge
local function approach(model, distance, job)
    local p = hrp()
    if not jobActive(job) or not (model and model.Parent and p) then return false end
    local t = model:FindFirstChild("HumanoidRootPart")
    if not t then return false end
    if (p.Position - t.Position).Magnitude <= distance then return true end
    if os.clock() - lastApproach < 1.2 then return false end
    lastApproach = os.clock()
    return pcall(function() p.CFrame = t.CFrame * CFrame.new(0, 0, distance) end)
end

-- Небольшой разброс интервалов ограничивает повторные действия.
local function jitter(min, max)
    return min + math.random() * (max - min)
end

-- Поиск лейр-босса.
--
-- ЖЕЛЕЗНОЕ ПРАВИЛО: только Workspace.Living.Boss. Никаких эвристик.
-- В Workspace.Living лежат МИРОВЫЕ боссы (Jotaro Over Heaven, JohnnyJoestar,
-- Alternate Jotaro Part 4) — те самые, что в Boss Farm. Любая попытка
-- «угадать» босса по имени или по факту появления хватает их, и фарм
-- уезжает из лейра в обычный мир убивать всё подряд.
--
-- Оригинальный message.txt верил ровно в имя "Boss" — и был прав.
local function findLairBoss()
    local L = living()
    if not L then return nil end

    local b = L:FindFirstChild("Boss")
    if not b or Players:GetPlayerFromCharacter(b) then return nil end

    local h = b:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return nil end

    return b
end

-- ── настройки фармов (общие, как в оригинале) ─────────────────────────────
local AllMovesets   = {}
local ClearMoves    = {}
local UseCustomMoves = false

local function attackStep(job)
    if not jobActive(job) then return false end
    summonIfNeeded(job)
    if not jobActive(job) then return false end
    if UseCustomMoves and #AllMovesets > 0 then
        local name = AllMovesets[math.random(1, #AllMovesets)]
        return press(KEYMAP[name], 0.05, job)
    end
    return press(Enum.UserInputType.MouseButton1, 0.03, job)
end

-- ── предметы / экипировка ─────────────────────────────────────────────────
local function equipmentAcquire(job)
    local current = Runtime.equipment
    if current then return nil end
    local owner = { job = job, thread = coroutine.running() }
    Runtime.equipment = owner
    return owner
end

local function equipmentRelease(owner)
    if Runtime.equipment == owner then Runtime.equipment = nil end
end
addCleanup(function() Runtime.equipment = nil end)

-- A consumable owns equipment until confirmation, cancellation or timeout.
-- This also keeps Auto Umbrella from unequipping a delayed consumable.
local function useToolName(name, job, beforeUse)
    if not job and Runtime.movement then jobStop(Runtime.movement.name) end
    local c, h, bp = char(), hum(), backpack()
    if not jobActive(job) or not (c and h and h.Health > 0) then return false end
    local tool = (bp and bp:FindFirstChild(name)) or c:FindFirstChild(name)
    if not (tool and tool:IsA("Tool")) then notify("No " .. tostring(name) .. " in inventory", 3); return false end
    local inherited = Runtime.equipment
    local owned = inherited and inherited.job == job and inherited.thread == coroutine.running()
    local owner = owned and inherited or equipmentAcquire(job)
    if not owner then notify("Another item-use operation owns equipment", 3); return false end
    local usesStandArrow = name == "Stand Arrow" or name == "Charged Arrow" or name == "Requiem Arrow" or name == "Kars Mask"
    local removesStand = name == "Rokakaka" or name == "Rotten Rokakaka"
    local hadStand = hasStand()
    local initialStand = standCode()
    local ok, used = pcall(function()
        if tool.Parent == bp then h:EquipTool(tool) end
        local equipDeadline = os.clock() + 3
        while tool.Parent ~= c and jobActive(job) and char() == c and h.Health > 0 and os.clock() < equipDeadline do
            if beforeUse and not beforeUse() then return false end
            if not waitActive(0.05, job) then return false end
        end
        if not jobActive(job) or char() ~= c or h.Health <= 0 or tool.Parent ~= c then return false end
        if beforeUse and not beforeUse() then return false end
        local use = tool:FindFirstChild("Use")
        local ev = events()
        local useItem = ev and ev:FindFirstChild("UseItem")
        if use and use:IsA("RemoteEvent") then use:FireServer(); return true end
        tool:Activate()
        if not jobActive(job) or char() ~= c or h.Health <= 0 then return false end
        if useItem and useItem:IsA("RemoteEvent") then useItem:FireServer() end
        return true
    end)
    if ok and used == true and not owned and (usesStandArrow or removesStand) then
        local deadline = os.clock() + 8
        while Runtime.alive and Runtime.equipment == owner and char() == c and h.Health > 0 and os.clock() < deadline do
            local changed = standCode() ~= initialStand or (removesStand and hadStand and not hasStand())
                or (usesStandArrow and not hadStand and hasStand()) or tool.Parent == nil
            if changed or not waitActive(0.1, job) then break end
        end
    end
    if not owned then equipmentRelease(owner) end
    if not ok then notify("Could not use " .. tostring(name) .. ": " .. tostring(used), 4); return false end
    return used == true
end

local function fireProximity(prompt, job)
    if not jobActive(job) or not (prompt and prompt.Parent and prompt:IsA("ProximityPrompt")) then return false end
    if fireproximityprompt and pcall(fireproximityprompt, prompt) then return jobActive(job) end
    local began = pcall(function() prompt:InputHoldBegin() end)
    if not began then return false end
    Runtime.heldPrompts[prompt] = job or true
    local complete = waitActive((tonumber(prompt.HoldDuration) or 0.5) + 0.05, job)
    pcall(function() prompt:InputHoldEnd() end)
    Runtime.heldPrompts[prompt] = nil
    return complete
end

local function webhookSend(url, payload)
    if not Runtime.alive or not url or url == "" then return false end
    local req = http_request or request or HttpPost or (syn and syn.request)
    if not req then return false end
    local body = HttpService:JSONEncode(payload)
    return pcall(req, {
        Url = url, Method = "POST",
        Headers = { ["content-type"] = "application/json" },
        Body = body,
    })
end

local function tpToCF(cf, job)
    local p = hrp()
    if not Runtime.alive or not (p and cf) or (job and not jobActive(job)) then return false end
    -- A manual scripted move must not masquerade as a server entry transfer.
    -- Job-owned item/merchant movement keeps its own generation instead.
    if not job then
        Runtime.movementRevision = Runtime.movementRevision + 1
        if Runtime.onMovementChanged then pcall(Runtime.onMovementChanged, nil) end
        if Runtime.movement then
            Runtime.movement.cancelReason = "manual_teleport"
            jobStop(Runtime.movement.name)
        end
    end
    local moved = pcall(function() p.CFrame = cf end)
    if not moved then return false end
    local c = char()
    local st = c and c:FindFirstChild("Stand")
    local stRoot = st and st:FindFirstChild("HumanoidRootPart")
    if stRoot then pcall(function() stRoot.CFrame = cf end) end
    return true
end

local function tpToPosition(x, y, z)
    return tpToCF(CFrame.new(x, y, z))
end

-- ══════════════════════════════════════════════════════════════════════════
-- HOME
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Home")
CreateNote("Discord: https://discord.gg/mGfgkPN37X", "Home")
CreateNote("Contact: Polarrr#1912", "Home")

-- ══════════════════════════════════════════════════════════════════════════
-- LOCAL PLAYER
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("LocalPlayer")

CreateButton("Open Stand Storage", "LocalPlayer", function()
    local nf = npcFolder()
    local adm = nf and nf:FindFirstChild("admpn")
    local done = adm and adm:FindFirstChild("Done")
    if done and done:IsA("RemoteEvent") then
        pcall(function() done:FireServer() end)
    else
        notify("admpn.Done not found", 3)
    end
end)

CreateButton("Use Stand Arrow", "LocalPlayer", function()
    useToolName("Stand Arrow")
end)

CreateButton("Use Charged Arrow", "LocalPlayer", function()
    useToolName("Charged Arrow")
end)

CreateButton("Use Requiem Arrow", "LocalPlayer", function()
    useToolName("Requiem Arrow")
end)

CreateButton("Use Rokakaka", "LocalPlayer", function()
    useToolName("Rokakaka")
end)

CreateButton("Use Rotten Rokakaka", "LocalPlayer", function()
    useToolName("Rotten Rokakaka")
end)

local AutoUmbrella = false
CreateToggle("Auto Umbrella", "LocalPlayer", function(on)
    AutoUmbrella = on == true
    if not AutoUmbrella then jobStop("umbrella"); return false end

    -- FIX: цикл блокировал собственный колбэк; вынесен в task.spawn
    jobStart("umbrella", false, function()
        AutoUmbrella = false
        SetToggle("Auto Umbrella", "LocalPlayer", false)
    end, function(job)
        while jobActive(job) do
            local c, h, bp = char(), hum(), backpack()
            local tool = bp and bp:FindFirstChild("Umbrella")
            if not Runtime.equipment and c and h and h.Health > 0 and tool and not c:FindFirstChild("Umbrella") then h:EquipTool(tool) end
            if not waitActive(0.35, job) then break end
        end
    end)
    return AutoUmbrella
end)

local AntiAFK = false
CreateToggle("Anti AFK", "LocalPlayer", function(on)
    AntiAFK = on == true
    if not AntiAFK then jobStop("idle") end
    return AntiAFK
end)

runConnect(LP.Idled, function()
    if not AntiAFK then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    jobStart("idle", false, function()
        if Runtime.idleRelease then pcall(Runtime.idleRelease); Runtime.idleRelease = nil end
    end, function(job)
        Runtime.idleRelease = function() VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame) end
        VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame)
        waitActive(1, job)
    end)
end)
addCleanup(function()
    if Runtime.idleRelease then pcall(Runtime.idleRelease); Runtime.idleRelease = nil end
end)

-- ══════════════════════════════════════════════════════════════════════════
-- SHOPS
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Shops")
CreateNote("Selling", "Shops")

local SellKetchup = false
CreateToggle("Auto Sell Ketchup", "Shops", function(on)
    SellKetchup = on == true
    if not SellKetchup then jobStop("sell"); return false end
    local ev = events()
    local sell = ev and ev:FindFirstChild("SellKetchup")
    if not (sell and sell:IsA("RemoteEvent")) then
        SellKetchup = false
        notify("SellKetchup remote missing", 3)
        return false
    end
    jobStart("sell", false, function()
        SellKetchup = false
        SetToggle("Auto Sell Ketchup", "Shops", false)
    end, function(job)
        while jobActive(job) do
            local bp, c = backpack(), char()
            if (bp and bp:FindFirstChild("Ketchup")) or (c and c:FindFirstChild("Ketchup")) then
                sell:FireServer("Lots")
            end
            if not waitActive(0.5, job) then break end
        end
    end)
    return SellKetchup
end)

CreateNote("Autobuy Only Works For Level 200+", "Shops")

local Amount = 0
CreateTextBox("Count", "Shops", { CustomText = "Amount" }, function(A)
    local n = finiteNumber(A, 1, 100000)
    if not n then notify("Amount must be a positive finite number", 3); return end
    if n >= 1 then
        Amount = math.floor(n)
        notify("Amount Set To : " .. tostring(Amount), 3)
    else
        notify("Please Set The Number Above 0+", 3)
    end
end)

local AllItems = { "Rokakaka", "New Rokakaka", "Requiem Arrow", "Stand Arrow", "Dio's Diary", "Charged Arrow" }

-- FIX: Item захватывался замыканием внутри task.spawn (мог уйти не тот
-- предмет), плюс падало на захардкоженном нике "polar_eXDAVH".
local function buyFromStockMarket(itemName)
    if Runtime.movement then jobStop(Runtime.movement.name) end
    local c, h = char(), hum()
    if not (c and h) then return false end

    local ev = events()
    local sm = ev and ev:FindFirstChild("SM_Event")
    if not (sm and sm:IsA("RemoteEvent")) then notify("SM_Event missing", 3); return false end
    if Amount < 1 then notify("Set Count above 0 first", 3); return false end

    local nf = npcFolder()
    local market = nf and nf:FindFirstChild("StockMarket")
    local head = market and (market:FindFirstChild("Head") or market:FindFirstChild("HumanoidRootPart"))

    local oldPos = hrp() and hrp().CFrame
    if head then tpToCF(head.CFrame * CFrame.new(0, 3, 0)) end
    if not waitActive(0.4) or char() ~= c then return false end

    local sent = pcall(function() sm:FireServer("Buy", itemName, Amount) end)
    if not sent or not waitActive(0.4) then return false end

    local prompt = market and market:FindFirstChild("TalkToPrompt")
    if prompt then fireProximity(prompt) end
    if not waitActive(0.4) or char() ~= c then return false end

    if oldPos then tpToCF(oldPos) end

    -- FIX: было game.Players["polar_eXDAVH"].PlayerGui...
    pcall(function()
        local gui = LP.PlayerGui:FindFirstChild("newStockMarketGUI")
        local frame = gui and gui:FindFirstChild("SM_Frame")
        local exit = frame and frame:FindFirstChild("ExitButton")
        if exit then
            if firesignal then
                pcall(function() firesignal(exit.MouseButton1Click) end)
            elseif frame then
                -- без firesignal просто прячем окно, чтобы не ломать GUI
                frame.Visible = false
            end
        end
    end)
    return true
end

for i = 1, #AllItems do
    local Item = AllItems[i]
    CreateButton("Purchase: " .. Item, "Shops", function()
        buyFromStockMarket(Item)
    end)
end

-- ══════════════════════════════════════════════════════════════════════════
-- FARM SETTINGS
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Farm Settings")
CreateNote("Movesets", "Farm Settings")

-- FIX: раньше тут перебирались RemoteEvent'ы Character.StandEvents
-- (M1, Summon, Barrage...) — их в игре больше нет, список всегда был пуст.
-- Теперь берём реальные клавиши мувсета из Info:InvokeServer("Moveset").
CreateButton("Refresh Movesets", "Farm Settings", function()
    for _, name in ipairs(ClearMoves) do
        pcall(function() Delete(name) end)
    end
    ClearMoves = {}
    AllMovesets = {}

    local keys = moveset()
    if #keys == 0 then
        notify("Moveset empty - stand not summoned?", 4)
        return
    end

    for _, keyName in ipairs(keys) do
        local name = tostring(keyName)
        if KEYMAP[name] then
            ClearMoves[#ClearMoves + 1] = name
            CreateToggle(name, "Farm Settings", function(on)
                local at = table.find(AllMovesets, name)
                if on then
                    if not at then AllMovesets[#AllMovesets + 1] = name end
                elseif at then
                    table.remove(AllMovesets, at)
                end
                return on == true
            end)
        end
    end

    task.wait(0.2)
    notify(#ClearMoves .. " moves listed", 4)
end)

CreateToggle("Use Custom Moves", "Farm Settings", function(on)
    UseCustomMoves = on == true
    return UseCustomMoves
end)

-- ══════════════════════════════════════════════════════════════════════════
-- BOSS FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Boss Farm")
CreateNote("Settings", "Boss Farm")

local BossDistance = 4
CreateTextBox("Distance", "Boss Farm", {}, function(Input)
    local n = finiteNumber(Input, 0.5, 100)
    if n then BossDistance = n end
end)

local BossUnderneath = false
CreateToggle("Underneath", "Boss Farm", function(on)
    BossUnderneath = on == true
    return BossUnderneath
end)

-- Три тоггла ниже — один и тот же цикл. Оригинал копировал его трижды.
local BossOn = {}

local function bossFarm(modelName, label)
    CreateToggle(label, "Boss Farm", function(on)
        local name = "boss:" .. modelName
        BossOn[modelName] = on == true
        if not BossOn[modelName] then jobStop(name); return false end
        jobStart(name, true, function()
            BossOn[modelName] = false
            SetToggle(label, "Boss Farm", false)
        end, function(job)
            while jobActive(job) do
                local L = living()
                local boss = L and L:FindFirstChild(modelName)
                local h = boss and boss:FindFirstChildOfClass("Humanoid")
                if boss and h and h.Health > 0 and not Players:GetPlayerFromCharacter(boss) then
                    while jobActive(job) and boss.Parent == L and h.Health > 0 do
                        setAimTarget(boss)
                        if holdPosition(boss, BossDistance, BossUnderneath, job) then
                            killTarget(boss)
                            attackStep(job)
                        end
                        if not waitActive(jitter(STEALTH.AttackMin, STEALTH.AttackMax), job) then break end
                    end
                end
                if not waitActive(0.5, job) then break end
            end
        end)
        return BossOn[modelName] == true
    end)
end

bossFarm("Jotaro Over Heaven",       "Farm: Jotaro Over Heaven")
bossFarm("JohnnyJoestar",            "Farm: Johnny Joestar")
bossFarm("Alternate Jotaro Part 4",  "Farm: Jotaro Part 4")

-- ══════════════════════════════════════════════════════════════════════════
-- LAIR FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Lair Farm")
CreateNote("Selected Lair NPC: None", "Lair Farm")
CreateNote("Lair status: idle", "Lair Farm")

CreateButton("Tutorial", "Lair Farm", function()
    notify("Step 1 (Quest Selection), Stand Near Lair NPC And Press 'Select Lair NPC'", 6)
end)

local SelectedLairNPC
local SelectedLairNPCText = "None"
local stopLairSelection

CreateButton("Select Lair NPC", "Lair Farm", function()
    local c, p = char(), hrp()
    local nf = npcFolder()
    if not (c and p and nf) then return end

    -- БЛИЖАЙШИЙ, а не последний в списке (в оригинале перебор оставлял
    -- случайного NPC, если рядом стояло двое).
    local best, bestDist = nil, 15
    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        local done = v:FindFirstChild("Done")
        if root and done and done:IsA("RemoteEvent") then
            local d = (p.Position - root.Position).Magnitude
            if d < bestDist then best, bestDist = v, d end
        end
    end
    if not best then
        notify("No Lair NPC within 15 studs", 4)
        return
    end

    do
        local v = best
        local head = v:FindFirstChild("Head")
        local main = head and head:FindFirstChild("Main")
        local txt = main and main:FindFirstChild("Text")
        local pretty = (txt and txt.Text) or v.Name

        if stopLairSelection then stopLairSelection() end
        SelectedLairNPC = v
        SelectedLairNPCText = pretty
        setNote("Selected Lair NPC:", "Selected Lair NPC: " .. pretty)
        notify("Lair NPC: " .. pretty, 3)
    end
end)

local LairDistance = 4
CreateNote("Farming Position", "Lair Farm")
CreateTextBox("Set Distance: ", "Lair Farm", { CustomText = "Default: 4" }, function(Input)
    local n = finiteNumber(Input, 0.5, 100)
    if n then LairDistance = n end
end)

local Underneath = false
CreateToggle("Underneath", "Lair Farm", function(on)
    Underneath = on == true
    return Underneath
end)

-- ЯДРО ЭКСПЛОЙТА: HP босса выставляется в 0 с клиента.
-- По умолчанию ВЫКЛЮЧЕН. В предыдущем прогоне наблюдался kick 267,
-- но связь конкретной записи с серверной проверкой не установлена.
local InstantBossKill = false
CreateNote("HP write is local; server kill unverified. Off by default.", "Lair Farm")
CreateToggle("Instant Boss Kill (HP = 0)", "Lair Farm", function(on)
    InstantBossKill = on == true
    notify("instant kill " .. (InstantBossKill and "ON" or "off"), 3)
    return InstantBossKill
end)

local LairArenaRadius = 500
-- Done is sent only to the explicitly selected NPC, while still in range.
-- A client snapshot does not prove that any other NPC is a lair provider.
local function selectedLairReady()
    local nf = npcFolder()
    local npc = SelectedLairNPC
    local root = npc and npc:FindFirstChild("HumanoidRootPart")
    local done = npc and npc:FindFirstChild("Done")
    return npc and npc.Parent == nf and root and done and done:IsA("RemoteEvent")
end

local function TriggerLair(force, job)
    if not jobActive(job) or not selectedLairReady() then return false end
    local p, h = hrp(), hum()
    local root = SelectedLairNPC:FindFirstChild("HumanoidRootPart")
    if not (p and h and h.Health > 0 and root) then return false end
    -- Как в исходном message.txt: запрос уходит с любой дистанции.
    -- Серверная сторона сама решает, телепортировать игрока в лейр.
    if not force and os.clock() < nextTriggerAt then return false end
    -- Квест берётся ДО телепорта: NPC с QuestDone сначала выдаёт задание,
    -- только потом Done уводит в лейр. Без этого босс бьётся вне квеста.
    local questDone = SelectedLairNPC:FindFirstChild("QuestDone")
    if questDone and questDone:IsA("RemoteEvent") then
        pcall(function() questDone:FireServer() end)
        if job then waitActive(0.35, job) end
    end
    local sent = pcall(function() SelectedLairNPC.Done:FireServer() end)
    if sent then
        lastTriggerAt = os.clock()
        nextTriggerAt = os.clock() + jitter(STEALTH.TriggerMin, STEALTH.TriggerMax)
    end
    return sent
end

local ShortPause = false
CreateToggle("Use Pausing", "Lair Farm", function(on)
    ShortPause = on == true
    return ShortPause
end)

local PauseTimer = 1
CreateTextBox("Pause Length", "Lair Farm", {}, function(Input)
    local n = finiteNumber(Input, 0, 300)
    if n then PauseTimer = n end
end)

local StartLairFarming = false
local LairRestarts = 0
local LairRestartToken = { cancelled = false }
local LairState = {
    phase = "idle", stopReason = nil, detail = nil, anchor = nil, origin = nil,
    entrySent = false, entryAt = nil, arrival = nil, target = nil, targetRoot = nil, targetHum = nil,
    context = nil, probe = nil, trace = {},
}

local function lairStatus(phase, reason, detail)
    local changed = LairState.phase ~= phase or LairState.stopReason ~= reason or LairState.detail ~= detail
    LairState.phase, LairState.stopReason, LairState.detail = phase, reason, detail
    setNote("Lair status:", "Lair status: " .. phase .. (detail and (" — " .. detail) or ""))
    if changed then
        local entry = { time = os.clock(), phase = phase, reason = reason, detail = detail }
        LairState.trace[#LairState.trace + 1] = entry
        if #LairState.trace > 24 then table.remove(LairState.trace, 1) end
        print("[Arctic SUR][Lair] " .. phase .. (reason and (" / " .. reason) or "") .. (detail and (" / " .. detail) or ""))
    end
end

-- Only one exact live Living.Boss in the anchored arena; no world-name fallback.
-- Entry may correlate one observed arrival with the captured successful Done.
-- That client correlation is not proof of server arena ownership.
local function arenaBoss(anchor)
    local L = living()
    if not L then return nil end
    local found, foundRoot, foundHum
    for _, b in ipairs(L:GetChildren()) do
        if b:IsA("Model") and b.Name == "Boss" and not Players:GetPlayerFromCharacter(b) then
            local h, root = b:FindFirstChildOfClass("Humanoid"), b:FindFirstChild("HumanoidRootPart")
            if h and root and root:IsA("BasePart") and h.Health > 0 and (root.Position - anchor).Magnitude <= LairArenaRadius then
                if found then return nil, "boss_ambiguous" end
                found, foundRoot, foundHum = b, root, h
            end
        end
    end
    return found, nil, foundRoot, foundHum
end

local function lairExact(context)
    local b, root, h = context.target, context.targetRoot, context.targetHum
    return b and b.Parent == living() and b.Name == "Boss" and b:IsA("Model")
        and not Players:GetPlayerFromCharacter(b) and root and root.Parent == b and root:IsA("BasePart")
        and h and h.Parent == b and b:FindFirstChild("HumanoidRootPart") == root and b:FindFirstChildOfClass("Humanoid") == h
end

local function clearLairContext()
    local context = LairState.context
    if context and context.healthConnection then
        context.healthConnection:Disconnect()
        context.healthConnection = nil
    end
    if context and context.expiryThread and context.expiryThread ~= coroutine.running() and task.cancel then
        pcall(task.cancel, context.expiryThread)
        Runtime.tasks[context.expiryThread] = nil
    end
    LairState.context, LairState.probe = nil, nil
    LairState.target, LairState.targetRoot, LairState.targetHum = nil, nil, nil
    setAimTarget(nil)
end
addCleanup(clearLairContext)

local function lairResumeReady(p, h, character)
    local context = LairState.context
    if not context or not context.resumeUntil or os.clock() >= context.resumeUntil or os.clock() >= context.deadline
        or context.movementRevision ~= Runtime.movementRevision
        or (context.provider and context.provider ~= SelectedLairNPC)
        or context.character ~= character or context.playerRoot ~= p or context.playerHum ~= h
        or not context.anchor or not context.arrival or (not context.entrySent and not context.inplace)
        or (p.Position - context.anchor).Magnitude > LairArenaRadius + LairDistance or not lairExact(context)
        or (context.targetRoot.Position - context.anchor).Magnitude > LairArenaRadius then return false end
    local probe = context.probe
    return context.targetHum.Health > 0 or (probe and probe.model == context.target and probe.humanoid == context.targetHum
        and probe.root == context.targetRoot and probe.ownedZero and context.targetHum.Health == 0)
end

local function stopLairFarm(reason, detail)
    reason = reason or "user_off"
    StartLairFarming = false
    -- Явный OFF отменяет и ожидание респавна: приказ снят пользователем.
    if reason == "user_off" and LairRestartToken then LairRestartToken.cancelled = true end
    if reason == "user_off" and LairState.context and LairState.context.arrival and lairExact(LairState.context) then
        if not LairState.context.resumeUntil then
            LairState.context.resumeUntil = math.min(os.clock() + 120, LairState.context.deadline)
            if LairState.context.expiryThread and task.cancel then
                pcall(task.cancel, LairState.context.expiryThread)
                Runtime.tasks[LairState.context.expiryThread] = nil
            end
            local paused = LairState.context
            -- Runtime-owned passive expiry: releases only the matching paused
            -- observation; it never starts a job, moves, or sends a request.
            paused.expiryThread = runAsync(function()
                waitActive(math.max(0, paused.resumeUntil - os.clock()), nil)
                if Runtime.alive and LairState.context == paused and not Runtime.jobs.lair then clearLairContext() end
            end)
        end
    else
        clearLairContext()
    end
    if reason or LairState.phase ~= "stopped" then lairStatus("stopped", reason, detail or "Stopped") end
    local job = Runtime.jobs.lair
    if job then job.cancelReason = reason end
    jobStop("lair")
    SetToggle("Begin Lair Farm", "Lair Farm", false)
end
stopLairSelection = function() stopLairFarm("provider_changed", "Lair NPC reselected") end
-- Any newer movement owner or manual move discards a paused captured arena.
Runtime.onMovementChanged = function(name)
    if name ~= "lair" and LairState.context and not Runtime.jobs.lair then clearLairContext() end
end

local function startLairFarm(isRestart)
    if StartLairFarming and Runtime.jobs.lair then return true end
    if not isRestart then
        -- Ручной запуск открывает новый бюджет перезапусков.
        LairRestarts = 0
        LairRestartToken = { cancelled = false }
    end
    local p, h, character = hrp(), hum(), char()
    if not Runtime.alive or not (p and h and h.Health > 0) then
        clearLairContext()
        lairStatus("stopped", "not_ready", "Use a live character")
        return false
    end
    -- A valid captured arena resumes BEFORE asking for the distant/unstreamed
    -- entry provider. An unrelated nearby Boss is never resume evidence.
    local resume = lairResumeReady(p, h, character)
    local context = resume and LairState.context or nil
    if not resume then
        clearLairContext()
        local localBoss, localReason, localRoot = arenaBoss(p.Position)
        local providerReady = selectedLairReady()
        local providerRoot = providerReady and SelectedLairNPC:FindFirstChild("HumanoidRootPart") or nil
        local useInplace = false
        if providerReady then
            -- Исходное поведение: выбранный NPC принимает запрос с любой точки
            -- карты. Дистанция не блокирует вход.
        else
            -- Без выбора стартуем только по одной близкой точной Boss.
            if localReason then
                lairStatus("stopped", localReason, "Several exact Boss models here; select the nearby NPC")
                return false
            end
            if not (localBoss and (localRoot.Position - p.Position).Magnitude <= 100) then
                lairStatus("stopped", "not_ready", "Select a nearby Lair NPC")
                notify("You Are Missing A Step! Please Check Tutorial Then Re-Enable!")
                return false
            end
            useInplace = true
        end
        local now = os.clock()
        if useInplace then
            context = {
                provider = providerReady and SelectedLairNPC or nil,
                providerRoot = providerRoot,
                providerDone = providerReady and SelectedLairNPC:FindFirstChild("Done") or nil,
                character = character, playerRoot = p, playerHum = h, deadline = now + STEALTH.SessionMaxMin * 60,
                origin = p.Position, entrySent = false, entryAt = nil, entryDeadline = now + 40, arrival = p.Position,
                anchor = p.Position, target = nil, targetRoot = nil, targetHum = nil, probe = nil, healthConnection = nil,
                probes = setmetatable({}, { __mode = "k" }),
                movementRevision = Runtime.movementRevision, resumeUntil = nil, inplace = true,
            }
            LairState.context = context
            LairState.origin, LairState.anchor, LairState.arrival = context.origin, context.anchor, context.arrival
            LairState.entrySent, LairState.entryAt = false, nil
            LairState.trace = {}
            sessionStart, nextTriggerAt = now, 0
            lairStatus("fight", "inplace", "Exact local Boss; no entry request sent")
        else
            context = {
                provider = SelectedLairNPC, providerRoot = providerRoot, providerDone = SelectedLairNPC:FindFirstChild("Done"),
                character = character, playerRoot = p, playerHum = h, deadline = now + STEALTH.SessionMaxMin * 60,
                origin = p.Position, entrySent = false, entryAt = nil, entryDeadline = now + 40, arrival = nil,
                anchor = nil, target = nil, targetRoot = nil, targetHum = nil, probe = nil, healthConnection = nil,
                probes = setmetatable({}, { __mode = "k" }),
                movementRevision = Runtime.movementRevision, resumeUntil = nil,
            }
            LairState.context = context
            LairState.origin, LairState.anchor, LairState.arrival = context.origin, nil, nil
            LairState.entrySent, LairState.entryAt = false, nil
            LairState.trace = {}
            sessionStart, nextTriggerAt = now, 0
            lairStatus("entry", nil, "Sending one selected entry request; waiting for arrival")
        end
    else
        context.resumeUntil = nil
        if context.expiryThread and context.expiryThread ~= coroutine.running() and task.cancel then
            pcall(task.cancel, context.expiryThread)
            Runtime.tasks[context.expiryThread] = nil
        end
        context.expiryThread = nil
        lairStatus("fight", nil, "Resumed the same exact Boss and captured arena")
    end
    StartLairFarming = true
    jobStart("lair", true, function(job)
        StartLairFarming = false
        if job.cancelReason ~= "user_off" or not context.resumeUntil or not Runtime.alive then clearLairContext() end
        if LairState.phase ~= "stopped" then
            lairStatus("stopped", job.cancelReason or "cancelled", "Lair worker cancelled")
        end
        SetToggle("Begin Lair Farm", "Lair Farm", false)
        -- Смерть и респавн не отменяют приказ: ждём живой персонаж и снова
        -- включаем тот же фарм, вместо того чтобы оставить переключатель OFF.
        if Runtime.alive and (job.cancelReason == "respawning" or job.cancelReason == "character_changed")
            and LairRestarts < 20 then
            LairRestarts = LairRestarts + 1
            local token = LairRestartToken
            SetToggle("Begin Lair Farm", "Lair Farm", true)
            runAsync(function()
                local waited = 0
                while Runtime.alive and not token.cancelled and waited < 90 do
                    local p2, h2 = hrp(), hum()
                    if p2 and h2 and h2.Health > 0 then break end
                    if not waitActive(0.5, nil) then return end
                    waited = waited + 0.5
                end
                -- Отмена пользователем во время ожидания имеет приоритет.
                if token.cancelled then
                    SetToggle("Begin Lair Farm", "Lair Farm", false)
                    return
                end
                if Runtime.alive and not Runtime.jobs.lair and not StartLairFarming then startLairFarm(true) end
            end)
        end
    end, function(job)
        context.movementRevision = Runtime.movementRevision
        local function exit(reason, text)
            job.cancelReason = reason
            lairStatus("stopped", reason, text)
            notify("Lair Farm: " .. text, 6)
            return false
        end
        local function targetGone()
            -- Our own HP=0 never authorizes a new request or a different arena.
            return context.target and context.target.Parent ~= living()
        end
        local function returning()
            return context.anchor and context.arrival and context.entrySent and targetGone()
                and selectedLairReady() and SelectedLairNPC == context.provider
                and context.provider:FindFirstChild("HumanoidRootPart") == context.providerRoot
                and context.provider:FindFirstChild("Done") == context.providerDone
                and (p.Position - context.origin).Magnitude <= 25 and (p.Position - context.providerRoot.Position).Magnitude <= 25
        end
        local function live()
            if not jobActive(job) or LairState.context ~= context then return false end
            if os.clock() >= context.deadline then return exit("session_limit", "session limit reached") end
            if context.provider and SelectedLairNPC ~= context.provider then return exit("provider_changed", "selected NPC changed") end
            if char() ~= character or hrp() ~= p or hum() ~= h then
                job.cancelReason = "respawning"
                lairStatus("stopped", "respawning", "Character replaced; waiting for respawn")
                return false
            end
            if not p.Parent or not h.Parent or h.Health <= 0 then
                job.cancelReason = "respawning"
                lairStatus("stopped", "respawning", "Character died; waiting for respawn")
                return false
            end
            if context.movementRevision ~= Runtime.movementRevision then return exit("movement_changed", "movement ownership changed") end
            return true
        end
        local function watchTarget(candidate, root, humanoid)
            if context.healthConnection then context.healthConnection:Disconnect() end
            context.target, context.targetRoot, context.targetHum = candidate, root, humanoid
            local probe = context.probes[humanoid]
            if not probe or probe.model ~= candidate or probe.root ~= root then
                probe = { model = candidate, root = root, humanoid = humanoid, attempted = false, ownedZero = false, writing = false }
                context.probes[humanoid] = probe
            end
            if humanoid.Health > 0 then probe.ownedZero = false end
            context.probe = probe
            -- The observer also runs while manually OFF: a rebound followed by
            -- external zero cannot inherit ownership from an earlier probe.
            context.healthConnection = runConnect(humanoid.HealthChanged, function(health)
                if LairState.context ~= context or context.probe ~= probe then return end
                if health > 0 then probe.ownedZero = false end
            end)
            LairState.target, LairState.targetRoot, LairState.targetHum = candidate, root, humanoid
            LairState.probe = probe
            setAimTarget(candidate)
        end
        local function capture(candidate, root, humanoid)
            watchTarget(candidate, root, humanoid)
            context.anchor, context.arrival = p.Position, p.Position
            LairState.anchor, LairState.arrival = context.anchor, context.arrival
            lairStatus("fight", nil, "Exact Boss acquired")
        end
        -- Исходный цикл message.txt: Done уходит с любой дистанции, пока рядом
        -- не появится ровно одна точная Living.Boss. Никаких 40-секундных
        -- отказов по «неподтверждённому входу».
        local function enter()
            while live() do
                if not selectedLairReady() or context.provider:FindFirstChild("HumanoidRootPart") ~= context.providerRoot
                    or context.provider:FindFirstChild("Done") ~= context.providerDone then
                    return exit("provider_unavailable", "selected entry NPC unavailable")
                end
                context.origin, LairState.origin = p.Position, p.Position
                local ok = TriggerLair(not context.entrySent, job)
                if not ok and not context.entrySent then
                    return exit("entry_request_failed", "entry request could not be sent")
                end
                if not context.entrySent then
                    context.entrySent, context.entryAt = true, os.clock()
                    LairState.entrySent, LairState.entryAt = true, context.entryAt
                    if not live() then return false end
                    lairStatus("entry", nil, "Entry request sent; waiting for the exact Boss")
                end
                local candidate, reason, root, humanoid = arenaBoss(p.Position)
                if reason then return exit(reason, "several exact Boss models nearby") end
                if candidate and humanoid and humanoid.Health > 0 then capture(candidate, root, humanoid); return true end
                if not waitActive(0.2, job) then return false end
            end
            return false
        end
        local function repeatEntry()
            if not returning() then return false end
            if context.healthConnection then context.healthConnection:Disconnect(); context.healthConnection = nil end
            context.target, context.targetRoot, context.targetHum, context.probe = nil, nil, nil, nil
            context.anchor, context.arrival = nil, nil
            context.origin, context.entrySent, context.entryAt, context.entryDeadline = p.Position, false, nil, os.clock() + 40
            LairState.target, LairState.targetRoot, LairState.targetHum, LairState.probe = nil, nil, nil, nil
            LairState.anchor, LairState.arrival, LairState.origin = nil, nil, context.origin
            LairState.entrySent, LairState.entryAt = false, nil
            lairStatus("entry", "observed_return", "Old exact target removed and known entry origin reached")
            return enter()
        end
        if context.inplace then
            local localBoss, localReason, localRoot, localHum
            if context.target and lairExact(context) then
                local probe = context.probe
                if context.targetHum.Health > 0 or (probe and probe.ownedZero) then
                    localBoss, localRoot, localHum = context.target, context.targetRoot, context.targetHum
                end
            end
            if not localBoss then localBoss, localReason, localRoot, localHum = arenaBoss(context.anchor) end
            if localReason then exit(localReason, "several exact Boss models in the local arena"); return end
            if not localBoss then exit("boss_timeout", "the exact local Boss disappeared before capture"); return end
            capture(localBoss, localRoot, localHum)
        elseif not resume and not enter() then
            return
        end
        while live() do
            if returning() then
                if not repeatEntry() then return end
            end
            if ShortPause and not waitActive(PauseTimer, job) then return end
            while live() do
                if returning() then break end
                local boss, targetHum, targetRoot = context.target, context.targetHum, context.targetRoot
                if not boss or boss.Parent ~= living() then break end
                if not lairExact(context) then exit("boss_changed", "exact Boss root/Humanoid/owner changed"); return end
                if (targetRoot.Position - p.Position).Magnitude > LairArenaRadius then break end
                local probe = context.probe
                if targetHum.Health > 0 then probe.ownedZero = false end
                if targetHum.Health <= 0 and not probe.ownedZero then break end
                if holdPosition(boss, LairDistance, Underneath, job) then
                    if InstantBossKill and not probe.attempted and targetHum.Health > 0 then
                        -- Локальная запись Health=0 не репликуется на сервер и
                        -- вдобавок убеждает собственный клиент, что цель мертва:
                        -- удары после неё не регистрируются. Поэтому вместо
                        -- фальшивого нуля — плотная серия настоящих ударов.
                        probe.attempted, probe.at, probe.beforeHP, probe.writing = true, os.clock(), targetHum.Health, false
                        probe.untilAt = probe.at
                        -- Старые версии убивали именно так; возвращаем запись
                        -- HP=0 как основную попытку и продолжаем настоящие удары,
                        -- если клиентская запись не дала нуля.
                        probe.ownedZero = killTarget(boss) == true
                        lairStatus("fight", nil, probe.ownedZero and "Instant: local HP=0 written; attacks continue"
                            or "Instant: local write rejected; real attacks only")
                    end
                    if not probe.lastHP then probe.lastHP, probe.lastHPAt = targetHum.Health, os.clock() end
                    if os.clock() - probe.lastHPAt >= 1 then
                        local maxHP = math.max(targetHum.MaxHealth, 1)
                        local pct = math.floor(targetHum.Health / maxHP * 100 + 0.5)
                        probe.lastHPAt, probe.lastHP = os.clock(), targetHum.Health
                        lairStatus("fight", nil, "Boss HP " .. pct .. "% (" .. math.floor(targetHum.Health + 0.5)
                            .. "/" .. math.floor(maxHP + 0.5) .. ")")
                    end
                    attackStep(job)
                end
                if not waitActive(InstantBossKill and 0.04 or jitter(0.16, 0.26), job) then return end
            end
            if not live() then return end
            if returning() then
                if not repeatEntry() then return end
            else
                lairStatus("acquire", nil, "Target removed; waiting for the next exact Boss")
                local nextBoss, reason, root, humanoid
                local lastAsk = os.clock()
                while live() do
                    if returning() then break end
                    nextBoss, reason, root, humanoid = arenaBoss(p.Position)
                    if reason then exit(reason, "several exact Boss models nearby"); return end
                    if nextBoss then break end
                    if context.provider and os.clock() - lastAsk > 3 then
                        lastAsk = os.clock()
                        TriggerLair(false, job)
                    end
                    if not waitActive(0.2, job) then return end
                end
                if not live() then return end
                if returning() then
                    if not repeatEntry() then return end
                elseif nextBoss then
                    if nextBoss == context.target then
                        -- A positive external rebound keeps the same probe ledger.
                        lairStatus("fight", nil, "Same exact target has positive health again")
                    else
                        capture(nextBoss, root, humanoid)
                    end
                end
            end
        end
    end)
    return StartLairFarming
end

CreateToggle("Begin Lair Farm", "Lair Farm", function(on)
    if not on then stopLairFarm(); return false end
    return startLairFarm()
end)

-- ══════════════════════════════════════════════════════════════════════════
-- QUEST FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Quest Farm")
CreateNote("Selected Quest NPC: None", "Quest Farm")
CreateNote("Selected NPC: None", "Quest Farm")

CreateButton("Tutorial", "Quest Farm", function()
    notify("Step 1 (Quest Selection), Stand Near Quest NPC And Press 'Select Quest NPC'", 6)
    task.wait(5)
    notify("Step 2 (NPC Selection), Stand Near NPC To Kill And Press 'Select NPC", 6)
end)

local SelectedQuestNPC
local SelectedQuestNPCText = "None"
local SelectedNPC = "None"

CreateButton("Select Quest NPC", "Quest Farm", function()
    local c, p = char(), hrp()
    local nf = npcFolder()
    if not (c and p and nf) then return end

    local best, bestDist = nil, 15
    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        local done, questDone = v:FindFirstChild("Done"), v:FindFirstChild("QuestDone")
        if root and done and done:IsA("RemoteEvent") and questDone and questDone:IsA("RemoteEvent") then
            local d = (p.Position - root.Position).Magnitude
            if d < bestDist then best, bestDist = v, d end
        end
    end
    if not best then
        notify("No Quest NPC within 15 studs", 4)
        return
    end

    do
        local v = best
        local head = v:FindFirstChild("Head")
        local main = head and head:FindFirstChild("Main")
        local txt = main and main:FindFirstChild("Text")
        local pretty = (txt and txt.Text) or v.Name

        SelectedQuestNPC = v
        SelectedQuestNPCText = pretty
        setNote("Selected Quest NPC:", "Selected Quest NPC: " .. pretty)
        notify("Quest NPC: " .. pretty, 3)
    end
end)

CreateButton("Select NPC", "Quest Farm", function()
    local c, p = char(), hrp()
    local L = living()
    if not (c and p and L) then return end

    local best, bestDist = nil, 15
    for _, v in ipairs(L:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        local targetHum = v:FindFirstChildOfClass("Humanoid")
        if root and targetHum and targetHum.Health > 0 and v:FindFirstChild("AI") and not Players:GetPlayerFromCharacter(v) then
            local d = (p.Position - root.Position).Magnitude
            if d < bestDist then best, bestDist = v, d end
        end
    end
    if not best then
        notify("No NPC within 15 studs", 4)
        return
    end

    SelectedNPC = best.Name
    setNote("Selected NPC:", "Selected NPC: " .. best.Name)
    notify("Target NPC: " .. best.Name, 3)
end)

local OnlyFarmNPC = false
CreateToggle("Only Farm NPC", "Quest Farm", function(on)
    OnlyFarmNPC = on == true
    return OnlyFarmNPC
end)

local QuestDistance = 4
CreateNote("Farming Position", "Quest Farm")
CreateTextBox("Set Distance: ", "Quest Farm", { CustomText = "Default: 4" }, function(Input)
    local n = finiteNumber(Input, 0.5, 100)
    if n then QuestDistance = n end
end)

local QUnderneath = false
CreateToggle("Underneath", "Quest Farm", function(on)
    QUnderneath = on == true
    return QUnderneath
end)

local function TriggerQuest(job)
    if not jobActive(job) or not (SelectedQuestNPC and SelectedQuestNPC.Parent == npcFolder()) then return false end
    local root, p = SelectedQuestNPC:FindFirstChild("HumanoidRootPart"), hrp()
    local questDone, done = SelectedQuestNPC:FindFirstChild("QuestDone"), SelectedQuestNPC:FindFirstChild("Done")
    if not (root and p and questDone and done and questDone:IsA("RemoteEvent") and done:IsA("RemoteEvent")) then return false end
    if (root.Position - p.Position).Magnitude > 25 then
        if not approach(SelectedQuestNPC, 6, job) or not waitActive(0.1, job) then return false end
    end
    local currentRoot, currentHum = hrp(), hum()
    if not jobActive(job) or not (currentRoot and currentHum and currentHum.Health > 0)
        or SelectedQuestNPC.Parent ~= npcFolder()
        or SelectedQuestNPC:FindFirstChild("QuestDone") ~= questDone
        or SelectedQuestNPC:FindFirstChild("Done") ~= done
        or (root.Position - currentRoot.Position).Magnitude > 25 then return false end
    local ok1 = pcall(function() questDone:FireServer() end)
    if not jobActive(job) then return false end
    local ok2 = pcall(function() done:FireServer() end)
    return ok1 and ok2
end

local StartQuestFarming = false
CreateToggle("Begin Quest Farm", "Quest Farm", function(on)
    StartQuestFarming = on == true
    if not StartQuestFarming then jobStop("quest"); return false end
    local ready = SelectedNPC ~= "None" and (OnlyFarmNPC or (SelectedQuestNPC and SelectedQuestNPC.Parent == npcFolder()))
    if not ready then
        StartQuestFarming = false
        notify("You Are Missing A Step! Please Check Tutorial Then Re-Enable!")
        return false
    end
    jobStart("quest", true, function()
        StartQuestFarming = false
        SetToggle("Begin Quest Farm", "Quest Farm", false)
    end, function(job)
        while jobActive(job) do
            local L, p, myHum = living(), hrp(), hum()
            if L and p and myHum and myHum.Health > 0 then
                local target, bestDist
                for _, candidate in ipairs(L:GetChildren()) do
                    local th, root = candidate:FindFirstChildOfClass("Humanoid"), candidate:FindFirstChild("HumanoidRootPart")
                    if candidate.Name == SelectedNPC and candidate:FindFirstChild("AI") and th and root and th.Health > 0 and not Players:GetPlayerFromCharacter(candidate) then
                        local d = (p.Position - root.Position).Magnitude
                        if not bestDist or d < bestDist then target, bestDist = candidate, d end
                    end
                end
                if target then
                    if not OnlyFarmNPC and not TriggerQuest(job) then
                        notify("Quest request could not be sent; stopped.", 5)
                        break
                    end
                    local th = target:FindFirstChildOfClass("Humanoid")
                    while jobActive(job) and target.Parent == L and th and th.Health > 0 do
                        setAimTarget(target)
                        if holdPosition(target, QuestDistance, QUnderneath, job) then attackStep(job) end
                        if not waitActive(jitter(STEALTH.AttackMin, STEALTH.AttackMax), job) then break end
                    end
                    if not jobActive(job) then break end
                    if not OnlyFarmNPC then TriggerQuest(job) end
                    -- No unrelated +1000/+10 teleports after finishing or disabling.
                end
            end
            if not waitActive(0.4, job) then break end
        end
    end)
    return StartQuestFarming
end)

-- ══════════════════════════════════════════════════════════════════════════
-- ITEM FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Item Farm")
CreateNote("Farm Methods", "Item Farm")

local FarmMethod = 0
local StartFarming = false
local ItemSpeeds = {}
local startItemFarm
CreateNote("Current Method: None", "Item Farm")

local function restoreItemSpeeds()
    for humanoid, speed in pairs(ItemSpeeds) do
        if humanoid.Parent then
            pcall(function()
                if humanoid.WalkSpeed == 30 then humanoid.WalkSpeed = speed end
                local root = humanoid.Parent:FindFirstChild("HumanoidRootPart")
                if root then humanoid:MoveTo(root.Position) end
            end)
        end
    end
    ItemSpeeds = {}
end
addCleanup(restoreItemSpeeds)

local function setMethod(text)
    setNote("Current Method:", "Current Method: " .. text)
end
local function switchItemMethod(method, text)
    local running = StartFarming
    jobStop("items")
    restoreItemSpeeds()
    FarmMethod = method
    setMethod(text)
    if running and startItemFarm then
        local on = startItemFarm(true)
        SetToggle("Start Farming", "Item Farm", on)
    end
end
CreateButton("Instant", "Item Farm", function() switchItemMethod(1, "Instant") end)
CreateButton("Legit", "Item Farm", function() switchItemMethod(2, "Legit") end)

-- Only unowned world Tools; never chase another player's equipped inventory.
local function worldItem(tool)
    if not (tool and tool.Parent and tool:IsA("Tool")) then return false end
    local parent = tool.Parent
    while parent and parent ~= Workspace do
        if parent == char() or parent == backpack() or parent:IsA("Backpack") then return false end
        if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then return false end
        parent = parent.Parent
    end
    return parent == Workspace
end

local function itemTargets()
    local out, seen = {}, {}
    local p = hrp()
    local function consider(inst)
        if seen[inst] or not worldItem(inst) then return end
        seen[inst] = true
        local part = inst:FindFirstChild("Handle") or inst:FindFirstChildWhichIsA("BasePart", true)
        if not (part and part:IsA("BasePart")) then return end
        local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt", true)
        out[#out + 1] = { obj = inst, part = part, prompt = prompt }
    end
    for _, child in ipairs(Workspace:GetChildren()) do if child:IsA("Tool") then consider(child) end end
    for _, name in ipairs({ "Vfx", "Items" }) do
        local folder = Workspace:FindFirstChild(name)
        if folder then for _, child in ipairs(folder:GetDescendants()) do consider(child) end end
    end
    if p then table.sort(out, function(a, b) return (a.part.Position - p.Position).Magnitude < (b.part.Position - p.Position).Magnitude end) end
    return out
end

local function ownItem(tool)
    local bp, c = backpack(), char()
    return tool and ((bp and tool:IsDescendantOf(bp)) or (c and tool:IsDescendantOf(c)))
end

local function grabTool(t, job)
    local p, c = hrp(), char()
    if not jobActive(job) or not (p and t and t.part.Parent and worldItem(t.obj)) then return false end
    if not tpToCF(t.part.CFrame, job) or not waitActive(0.15, job) or char() ~= c then return false end
    if ownItem(t.obj) then return true end
    if not worldItem(t.obj) then return false end
    if t.prompt then fireProximity(t.prompt, job) end
    if not waitActive(0.15, job) then return false end
    return ownItem(t.obj) or t.obj.Parent == nil
end

local function moveWaypoint(h, position, job, character)
    local reached
    local connection = runConnect(h.MoveToFinished, function(ok) reached = ok end)
    job.connections[connection] = true
    h:MoveTo(position)
    local deadline = os.clock() + 3
    while reached == nil and jobActive(job) and char() == character and h.Parent == character
        and h.Health > 0 and FarmMethod == 2 and os.clock() < deadline do
        if not waitActive(0.05, job) then break end
    end
    connection:Disconnect()
    job.connections[connection] = nil
    local success = jobActive(job) and char() == character and FarmMethod == 2 and reached == true
    if not success then
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root and h.Parent then h:MoveTo(root.Position) end
    end
    return success
end

local function walkAndGrab(t, job)
    local h, p, c = hum(), hrp(), char()
    if not jobActive(job) or not (h and h.Health > 0 and p and t and t.part.Parent and worldItem(t.obj)) then return false end
    local path = PathfindingService:CreatePath({ AgentCanJump = true })
    path:ComputeAsync(p.Position, t.part.Position)
    if not jobActive(job) or char() ~= c or not worldItem(t.obj) or path.Status ~= Enum.PathStatus.Success then return false end
    for _, wp in ipairs(path:GetWaypoints()) do
        if not jobActive(job) or char() ~= c or not worldItem(t.obj) or FarmMethod ~= 2 then return false end
        if wp.Action == Enum.PathWaypointAction.Jump then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        if not moveWaypoint(h, wp.Position, job, c) then return false end
    end
    if not jobActive(job) or not worldItem(t.obj) then return ownItem(t.obj) end
    if t.prompt then fireProximity(t.prompt, job) end
    return ownItem(t.obj) or t.obj.Parent == nil
end

startItemFarm = function(on)
    StartFarming = on == true
    if not StartFarming then jobStop("items"); restoreItemSpeeds(); return false end
    if FarmMethod ~= 1 and FarmMethod ~= 2 then
        StartFarming = false
        notify("Select A Farm Method, And Re-Enable!")
        return false
    end
    jobStart("items", true, function()
        StartFarming = false
        SetToggle("Start Farming", "Item Farm", false)
        restoreItemSpeeds()
    end, function(job)
        while jobActive(job) do
            local h = hum()
            if h and h.Health > 0 then
                if FarmMethod == 2 then
                    if ItemSpeeds[h] == nil then ItemSpeeds[h] = h.WalkSpeed end
                    h.WalkSpeed = 30
                else
                    restoreItemSpeeds()
                end
                for _, t in ipairs(itemTargets()) do
                    if not jobActive(job) then break end
                    if FarmMethod == 1 then grabTool(t, job) else walkAndGrab(t, job) end
                    if not waitActive(0.15, job) then break end
                end
            end
            if not waitActive(FarmMethod == 1 and 0.3 or 1, job) then break end
        end
    end)
    return StartFarming
end
CreateToggle("Start Farming", "Item Farm", startItemFarm)

-- ══════════════════════════════════════════════════════════════════════════
-- TELEPORTS
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Teleports")

CreateTextBox("Teleport To", "Teleports", { CustomText = "Player Name" }, function(A)
    if not A or A == "" then return end
    local target = Players:FindFirstChild(Fill(A))
    local c = target and target.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not root then notify("Player not found: " .. tostring(A), 3); return end
    tpToCF(root.CFrame)
end)

CreateTextBox("Teleport Above To : ", "Teleports", { CustomText = "Player Name" }, function(A)
    if not A or A == "" then return end
    local target = Players:FindFirstChild(Fill(A))
    local c = target and target.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if not root then notify("Player not found: " .. tostring(A), 3); return end
    tpToCF(root.CFrame * CFrame.new(0, 25, 0))
end)

local LANDMARKS = {
    { "D4C Dimension",      CFrame.new(11927.1, -3.28935, -4488.59) },
    { "Rarity Boards",      CFrame.new(-658.979, 67.0282, -451.495) },
    { "Stand Storage Room", CFrame.new(-393.893, 23.5808, -280.786) },
    { "Inner Sanctum",      CFrame.new(27877.87109375, 27.233600616455078, -147.72268676757812) },
    { "Mud Pit",            CFrame.new(17.0716, 66.9873, -246.13) },
    { "Hamon Dealer",       CFrame.new(-801.427, 66.5359, -735.121) },
    { "Vehicle Man",        CFrame.new(-187.042, 78.4486, -1076.25) },
    { "Testing Zone",       CFrame.new(19999.3, 100.155, -730.726) },
    { "Bad Gi Spawn",       CFrame.new(-687.604736328125, 67.03131866455078, -837.9588623046875) },
    { "Scary Monster Cave", CFrame.new(-683.89794921875, 67.03133392333984, -1039.75634765625) },
    { "Sewer",              CFrame.new(-5308.6455078125, -450.83184814453125, -3815.388427734375) },
    { "Yoshikage Kira Spawn", CFrame.new(-446.5094299316406, 67.03131103515625, -995.3768310546875) },
    { "Dio's Rock",         CFrame.new(-37.414466857910156, 92.30691528320312, -804.2440185546875) },
    { "Gyro Zeppeli",       CFrame.new(57.21436309814453, 66.80048370361328, -216.83428955078125) },
}

for _, lm in ipairs(LANDMARKS) do
    local label, cf = lm[1], lm[2]
    CreateButton(label, "Teleports", function()
        tpToCF(cf)
    end)
end

CreateNote("NPC's", "Teleports")

-- FIX: v захватывался замыканием — кнопки могли телепортировать не к тому NPC
do
    local nf = npcFolder()
    if nf then
        for _, v in ipairs(nf:GetChildren()) do
            local npc = v
            local head = npc:FindFirstChild("Head")
            local main = head and head:FindFirstChild("Main")
            local sub = head and head:FindFirstChild("Sub")
            local mainText = main and main:FindFirstChild("Text")
            local subText = sub and sub:FindFirstChild("Text")

            if head and mainText then
                local label = mainText.Text
                if subText and subText.Text ~= "" then
                    label = label .. " [" .. subText.Text .. "]"
                end
                runAsync(function()
                    CreateButton(label, "Teleports", function()
                        tpToCF(CFrame.new(head.Position + Vector3.new(0, 3, 0)))
                    end)
                end)
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- STAND FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Stand Farm")
CreateSearchBar("Stand Farm")

CreateNote("Checking Configuration", "Stand Farm")

local function standConfigurationChanged()
    jobStop("stand")
end

local StandCheck = false
CreateToggle("Enable Stand Check", "Stand Farm", function(on)
    standConfigurationChanged()
    StandCheck = on == true
    return StandCheck
end)

local AttributeCheck = false
CreateToggle("Enable Attribute Check", "Stand Farm", function(on)
    standConfigurationChanged()
    AttributeCheck = on == true
    return AttributeCheck
end)

local SplitChecking = false
CreateToggle("Split Checking", "Stand Farm", function(on)
    standConfigurationChanged()
    SplitChecking = on == true
    return SplitChecking
end)

CreateNote("Extra Settings", "Stand Farm")

local UseStandArrows   = true
local UseChargedArrows = false
local UseKarsMask      = false

CreateButton("Use Stand Arrows", "Stand Farm", function()
    standConfigurationChanged()
    UseStandArrows, UseChargedArrows, UseKarsMask = true, false, false
    notify("Using Stand Arrows", 3)
end)

CreateButton("Use Charged Arrows", "Stand Farm", function()
    standConfigurationChanged()
    UseStandArrows, UseChargedArrows, UseKarsMask = false, true, false
    notify("Using Charged Arrows", 3)
end)

CreateButton("Use Kars Mask", "Stand Farm", function()
    standConfigurationChanged()
    UseStandArrows, UseChargedArrows, UseKarsMask = false, false, true
    notify("Using Kars Mask", 3)
end)

local AutoBuyArrows = false
CreateToggle("Auto Buy Selected Arrows", "Stand Farm", function(on)
    AutoBuyArrows = on == true
    return AutoBuyArrows
end)

local AutoBuyRokakaka = false
CreateToggle("Auto Buy Rokakaka", "Stand Farm", function(on)
    AutoBuyRokakaka = on == true
    return AutoBuyRokakaka
end)

local Webhook = ""
CreateTextBox("Set Webhook", "Stand Farm", {}, function(Input)
    Webhook = Input or ""
end)

local EnableWebhook = false
CreateToggle("Enable Webhook", "Stand Farm", function(on)
    EnableWebhook = on == true
    return EnableWebhook
end)

CreateNote("Stands", "Stand Farm")

local WhitelistedStands = {}
local WhitelistedAttributes = {}

local Ignore = {
    "The Universe Over Heaven", "Shinjitsu Tenj no uch", "The Waifu: Over Heaven From Your Biazarre Adventure",
    "Rapture", "True Star Platinum: The World", "Diego's The World: High Voltage",
    "Premier Macho", "Stab Platinum: The World", "King Crimson Requiem", "Silver Chariot Requiem",
    "Eclispe Dio's The World Over Heaven", "Headless Star Platinum", "Tusk Act 2", "Tusk Act 3",
    "Star Platinum The World: Requiem", "Tusk Act 4", "Star Platinum OVA Over Heaven",
    "Star Platinum The World", "Star Platinum Over Heaven", "Crazy Diamond: Over Heaven",
    "The World's Greatest High", "C-Moon", "Shadow The World", "Main In Heaven",
    "Silver Chariot Requiem OVA", "The World OVA Over Heaven", "Kars", "Cauldron Black",
    "Stab Platinum", "Dio's The World Over Heaven", "The World Over Heaven", "Halal Goku",
    "Gold Experience Requiem Requiem", "Gold Experience Requiem", "Killer Queen Bites The Dust",
    "Celebratory Soft & Wet", "Anubis", "The World Alternate Universe: Executioner",
    "The World Alternate Universe: Electrocutioner", "King Crimson: Requiem", "Brainy's The World",
    "TAMIH", "ABDSTW", "Made In Hell", "Jotaro's Star Platinum Over Heaven",
    "The World Over Heaven OVA", "Golden Experience: Reality Bender", "Ultimate Life Form",
    "Ben", "Made In Heaven", "Snowglobe Made In Heaven", "Premier Macho Requiem",
    "Halal Vegeta", "HalalGoku", "IBM", "Festive The World", "The Universe",
    "Dirty Deeds Done Dirt Cheap: Love Train",
}

local Created = {}
do
    local convert = ReplicatedStorage:FindFirstChild("StandNameConvert")
    if convert then
        for _, v in ipairs(convert:GetChildren()) do
            if v:IsA("StringValue") and v.Value ~= ""
               and not table.find(Created, v.Value)
               and not table.find(Ignore, v.Value) then
                local stand = v.Value
                Created[#Created + 1] = stand
                runAsync(function()
                    CreateToggle(stand, "Stand Farm", function(on)
                        standConfigurationChanged()
                        local at = table.find(WhitelistedStands, stand)
                        if on and not at then
                            WhitelistedStands[#WhitelistedStands + 1] = stand
                        elseif not on and at then table.remove(WhitelistedStands, at) end
                        return on == true
                    end)
                end)
            end
        end
    end
end

CreateNote("Attributes", "Stand Farm")

do
    local ok, frame = pcall(function()
        return Workspace.Map.ChancesBoards.AttributeChances.newSurface.ScrollFrame
    end)
    if ok and frame then
        local seen = {}
        for _, v in ipairs(frame:GetChildren()) do
            if v:IsA("TextLabel") then
                local attr = tostring(v.Text):gsub("%s*[%(%[]?[%d%.]+%%%s*[%)%]]?%s*$", ""):match("^%s*(.-)%s*$")
                if attr == "Glass" then attr = "Glass Cannon" end
                if attr and attr ~= "" and not seen[attr] then
                    seen[attr] = true
                    local name = attr
                    runAsync(function()
                        CreateToggle(name, "Stand Farm", function(on)
                            standConfigurationChanged()
                            local at = table.find(WhitelistedAttributes, name)
                            if on and not at then
                                WhitelistedAttributes[#WhitelistedAttributes + 1] = name
                            elseif not on and at then table.remove(WhitelistedAttributes, at) end
                            return on == true
                        end)
                    end)
                end
            end
        end
    end
end

local function sendRollWebhook(currentStand, currentAttri)
    if not EnableWebhook or not Runtime.alive then return end
    webhookSend(Webhook, {
        content = "@everyone```\nUsername: " .. LP.Name
               .. "\nStand: " .. currentStand
               .. "\nAttribute: " .. currentAttri .. "```",
    })
end

local function standConfigurationReady()
    return (StandCheck or AttributeCheck)
        and (not StandCheck or #WhitelistedStands > 0)
        and (not AttributeCheck or #WhitelistedAttributes > 0)
end

local function standMatches()
    local currentStand, currentAttri = standName(), standAttri()
    local check1 = StandCheck and table.find(WhitelistedStands, currentStand) ~= nil
    local check2 = AttributeCheck and table.find(WhitelistedAttributes, currentAttri) ~= nil
    local hit
    if SplitChecking then hit = check1 or check2
    elseif StandCheck and AttributeCheck then hit = check1 and check2
    else hit = check1 or check2 end
    return hit, currentStand, currentAttri
end

local function stopOnStandMatch(job)
    if not jobActive(job) then return true end
    if not standConfigurationReady() then
        jobStop("stand")
        notify("Stand Farm: checking configuration changed; stopped.", 5)
        return true
    end
    local hit, currentStand, currentAttri = standMatches()
    if not hit then return false end
    jobStop("stand")
    notify("Target roll found: " .. currentStand .. " [" .. currentAttri .. "]", 8)
    runAsync(function() sendRollWebhook(currentStand, currentAttri) end)
    return true
end

-- ── NEXT MOVE ─────────────────────────────────────────────────────────────
-- FIX: UseArrow / UseChargedArrow — несуществующие глобалы, из-за опечатки
-- автопокупка не срабатывала никогда. Плюс вечные repeat-until без таймаута.
local function rollReady(job, character)
    local h = hum()
    local data = LP:FindFirstChild("Data")
    return jobActive(job) and char() == character and h and h.Health > 0 and hrp()
        and data and data:FindFirstChild("Stand") and data:FindFirstChild("Attri")
end

local function awaitInventory(name, job, character)
    local deadline = os.clock() + 4
    while rollReady(job, character) and os.clock() < deadline do
        local bp = backpack()
        local tool = character:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
        if tool and tool:IsA("Tool") then return true end
        if not waitActive(0.1, job) then break end
    end
    return false
end

local function buyArrow(job)
    if UseKarsMask then return false, "Kars Mask auto-buy protocol is not available" end
    local ev, nf = events(), npcFolder()
    local buy = ev and ev:FindFirstChild("BuyItem")
    local charged = UseChargedArrows
    local merchant = charged and "Merchant120" or "MerchantAU"
    local npc = nf and (nf:FindFirstChild(merchant) or (charged and nf:FindFirstChild("Merchantlvl120")))
    local c = char()
    if not (buy and buy:IsA("RemoteEvent") and npc and npc:FindFirstChild("HumanoidRootPart")) or not rollReady(job, c) then return false, "Arrow merchant unavailable" end
    if not tpToCF(npc.HumanoidRootPart.CFrame, job) then return false, "Could not reach arrow merchant" end
    if not waitActive(0.5, job) or not rollReady(job, c) or stopOnStandMatch(job) then return false, "cancelled" end
    -- Merchantlvl120 is the protocol role in the saved NpcDialogue client.
    local sent = pcall(function() buy:FireServer(charged and "Merchantlvl120" or "MerchantAU", charged and "Option2" or "Option4") end)
    if not sent then return false, "Arrow purchase request failed" end
    if not awaitInventory(charged and "Charged Arrow" or "Stand Arrow", job, c) then return false, "Arrow purchase produced no item" end
    return true
end

local function buyRokakaka(job)
    local ev, nf = events(), npcFolder()
    local buy = ev and ev:FindFirstChild("BuyItem")
    local npc = nf and nf:FindFirstChild("MerchantAU")
    local c = char()
    if not (buy and buy:IsA("RemoteEvent") and npc and npc:FindFirstChild("HumanoidRootPart")) or not rollReady(job, c) then return false, "Rokakaka merchant unavailable" end
    if not tpToCF(npc.HumanoidRootPart.CFrame, job) then return false, "Could not reach Rokakaka merchant" end
    if not waitActive(0.5, job) or not rollReady(job, c) or stopOnStandMatch(job) then return false, "cancelled" end
    local sent = pcall(function() buy:FireServer("MerchantAU", "Option2") end)
    if not sent then return false, "Rokakaka purchase request failed" end
    if not awaitInventory("Rokakaka", job, c) then return false, "Rokakaka purchase produced no item" end
    return true
end

local function NextMove(job)
    local c = char()
    if not rollReady(job, c) then return false, "Character or Data unavailable" end
    local arrow = UseKarsMask and "Kars Mask" or (UseChargedArrows and "Charged Arrow" or "Stand Arrow")
    local removing = hasStand()
    local name = removing and "Rokakaka" or arrow
    local bp = backpack()
    local tool = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
    if not tool then
        if removing and AutoBuyRokakaka then return buyRokakaka(job) end
        if not removing and AutoBuyArrows then return buyArrow(job) end
        return false, "No " .. name .. " in inventory"
    end
    if not tool:IsA("Tool") then return false, name .. " is not a Tool" end
    local owner = equipmentAcquire(job)
    if not owner then return false, "Another operation owns equipment" end
    local ok, result, reason = pcall(function()
        local function beforeUse()
            return rollReady(job, c) and not stopOnStandMatch(job) and hasStand() == removing
        end
        if not useToolName(name, job, beforeUse) then return false, "Could not use " .. name end
        local deadline = os.clock() + 8
        while rollReady(job, c) and os.clock() < deadline do
            if stopOnStandMatch(job) then return true end
            if hasStand() ~= removing then return true end
            if not waitActive(0.2, job) then return false, "cancelled" end
        end
        return false, "No stand change after " .. name
    end)
    equipmentRelease(owner)
    if not ok then return false, tostring(result) end
    return result, reason
end

local StandFarm = false
local stopFakeProfile
CreateToggle("Begin Stand Farm", "Stand Farm", function(on)
    StandFarm = on == true
    if not StandFarm then jobStop("stand"); return false end
    if not standConfigurationReady() then
        StandFarm = false
        notify("Enable a check and select its target before farming.", 5)
        return false
    end
    if stopFakeProfile then stopFakeProfile() end
    jobStart("stand", true, function()
        StandFarm = false
        SetToggle("Begin Stand Farm", "Stand Farm", false)
    end, function(job)
        local failures = 0
        while jobActive(job) do
            if not standConfigurationReady() then
                notify("Stand Farm: checking configuration changed; stopped.", 5)
                break
            end
            local c = char()
            if not rollReady(job, c) then
                if not waitActive(0.5, job) then break end
            else
                if stopOnStandMatch(job) then return end
                local ok, reason = NextMove(job)
                if not jobActive(job) then break end
                if ok then failures = 0 else failures = failures + 1 end
                if failures >= 3 then notify("Stand Farm stopped: " .. tostring(reason), 6); break end
                if not waitActive(0.4, job) then break end
            end
        end
    end)
    return StandFarm
end)

-- ══════════════════════════════════════════════════════════════════════════
-- Loaded notification is emitted after every menu and the control API exist.

-- ══════════════════════════════════════════════════════════════════════════
-- BEGIN SUR FAKE TARGET BLOCK
-- ══════════════════════════════════════════════════════════════════════════
-- FAKE PROFILE  (local /check fields + fake stand model)
-- Player.Data.Stand / .Attri / .GUID and Character.Stats.AttackDmg,
-- Character.DmgBoostAttri / Humanoid.MaxHealth are read by the saved client.
-- HUD: PlayerGui.PlayerGUI.ingame.Stats. StandNameConvert maps code to name.
-- These writes change this client's view, not server ownership or other clients.
-- ══════════════════════════════════════════════════════════════════════════
local Fake, AutoKill, fakeStop

do
local function installFakeTargetBlock()
Fake = {
    active = false, stand = nil, attri = nil, guid = nil,
    health = nil, dmg = nil, boost = nil,
    saved = {}, clamped = {}, hud = {}, character = nil, removing = nil,
    model = nil, relCFrame = nil, modelEnabled = false, modelCode = nil, side = 1,
}

local function dataValue(name)
    local d = LP:FindFirstChild("Data")
    local value = d and d:FindFirstChild(name)
    return value and value:IsA("ValueBase") and value or nil
end

local function statsFolder()
    local c = char()
    return c and c:FindFirstChild("Stats")
end

local function standCatalog()
    local out = {}
    local holder = ReplicatedStorage:FindFirstChild("StandNameConvert")
    if holder then
        for _, v in ipairs(holder:GetChildren()) do
            if v:IsA("StringValue") then out[#out + 1] = { code = v.Name, pretty = tostring(v.Value) } end
        end
    end
    table.sort(out, function(a, b) return a.code < b.code end)
    return out
end

local function standPretty(code)
    local holder = ReplicatedStorage:FindFirstChild("StandNameConvert")
    local v = holder and holder:FindFirstChild(tostring(code))
    return v and v:IsA("StringValue") and tostring(v.Value) or tostring(code or "None")
end

local function attriCatalog()
    local out, seen = {}, {}
    local map = Workspace:FindFirstChild("Map")
    local boards = map and map:FindFirstChild("ChancesBoards")
    local board = boards and boards:FindFirstChild("AttributeChances")
    local surface = board and board:FindFirstChild("newSurface")
    local frame = surface and surface:FindFirstChild("ScrollFrame")
    if frame then
        for _, v in ipairs(frame:GetChildren()) do
            if v:IsA("TextLabel") then
                local name = tostring(v.Text):gsub("%s*[%(%[]?[%d%.]+%%%s*[%)%]]?%s*$", ""):match("^%s*(.-)%s*$")
                if name == "Glass" then name = "Glass Cannon" end
                if name and name ~= "" and not seen[name] then seen[name] = true; out[#out + 1] = name end
            end
        end
    end
    if #out == 0 then
        for _, holderName in ipairs({ "AttriList", "Attributes", "AttriNames", "RarityList" }) do
            local holder = ReplicatedStorage:FindFirstChild(holderName)
            if holder then
                for _, v in ipairs(holder:GetChildren()) do
                    if (v:IsA("StringValue") or v:IsA("Folder")) and not seen[v.Name] then
                        seen[v.Name] = true; out[#out + 1] = v.Name
                    end
                end
            end
        end
    end
    if #out == 0 then out = { "None", "Weak", "Normal", "Good", "Great", "Excellent", "Perfect", "Legendary", "Mythical", "Godly", "Divine" } end
    table.sort(out)
    return out
end

-- ── exact-instance/property ledger ────────────────────────────────────────
local function fakeOriginal(instance, property)
    if not instance then return nil end
    local fields = Fake.saved[instance]
    local record = fields and fields[property]
    if record then return record.original end
    local ok, value = pcall(function() return instance[property] end)
    return ok and value or nil
end

local function fakeWrite(instance, property, value)
    if not (instance and instance.Parent) or value == nil then return false end
    local fields = Fake.saved[instance]
    local record = fields and fields[property]
    local original = record and record.original
    if not record then
        local ok
        ok, original = pcall(function() return instance[property] end)
        if not ok then return false end
    else
        local ok, observed = pcall(function() return instance[property] end)
        if not ok then return false end
        if observed ~= record.last then record.original = observed end
    end
    local ok = pcall(function() instance[property] = value end)
    if not ok then return false end
    if not fields then fields = {}; Fake.saved[instance] = fields end
    if not record then record = { original = original }; fields[property] = record end
    record.last = value
    return true
end

local function restoreProperty(instance, property)
    local fields = Fake.saved[instance]
    local record = fields and fields[property]
    if not record then return end
    if instance.Parent then
        pcall(function()
            -- A later independent update is not owned by this fake session.
            if instance[property] == record.last then instance[property] = record.original end
        end)
    end
    fields[property] = nil
    if not next(fields) then Fake.saved[instance] = nil end
end

local function fakeRestore(healthCharacter)
    local entries = {}
    for instance, fields in pairs(Fake.saved) do
        for property in pairs(fields) do entries[#entries + 1] = { instance, property } end
    end
    -- Max must be restored before a Health clamp caused by changing Max.
    for _, entry in ipairs(entries) do if entry[2] == "MaxHealth" then restoreProperty(entry[1], entry[2]) end end
    for _, entry in ipairs(entries) do if entry[2] ~= "MaxHealth" then restoreProperty(entry[1], entry[2]) end end
    if not healthCharacter then healthCharacter = char() end
    for humanoid, clamp in pairs(Fake.clamped) do
        if humanoid.Parent and humanoid.Parent == healthCharacter and humanoid.Health > 0
            and humanoid.Health == clamp.after then
            pcall(function() humanoid.Health = math.min(clamp.before, humanoid.MaxHealth) end)
        end
    end
    Fake.saved, Fake.clamped, Fake.hud, Fake.character = {}, {}, {}, nil
end

-- ── панель статов слева ───────────────────────────────────────────────────
local function hudStats()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    local gui = pg and pg:FindFirstChild("PlayerGUI")
    local ingame = gui and gui:FindFirstChild("ingame")
    return ingame and ingame:FindFirstChild("Stats")
end

local function standGuiName()
    local frame = hudStats()
    local holder = frame and frame:FindFirstChild("StandName")
    local label = holder and holder:FindFirstChild("TextLabel", true)
    return label and label:IsA("TextLabel") and tostring(label.Text) or standName()
end

local function hudKind(label, frame)
    local cursor = label
    while cursor and cursor ~= frame do
        local name = string.lower(cursor.Name):gsub("[%s_%-]", "")
        if name == "standname" then return "stand" end
        if name == "attri" or name == "attribute" then return "attri" end
        if name == "standhealth" or name == "maxhealth" or name == "health" then return "health" end
        if name == "standdamage" or name == "attackdmg" or name == "damage" then return "dmg" end
        if name == "guid" or name == "standguid" then return "guid" end
        cursor = cursor.Parent
    end
    return nil
end

local function hudApply()
    local frame = hudStats()
    if not frame then return end
    local st = statsFolder()
    local attack = st and st:FindFirstChild("AttackDmg")
    local boost = char() and char():FindFirstChild("DmgBoostAttri")
    local originalDmg = attack and fakeOriginal(attack, "Value")
    local originalBoost = boost and fakeOriginal(boost, "Value") or 1
    local realStand = standPretty(fakeOriginal(dataValue("Stand"), "Value") or standCode())
    local realAttr = fakeOriginal(dataValue("Attri"), "Value")
    local realHealth = fakeOriginal(hum(), "MaxHealth")
    local realDamage = originalDmg and math.floor(originalDmg * (originalBoost or 1))
    local wants = {
        stand = Fake.stand and standPretty(Fake.stand), attri = Fake.attri, guid = Fake.guid,
        health = Fake.health and tostring(Fake.health),
        dmg = (Fake.dmg ~= nil or Fake.boost ~= nil) and tostring(math.floor((Fake.dmg or originalDmg or 0) * (Fake.boost or originalBoost or 1))) or nil,
    }
    for _, label in ipairs(frame:GetDescendants()) do
        if label:IsA("TextLabel") then
            local kind = Fake.hud[label] or hudKind(label, frame)
            if not kind then
                -- Exact textual fallback only; unrelated numeric labels are untouched.
                local original = fakeOriginal(label, "Text")
                if original == realStand and Fake.stand then kind = "stand"
                elseif original == realAttr and Fake.attri then kind = "attri"
                elseif realHealth and original == tostring(realHealth) and label.Name == "StandHealth" then kind = "health"
                elseif realDamage and original == tostring(realDamage) and label.Name == "StandDamage" then kind = "dmg" end
            end
            if kind then
                Fake.hud[label] = kind
                if wants[kind] ~= nil then fakeWrite(label, "Text", tostring(wants[kind])) else restoreProperty(label, "Text") end
            end
        end
    end
end

-- ── запись / восстановление ───────────────────────────────────────────────
local function fakeApply()
    if not Fake.active or not Runtime.alive then return end
    local c = char()
    if not c or Fake.removing == c then return end
    Fake.character = c
    for _, spec in ipairs({ {"Stand", Fake.stand}, {"Attri", Fake.attri}, {"GUID", Fake.guid} }) do
        local v = dataValue(spec[1])
        if spec[2] ~= nil then fakeWrite(v, "Value", spec[2]) elseif v then restoreProperty(v, "Value") end
    end
    local st = statsFolder()
    local attack = st and st:FindFirstChild("AttackDmg")
    local boost = c:FindFirstChild("DmgBoostAttri")
    if attack then if Fake.dmg ~= nil then fakeWrite(attack, "Value", Fake.dmg) else restoreProperty(attack, "Value") end end
    if boost then if Fake.boost ~= nil then fakeWrite(boost, "Value", Fake.boost) else restoreProperty(boost, "Value") end end
    local h = hum()
    if h and h.Health > 0 then
        if Fake.health ~= nil then
            local before = h.Health
            local priorClamp = Fake.clamped[h]
            if priorClamp and before ~= priorClamp.after then Fake.clamped[h] = nil end
            if fakeWrite(h, "MaxHealth", Fake.health) then
                local after = h.Health
                if after < before and after <= Fake.health then
                    local clamp = Fake.clamped[h]
                    if not clamp then Fake.clamped[h] = { before = before, after = after } else clamp.after = after end
                end
            end
        else
            restoreProperty(h, "MaxHealth")
            local clamp = Fake.clamped[h]
            if clamp and h.Health == clamp.after and h.Health > 0 then h.Health = math.min(clamp.before, h.MaxHealth) end
            Fake.clamped[h] = nil
        end
    end
    hudApply()
end

-- ── модель фейк-стенда ────────────────────────────────────────────────────
local function fakeStandClear()
    Fake.modelEnabled = false
    jobStop("fake-model")
    local m = Fake.model
    Fake.model, Fake.relCFrame, Fake.modelCode = nil, nil, nil
    if m then pcall(function() m:Destroy() end) end
end

local function findStandSource(code)
    for _, plr in ipairs(Players:GetPlayers()) do
        local c = plr.Character
        local model = c and c:FindFirstChild("Stand")
        local d = plr:FindFirstChild("Data")
        local value = d and d:FindFirstChild("Stand")
        local actual = value and (plr == LP and fakeOriginal(value, "Value") or value.Value)
        if model and model:IsA("Model") and actual ~= nil and tostring(actual) == tostring(code) then return model end
    end
    for _, folderName in ipairs({ "Storage", "QuestAssets", "UIStorage", "Vfx" }) do
        local holder = Workspace:FindFirstChild(folderName)
        local model = holder and holder:FindFirstChild(tostring(code))
        if model and model:IsA("Model") then return model end
    end
    local model = ReplicatedStorage:FindFirstChild(tostring(code))
    return model and model:IsA("Model") and model or nil
end

local function sanitizeStand(model)
    local partCount = 0
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("LuaSourceContainer") or inst:IsA("BaseScript") or inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
            inst:Destroy()
        elseif inst:IsA("BasePart") then
            partCount = partCount + 1
            inst.Anchored, inst.CanCollide, inst.CanQuery, inst.CanTouch = true, false, false, false
        elseif inst:IsA("JointInstance") or inst:IsA("WeldConstraint") then
            local external = false
            for _, property in ipairs({ "Part0", "Part1" }) do
                local ok, value = pcall(function() return inst[property] end)
                if ok and value and not value:IsDescendantOf(model) then external = true end
            end
            if external then inst:Destroy() end
        elseif inst:IsA("Constraint") then
            local external = false
            for _, property in ipairs({ "Attachment0", "Attachment1" }) do
                local ok, value = pcall(function() return inst[property] end)
                if ok and value and not value:IsDescendantOf(model) then external = true end
            end
            if external then inst:Destroy() end
        elseif inst:IsA("ObjectValue") then
            local value = inst.Value
            if value and not value:IsDescendantOf(model) then inst.Value = nil end
        elseif inst:IsA("Humanoid") then
            inst.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
    return partCount > 0
end

local function fakeStandWorker()
    return jobStart("fake-model", false, function()
        local model = Fake.model
        Fake.model, Fake.relCFrame, Fake.modelEnabled, Fake.modelCode = nil, nil, false, nil
        if model then pcall(function() model:Destroy() end) end
    end, function(job)
        while jobActive(job) and Fake.modelEnabled do
            local model, offset = Fake.model, Fake.relCFrame
            if not (model and model.Parent == Workspace and offset) then break end
            local root, h = hrp(), hum()
            if root and h and h.Health > 0 then
                local ok = pcall(function() model:PivotTo(root.CFrame * offset) end)
                if not ok then notify("Fake model tracking failed; cleared.", 4); break end
            end
            if not waitActive(0.1, job) then break end
        end
    end)
end

local function fakeStandSpawn(code, side)
    local root, h = hrp(), hum()
    if not Runtime.alive or not (root and h and h.Health > 0) then return false, "No live character root" end
    code = code and tostring(code) or standCode()
    if not code or code == "" or code == "None" then return false, "Select a stand code first" end
    local source = findStandSource(code)
    if not source or not source:IsA("Model") then return false, "No exact stand model for " .. code end
    if not source.Archivable then return false, "Source is not archivable" end
    local candidate
    local ok, err = pcall(function()
        candidate = source:Clone()
        if not candidate or not candidate:IsA("Model") then error("Clone did not produce a Model") end
        candidate.Name = "SUR_FakeStand"
        candidate:SetAttribute("SUR_FakePreview", true)
        if not sanitizeStand(candidate) then error("Stand clone has no BasePart") end
        local offset = CFrame.new(3 * (side or 1), 0, 0)
        candidate:PivotTo(root.CFrame * offset)
        if not Runtime.alive or root ~= hrp() or h ~= hum() or h.Health <= 0 then error("Character changed while cloning") end
        candidate.Parent = Workspace
        if candidate.Parent ~= Workspace then error("Could not parent preview") end
        local previous = Fake.model
        Fake.model, Fake.relCFrame, Fake.modelCode, Fake.side = candidate, offset, code, side or 1
        Fake.modelEnabled = true
        if previous then previous:Destroy() end
    end)
    if not ok then
        if candidate and candidate ~= Fake.model then pcall(function() candidate:Destroy() end) end
        return false, tostring(err)
    end
    fakeStandWorker()
    return Fake.model == candidate and Fake.modelEnabled
end

local function fakeStart()
    if not Runtime.alive then return false end
    if Fake.active and Runtime.jobs["fake-profile"] then return true end
    jobStop("stand")
    Fake.active = true
    jobStart("fake-profile", false, function()
        Fake.active = false
        fakeRestore()
        SetToggle("Fake Profile ON", "Fake", false)
    end, function(job)
        while jobActive(job) do
            fakeApply()
            if not waitActive(0.2, job) then break end
        end
    end)
    return Fake.active
end

fakeStop = function()
    if not Fake.active and not Runtime.jobs["fake-profile"] and not next(Fake.saved) then return false end
    Fake.active = false
    jobStop("fake-profile")
    if next(Fake.saved) or next(Fake.clamped) then fakeRestore() end
    SetToggle("Fake Profile ON", "Fake", false)
    return false
end
addCleanup(function() fakeStop(); fakeStandClear() end)

runConnect(LP.CharacterRemoving, function(character)
    -- No old character ledger is restored into a replacement character.
    Fake.removing = character
    fakeRestore(character)
end)
runConnect(LP.CharacterAdded, function(character)
    if char() == character then Fake.removing = nil end
end)

-- ── menu pickers use the original library ─────────────────────────────────
local PickerMenus = {}
local function makePicker(menuName, entries, onPick)
    if PickerMenus[menuName] then
        Delete(menuName) -- menu selector and ScrollingFrame share a name
        Delete(menuName)
    end
    PickerMenus[menuName] = true
    CreateMenu(menuName)
    CreateSearchBar(menuName)
    for _, entry in ipairs(entries) do
        local picked = entry
        if type(entry) == "table" and entry.value ~= nil then picked = entry.value end
        local label = type(entry) == "table" and (entry.label or tostring(picked)) or tostring(entry)
        CreateButton(label, menuName, function() onPick(picked) end)
    end
    local button = Handler and Handler:FindFirstChild(menuName)
    if button then
        for _, child in ipairs(Menus:GetChildren()) do if child:IsA("GuiObject") then child.Visible = child.Name == menuName end end
    end
end

local function setFakeText(field, text)
    local value = tostring(text or ""):match("^%s*(.-)%s*$")
    Fake[field] = value ~= "" and value or nil
    if Fake.active then fakeApply() end
    if field == "stand" and Fake.modelEnabled and Fake[field] ~= nil then
        local ok, err = fakeStandSpawn(Fake[field], Fake.side)
        if not ok then notify("Preview kept: " .. tostring(err), 4) end
    end
end

local function setFakeNumber(field, text, minimum)
    if tostring(text or ""):match("^%s*$") then
        Fake[field] = nil
    else
        local value = finiteNumber(text, minimum, 1000000000)
        if not value then notify("Enter a finite " .. field .. " value", 4); return end
        Fake[field] = value
    end
    if Fake.active then fakeApply() end
end

-- ── меню Fake ─────────────────────────────────────────────────────────────
CreateMenu("Fake")
CreateNote("Local Data / Stats / HUD only; no server stand or shared damage.", "Fake")
CreateToggle("Fake Profile ON", "Fake", function(on)
    if on then return fakeStart() end
    return fakeStop()
end)
CreateButton("Load from game (real values)", "Fake", function()
    Fake.stand = fakeOriginal(dataValue("Stand"), "Value")
    Fake.attri = fakeOriginal(dataValue("Attri"), "Value")
    Fake.guid = fakeOriginal(dataValue("GUID"), "Value")
    local st = statsFolder()
    Fake.dmg = fakeOriginal(st and st:FindFirstChild("AttackDmg"), "Value")
    Fake.boost = fakeOriginal(char() and char():FindFirstChild("DmgBoostAttri"), "Value")
    Fake.health = fakeOriginal(hum(), "MaxHealth")
    if Fake.active then fakeApply() end
    notify("Loaded real local values", 4)
end)
CreateTextBox("Stand Code", "Fake", { CustomText = "SPTW_R" }, function(t) setFakeText("stand", t) end)
CreateTextBox("Attribute", "Fake", { CustomText = "Godly" }, function(t) setFakeText("attri", t) end)
CreateTextBox("GUID", "Fake", { CustomText = "00000000-0000-0000-0000-000000000000" }, function(t) setFakeText("guid", t) end)
CreateTextBox("Stand Damage", "Fake", { CustomText = "9999" }, function(t) setFakeNumber("dmg", t, 0) end)
CreateTextBox("Damage Boost", "Fake", { CustomText = "9999" }, function(t) setFakeNumber("boost", t, 0) end)
CreateTextBox("Stand Health", "Fake", { CustomText = "99999" }, function(t) setFakeNumber("health", t, 1) end)
CreateButton("List all stands", "Fake", function()
    local catalog, names = standCatalog(), {}
    for i = 1, math.min(#catalog, 12) do names[#names + 1] = catalog[i].code end
    notify(#catalog .. " stands: " .. table.concat(names, ", "), 8)
end)
CreateButton("Open stand list", "Fake", function()
    local entries = {}
    for _, entry in ipairs(standCatalog()) do entries[#entries + 1] = { value = entry.code, label = entry.pretty .. " [" .. entry.code .. "]" } end
    makePicker("Fake: Stands", entries, function(code) setFakeText("stand", code) end)
end)
CreateButton("Open attribute list", "Fake", function()
    makePicker("Fake: Attributes", attriCatalog(), function(value) Fake.attri = value; if Fake.active then fakeApply() end end)
end)
CreateButton("Open stand model list", "Fake", function()
    local entries = {}
    for _, entry in ipairs(standCatalog()) do entries[#entries + 1] = entry.code end
    makePicker("Fake: Models", entries, function(code)
        local ok, err = fakeStandSpawn(code, 1)
        if not ok then notify(err, 4) end
    end)
end)
CreateButton("Fake stand model ON", "Fake", function()
    local ok, err = fakeStandSpawn(Fake.stand, 1)
    if not ok then notify(err, 4) end
end)
CreateButton("Fake stand model OFF", "Fake", function() fakeStandClear() end)
CreateButton("Read current from HUD", "Fake", function()
    print("[HUD] stand = " .. standGuiName())
    notify("HUD: " .. standGuiName(), 4)
end)
CreateButton("Print what /check will show", "Fake", function()
    local st = statsFolder()
    local attack = st and st:FindFirstChild("AttackDmg")
    local boost = char() and char():FindFirstChild("DmgBoostAttri")
    notify("Local check: stand=" .. standName() .. " attri=" .. tostring(dataValue("Attri") and dataValue("Attri").Value)
        .. " hp=" .. tostring(hum() and hum().MaxHealth) .. " dmg=" .. tostring(attack and math.floor(attack.Value * (boost and boost.Value or 1)))
        .. " guid=" .. tostring(dataValue("GUID") and dataValue("GUID").Value), 8)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- AUTO KILL — exact mouse-selected NPC, behind teleport, local Health = 0
-- ══════════════════════════════════════════════════════════════════════════
AutoKill = { enabled = false, target = nil, root = nil, humanoid = nil, behind = 6, picking = false, token = 0 }

local function isPlayerDescendant(instance)
    for _, player in ipairs(Players:GetPlayers()) do
        local c = player.Character
        if c and (instance == c or instance:IsDescendantOf(c)) then return true end
    end
    return false
end

local function isNpcModel(model)
    local L = living()
    if not (model and model:IsA("Model") and model.Parent == L and L) or isPlayerDescendant(model)
        or model == Fake.model or model:GetAttribute("SUR_FakePreview") then return false end
    local h, root = model:FindFirstChildOfClass("Humanoid"), model:FindFirstChild("HumanoidRootPart")
    return h and h.Health > 0 and root and root:IsA("BasePart") and true or false
end

local function modelFromInstance(instance)
    local L = living()
    local cursor = instance
    if not L or not cursor or isPlayerDescendant(cursor) then return nil end
    while cursor and cursor ~= L and cursor ~= Workspace do
        if cursor.Parent == L then return isNpcModel(cursor) and cursor or nil end
        cursor = cursor.Parent
    end
    return nil
end

local function selectionNote(text)
    setNote("Selected target:", "Selected target: " .. (text or "None"))
end

local function cancelPicker()
    AutoKill.token = AutoKill.token + 1
    AutoKill.picking = false
    jobStop("target-picker")
end

local function autoKillStop(clear)
    AutoKill.enabled = false
    jobStop("auto-kill")
    SetToggle("Auto Kill Selected", "Auto Kill", false)
    if clear then
        cancelPicker()
        AutoKill.target, AutoKill.root, AutoKill.humanoid = nil, nil, nil
        selectionNote(nil)
    end
end

local function selectedTargetReady(model, root, h)
    return isNpcModel(model) and AutoKill.target == model and AutoKill.root == root and AutoKill.humanoid == h
        and model:FindFirstChild("HumanoidRootPart") == root and model:FindFirstChildOfClass("Humanoid") == h
end

local function killBehind(model, root, targetHum, distance, job)
    local me, localHum, character = hrp(), hum(), char()
    if not jobActive(job) or not selectedTargetReady(model, root, targetHum) or not (me and localHum and localHum.Health > 0) then return false end
    local want = root.CFrame * CFrame.new(0, 0, distance)
    local moved = pcall(function() me.CFrame = want end)
    if not moved or not jobActive(job) or char() ~= character or hrp() ~= me or localHum.Health <= 0
        or not selectedTargetReady(model, root, targetHum) or (me.Position - want.Position).Magnitude > 1 then return false end
    -- No fallback damage/state changes. Success is local Health only.
    local ok = pcall(function() targetHum.Health = 0 end)
    return ok and targetHum.Health == 0
end

CreateMenu("Auto Kill")
CreateNote("Select target → click the boss in the world.", "Auto Kill")
CreateNote("Selected target: None", "Auto Kill")
CreateNote("HP write is local; server kill and reward are unverified.", "Auto Kill")
CreateButton("Select target (click boss)", "Auto Kill", function()
    autoKillStop(true)
    AutoKill.picking = true
    local token = AutoKill.token
    jobStart("target-picker", false, function()
        if AutoKill.token == token then AutoKill.picking = false end
    end, function(job)
        if waitActive(15, job) and AutoKill.token == token then
            AutoKill.picking = false
            notify("Target selection expired", 3)
        end
    end)
    notify("Click the NPC itself; Escape/right click cancels", 6)
end)
CreateTextBox("Behind distance", "Auto Kill", { CustomText = "6" }, function(t)
    local value = finiteNumber(t, 0.5, 100)
    if value then AutoKill.behind = value end
end)
CreateToggle("Auto Kill Selected", "Auto Kill", function(on)
    if not on then autoKillStop(false); return false end
    cancelPicker()
    local target, root, h = AutoKill.target, AutoKill.root, AutoKill.humanoid
    if not selectedTargetReady(target, root, h) or not (hrp() and hum() and hum().Health > 0) then
        autoKillStop(true)
        notify("No live exact target; select it first.", 4)
        return false
    end
    AutoKill.enabled = true
    jobStart("auto-kill", true, function()
        AutoKill.enabled = false
        SetToggle("Auto Kill Selected", "Auto Kill", false)
    end, function(job)
        if not selectedTargetReady(target, root, h) then return end
        local success = killBehind(target, root, h, AutoKill.behind, job)
        notify(success and "Local selected HP=0; server kill unconfirmed." or "Selected action failed; stopped.", 5)
    end)
    return AutoKill.enabled
end)
CreateButton("Stop Auto Kill", "Auto Kill", function() autoKillStop(true); notify("Auto Kill stopped", 3) end)

-- клик по миру = выбор цели, пока включён режим picking
runConnect(UIS.InputBegan, function(input, gameProcessed)
    if not Runtime.alive or not AutoKill.picking then return end
    if input.KeyCode == Enum.KeyCode.Escape or input.UserInputType == Enum.UserInputType.MouseButton2 then
        autoKillStop(true); return
    end
    if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or UIS:GetFocusedTextBox() then return end
    local token = AutoKill.token
    local ok, mouse = pcall(function() return LP:GetMouse() end)
    local target = ok and mouse and modelFromInstance(mouse.Target) or nil
    if token ~= AutoKill.token or not Runtime.alive then return end
    cancelPicker()
    AutoKill.target = target
    AutoKill.root = target and target:FindFirstChild("HumanoidRootPart") or nil
    AutoKill.humanoid = target and target:FindFirstChildOfClass("Humanoid") or nil
    selectionNote(target and target.Name)
    notify(target and ("Target: " .. target.Name) or "Nothing selected; click the NPC itself", 4)
end)
runConnect(LP.CharacterRemoving, function() autoKillStop(true) end)
addCleanup(function() autoKillStop(true) end)
end
installFakeTargetBlock()
end -- Private Fake/Auto Kill helpers; only state and stop escape this scope.
-- END SUR FAKE TARGET BLOCK

-- SUR CONTROL API
-- Пульт для агента/консоли. UI не трогает, меню не меняет — только дёргает
-- те же функции, что и кнопки. Нужен, чтобы фарм можно было поднять без
-- кликов по тогглам.
-- ══════════════════════════════════════════════════════════════════════════
local SUR = {}
local publicEnv = getgenv()
publicEnv.SUR = SUR

function SUR.unload()
    if not Runtime.alive then return true end
    Runtime.alive = false
    local names = {}
    for name in pairs(Runtime.jobs) do names[#names + 1] = name end
    for _, name in ipairs(names) do jobStop(name) end
    AutoUmbrella, AntiAFK, SellKetchup = false, false, false
    StartLairFarming, StartQuestFarming, StartFarming, StandFarm = false, false, false, false
    for name in pairs(BossOn) do BossOn[name] = false end
    for held in pairs(Runtime.heldInputs) do
        pcall(function() held.remote:FireServer({ State = "End", Key = held.key, Type = held.utype }) end)
    end
    Runtime.heldInputs = {}
    for prompt in pairs(Runtime.heldPrompts) do pcall(function() prompt:InputHoldEnd() end) end
    Runtime.heldPrompts = {}
    for _, connection in ipairs(Runtime.connections) do pcall(function() connection:Disconnect() end) end
    Runtime.connections = {}
    for thread in pairs(Runtime.tasks) do
        if thread ~= coroutine.running() and task.cancel then pcall(task.cancel, thread) end
    end
    Runtime.tasks = {}
    for i = #Runtime.cleanup, 1, -1 do
        local ok, err = pcall(Runtime.cleanup[i])
        if not ok then warn("[Arctic SUR] cleanup: " .. tostring(err)) end
    end
    Runtime.cleanup = {}
    UIDestroy()
    -- An old retained unload reference must never erase a newer injection.
    if publicEnv.SUR == SUR then publicEnv.SUR = nil end
    if publicEnv.SUR_unload == SUR.unload then publicEnv.SUR_unload = nil end
    return true
end
publicEnv.SUR_unload = SUR.unload

-- Local character transitions cannot carry a farm into an unrelated spawn.
runConnect(LP.CharacterRemoving, function()
    Runtime.movementRevision = Runtime.movementRevision + 1
    if not Runtime.jobs.lair then clearLairContext() end
    local job = Runtime.movement
    if job and job.name == "lair" then
        stopLairFarm("character_changed", "character changed")
    elseif job then
        jobStop(job.name)
    end
end)

stopFakeProfile = function() fakeStop() end

function SUR.state()
    local p = hrp()
    return {
        player    = LP.Name,
        level     = (function()
            local d = LP:FindFirstChild("Data")
            local l = d and d:FindFirstChild("Level")
            return l and l.Value or nil
        end)(),
        place     = game.PlaceId,
        stand     = standName(),
        attri     = standAttri(),
        moves     = #ClearMoves,
        standCode = standCode(),
        active    = Runtime.alive,
        movement  = Runtime.movement and Runtime.movement.name or nil,
        fakeOn    = Fake.active,
        autoKill  = AutoKill.enabled,
        picking   = AutoKill.picking,
        selectedTarget = AutoKill.target and AutoKill.target.Name or nil,
        position  = p and { X = p.Position.X, Y = p.Position.Y, Z = p.Position.Z } or nil,
        lairNPC   = SelectedLairNPCText,
        lairOn    = StartLairFarming,
        lairPhase = LairState.phase,
        lairStopReason = LairState.stopReason,
        lairDetail = LairState.detail,
        lairEntrySent = LairState.entrySent,
        lairProbeAttempted = LairState.probe and LairState.probe.attempted or false,
        lairLocalZeroOwned = LairState.probe and LairState.probe.ownedZero or false,
        lairResumeUntil = LairState.context and LairState.context.resumeUntil or nil,
        lairAnchor = LairState.anchor and { X = LairState.anchor.X, Y = LairState.anchor.Y, Z = LairState.anchor.Z } or nil,
        instant   = InstantBossKill,
        underneath= Underneath,
        bossAlive = (function()
            local b = StartLairFarming and LairState.target or findLairBoss()
            return b and b.Parent and b.Name or nil
        end)(),
    }
end

-- Список NPC вокруг: имя, дистанция, есть ли Done/QuestDone.
function SUR.npcs(radius)
    local p = hrp()
    local nf = npcFolder()
    local out = {}
    if not Runtime.alive or not (p and nf) then return out end
    radius = finiteNumber(radius, 1, 10000) or 400
    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        if root then
            local d = (p.Position - root.Position).Magnitude
            if d <= (radius or 400) then
                out[#out + 1] = {
                    name    = v.Name,
                    dist    = math.floor(d),
                    done    = v:FindFirstChild("Done") ~= nil,
                    quest   = v:FindFirstChild("QuestDone") ~= nil,
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

-- Выбор лейр-NPC: по имени (частичное совпадение) или ближайшего.
-- radius обязателен: без него можно было зацепить NPC в другой части карты
-- и уехать телепортом из лейра в обычный мир.
function SUR.selectLair(fragment, radius)
    local nf = npcFolder()
    if not nf then return false, "no Map.NPCs" end

    if not Runtime.alive then return false, "unloaded" end
    radius = finiteNumber(radius, 1, 500) or 15
    if fragment ~= nil then fragment = tostring(fragment) end
    local p = hrp()
    if not p then return false, "no character" end

    local pick, pickDist = nil, math.huge

    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        local okName = (not fragment) or string.find(string.lower(v.Name), string.lower(fragment), 1, true)
        local done = v:FindFirstChild("Done")
        if root and okName and done and done:IsA("RemoteEvent") then
            local d = (p.Position - root.Position).Magnitude
            if d <= radius and d < pickDist then pick, pickDist = v, d end
        end
    end

    if not pick then return false, "no match within " .. radius .. " studs" end

    local head = pick:FindFirstChild("Head")
    local main = head and head:FindFirstChild("Main")
    local txt  = main and main:FindFirstChild("Text")

    stopLairFarm("provider_changed", "Lair NPC reselected")
    SelectedLairNPC = pick
    SelectedLairNPCText = (txt and txt.Text) or pick.Name
    setNote("Selected Lair NPC:", "Selected Lair NPC: " .. SelectedLairNPCText)
    return true, SelectedLairNPCText
end

function SUR.underneath(on)
    if not Runtime.alive then return false end
    Underneath = on ~= false
    SetToggle("Underneath", "Lair Farm", Underneath)
    return Underneath
end

function SUR.instantKill(on)
    if not Runtime.alive then return false end
    InstantBossKill = on == true
    SetToggle("Instant Boss Kill (HP = 0)", "Lair Farm", InstantBossKill)
    return InstantBossKill
end

function SUR.lairStart()
    local on = startLairFarm()
    SetToggle("Begin Lair Farm", "Lair Farm", on)
    return on
end

function SUR.lairStop()
    stopLairFarm()
    return true
end

-- Диагностика живого клиента: что реально лежит в Living и в Map.NPCs.
function SUR.scan()
    local L = living()
    local out = { living = {}, npcFolders = {}, playerGui = {} }

    if L then
        for _, m in ipairs(L:GetChildren()) do
            local h = m:FindFirstChildOfClass("Humanoid")
            out.living[#out.living + 1] = {
                name  = m.Name,
                human = h ~= nil,
                hp    = h and h.Health or nil,
                max   = h and h.MaxHealth or nil,
                root  = m:FindFirstChild("HumanoidRootPart") ~= nil,
            }
        end
    end

    local nf = npcFolder()
    if nf then
        for _, v in ipairs(nf:GetChildren()) do
            out.npcFolders[#out.npcFolders + 1] = {
                name = v.Name,
                done = v:FindFirstChild("Done") ~= nil,
            }
        end
    end

    return out
end


function SUR.diagnostics()
    local out = { active = Runtime.alive, jobs = {}, errors = {}, connections = 0, tasks = 0,
        lair = { phase = LairState.phase, stopReason = LairState.stopReason, detail = LairState.detail, trace = {} } }
    for i, entry in ipairs(LairState.trace) do
        out.lair.trace[i] = { time = entry.time, phase = entry.phase, reason = entry.reason, detail = entry.detail }
    end
    local ctx = LairState.context
    out.lair.context = ctx and {
        inplace = ctx.inplace == true, entrySent = ctx.entrySent == true,
        resumeUntil = ctx.resumeUntil, exact = lairExact(ctx),
        revision = ctx.movementRevision, currentRevision = Runtime.movementRevision,
        ownedZero = ctx.probe and ctx.probe.ownedZero or false,
        targetHealth = ctx.targetHum and ctx.targetHum.Health or nil,
    } or nil
    for name in pairs(Runtime.jobs) do out.jobs[#out.jobs + 1] = name end
    table.sort(out.jobs)
    for _, connection in ipairs(Runtime.connections) do if connection.Connected then out.connections = out.connections + 1 end end
    for thread in pairs(Runtime.tasks) do
        if coroutine.status(thread) ~= "dead" then out.tasks = out.tasks + 1 else Runtime.tasks[thread] = nil end
    end
    for i, err in ipairs(Runtime.errors) do out.errors[i] = err end
    return out
end

pcall(function()
    CreateNotification("Arctic", "Loaded. Press L to toggle.", { Duration = 6 })
end)
print("[Arctic SUR] loaded | stand=" .. standName() .. " | attri=" .. standAttri())
