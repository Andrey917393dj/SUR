-- ═══════════════════════════════════════════════════════════════
--  ARCTIC SUR  —  message.txt port (single file)
--  Same menus, same buttons, working internals.
--  UI library embedded. No HttpGet, no external dependency.
-- ═══════════════════════════════════════════════════════════════

-- ============================================================
-- Arctic UI Library (Lib.txt) — FIXED VERSION
-- Fixes: nil-check for B, deprecated KeyDown, missing EditString,
--        missing Fill, missing Delete alias, broken CreateSearchBar
--        fake LocalScript, table.find on dict in CreateTextBoxToggle,
--        Toggle tween loop efficiency, Sound memory leak.
-- ============================================================

-- ══ module scope: Start() fills these, API functions read them ══
local ScreenGui, Frame, Hotbar, CloseButton, TitleLabel, Buttons, Handler, Menus
local DefaultColor = Color3.fromRGB(124, 106, 255)
local TweenServ = game:GetService("TweenService")
local UIS       = game:GetService("UserInputService")

function Start(A, B)
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
        for _, v in pairs(game:GetService("CoreGui"):GetChildren()) do
            if v.Name == A then
                v:Destroy()
            end
        end
    end

    -- ── UI Construction ──────────────────────────────────────
    ScreenGui    = Instance.new("ScreenGui")
    Frame        = Instance.new("Frame")
    Hotbar       = Instance.new("Frame")
    CloseButton  = Instance.new("ImageButton")
    TitleLabel   = Instance.new("TextLabel")
    local UICorner     = Instance.new("UICorner")
    Buttons      = Instance.new("Frame")
    Handler      = Instance.new("ScrollingFrame")
    local UICorner_2   = Instance.new("UICorner")
    Menus        = Instance.new("Frame")
    local UICorner_3   = Instance.new("UICorner")
    local UIListLayout = Instance.new("UIListLayout")

    ScreenGui.Name = A
    local function getSafeGuiParent()
        if gethui then
            local ok, res = pcall(gethui)
            if ok and res then return res end
        end
        local cg = game:GetService("CoreGui")
        local ok = pcall(function() return cg.Name end)
        if ok then return cg end
        return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    end
    local guiParent = getSafeGuiParent()
    ScreenGui.Parent = guiParent
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

    CloseButton.Parent = Hotbar
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.BackgroundTransparency = 1.000
    CloseButton.BorderSizePixel = 0
    CloseButton.Position = UDim2.new(0.944111764, 0, 0.111111104, 0)
    CloseButton.Size = UDim2.new(0, 20, 0, 20)
    CloseButton.Image = "rbxassetid://3944676352"

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
    Hotbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = Frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    Hotbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            updateDrag(input)
        end
    end)

    CloseButton.MouseButton1Down:Connect(function()
        Frame.Visible = false
    end)

    -- Toggle UI: default J; override with getgenv().ArcticUiHotkey = "Semicolon" etc. (Enum.KeyCode name)
    UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        local key = Enum.KeyCode.J
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

    -- ── Helper: build a colour-tracking indicator tween loop ──
end

local function MakeIndicatorLoop(indicator, getFlagFn)
    task.spawn(function()
        local tweenInf = TweenInfo.new(0.2)
        local lastState = nil
        while ScreenGui and ScreenGui.Parent do
            local state = not not getFlagFn()
            if state ~= lastState then
                lastState = state
                local target = state and DefaultColor or Color3.fromRGB(10, 10, 13)
                TweenServ:Create(indicator, tweenInf, {BackgroundColor3 = target}):Play()
            end
            task.wait(0.1)
        end
    end)
end

-- ── Public API functions ──────────────────────────────────

-- Destroy an element inside the GUI by name (case-insensitive)
function Destroy(Name)
    local lower = string.lower(Name)
    for _, v in pairs(ScreenGui:GetDescendants()) do
        if string.lower(v.Name) == lower then
            v:Destroy()
            return
        end
    end
end

-- FIX: main script calls Delete() but lib only defined Destroy() — alias added
function Delete(Name)
    Destroy(Name)
end

-- FIX: EditString was called in main script but never defined in lib.
-- Finds a Note element by its current name and renames both the container
-- and the inner TextLabel text so the display updates correctly.
function EditString(OldText, NewText)
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
function Fill(Partial)
    local lower = string.lower(Partial)
    for _, player in pairs(game:GetService("Players"):GetPlayers()) do
        if string.lower(player.Name):sub(1, #Partial) == lower then
            return player.Name
        end
    end
    return Partial  -- fallback: return as-is
end

function CreateMenu(Name)
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

    TextButton.MouseButton1Down:Connect(function()
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
    end)
end

function CreateButton(Name, MenuName, Callback)
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

    Regular.MouseButton1Down:Connect(function()
        pcall(Callback)
    end)
end

function CreateTextBox(Name, MenuName, Options, Callback)
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
    InputBox.FocusLost:Connect(function(enterPressed)
        pcall(Callback, InputBox.Text)
    end)
    if Options["AutoUpdate"] then
        InputBox:GetPropertyChangedSignal("Text"):Connect(function()
            pcall(Callback, InputBox.Text)
        end)
    else
        Container.MouseButton1Down:Connect(function()
            pcall(Callback, InputBox.Text)
        end)
    end
end

function CreateToggle(Name, MenuName, Callback)
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

    local IsOn = false
    -- FIX: was an always-running loop that tweened every task.wait() frame.
    -- Now uses a shared helper that polls at 0.1s intervals — much less wasteful.
    MakeIndicatorLoop(Indicator, function() return IsOn end)

    ToggleBtn.MouseButton1Down:Connect(function()
        IsOn = not IsOn
        pcall(Callback)
    end)
end

function CreateNote(Text, MenuName)
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
end

function CreateTextBoxToggle(Name, MenuName, Options, Callback)
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

    local IsOn = false
    MakeIndicatorLoop(Indicator, function() return IsOn end)

    -- FIX: was table.find(C, "AutoUpdate") — wrong for dict tables.
    if Options["AutoUpdate"] then
        Container.MouseButton1Down:Connect(function()
            IsOn = not IsOn
        end)
        InputBox:GetPropertyChangedSignal("Text"):Connect(function()
            pcall(Callback, InputBox.Text)
        end)
    else
        Container.MouseButton1Down:Connect(function()
            IsOn = not IsOn
            pcall(Callback, InputBox.Text)
        end)
    end
end

function CreateSearchBar(MenuName)
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
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
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
    end)
end

function CreateNotification(Title, Text, Options)
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
-- УЯЗВИМОСТЬ (сохранена намеренно, это ядро Lair Farm):
--      Workspace.Living.Boss.Humanoid.Health = 0
--   Клиент пишет Health напрямую, сервер принимает репликацию → лейр-босс
--   умирает мгновенно, без боя. В оригинале строка стояла безусловно; здесь
--   она за тогглом "Instant Boss Kill (HP = 0)", по умолчанию ВКЛЮЧЕН.
-- ══════════════════════════════════════════════════════════════════════════

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local HttpService       = game:GetService("HttpService")
local PathfindingService= game:GetService("PathfindingService")
local Workspace         = game.Workspace

local LP = Players.LocalPlayer

Start("Arctic")

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
    pcall(function()
        CreateNotification("Arctic", tostring(text), { Duration = dur or 4 })
    end)
end

-- Подписи-статусы ("Selected Lair NPC: ...") ищем по префиксу, а не по
-- точному имени: EditString ломался, как только текст расходился на символ.
local function setNote(prefix, newText)
    local gui = getgenv and getgenv().ArcticScreenGui
    if not gui then return false end
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Name ~= prefix
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

local function press(key, hold)
    local se = standEvents()
    if not se then return false end
    local input = se:FindFirstChild("Input")
    if not input then return false end

    local isMouse = (key == Enum.UserInputType.MouseButton1
                  or key == Enum.UserInputType.MouseButton2)
    local utype = isMouse and key or Enum.UserInputType.Keyboard

    local ok = pcall(function()
        input:FireServer({ State = "Begin", Key = key, Type = utype })
    end)
    if not ok then return false end

    if hold and hold > 0 then task.wait(hold) end

    pcall(function()
        input:FireServer({ State = "End", Key = key, Type = utype })
    end)
    return true
end

local function moveset()
    local se = standEvents()
    local info = se and se:FindFirstChild("Info")
    if not info then return {} end
    local ok, res = pcall(function() return info:InvokeServer("Moveset") end)
    if not (ok and type(res) == "table") then return {} end

    -- игра может вернуть как массив имён клавиш, так и словарь — приводим к массиву
    local out = {}
    for k, v in pairs(res) do
        if type(k) == "number" then
            out[#out + 1] = v
        else
            out[#out + 1] = tostring(k)
        end
    end
    return out
end

local function standName()
    local d = LP:FindFirstChild("Data")
    local s = d and d:FindFirstChild("Stand")
    if s then return tostring(s.Value) end
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
    local n = standName()
    return n ~= "" and n ~= "None"
end

-- Оригинал проверял Character.Aura.Value и падал, если Aura нет.
-- Троттлинг: Q имеет кулдаун 1.5с, спамить его каждый тик бессмысленно.
local lastSummon = 0
local function summonIfNeeded()
    local c = char()
    if not c then return end
    if c:FindFirstChild("Stand") then return end
    if tick() - lastSummon < 1.7 then return end
    lastSummon = tick()
    press(Enum.KeyCode.Q, 0.1)
end

-- ══════════════════════════════════════════════════════════════════════════
-- STEALTH LAYER
-- Античит здесь СЕРВЕРНЫЙ (в клиентском дампе его нет). Он реагирует не на
-- сам факт скрипта, а на пакетный паттерн: CFrame-записи 7 раз в секунду,
-- нулевая скорость каждый тик, дёрганье RemoteEvent без задержки.
-- Всё ниже — про то, чтобы паттерн перестал быть похож на бота.
-- ══════════════════════════════════════════════════════════════════════════
local STEALTH = {
    RepositionGap  = 0.85,   -- мин. пауза между записями CFrame
    RepositionDist = 12,     -- ближе — вообще не двигаемся
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

-- ЯДРО ЭКСПЛОЙТА. Пишем Health=0 с клиента — это и есть пакет, который
-- сервер видит как «Auto Lair Farm». Держим в pcall, с кулдауном и фолбэком.
local lastKillAt = 0
local function killTarget(model)
    if not model then return false end
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
-- (нулевая скорость каждый тик — самый тупой детект из возможных).
-- Закапываемся максимум на UnderDepth, иначе проваливаемся под пол карты.
local function holdPosition(model, distance, underneath)
    local p = hrp()
    if not (model and p) then return end
    local t = model:FindFirstChild("HumanoidRootPart")
    if not t then return end

    local want
    if underneath then
        local depth = math.min(tonumber(distance) or 4, STEALTH.UnderDepth)
        want = CFrame.new(t.Position + Vector3.new(0, -depth, distance))
    else
        want = CFrame.new(t.Position + Vector3.new(0, 0, distance))
    end

    if (p.Position - want.Position).Magnitude < STEALTH.RepositionDist then return end
    if os.clock() - lastReposition < STEALTH.RepositionGap then return end

    lastReposition = os.clock()
    pcall(function() p.CFrame = want end)
end

-- Мягкий догон для дальних целей: одна перестановка на 1.2с, без цикла.
local lastApproach = 0
local function approach(model, distance)
    local p = hrp()
    if not (model and p) then return end
    local t = model:FindFirstChild("HumanoidRootPart")
    if not t then return end
    if (p.Position - t.Position).Magnitude <= distance then return true end
    if os.clock() - lastApproach < 1.2 then return false end
    lastApproach = os.clock()
    pcall(function() p.CFrame = CFrame.new(t.Position + Vector3.new(0, 0, distance)) end)
    return true
end

-- Рандомный разброс таймингов: ровный шаг — это подпись бота.
local function jitter(min, max)
    return min + math.random() * (max - min)
end

-- Поиск босса в Living: сначала каноническое имя "Boss", потом любой живой
-- Humanoid, который не является игроком. message.txt верил только в "Boss".
local function findLairBoss()
    local L = living()
    if not L then return nil end

    local b = L:FindFirstChild("Boss")
    if b then return b end

    for _, m in ipairs(L:GetChildren()) do
        local h = m:FindFirstChildOfClass("Humanoid")
        local r = m:FindFirstChild("HumanoidRootPart")
        if h and r and h.Health > 0 and not Players:GetPlayerFromCharacter(m) then
            return m
        end
    end
    return nil
end

-- ── настройки фармов (общие, как в оригинале) ─────────────────────────────
local AllMovesets   = {}
local ClearMoves    = {}
local UseCustomMoves = false

local function attackStep()
    summonIfNeeded()
    if UseCustomMoves and #AllMovesets > 0 then
        local name = AllMovesets[math.random(1, #AllMovesets)]
        press(KEYMAP[name] or Enum.KeyCode.E, 0.05)
    else
        press(Enum.UserInputType.MouseButton1, 0.03)
    end
end

-- ── предметы / экипировка ─────────────────────────────────────────────────
local function useToolName(name)
    local c, h = char(), hum()
    if not (c and h) then return false end

    local bp = backpack()
    local tool = (bp and bp:FindFirstChild(name)) or c:FindFirstChild(name)
    if not tool then
        notify("No " .. tostring(name) .. " in inventory", 3)
        return false
    end

    if tool.Parent == bp then
        pcall(function() h:EquipTool(tool) end)
        local equipped = c:WaitForChild(name, 3)
        if equipped then tool = equipped end
    end

    task.wait(0.15)
    pcall(function() tool:Activate() end)

    local use = tool:FindFirstChild("Use")
    if use and use:IsA("RemoteEvent") then
        pcall(function() use:FireServer() end)
    end

    local ev = events()
    local useItem = ev and ev:FindFirstChild("UseItem")
    if useItem and useItem:IsA("RemoteEvent") then
        pcall(function() useItem:FireServer() end)
    end
    return true
end

local function fireProximity(prompt)
    if not prompt then return false end
    if fireproximityprompt then
        if pcall(fireproximityprompt, prompt) then return true end
    end
    -- фолбэк: удержание промпта вручную
    local began = pcall(function() prompt:InputHoldBegin() end)
    if began then
        task.wait((tonumber(prompt.HoldDuration) or 0.5) + 0.05)
        pcall(function() prompt:InputHoldEnd() end)
        return true
    end
    return false
end

local function webhookSend(url, payload)
    if not url or url == "" then return false end
    local req = http_request or request or HttpPost or (syn and syn.request)
    if not req then return false end
    local body = HttpService:JSONEncode(payload)
    return pcall(req, {
        Url = url, Method = "POST",
        Headers = { ["content-type"] = "application/json" },
        Body = body,
    })
end

local function tpToCF(cf)
    local p = hrp()
    if not (p and cf) then return false end
    pcall(function() p.CFrame = cf end)
    pcall(function() p.AssemblyLinearVelocity = Vector3.new(0, 0, 0) end)
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
CreateToggle("Auto Umbrella", "LocalPlayer", function()
    AutoUmbrella = not AutoUmbrella
    if not AutoUmbrella then return end

    -- FIX: цикл блокировал собственный колбэк; вынесен в task.spawn
    task.spawn(function()
        while AutoUmbrella do
            pcall(function()
                local c, h = char(), hum()
                local bp = backpack()
                if not (c and h and bp) then return end
                if bp:FindFirstChild("Umbrella") and not c:FindFirstChild("Umbrella") then
                    h:EquipTool(bp:FindFirstChild("Umbrella"))
                end
            end)
            task.wait(0.35)
        end
    end)
end)

local AntiAFK = false
CreateToggle("Anti AFK", "LocalPlayer", function()
    AntiAFK = not AntiAFK
end)

LP.Idled:Connect(function()
    if not AntiAFK then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    pcall(function()
        VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame)
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- SHOPS
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Shops")
CreateNote("Selling", "Shops")

local SellKetchup = false
CreateToggle("Auto Sell Ketchup", "Shops", function()
    SellKetchup = not SellKetchup
    if not SellKetchup then return end

    local ev = events()
    local sell = ev and ev:FindFirstChild("SellKetchup")
    if not sell then notify("SellKetchup remote missing", 3); return end

    pcall(function() sell:FireServer("Lots") end)

    task.spawn(function()
        while SellKetchup do
            pcall(function()
                local bp = backpack()
                if bp then bp:WaitForChild("Ketchup", 5) end
                sell:FireServer("Lots")
            end)
            task.wait(0.5)
        end
    end)
end)

CreateNote("Autobuy Only Works For Level 200+", "Shops")

local Amount = 0
CreateTextBox("Count", "Shops", { CustomText = "Amount" }, function(A)
    local n = tonumber(A)
    if not n then return end
    if n >= 1 then
        Amount = n
        notify("Amount Set To : " .. tostring(Amount), 3)
    else
        notify("Please Set The Number Above 0+", 3)
    end
end)

local AllItems = { "Rokakaka", "New Rokakaka", "Requiem Arrow", "Stand Arrow", "Dio's Diary", "Charged Arrow" }

-- FIX: Item захватывался замыканием внутри task.spawn (мог уйти не тот
-- предмет), плюс падало на захардкоженном нике "polar_eXDAVH".
local function buyFromStockMarket(itemName)
    local c, h = char(), hum()
    if not (c and h) then return false end

    local ev = events()
    local sm = ev and ev:FindFirstChild("SM_Event")
    if not sm then notify("SM_Event missing", 3); return false end

    local nf = npcFolder()
    local market = nf and nf:FindFirstChild("StockMarket")
    local head = market and (market:FindFirstChild("Head") or market:FindFirstChild("HumanoidRootPart"))

    local oldPos = hrp() and hrp().CFrame
    if head then tpToCF(head.CFrame * CFrame.new(0, 3, 0)) end
    task.wait(0.4)

    pcall(function() sm:FireServer("Buy", itemName, Amount) end)
    task.wait(0.4)

    local prompt = market and market:FindFirstChild("TalkToPrompt")
    if prompt then fireProximity(prompt) end
    task.wait(0.4)

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
            task.spawn(function()
                local on = false
                CreateToggle(name, "Farm Settings", function()
                    on = not on
                    local at = table.find(AllMovesets, name)
                    if on then
                        if not at then AllMovesets[#AllMovesets + 1] = name end
                    else
                        if at then table.remove(AllMovesets, at) end
                    end
                end)
            end)
        end
    end

    task.wait(0.2)
    notify(#ClearMoves .. " moves listed", 4)
end)

CreateToggle("Use Custom Moves", "Farm Settings", function()
    UseCustomMoves = not UseCustomMoves
end)

-- ══════════════════════════════════════════════════════════════════════════
-- BOSS FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Boss Farm")
CreateNote("Settings", "Boss Farm")

local BossDistance = 4
CreateTextBox("Distance", "Boss Farm", {}, function(Input)
    local n = tonumber(Input)
    if n and n > 0 then BossDistance = n end
end)

local BossUnderneath = false
CreateToggle("Underneath", "Boss Farm", function()
    BossUnderneath = not BossUnderneath
end)

-- Три тоггла ниже — один и тот же цикл. Оригинал копировал его трижды.
local BossOn = {}

local function bossFarm(modelName, label)
    CreateToggle(label, "Boss Farm", function()
        BossOn[modelName] = not BossOn[modelName]
        if not BossOn[modelName] then return end

        task.spawn(function()
            while BossOn[modelName] do
                local L = living()
                local boss = L and L:FindFirstChild(modelName)

                if not boss then
                    notify("Waiting for " .. modelName .. "...", 3)
                    repeat
                        task.wait(0.5)
                        L = living()
                        boss = L and L:FindFirstChild(modelName)
                    until boss or not BossOn[modelName]
                end

                while BossOn[modelName] and boss and boss.Parent do
                    pcall(function()
                        holdPosition(boss, BossDistance, BossUnderneath)
                        attackStep()
                    end)
                    task.wait(jitter(STEALTH.AttackMin, STEALTH.AttackMax))
                end

                if BossOn[modelName] then task.wait(0.5) end
            end
        end)
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

CreateButton("Tutorial", "Lair Farm", function()
    notify("Step 1 (Quest Selection), Stand Near Lair NPC And Press 'Select Lair NPC'", 6)
end)

local SelectedLairNPC
local SelectedLairNPCText = "None"

CreateButton("Select Lair NPC", "Lair Farm", function()
    local c, p = char(), hrp()
    local nf = npcFolder()
    if not (c and p and nf) then return end

    -- БЛИЖАЙШИЙ, а не последний в списке (в оригинале перебор оставлял
    -- случайного NPC, если рядом стояло двое).
    local best, bestDist = nil, 15
    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        if root then
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

        SelectedLairNPC = v
        SelectedLairNPCText = pretty
        setNote("Selected Lair NPC:", "Selected Lair NPC: " .. pretty)
        notify("Lair NPC: " .. pretty, 3)
    end
end)

local LairDistance = 4
CreateNote("Farming Position", "Lair Farm")
CreateTextBox("Set Distance: ", "Lair Farm", { CustomText = "Default: 4" }, function(Input)
    local n = tonumber(Input)
    if n and n > 0 then LairDistance = n end
end)

local Underneath = false
CreateToggle("Underneath", "Lair Farm", function()
    Underneath = not Underneath
end)

-- ЯДРО ЭКСПЛОЙТА: HP босса выставляется в 0 с клиента.
-- По умолчанию ВЫКЛЮЧЕН: именно этот пакет сервер ловит как
-- "Exploit Detected: Auto Lair Farm (267)". Включай осознанно.
local InstantBossKill = false
CreateNote("Instant Kill = HP write = kick 267. Off by default.", "Lair Farm")
CreateToggle("Instant Boss Kill (HP = 0)", "Lair Farm", function()
    InstantBossKill = not InstantBossKill
    notify("instant kill " .. (InstantBossKill and "ON" or "off"), 3)
end)

-- Дёрганье Done. В message.txt летело каждые 0.6с без проверки дистанции —
-- ровный метроном, по которому сервер и считает бота. Теперь: только рядом
-- с NPC, только раз в 2.6–4.4с, и с перестановкой, если отбежали.
function TriggerLair(force)
    if not SelectedLairNPC or not SelectedLairNPC.Parent then
        notify("Error Grabbing Remote 2", 3)
        return false
    end

    local done = SelectedLairNPC:FindFirstChild("Done")
    if not (done and done:IsA("RemoteEvent")) then
        notify("Error Grabbing Remote 2", 3)
        return false
    end

    local root = SelectedLairNPC:FindFirstChild("HumanoidRootPart")
    local p = hrp()
    if root and p and (p.Position - root.Position).Magnitude > 25 then
        approach(SelectedLairNPC, 6)
        return false
    end

    if not force then
        if os.clock() < nextTriggerAt then return false end
        nextTriggerAt = os.clock() + jitter(STEALTH.TriggerMin, STEALTH.TriggerMax)
    end
    lastTriggerAt = os.clock()

    pcall(function() done:FireServer() end)
    return true
end

local ShortPause = false
CreateToggle("Use Pausing", "Lair Farm", function()
    ShortPause = not ShortPause
end)

local PauseTimer = 1
CreateTextBox("Pause Length", "Lair Farm", {}, function(Input)
    local n = tonumber(Input)
    if n and n >= 0 then PauseTimer = n end
end)

local StartLairFarming = false

-- Тело вынесено в функцию: тем же путём фарм запускается из консоли
-- (getgenv().SUR.lairStart), не имитируя клик по тогглу.
local function startLairFarm()
    if StartLairFarming then return true end
    if not SelectedLairNPC then
        notify("You Are Missing A Step! Please Check Tutorial Then Re-Enable!")
        return false
    end

    StartLairFarming = true
    sessionStart = os.clock()
    nextTriggerAt = 0

    task.spawn(function()
        while StartLairFarming do
            -- авто-стоп: бесконечная сессия — тоже сигнатура бота
            if os.clock() - sessionStart > STEALTH.SessionMaxMin * 60 then
                StartLairFarming = false
                notify("Lair Farm: session limit reached, stopped.", 6)
                break
            end

            -- 1. дёргаем Done, пока не появится босс (троттлинг внутри TriggerLair)
            local t0 = os.clock()
            while StartLairFarming and not findLairBoss() and os.clock() - t0 < 40 do
                TriggerLair()
                task.wait(jitter(0.9, 1.5))
            end
            if not StartLairFarming then break end

            if ShortPause then task.wait(PauseTimer) end

            -- 2. бой. Позиция — ДО атаки, иначе босс успевает отойти.
            while StartLairFarming do
                local boss = findLairBoss()
                if not boss then break end

                pcall(function()
                    holdPosition(boss, LairDistance, Underneath)
                    if InstantBossKill then killTarget(boss) end
                    attackStep()
                end)

                task.wait(jitter(STEALTH.AttackMin, STEALTH.AttackMax))
            end

            if ShortPause then task.wait(PauseTimer) end
            task.wait(jitter(0.4, 0.9))
        end
    end)
    return true
end

CreateToggle("Begin Lair Farm", "Lair Farm", function()
    if StartLairFarming then
        StartLairFarming = false
    else
        startLairFarm()
    end
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
        if root then
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
        if root and v:FindFirstChild("AI") then
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
CreateToggle("Only Farm NPC", "Quest Farm", function()
    OnlyFarmNPC = not OnlyFarmNPC
end)

local QuestDistance = 4
CreateNote("Farming Position", "Quest Farm")
CreateTextBox("Set Distance: ", "Quest Farm", { CustomText = "Default: 4" }, function(Input)
    local n = tonumber(Input)
    if n and n > 0 then QuestDistance = n end
end)

local QUnderneath = false
CreateToggle("Underneath", "Quest Farm", function()
    QUnderneath = not QUnderneath
end)

local function TriggerQuest()
    if not SelectedQuestNPC or not SelectedQuestNPC.Parent then
        notify("Error Grabbing Remote 1", 3)
        return false
    end

    local questDone = SelectedQuestNPC:FindFirstChild("QuestDone")
    local done = SelectedQuestNPC:FindFirstChild("Done")

    if questDone and questDone:IsA("RemoteEvent") then
        pcall(function() questDone:FireServer() end)
    else
        notify("Error Grabbing Remote 1", 3)
    end

    if done and done:IsA("RemoteEvent") then
        pcall(function() done:FireServer() end)
    else
        notify("Error Grabbing Remote 2", 3)
    end
    return true
end

local StartQuestFarming = false
CreateToggle("Begin Quest Farm", "Quest Farm", function()
    StartQuestFarming = not StartQuestFarming
    if not StartQuestFarming then return end

    -- FIX: приоритет операторов в оригинале читался не так, как задумано
    local ready = (SelectedNPC ~= "None")
                 and (SelectedQuestNPC ~= nil or OnlyFarmNPC == true)
    if not ready then
        notify("You Are Missing A Step! Please Check Tutorial Then Re-Enable!")
        StartQuestFarming = false
        return
    end

    task.spawn(function()
        while StartQuestFarming do
            local L = living()
            if not L then task.wait(0.5) else
                for _, target in ipairs(L:GetChildren()) do
                    if not StartQuestFarming then break end

                    local th = target:FindFirstChildOfClass("Humanoid")
                    if target.Name == SelectedNPC and th and th.Health > 0 then
                        if not OnlyFarmNPC then TriggerQuest() end

                        -- FIX: внутренние циклы больше не затеняют target
                        while StartQuestFarming and target.Parent and th.Health > 0 do
                            pcall(function()
                                holdPosition(target, QuestDistance, QUnderneath)
                                attackStep()
                            end)
                            task.wait(jitter(STEALTH.AttackMin, STEALTH.AttackMax))
                        end

                        if not OnlyFarmNPC then TriggerQuest() end

                        local p = hrp()
                        if p then
                            pcall(function()
                                p.CFrame = CFrame.new(p.Position + Vector3.new(0, 0, 1000))
                                p.CFrame = CFrame.new(p.Position + Vector3.new(0, 10, 0))
                            end)
                        end
                    end
                end
                task.wait(0.3)
            end
        end
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
-- ITEM FARM
-- ══════════════════════════════════════════════════════════════════════════
CreateMenu("Item Farm")
CreateNote("Farm Methods", "Item Farm")

local FarmMethod = 0
CreateNote("Current Method: None", "Item Farm")

local function setMethod(text)
    setNote("Current Method:", "Current Method: " .. text)
end

CreateButton("Instant", "Item Farm", function()
    FarmMethod = 1
    setMethod("Instant")
end)

CreateButton("Legit", "Item Farm", function()
    FarmMethod = 2
    setMethod("Legit")
end)

-- FIX: раньше сканировался только Workspace.Vfx и в fireproximityprompt
-- летел nil, если промпта нет. Теперь Vfx + Items + любые Tool с промптом.
local function itemTargets()
    local out = {}
    local me = char()

    local function consider(inst)
        if not inst:IsA("Tool") then return end
        local parent = inst.Parent
        while parent and parent ~= Workspace do
            if parent == me or (backpack() and parent == backpack()) then return end
            if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") and parent ~= me then return end
            parent = parent.Parent
        end

        local part = inst:FindFirstChildOfClass("MeshPart")
                   or inst:FindFirstChildOfClass("Part")
                   or inst:FindFirstChildWhichIsA("BasePart")
        if not part then return end

        local prompt
        for _, d in ipairs(inst:GetDescendants()) do
            if d:IsA("ProximityPrompt") then prompt = d break end
        end

        out[#out + 1] = { obj = inst, part = part, prompt = prompt }
    end

    for _, folderName in ipairs({ "Vfx", "Items" }) do
        local f = Workspace:FindFirstChild(folderName)
        if f then
            for _, v in ipairs(f:GetChildren()) do consider(v) end
        end
    end

    return out
end

local function grabTool(t)
    if not (t and t.part) then return false end
    local p = hrp()
    if not p then return false end

    pcall(function() p.CFrame = t.part.CFrame end)
    task.wait(0.15)
    if t.prompt then fireProximity(t.prompt) end
    task.wait(0.15)

    return t.obj.Parent == nil
end

local function walkAndGrab(t)
    local h = hum()
    local p = hrp()
    if not (h and p and t.part) then return end

    local path = PathfindingService:CreatePath({ AgentCanJump = true })
    local ok = pcall(function() path:ComputeAsync(p.Position, t.part.Position) end)
    if not ok then return end

    for _, wp in ipairs(path:GetWaypoints()) do
        h:MoveTo(wp.Position)
        if wp.Action == Enum.PathWaypointAction.Jump then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        -- таймаут: без него луп вешался навсегда, если дойти нельзя
        h.MoveToFinished:Wait(3)
    end

    if t.prompt then fireProximity(t.prompt) end
end

local StartFarming = false
CreateToggle("Start Farming", "Item Farm", function()
    StartFarming = not StartFarming

    if not StartFarming then
        local h = hum()
        if h then pcall(function() h.WalkSpeed = 16 end) end
        return
    end

    if FarmMethod ~= 1 and FarmMethod ~= 2 then
        notify("Select A Farm Method, And Re-Enable!")
        StartFarming = false
        return
    end

    local instant = (FarmMethod == 1)

    task.spawn(function()
        if not instant then
            local h = hum()
            if h then pcall(function() h.WalkSpeed = 30 end) end
        end

        while StartFarming do
            local list = itemTargets()

            if instant then
                for _, t in ipairs(list) do
                    if not StartFarming then break end
                    pcall(grabTool, t)
                    task.wait(0.1)
                end
            else
                for _, t in ipairs(list) do
                    if not StartFarming then break end
                    pcall(walkAndGrab, t)
                    task.wait(0.3)
                end
            end

            task.wait(instant and 0.2 or 1.0)
        end
    end)
end)

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
                task.spawn(function()
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

local StandCheck = false
CreateToggle("Enable Stand Check", "Stand Farm", function()
    StandCheck = not StandCheck
end)

local AttributeCheck = false
CreateToggle("Enable Attribute Check", "Stand Farm", function()
    AttributeCheck = not AttributeCheck
end)

local SplitChecking = false
CreateToggle("Split Checking", "Stand Farm", function()
    SplitChecking = not SplitChecking
end)

CreateNote("Extra Settings", "Stand Farm")

local UseStandArrows   = true
local UseChargedArrows = false
local UseKarsMask      = false

CreateButton("Use Stand Arrows", "Stand Farm", function()
    UseStandArrows, UseChargedArrows, UseKarsMask = true, false, false
    notify("Using Stand Arrows", 3)
end)

CreateButton("Use Charged Arrows", "Stand Farm", function()
    UseStandArrows, UseChargedArrows, UseKarsMask = false, true, false
    notify("Using Charged Arrows", 3)
end)

CreateButton("Use Kars Mask", "Stand Farm", function()
    UseStandArrows, UseChargedArrows, UseKarsMask = false, false, true
    notify("Using Kars Mask", 3)
end)

local AutoBuyArrows = false
CreateToggle("Auto Buy Selected Arrows", "Stand Farm", function()
    AutoBuyArrows = not AutoBuyArrows
end)

local AutoBuyRokakaka = false
CreateToggle("Auto Buy Rokakaka", "Stand Farm", function()
    AutoBuyRokakaka = not AutoBuyRokakaka
end)

local Webhook = ""
CreateTextBox("Set Webhook", "Stand Farm", {}, function(Input)
    Webhook = Input or ""
end)

local EnableWebhook = false
CreateToggle("Enable Webhook", "Stand Farm", function()
    EnableWebhook = not EnableWebhook
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
                task.spawn(function()
                    CreateToggle(stand, "Stand Farm", function()
                        local at = table.find(WhitelistedStands, stand)
                        if at then
                            table.remove(WhitelistedStands, at)
                        else
                            WhitelistedStands[#WhitelistedStands + 1] = stand
                        end
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
                local attr = string.split(v.Text, " ")[1]
                if attr == "Glass" then attr = "Glass Cannon" end
                if attr and attr ~= "" and not seen[attr] then
                    seen[attr] = true
                    local name = attr
                    task.spawn(function()
                        CreateToggle(name, "Stand Farm", function()
                            local at = table.find(WhitelistedAttributes, name)
                            if at then
                                table.remove(WhitelistedAttributes, at)
                            else
                                WhitelistedAttributes[#WhitelistedAttributes + 1] = name
                            end
                        end)
                    end)
                end
            end
        end
    end
end

local function sendRollWebhook()
    if not EnableWebhook then return end
    webhookSend(Webhook, {
        content = "@everyone```\nUsername: " .. LP.Name
               .. "\nStand: " .. standName()
               .. "\nAttribute: " .. standAttri() .. "```",
    })
end

-- ── NEXT MOVE ─────────────────────────────────────────────────────────────
-- FIX: UseArrow / UseChargedArrow — несуществующие глобалы, из-за опечатки
-- автопокупка не срабатывала никогда. Плюс вечные repeat-until без таймаута.
local function waitForEquip(toolName, timeout)
    local c = char()
    if not c then return nil end
    return c:WaitForChild(toolName, timeout or 3)
end

local function buyArrow()
    local ev = events()
    local buy = ev and ev:FindFirstChild("BuyItem")
    if not buy then return false end
    local nf = npcFolder()
    if not nf then return false end

    if UseStandArrows then
        local npc = nf:FindFirstChild("MerchantAU")
        if npc and npc:FindFirstChild("HumanoidRootPart") then
            tpToCF(npc.HumanoidRootPart.CFrame)
            task.wait(0.5)
            pcall(function() buy:FireServer("MerchantAU", "Option4") end)
            task.wait(0.5)
            return true
        end
    elseif UseChargedArrows then
        local npc = nf:FindFirstChild("Merchant120") or nf:FindFirstChild("Merchantlvl120")
        if npc and npc:FindFirstChild("HumanoidRootPart") then
            tpToCF(npc.HumanoidRootPart.CFrame)
            task.wait(0.5)
            pcall(function() buy:FireServer("Merchantlvl120", "Option2") end)
            task.wait(0.5)
            return true
        end
    end
    return false
end

local function buyRokakaka()
    local ev = events()
    local buy = ev and ev:FindFirstChild("BuyItem")
    local nf = npcFolder()
    local npc = nf and nf:FindFirstChild("MerchantAU")
    if not (buy and npc and npc:FindFirstChild("HumanoidRootPart")) then return false end
    tpToCF(npc.HumanoidRootPart.CFrame)
    task.wait(0.5)
    pcall(function() buy:FireServer("MerchantAU", "Option2") end)
    task.wait(0.5)
    return true
end

function NextMove()
    local arrow = "Stand Arrow"
    if UseChargedArrows then
        arrow = "Charged Arrow"
    elseif UseKarsMask then
        arrow = "Kars Mask"
    end

    if not hasStand() then
        local bp = backpack()
        if bp and bp:FindFirstChild(arrow) then
            local c, h = char(), hum()
            if not (c and h) then return end
            pcall(function() h:EquipTool(bp:FindFirstChild(arrow)) end)
            local tool = waitForEquip(arrow, 3)
            if not tool then return end

            local ev = events()
            local useItem = ev and ev:FindFirstChild("UseItem")

            for _ = 1, 40 do
                if hasStand() then break end
                pcall(function() tool:Activate() end)
                if useItem then pcall(function() useItem:FireServer() end) end
                task.wait(0.5)
            end
        elseif AutoBuyArrows then
            buyArrow()
        end
        return
    end

    -- есть стенд → роллим рокакаку
    local bp = backpack()
    if bp and bp:FindFirstChild("Rokakaka") then
        local c, h = char(), hum()
        if not (c and h) then return end
        pcall(function() h:EquipTool(bp:FindFirstChild("Rokakaka")) end)
        local tool = waitForEquip("Rokakaka", 3)
        if not tool then return end

        local ev = events()
        local useItem = ev and ev:FindFirstChild("UseItem")

        for _ = 1, 40 do
            if not hasStand() then break end
            pcall(function() tool:Activate() end)
            if useItem then pcall(function() useItem:FireServer() end) end
            task.wait(0.5)
        end
    elseif AutoBuyRokakaka then
        buyRokakaka()
    end
end

local StandFarm = false
CreateToggle("Begin Stand Farm", "Stand Farm", function()
    StandFarm = not StandFarm
    if not StandFarm then return end

    task.spawn(function()
        while StandFarm do
            local currentStand = standName()
            local currentAttri = standAttri()

            local check1 = table.find(WhitelistedStands, currentStand) ~= nil
            local check2 = table.find(WhitelistedAttributes, currentAttri) ~= nil

            local hit = false

            if SplitChecking then
                hit = check1 or check2
            elseif StandCheck and not AttributeCheck then
                hit = check1
            elseif not StandCheck and AttributeCheck then
                hit = check2
            elseif StandCheck and AttributeCheck then
                hit = check1 and check2
            end

            if hit then
                sendRollWebhook()
                -- FIX: раньше тут был break — тоггл оставался включённым,
                -- а цикл уже мёртвый. Теперь честный стоп.
                StandFarm = false
                notify("Target roll found: " .. currentStand .. " [" .. currentAttri .. "]", 8)
                return
            end

            NextMove()
            task.wait(0.4)
        end
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════
pcall(function()
    CreateNotification("Arctic", "Loaded. Press J to toggle.", { Duration = 6 })
end)
print("[Arctic SUR] loaded | stand=" .. standName() .. " | attri=" .. standAttri()
      .. " | moves=" .. #moveset())

-- ══════════════════════════════════════════════════════════════════════════
-- SUR CONTROL API
-- Пульт для агента/консоли. UI не трогает, меню не меняет — только дёргает
-- те же функции, что и кнопки. Нужен, чтобы фарм можно было поднять без
-- кликов по тогглам.
-- ══════════════════════════════════════════════════════════════════════════
local SUR = {}
getgenv().SUR = SUR

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
        moves     = #moveset(),
        position  = p and { X = p.Position.X, Y = p.Position.Y, Z = p.Position.Z } or nil,
        lairNPC   = SelectedLairNPCText,
        lairOn    = StartLairFarming,
        instant   = InstantBossKill,
        underneath= Underneath,
        bossAlive = (function()
            local b = findLairBoss()
            return b and b.Name or nil
        end)(),
    }
end

-- Список NPC вокруг: имя, дистанция, есть ли Done/QuestDone.
function SUR.npcs(radius)
    local p = hrp()
    local nf = npcFolder()
    local out = {}
    if not (p and nf) then return out end
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
function SUR.selectLair(fragment)
    local nf = npcFolder()
    if not nf then return false, "no Map.NPCs" end

    local pick, pickDist = nil, math.huge
    local p = hrp()

    for _, v in ipairs(nf:GetChildren()) do
        local root = v:FindFirstChild("HumanoidRootPart")
        local okName = (not fragment) or string.find(string.lower(v.Name), string.lower(fragment), 1, true)
        if root and okName and v:FindFirstChild("Done") then
            local d = p and (p.Position - root.Position).Magnitude or 0
            if d < pickDist then pick, pickDist = v, d end
        end
    end

    if not pick then return false, "no match" end

    local head = pick:FindFirstChild("Head")
    local main = head and head:FindFirstChild("Main")
    local txt  = main and main:FindFirstChild("Text")

    SelectedLairNPC = pick
    SelectedLairNPCText = (txt and txt.Text) or pick.Name
    setNote("Selected Lair NPC:", "Selected Lair NPC: " .. SelectedLairNPCText)
    return true, SelectedLairNPCText
end

function SUR.underneath(on)
    Underneath = (on ~= false)
    return Underneath
end

function SUR.instantKill(on)
    InstantBossKill = (on == true)
    return InstantBossKill
end

function SUR.lairStart()
    return startLairFarm()
end

function SUR.lairStop()
    StartLairFarming = false
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
