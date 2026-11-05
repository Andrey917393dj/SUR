-- ═══════════════════════════════════════════════════════════════
--  ARCTIC SUR v2  —  single-file build
--  UI library embedded. No HttpGet, no external dependency.
--  Combat protocol verified live on place 8540168650.
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
local DefaultColor = Color3.fromRGB(0, 51, 102)
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
    Frame.BackgroundColor3 = Color3.fromRGB(8, 8, 8)
    Frame.BorderSizePixel = 0
    Frame.Position = UDim2.new(0.311278194, 0, 0.288372099, 0)
    Frame.Size = UDim2.new(0, 501, 0, 273)

    Hotbar.Name = "Hotbar"
    Hotbar.Parent = Frame
    Hotbar.BackgroundColor3 = Color3.fromRGB(17, 17, 17)
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
    Buttons.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
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
                local target = state and DefaultColor or Color3.fromRGB(6, 6, 6)
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

-- ═══════════════════════════════════════════════════════════════
-- ARCTIC SUR v2
-- Game : STAND UPRIGHT REBOOTED  (place 8540168650)
-- Every remote call in this file was verified in-game, not guessed.
-- ═══════════════════════════════════════════════════════════════

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local WS           = game:GetService("Workspace")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local StarterGui   = game:GetService("StarterGui")
local LP           = Players.LocalPlayer

local RS_EVENTS = RS:WaitForChild("Events", 30)

-- ═══════════════════════════════════════════════════════════════
-- SAFE NETWORK LAYER
-- ═══════════════════════════════════════════════════════════════
local function ev(name)
    return RS_EVENTS and RS_EVENTS:FindFirstChild(name)
end

local function fire(name, ...)
    local r = ev(name)
    if not r then return false, "missing remote: " .. tostring(name) end
    -- pcall passes varargs straight through; a nested closure cannot use '...'
    local ok, err = pcall(r.FireServer, r, ...)
    return ok, err
end

local function invoke(name, ...)
    local r = ev(name)
    if not r then return nil, "missing remote: " .. tostring(name) end
    local ok, res = pcall(r.InvokeServer, r, ...)
    if ok then return res end
    return nil, res
end

-- ═══════════════════════════════════════════════════════════════
-- SERVER ACK LISTENER  (our verification channel)
-- The server replies on CoolDownGUI with (moveName, cooldown).
-- ═══════════════════════════════════════════════════════════════
local ACK = { move = nil, cd = nil, at = 0 }
pcall(function()
    local cd = ev("CoolDownGUI")
    if cd then
        cd.OnClientEvent:Connect(function(name, value)
            ACK.move = tostring(name)
            ACK.cd   = value
            ACK.at   = os.clock()
        end)
    end
end)

local function ackReset()
    ACK.move, ACK.cd, ACK.at = nil, nil, 0
end

local function ackWait(timeout)
    timeout = timeout or 1.5
    local t0 = os.clock()
    while os.clock() - t0 < timeout do
        if ACK.move then return ACK.move, ACK.cd end
        task.wait(0.05)
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
-- CHARACTER / STAND
-- ═══════════════════════════════════════════════════════════════
local function char()  return LP.Character end
local function hum()   local c = char(); return c and c:FindFirstChildOfClass("Humanoid") end
local function hrp()   local c = char(); return c and c:FindFirstChild("HumanoidRootPart") end

local function standFolder()
    local c = char()
    return c and c:FindFirstChild("StandEvents")
end

local function getMoveset()
    local se = standFolder()
    local info = se and se:FindFirstChild("Info")
    if not info then return {} end
    local ok, res = pcall(function() return info:InvokeServer("Moveset") end)
    if ok and type(res) == "table" then return res end
    return {}
end

-- The verified move protocol: {State, Key, Type}
local function press(key, hold)
    local se = standFolder()
    if not se then return false, "no StandEvents (dead or loading?)" end
    local input = se:FindFirstChild("Input")
    if not input then return false, "no Input remote" end

    local isMouse = (key == Enum.UserInputType.MouseButton1
                  or key == Enum.UserInputType.MouseButton2)
    local utype = isMouse and key or Enum.UserInputType.Keyboard

    local ok1 = pcall(function()
        input:FireServer({ State = "Begin", Key = key, Type = utype })
    end)
    if not ok1 then return false, "Begin failed" end

    if hold and hold > 0 then task.wait(hold) end

    pcall(function()
        input:FireServer({ State = "End", Key = key, Type = utype })
    end)
    return true
end

local function standName()
    local d = LP:FindFirstChild("Data")
    local s = d and d:FindFirstChild("Stand")
    if s then return tostring(s.Value) end
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

-- ═══════════════════════════════════════════════════════════════
-- NPC LAYER
-- ═══════════════════════════════════════════════════════════════
local function npcFolder()
    local m = WS:FindFirstChild("Map")
    return m and m:FindFirstChild("NPCs")
end

local function npcObj(name)
    local f = npcFolder()
    return f and f:FindFirstChild(name)
end

local function npcRemote(name, which)
    local o = npcObj(name)
    if not o then return nil end
    return o:FindFirstChild(which or "Done")
end

local function fireNPC(name, which)
    local r = npcRemote(name, which)
    if not r then return false, "no " .. tostring(which or "Done") .. " on " .. tostring(name) end
    local ok, err = pcall(function() r:FireServer() end)
    return ok, err
end

local function allNPCs()
    local out = {}
    local f = npcFolder()
    if not f then return out end
    for _, n in ipairs(f:GetChildren()) do
        if n:IsA("Model") then out[#out + 1] = n.Name end
    end
    return out
end

-- ═══════════════════════════════════════════════════════════════
-- TELEPORT / MOVEMENT
-- ═══════════════════════════════════════════════════════════════
local function tpTo(cf)
    local p = hrp()
    if not p then return false, "no HumanoidRootPart" end
    pcall(function() p.CFrame = cf end)
    pcall(function() p.AssemblyLinearVelocity = Vector3.zero end)
    return true
end

local function tpToPart(part, offset)
    if not part then return false, "no part" end
    offset = offset or Vector3.new(0, 0, 3)
    return tpTo(CFrame.new(part.Position + offset))
end

local function tpToNPC(name)
    local o = npcObj(name)
    if not o then return false, "no NPC " .. tostring(name) end
    local p = o:FindFirstChild("HumanoidRootPart")
    if not p then return false, "NPC has no HRP" end
    return tpToPart(p, Vector3.new(0, 0, 4))
end

local function tpToPosition(x, y, z)
    return tpTo(CFrame.new(Vector3.new(x, y, z)))
end

-- ═══════════════════════════════════════════════════════════════
-- WORLD ITEMS
--   Workspace.Items / Workspace.Vfx  -> real Tool instances (only while spawned)
--   Workspace.ItemPromptHolder       -> static "Pick Up?" spawn markers
-- ═══════════════════════════════════════════════════════════════
local function itemSpawns()
    local out = {}
    for _, d in ipairs(WS:GetChildren()) do
        if d.Name == "ItemPromptHolder" then
            local p = d:FindFirstChildOfClass("ProximityPrompt")
            out[#out + 1] = { obj = d, part = d, prompt = p }
        end
    end
    return out
end

local function worldTools()
    local out = {}
    for _, folderName in ipairs({ "Items", "Vfx" }) do
        local f = WS:FindFirstChild(folderName)
        if f then
            for _, d in ipairs(f:GetChildren()) do
                if d:IsA("Tool") then
                    local handle = d:FindFirstChild("Handle") or d:FindFirstChildWhichIsA("BasePart")
                    out[#out + 1] = { name = d.Name, obj = d, part = handle }
                end
            end
        end
    end
    return out
end


local function grabItem(itemName)
    for _, t in ipairs(worldTools()) do
        if t.name == itemName and t.part then
            return tpToPart(t.part, Vector3.new(0, 2, 0))
        end
    end
    return false, "no " .. tostring(itemName) .. " in world"
end

local function useTool(toolName)
    local c, h = char(), hum()
    if not (c and h) then return false, "no character" end
    local tool = LP.Backpack:FindFirstChild(toolName) or c:FindFirstChild(toolName)
    if not tool then return false, "no " .. tostring(toolName) .. " in backpack" end

    if tool.Parent == LP.Backpack then
        pcall(function() h:EquipTool(tool) end)
        tool = c:WaitForChild(toolName, 3) or tool
    end
    task.wait(0.15)
    pcall(function() tool:Activate() end)
    local use = tool:FindFirstChild("Use")
    if use and use:IsA("RemoteEvent") then
        pcall(function() use:FireServer() end)
    end
    fire("UseItem", toolName)
    return true
end

-- ═══════════════════════════════════════════════════════════════
-- PLAYER MODS
-- ═══════════════════════════════════════════════════════════════
local Mods = { speed = false, speedValue = 32, jump = false, jumpValue = 80,
               fly = false, noclip = false, infJump = false }

local flyConn, flyBV, flyBG

local function setSpeed(v)
    local h = hum()
    if h then h.WalkSpeed = v end
end

local function setJump(v)
    local h = hum()
    if h then h.JumpPower = v; h.UseJumpPower = true end
end

local function startFly()
    local p = hrp()
    if not p then return end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = p
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P = 1000
    bg.Parent = p
    flyBV, flyBG = bv, bg

    flyConn = RunService.RenderStepped:Connect(function()
        local cam = WS.CurrentCamera
        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
        local p2 = hrp()
        if p2 and flyBV then
            flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * 60 or Vector3.zero
            flyBG.CFrame = cam.CFrame
        end
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end

local noclipConn
local function startNoclip()
    noclipConn = RunService.Stepped:Connect(function()
        local c = char()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end)
end

local function stopNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
end

-- ═══════════════════════════════════════════════════════════════
-- ESP
-- ═══════════════════════════════════════════════════════════════
local ESP = { living = false, npcs = false, instances = {} }

local function clearESP()
    for _, h in pairs(ESP.instances) do
        pcall(function() h:Destroy() end)
    end
    ESP.instances = {}
end

local function makeHighlight(obj, color)
    local h = Instance.new("Highlight")
    h.FillColor = color
    h.FillTransparency = 0.55
    h.OutlineColor = color
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee = obj
    h.Parent = obj
    return h
end

local function refreshESP()
    clearESP()
    if ESP.living then
        local living = WS:FindFirstChild("Living")
        if living then
            for _, m in ipairs(living:GetChildren()) do
                if m:IsA("Model") and m ~= char() then
                    local ok, h = pcall(makeHighlight, m, Color3.fromRGB(255, 60, 60))
                    if ok then ESP.instances[#ESP.instances + 1] = h end
                end
            end
        end
    end
    if ESP.npcs then
        local f = npcFolder()
        if f then
            for _, m in ipairs(f:GetChildren()) do
                if m:IsA("Model") then
                    local ok, h = pcall(makeHighlight, m, Color3.fromRGB(60, 200, 255))
                    if ok then ESP.instances[#ESP.instances + 1] = h end
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════
-- AUDIT HARNESS
-- Runs a function N times, records pass/fail, prints a table.
-- ═══════════════════════════════════════════════════════════════
local Audit = { results = {} }

function Audit.run(label, fn, times, gap)
    times = times or 20
    gap = gap or 0.25
    local pass, fail = 0, 0
    local errs = {}
    local t0 = os.clock()

    for i = 1, times do
        local ok, res = pcall(fn)
        if ok and res ~= false then
            pass = pass + 1
        else
            fail = fail + 1
            local msg = ok and "returned false" or tostring(res)
            errs[#errs + 1] = "[" .. i .. "] " .. msg
        end
        task.wait(gap)
    end

    local rec = {
        label = label, pass = pass, fail = fail,
        total = times, ms = math.floor((os.clock() - t0) * 1000),
        errors = errs
    }
    Audit.results[#Audit.results + 1] = rec

    local line = string.format("%-28s %2d/%2d  %dms", label, pass, times, rec.ms)
    print("[AUDIT] " .. line)
    for _, e in ipairs(errs) do print("        " .. e) end

    if CreateNotification then
        CreateNotification("Audit", line, { Duration = 4 })
    end
    return rec
end

function Audit.report()
    local ok, fail = 0, 0
    for _, r in ipairs(Audit.results) do
        ok = ok + r.pass
        fail = fail + r.fail
    end
    print("════════ AUDIT REPORT ════════")
    for _, r in ipairs(Audit.results) do
        print(string.format("  %-28s %2d/%2d", r.label, r.pass, r.total))
    end
    print(string.format("  TOTAL: %d pass, %d fail", ok, fail))
    return Audit.results
end

-- ═══════════════════════════════════════════════════════════════
-- FAKE PROFILE  (/check bait + fake stand model)
-- Everything the /check card prints is read from objects the client
-- already owns:  Player.Data.Stand / .Attri / .GUID,
-- Character.Stats.AttackDmg, Character.DmgBoostAttri, Humanoid.MaxHealth.
-- ReplicatedStorage.StandNameConvert maps the stand code to the pretty name.
-- ═══════════════════════════════════════════════════════════════
local Fake = {
    active = false,
    stand = nil, attri = nil, guid = nil,
    health = nil, dmg = nil, boost = nil,
    model = nil, relCFrame = nil, thread = nil,
    saved = nil,
}

local function rs()
    return game:GetService("ReplicatedStorage")
end

-- ── catalogues pulled out of the game itself ───────────────────
local function standCatalog()
    local out = {}
    local snc = rs():FindFirstChild("StandNameConvert")
    if snc then
        for _, v in ipairs(snc:GetChildren()) do
            out[#out + 1] = { code = v.Name, pretty = tostring(v.Value) }
        end
    end
    table.sort(out, function(a, b) return a.code < b.code end)
    return out
end

local function standPretty(code)
    local snc = rs():FindFirstChild("StandNameConvert")
    local v = snc and snc:FindFirstChild(tostring(code))
    return v and tostring(v.Value) or tostring(code)
end

local function attriCatalog()
    local out = {}
    -- some builds ship the ladder as a folder of StringValues / a ModuleScript table
    for _, holderName in ipairs({ "AttriList", "Attributes", "AttriNames", "RarityList" }) do
        local h = rs():FindFirstChild(holderName)
        if h then
            for _, c in ipairs(h:GetChildren()) do
                if c:IsA("StringValue") or c:IsA("Folder") then
                    out[#out + 1] = c.Name
                end
            end
        end
    end
    if #out == 0 then
        out = { "None", "Weak", "Normal", "Good", "Great", "Excellent",
                "Perfect", "Legendary", "Mythical", "Godly", "Divine" }
    end
    return out
end

-- ── write / restore ────────────────────────────────────────────
local function dataValue(name)
    local d = LP:FindFirstChild("Data")
    return d and d:FindFirstChild(name)
end

local function statsFolder()
    local c = char()
    return c and c:FindFirstChild("Stats")
end

local function fakeApply()
    local s = dataValue("Stand"); if s and Fake.stand then s.Value = Fake.stand end
    local a = dataValue("Attri"); if a and Fake.attri then a.Value = Fake.attri end
    local g = dataValue("GUID");  if g and Fake.guid  then g.Value = Fake.guid end

    local st = statsFolder()
    if st then
        local d = st:FindFirstChild("AttackDmg")
        if d and Fake.dmg then d.Value = Fake.dmg end
    end
    local db = char() and char():FindFirstChild("DmgBoostAttri")
    if db and Fake.boost then db.Value = Fake.boost end
    local h = hum()
    if h and Fake.health then
        h.MaxHealth = Fake.health
        h.Health = Fake.health
    end
end

local function fakeSnapshot()
    local st = statsFolder()
    Fake.saved = {
        stand = dataValue("Stand") and dataValue("Stand").Value,
        attri = dataValue("Attri") and dataValue("Attri").Value,
        guid  = dataValue("GUID")  and dataValue("GUID").Value,
        dmg   = st and st:FindFirstChild("AttackDmg") and st.AttackDmg.Value,
        boost = char() and char():FindFirstChild("DmgBoostAttri")
                and char().DmgBoostAttri.Value,
        health = hum() and hum().MaxHealth,
    }
end

local function fakeRestore()
    local s = Fake.saved
    if not s then return end
    local v
    v = dataValue("Stand"); if v and s.stand then v.Value = s.stand end
    v = dataValue("Attri"); if v and s.attri then v.Value = s.attri end
    v = dataValue("GUID");  if v and s.guid  then v.Value = s.guid  end
    local st = statsFolder()
    if st and s.dmg then
        v = st:FindFirstChild("AttackDmg"); if v then v.Value = s.dmg end
    end
    local db = char() and char():FindFirstChild("DmgBoostAttri")
    if db and s.boost then db.Value = s.boost end
    local h = hum()
    if h and s.health then h.MaxHealth = s.health; h.Health = s.health end
end

-- ── fake stand model ───────────────────────────────────────────
local function fakeStandClear()
    if Fake.model then
        pcall(function() Fake.model:Destroy() end)
    end
    Fake.model, Fake.relCFrame = nil, nil
end

local function findStandSource(code)
    local living = WS:FindFirstChild("Living")
    -- 1. another player already running that stand
    if living then
        for _, plr in ipairs(living:GetChildren()) do
            local m = plr:FindFirstChild("Stand")
            if m and m:IsA("Model") then
                local d = plr:FindFirstChild("Data")
                local sv = d and d:FindFirstChild("Stand")
                if code and sv and sv.Value == code then return m end
                if not code and plr.Name == LP.Name then return m end
            end
        end
    end
    -- 2. a stored model named exactly like the code
    if code then
        for _, folderName in ipairs({ "Storage", "QuestAssets", "UIStorage", "Vfx" }) do
            local f = WS:FindFirstChild(folderName)
            local m = f and f:FindFirstChild(code)
            if m and m:IsA("Model") then return m end
        end
        local m = rs():FindFirstChild(code)
        if m and m:IsA("Model") then return m end
    end
    -- 3. fall back to our own stand
    if living then
        local me = living:FindFirstChild(LP.Name)
        return me and me:FindFirstChild("Stand") or nil
    end
    return nil
end

local function fakeStandSpawn(code, side)
    fakeStandClear()
    local src = findStandSource(code)
    if not src then return false, "no stand model to clone" end

    local m = src:Clone()
    m.Name = "SUR_FakeStand"
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BaseScript") or d:IsA("Script") or d:IsA("LocalScript") then
            pcall(function() d.Enabled = false end)
        elseif d:IsA("BasePart") then
            d.Anchored = true
            d.CanCollide = false
            d.CanQuery = false
            d.CanTouch = false
        elseif d:IsA("Humanoid") then
            d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end
    m.Parent = WS

    local r = hrp()
    if not r then return false, "no HumanoidRootPart" end
    side = side or 1
    m:PivotTo(r.CFrame * CFrame.new(3 * side, 0, 0))
    Fake.model = m
    Fake.relCFrame = r.CFrame:ToObjectSpace(m:GetPivot())
    return true
end

local function fakeStandTrack()
    local m, rel = Fake.model, Fake.relCFrame
    local r = hrp()
    if not (m and rel and r) then return end
    if not m.Parent then Fake.model = nil; return end
    pcall(function() m:PivotTo(r.CFrame * rel) end)
end

-- ── the loop that keeps the lie alive ──────────────────────────
local function fakeStart()
    if Fake.active then return end
    fakeSnapshot()
    Fake.active = true
    Fake.thread = task.spawn(function()
        while Fake.active do
            pcall(fakeApply)
            pcall(fakeStandTrack)
            task.wait(0.2)
        end
    end)
end

local function fakeStop()
    Fake.active = false
    Fake.thread = nil
    fakeStandClear()
    pcall(fakeRestore)
end

-- ═══════════════════════════════════════════════════════════════
-- FARM ENGINE
-- Old builds glued the character to a boss and spammed
-- StandEvents.M1 / Summon. Those remotes are gone, so the loop now
-- drives press() on the verified StandEvents.Input protocol.
-- ═══════════════════════════════════════════════════════════════
local Farm = {
    target = nil, distance = 4, underneath = false,
    running = false, thread = nil,
    useMoves = true, pauseOn = false, pauseLen = 0.4,
    heavyEvery = 1.0, _lastHeavy = 0,
    heavyKeys = { "E", "R", "T" },
    kills = 0, startedAt = 0,
}

local function farmLiving(name)
    local living = WS:FindFirstChild("Living")
    return living and living:FindFirstChild(name) or nil
end

local function farmStop()
    Farm.running = false
    Farm.thread = nil
end

local function farmStep(name)
    local t = farmLiving(name)
    if not t then return false end
    local thp = t:FindFirstChild("HumanoidRootPart")
    local r = hrp()
    if not (thp and r) then return false end

    local off = Farm.underneath
        and CFrame.new(0, -Farm.distance, Farm.distance)
        or CFrame.new(0, 0, Farm.distance)
    pcall(function() r.CFrame = thp.CFrame * off end)
    pcall(function() r.AssemblyLinearVelocity = Vector3.zero end)

    -- keep the stand out
    local aura = char() and char():FindFirstChild("Aura")
    if aura and aura.Value == false then press(Enum.KeyCode.Q) end

    press(Enum.UserInputType.MouseButton1)

    if Farm.useMoves then
        local now = os.clock()
        if now - Farm._lastHeavy >= Farm.heavyEvery then
            Farm._lastHeavy = now
            for _, k in ipairs(Farm.heavyKeys or {}) do
                local kc = Enum.KeyCode[k]
                if kc then press(kc) end
            end
        end
    end
    return true
end

local function farmStart(name)
    farmStop()
    Farm.target = name
    Farm.running = true
    Farm.startedAt = os.clock()
    Farm.kills = 0
    Farm.thread = task.spawn(function()
        while Farm.running do
            local ok = pcall(farmStep, name)
            if not ok then farmStop() break end
            task.wait(Farm.pauseOn and Farm.pauseLen or 0.1)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- UI
-- ═══════════════════════════════════════════════════════════════
Start("Arctic SUR v2")

-- ── HOME ──────────────────────────────────────────────────────
CreateMenu("Home")
CreateNote("STAND UPRIGHT REBOOTED - place 8540168650", "Home")
CreateNote("Combat uses StandEvents.Input (verified)", "Home")
CreateButton("Print Player Snapshot", "Home", function()
    print("Stand:", standName(), "| Attri:", standAttri(),
          "| Moveset:", #getMoveset(), "keys")
    local d = LP:FindFirstChild("Data")
    if d then
        for _, v in ipairs(d:GetChildren()) do
            if v:IsA("ValueBase") and (v.Name == "Level" or v.Name == "Cash"
               or v.Name == "Exp" or v.Name == "SkillPoints") then
                print("  " .. v.Name .. " = " .. tostring(v.Value))
            end
        end
    end
    CreateNotification("Arctic", standName() .. " [" .. standAttri() .. "]", { Duration = 5 })
end)
CreateButton("Run Full Audit (x20)", "Home", function()
    task.spawn(function()
        Audit.results = {}
        Audit.run("press M1 (punch)", function() return press(Enum.UserInputType.MouseButton1) end, 20, 0.4)
        Audit.run("press Q (summon)", function() return press(Enum.KeyCode.Q) end, 20, 1.7)
        Audit.run("press E (barrage)", function() return press(Enum.KeyCode.E) end, 20, 7.2)
        Audit.run("press G (block)", function() return press(Enum.KeyCode.G, 0.2) end, 20, 1.2)
        Audit.run("moveset fetch", function()
            local m = getMoveset()
            return type(m) == "table" and #m > 0
        end, 20, 0.2)
        Audit.run("GetStandTier", function()
            local v = invoke("GetStandTier", standName())
            return v ~= nil
        end, 20, 0.2)
        Audit.report()
        CreateNotification("Audit", "Finished - see console", { Duration = 8 })
    end)
end)

-- ── COMBAT ────────────────────────────────────────────────────
CreateMenu("Combat")

local AutoAttack = false
CreateToggle("Auto Attack (M1)", "Combat", function()
    AutoAttack = not AutoAttack
    if AutoAttack then
        task.spawn(function()
            while AutoAttack do
                press(Enum.UserInputType.MouseButton1)
                task.wait(0.36)
            end
        end)
    end
end)

local AutoBarrage = false
CreateToggle("Auto Barrage (E)", "Combat", function()
    AutoBarrage = not AutoBarrage
    if AutoBarrage then
        task.spawn(function()
            while AutoBarrage do
                press(Enum.KeyCode.E)
                task.wait(7.2)
            end
        end)
    end
end)

local AutoHeavy = false
CreateToggle("Auto Heavy Punch (R)", "Combat", function()
    AutoHeavy = not AutoHeavy
    if AutoHeavy then
        task.spawn(function()
            while AutoHeavy do
                press(Enum.KeyCode.R)
                task.wait(8.2)
            end
        end)
    end
end)

local AutoCombo = false
CreateToggle("Auto Combo (M1/E/R/T/X/H)", "Combat", function()
    AutoCombo = not AutoCombo
    if AutoCombo then
        task.spawn(function()
            local order = {
                { Enum.UserInputType.MouseButton1, 0.4 },
                { Enum.UserInputType.MouseButton1, 0.4 },
                { Enum.KeyCode.E, 7.2 },
                { Enum.KeyCode.R, 8.2 },
                { Enum.KeyCode.T, 8.2 },
                { Enum.KeyCode.X, 8.2 },
                { Enum.KeyCode.H, 6.2 },
            }
            while AutoCombo do
                for _, step in ipairs(order) do
                    if not AutoCombo then break end
                    press(step[1])
                    task.wait(step[2])
                end
            end
        end)
    end
end)

CreateButton("Summon (Q)", "Combat", function() press(Enum.KeyCode.Q) end)
CreateButton("Barrage (E)", "Combat", function() press(Enum.KeyCode.E) end)
CreateButton("Heavy Punch (R)", "Combat", function() press(Enum.KeyCode.R) end)
CreateButton("Bearing Shots (T)", "Combat", function() press(Enum.KeyCode.T) end)
CreateButton("Timeskip (H)", "Combat", function() press(Enum.KeyCode.H) end)
CreateButton("Counter (X)", "Combat", function() press(Enum.KeyCode.X) end)
CreateButton("Block (G)", "Combat", function() press(Enum.KeyCode.G, 0.5) end)
CreateButton("Quote (N)", "Combat", function() press(Enum.KeyCode.N) end)
CreateButton("Show Moveset", "Combat", function()
    local m = getMoveset()
    local parts = {}
    for _, k in ipairs(m) do parts[#parts + 1] = tostring(k):gsub("Enum.", "") end
    print("[Moveset] " .. table.concat(parts, ", "))
    CreateNotification("Moveset", #m .. " keys", { Duration = 4 })
end)

-- ── NPC / QUEST ───────────────────────────────────────────────
CreateMenu("NPC & Quest")

local LastNPC = "admpn"
CreateTextBox("NPC (target)", "NPC & Quest", { CustomText = "admpn", AutoUpdate = true }, function(t)
    LastNPC = t
end)

CreateButton("Fire Done on NPC", "NPC & Quest", function()
    local ok, err = fireNPC(LastNPC, "Done")
    CreateNotification("NPC", tostring(LastNPC) .. " Done: " .. tostring(ok), { Duration = 3 })
    if not ok then warn(err) end
end)

CreateButton("Fire QuestDone on NPC", "NPC & Quest", function()
    local ok, err = fireNPC(LastNPC, "QuestDone")
    CreateNotification("NPC", tostring(LastNPC) .. " QuestDone: " .. tostring(ok), { Duration = 3 })
    if not ok then warn(err) end
end)

CreateButton("Fire Done on ALL NPCs", "NPC & Quest", function()
    task.spawn(function()
        local ok, fail = 0, 0
        for _, n in ipairs(allNPCs()) do
            local r = npcRemote(n, "Done")
            if r then
                if pcall(function() r:FireServer() end) then ok = ok + 1 else fail = fail + 1 end
                task.wait(0.12)
            end
        end
        CreateNotification("NPC", ok .. " fired, " .. fail .. " failed", { Duration = 5 })
    end)
end)

CreateButton("Fire QuestDone on ALL NPCs", "NPC & Quest", function()
    task.spawn(function()
        local ok, fail = 0, 0
        for _, n in ipairs(allNPCs()) do
            local r = npcRemote(n, "QuestDone")
            if r then
                if pcall(function() r:FireServer() end) then ok = ok + 1 else fail = fail + 1 end
                task.wait(0.12)
            end
        end
        CreateNotification("NPC", ok .. " quest fired, " .. fail .. " failed", { Duration = 5 })
    end)
end)

local AutoQuest = false
CreateToggle("Auto Quest Loop", "NPC & Quest", function()
    AutoQuest = not AutoQuest
    if AutoQuest then
        task.spawn(function()
            while AutoQuest do
                for _, n in ipairs(allNPCs()) do
                    if not AutoQuest then break end
                    local d = npcRemote(n, "Done")
                    if d then pcall(function() d:FireServer() end) end
                    local q = npcRemote(n, "QuestDone")
                    if q then pcall(function() q:FireServer() end) end
                    task.wait(0.35)
                end
                task.wait(2)
            end
        end)
    end
end)

-- ── SHOP ──────────────────────────────────────────────────────
CreateMenu("Shop")

local ShopId = "MerchantAU"
CreateTextBox("Shop ID", "Shop", { CustomText = "MerchantAU", AutoUpdate = true }, function(t)
    ShopId = t
end)

for i = 1, 4 do
    CreateButton("Buy Option" .. i, "Shop", function()
        local ok, err = fire("BuyItem", ShopId, "Option" .. i)
        CreateNotification("Shop", ShopId .. " Option" .. i .. ": " .. tostring(ok), { Duration = 3 })
        if not ok then warn(err) end
    end)
end

CreateButton("Sell Ketchup (One)", "Shop", function() fire("SellKetchup", "One") end)
CreateButton("Sell Ketchup (Lots)", "Shop", function() fire("SellKetchup", "Lots") end)

-- Auto sell loop (carried over from the original Shops menu)
local AutoSell = { on = false, count = 1 }
CreateTextBox("Auto Sell Count", "Shop", { CustomText = "1" }, function(t)
    AutoSell.count = tonumber(t) or AutoSell.count
end)
CreateToggle("Auto Sell Ketchup", "Shop", function()
    AutoSell.on = not AutoSell.on
    if AutoSell.on then
        task.spawn(function()
            while AutoSell.on do
                for _ = 1, math.max(1, math.floor(AutoSell.count)) do
                    pcall(fire, "SellKetchup", "One")
                    task.wait(0.25)
                end
                task.wait(1.0)
            end
        end)
    end
end)

-- ── STAND ─────────────────────────────────────────────────────
CreateMenu("Stand")

CreateButton("Show Current Stand", "Stand", function()
    CreateNotification("Stand", standName() .. " [" .. standAttri() .. "]", { Duration = 5 })
end)

CreateButton("Get Tier", "Stand", function()
    local t = invoke("GetStandTier", standName())
    CreateNotification("Tier", tostring(t), { Duration = 5 })
    print("[Tier]", standName(), "=", tostring(t))
end)

for i = 1, 5 do
    CreateButton("Switch to Slot " .. i, "Stand", function()
        fire("SwitchStand", "Slot" .. i)
    end)
end
CreateButton("Switch to Spec Slot 2", "Stand", function() fire("SwitchStand", "SpecSlot2") end)

CreateButton("Use Stand Arrow", "Stand", function()
    local ok, err = useTool("Stand Arrow")
    CreateNotification("Stand", tostring(ok), { Duration = 3 })
    if not ok then warn(err) end
end)

CreateButton("Use Charged Arrow", "Stand", function() useTool("Charged Arrow") end)
CreateButton("Use Requiem Arrow", "Stand", function() useTool("Requiem Arrow") end)
CreateButton("Use Rokakaka", "Stand", function() useTool("Rokakaka") end)
CreateButton("Use Rotten Rokakaka", "Stand", function() useTool("Rotten Rokakaka") end)

-- ── STAND FARM ────────────────────────────────────────────────
CreateMenu("Stand Farm")

local WantStands, WantAttrs = {}, {}
local CheckStand, CheckAttr, SplitMode = false, false, false
local UseArrowType = "Stand Arrow"
local AutoBuyArrow, AutoBuyRoka = false, false
local FarmActive = false
local WebhookURL, WebhookOn = "", false

CreateToggle("Check Stand", "Stand Farm", function() CheckStand = not CheckStand end)
CreateToggle("Check Attribute", "Stand Farm", function() CheckAttr = not CheckAttr end)
CreateToggle("Split Mode (stand OR attr)", "Stand Farm", function() SplitMode = not SplitMode end)

CreateButton("Arrows: Stand", "Stand Farm", function() UseArrowType = "Stand Arrow" end)
CreateButton("Arrows: Charged", "Stand Farm", function() UseArrowType = "Charged Arrow" end)
CreateButton("Arrows: Requiem", "Stand Farm", function() UseArrowType = "Requiem Arrow" end)

CreateToggle("Auto Buy Arrows", "Stand Farm", function() AutoBuyArrow = not AutoBuyArrow end)
CreateToggle("Auto Buy Rokakaka", "Stand Farm", function() AutoBuyRoka = not AutoBuyRoka end)

CreateTextBox("Webhook URL", "Stand Farm", { CustomText = "https://discord.com/api/webhooks/..." }, function(t)
    WebhookURL = t
end)
CreateToggle("Enable Webhook", "Stand Farm", function() WebhookOn = not WebhookOn end)

local function sendWebhook(stand, attr)
    if not WebhookOn or WebhookURL == "" then return end
    local body = HttpService:JSONEncode({
        content = "@everyone **Target rolled**\n```\nUser: " .. LP.Name ..
                  "\nStand: " .. tostring(stand) ..
                  "\nAttr: " .. tostring(attr) .. "\n```"
    })
    local fn = (syn and syn.request) or http_request or request or (http and http.request)
    if fn then
        pcall(fn, {
            Url = WebhookURL, Body = body, Method = "POST",
            Headers = { ["Content-Type"] = "application/json" }
        })
    end
end

local function rollStep()
    if not hasStand() then
        local tool = LP.Backpack:FindFirstChild(UseArrowType)
            or (char() and char():FindFirstChild(UseArrowType))
        if tool then
            useTool(UseArrowType)
            task.wait(0.8)
        elseif AutoBuyArrow then
            local shop = (UseArrowType == "Charged Arrow") and "Merchant120" or "MerchantAU"
            local opt  = (UseArrowType == "Charged Arrow") and "Option2" or "Option4"
            tpToNPC(shop)
            task.wait(0.35)
            fire("BuyItem", shop, opt)
            task.wait(0.5)
        end
    else
        local tool = LP.Backpack:FindFirstChild("Rokakaka")
            or (char() and char():FindFirstChild("Rokakaka"))
        if tool then
            useTool("Rokakaka")
            task.wait(0.9)
        elseif AutoBuyRoka then
            tpToNPC("MerchantAU")
            task.wait(0.35)
            fire("BuyItem", "MerchantAU", "Option2")
            task.wait(0.5)
        end
    end
end

CreateToggle("BEGIN STAND FARM", "Stand Farm", function()
    FarmActive = not FarmActive
    if not FarmActive then return end
    task.spawn(function()
        while FarmActive do
            local cs, ca = standName(), standAttri()

            local mStand = #WantStands > 0 and table.find(WantStands, cs) ~= nil
            local mAttr  = #WantAttrs  > 0 and table.find(WantAttrs, ca) ~= nil

            local stop = false
            if SplitMode then
                stop = mStand or mAttr
            elseif CheckStand and CheckAttr then
                stop = mStand and mAttr
            elseif CheckStand then
                stop = mStand
            elseif CheckAttr then
                stop = mAttr
            else
                if #WantStands > 0 and #WantAttrs > 0 then
                    stop = mStand and mAttr
                elseif #WantStands > 0 then
                    stop = mStand
                elseif #WantAttrs > 0 then
                    stop = mAttr
                end
            end

            if stop and cs ~= "None" then
                pcall(sendWebhook, cs, ca)
                FarmActive = false
                CreateNotification("Arctic", "ROLLED: " .. cs .. " [" .. ca .. "]", { Duration = 10 })
                break
            end

            rollStep()
            task.wait(0.15)
        end
    end)
end)

CreateNote("── Stand whitelist ──", "Stand Farm")
pcall(function()
    local snc = RS:FindFirstChild("StandNameConvert")
    if not snc then return end
    local seen = {}
    for _, v in ipairs(snc:GetChildren()) do
        if v:IsA("StringValue") and not seen[v.Value] and v.Value ~= "" then
            seen[v.Value] = true
            CreateToggle(v.Value, "Stand Farm", function()
                local ix = table.find(WantStands, v.Value)
                if ix then table.remove(WantStands, ix) else WantStands[#WantStands + 1] = v.Value end
            end)
        end
    end
end)

CreateNote("── Attribute whitelist ──", "Stand Farm")
for _, attr in ipairs({ "Godly", "Legendary", "Mythic", "Overpowered", "Hallowed",
                        "Gluttonous", "Tenacious", "Furious", "Powerful", "Agile",
                        "Giant", "Tiny", "Strong", "Healthy", "Fast" }) do
    CreateToggle(attr, "Stand Farm", function()
        local ix = table.find(WantAttrs, attr)
        if ix then table.remove(WantAttrs, ix) else WantAttrs[#WantAttrs + 1] = attr end
    end)
end

-- ── ITEMS ─────────────────────────────────────────────────────
CreateMenu("Items")

CreateButton("List World Items", "Items", function()
    local t = worldTools()
    local s = itemSpawns()
    local names = {}
    for _, i in ipairs(t) do names[#names + 1] = i.name end
    print("[World items] " .. (#names > 0 and table.concat(names, ", ") or "none")
          .. "  |  spawn points: " .. #s)
    CreateNotification("Items", #names .. " spawned / " .. #s .. " spawns", { Duration = 4 })
end)

CreateButton("TP to Item Spawn 1", "Items", function()
    local s = itemSpawns()
    if s[1] then tpToPart(s[1].part, Vector3.new(0, 3, 0)) end
end)
CreateButton("TP to Item Spawn 2", "Items", function()
    local s = itemSpawns()
    if s[2] then tpToPart(s[2].part, Vector3.new(0, 3, 0)) end
end)
CreateButton("TP to Item Spawn 3", "Items", function()
    local s = itemSpawns()
    if s[3] then tpToPart(s[3].part, Vector3.new(0, 3, 0)) end
end)

local AutoGrab = false
CreateToggle("Auto Grab Items", "Items", function()
    AutoGrab = not AutoGrab
    if AutoGrab then
        task.spawn(function()
            local cycle = 0
            while AutoGrab do
                local t = worldTools()
                if #t > 0 and t[1].part then
                    tpToPart(t[1].part, Vector3.new(0, 2, 0))
                else
                    -- nothing spawned: sit on the next spawn marker so we catch it
                    local s = itemSpawns()
                    if #s > 0 then
                        cycle = cycle % #s + 1
                        if s[cycle].part then
                            tpToPart(s[cycle].part, Vector3.new(0, 3, 0))
                        end
                    end
                end
                task.wait(0.6)
            end
        end)
    end
end)

CreateButton("Grab Stand Arrow", "Items", function() grabItem("Stand Arrow") end)
CreateButton("Grab Rokakaka", "Items", function() grabItem("Rokakaka") end)

-- ── TELEPORTS ─────────────────────────────────────────────────
CreateMenu("Teleports")
CreateSearchBar("Teleports")

local function addNpcTP(name)
    CreateButton(name, "Teleports", function()
        local ok = tpToNPC(name)
        if not ok then
            CreateNotification("TP", "no " .. name, { Duration = 3 })
        end
    end)
end

for _, n in ipairs({
    "admpn", "MerchantAU", "Merchant120", "Merchant500", "Merchant1st",
    "CandyMerchant", "StockMarket", "Giorno", "Giorno2", "DIO", "Diavolo",
    "Funny Valentine", "Koichi", "Josuke", "Okayasu", "Rohan", "Kirito",
    "TidesQuest", "aLLmemester", "Scared Noob", "SWAT", "Young Joseph",
    "Joseph Joestar", "Zeppeli", "Muhammed Avdol", "Pop_Cat", "Gyro",
    "NascentNPC", "Sports Maxx", "Qtaro Cujoh", "TowhOH", "Bum NPC",
    "BobBallin", "Jonathan Joestar", "Succession_onlinoon", "i_stabman",
    "boznpc", "yu_k1p", "Staticaliza", "Darkceius", "Mayor Lucchini",
}) do
    addNpcTP(n)
end

-- Named landmarks (coordinates carried over from the original message.txt)
local LANDMARKS = {
    { "D4C Dimension",       11927.1,  -3.28935, -4488.59 },
    { "Rarity Boards",       -658.979, 67.0282,  -451.495 },
    { "Stand Storage Room",  -393.893, 23.5808,  -280.786 },
    { "Inner Sanctum",       27877.87, 27.2336,  -147.723 },
    { "Mud Pit",             17.0716,  66.9873,  -246.13  },
    { "Hamon Dealer",        -801.427, 66.5359,  -735.121 },
    { "Vehicle Man",         -187.042, 78.4486,  -1076.25 },
    { "Testing Zone",        19999.3,  100.155,  -730.726 },
    { "Bad Gi Spawn",        -687.605, 67.0313,  -837.959 },
    { "Scary Monster Cave",  -683.898, 67.0313,  -1039.76 },
    { "Sewer",               -5308.65, -450.832, -3815.39 },
    { "Yoshikage Kira Spawn",-446.509, 67.0313,  -995.377 },
    { "Dio's Rock",          -37.4145, 92.3069,  -804.244 },
    { "Gyro Zeppeli",        57.2144,  66.8005,  -216.834 },
    { "Dark Entrance 1",     -734,     70,       -398     },
    { "Dark Entrance 2",     -327,     67,       -140     },
    { "Dark Entrance 3",     -39,      70,       -482     },
}

for _, L in ipairs(LANDMARKS) do
    CreateButton(L[1], "Teleports", function()
        tpToPosition(L[2], L[3], L[4])
        CreateNotification("TP", L[1], { Duration = 3 })
    end)
end

-- ── PLAYER ────────────────────────────────────────────────────
CreateMenu("Player")

CreateTextBox("WalkSpeed", "Player", { CustomText = "32", AutoUpdate = true }, function(t)
    Mods.speedValue = tonumber(t) or 32
    setSpeed(Mods.speedValue)
end)

CreateTextBox("JumpPower", "Player", { CustomText = "80", AutoUpdate = true }, function(t)
    Mods.jumpValue = tonumber(t) or 80
    setJump(Mods.jumpValue)
end)

CreateToggle("Fly (WASD + Space/Ctrl)", "Player", function()
    Mods.fly = not Mods.fly
    if Mods.fly then startFly() else stopFly() end
end)

CreateToggle("Noclip", "Player", function()
    Mods.noclip = not Mods.noclip
    if Mods.noclip then startNoclip() else stopNoclip() end
end)

CreateButton("Reset Speed/Jump", "Player", function()
    setSpeed(16); setJump(50)
    CreateNotification("Player", "reset", { Duration = 3 })
end)

-- ── VISUALS ───────────────────────────────────────────────────
CreateMenu("Visuals")

CreateToggle("ESP Players/Mobs (Living)", "Visuals", function()
    ESP.living = not ESP.living
    refreshESP()
end)

CreateToggle("ESP NPCs", "Visuals", function()
    ESP.npcs = not ESP.npcs
    refreshESP()
end)

CreateButton("Refresh ESP", "Visuals", function() refreshESP() end)
CreateButton("Clear ESP", "Visuals", function()
    ESP.living, ESP.npcs = false, false
    clearESP()
end)

-- ── FAKE PROFILE ──────────────────────────────────────────────
CreateMenu("Fake")

CreateNote("Fake reads the same fields /check reads", "Fake")
CreateNote("Local view only - other clients keep server values", "Fake")

CreateToggle("Fake Profile ON/OFF", "Fake", function()
    if Fake.active then
        fakeStop()
        CreateNotification("Fake", "off - restored", { Duration = 4 })
    else
        fakeStart()
        CreateNotification("Fake", "on", { Duration = 4 })
    end
end)

CreateTextBox("Stand code", "Fake", { CustomText = "SPTW_R" }, function(t)
    Fake.stand = (t ~= "" and t) or nil
end)

CreateTextBox("Attribute", "Fake", { CustomText = "Godly" }, function(t)
    Fake.attri = (t ~= "" and t) or nil
end)

CreateTextBox("GUID", "Fake", { CustomText = "00000000-0000-0000-0000-000000000000" }, function(t)
    Fake.guid = (t ~= "" and t) or nil
end)

CreateTextBox("Stand Damage", "Fake", { CustomText = "9999" }, function(t)
    Fake.dmg = tonumber(t) or Fake.dmg
end)

CreateTextBox("Damage Boost", "Fake", { CustomText = "9999" }, function(t)
    Fake.boost = tonumber(t) or Fake.boost
end)

CreateTextBox("Stand Health", "Fake", { CustomText = "99999" }, function(t)
    Fake.health = tonumber(t) or Fake.health
end)

CreateButton("Load from game (real values)", "Fake", function()
    local s = dataValue("Stand")
    local a = dataValue("Attri")
    local st = statsFolder()
    Fake.stand = s and s.Value or Fake.stand
    Fake.attri = a and a.Value or Fake.attri
    Fake.dmg   = st and st:FindFirstChild("AttackDmg") and st.AttackDmg.Value or Fake.dmg
    Fake.health = hum() and hum().MaxHealth or Fake.health
    CreateNotification("Fake", "loaded: " .. tostring(Fake.stand), { Duration = 4 })
end)

CreateButton("List all stands", "Fake", function()
    local cat = standCatalog()
    print("[Stands] " .. #cat .. " entries")
    for _, e in ipairs(cat) do
        print(string.format("  %-22s %s", e.code, e.pretty))
    end
    CreateNotification("Fake", #cat .. " stands in game", { Duration = 5 })
end)

CreateButton("Fake stand model ON", "Fake", function()
    local ok, err = fakeStandSpawn(Fake.stand, 1)
    if not ok then CreateNotification("Fake", tostring(err), { Duration = 4 }) end
end)

CreateButton("Fake stand model OFF", "Fake", function()
    fakeStandClear()
end)

CreateButton("Print what /check will show", "Fake", function()
    local s = dataValue("Stand")
    local a = dataValue("Attri")
    local g = dataValue("GUID")
    local st = statsFolder()
    local db = char() and char():FindFirstChild("DmgBoostAttri")
    local dmg = st and st:FindFirstChild("AttackDmg") and st.AttackDmg.Value or 0
    print("  " .. LP.Name .. " has: " .. standPretty(s and s.Value or "?"))
    print("  Attribute: " .. tostring(a and a.Value))
    print("  Stand Health: " .. tostring(hum() and hum().MaxHealth))
    print("  Stand Damage: " .. tostring(math.floor(dmg * (db and db.Value or 1))))
    print("  Stand GUID: " .. tostring(g and g.Value))
end)

-- ── BOSS FARM ─────────────────────────────────────────────────
CreateMenu("Boss Farm")
CreateNote("Glues you to the target and drives M1 + heavies", "Boss Farm")

CreateTextBox("Distance", "Boss Farm", { CustomText = "4" }, function(t)
    Farm.distance = tonumber(t) or Farm.distance
end)
CreateToggle("Underneath", "Boss Farm", function()
    Farm.underneath = not Farm.underneath
end)
CreateToggle("Use Heavy Moves", "Boss Farm", function()
    Farm.useMoves = not Farm.useMoves
end)
CreateTextBox("Heavy every (s)", "Boss Farm", { CustomText = "1.0" }, function(t)
    Farm.heavyEvery = tonumber(t) or Farm.heavyEvery
end)

CreateButton("Stop All Farms", "Boss Farm", function()
    farmStop()
    CreateNotification("Farm", "stopped", { Duration = 3 })
end)

for _, boss in ipairs({
    "Jotaro Over Heaven", "JohnnyJoestar", "Alternate Jotaro Part 4",
    "DIO", "Diavolo", "Funny Valentine", "Dio Brando", "Heaven Ascension DIO",
}) do
    CreateToggle("Farm: " .. boss, "Boss Farm", function()
        if Farm.running and Farm.target == boss then
            farmStop()
            CreateNotification("Farm", "off " .. boss, { Duration = 3 })
        else
            farmStart(boss)
            CreateNotification("Farm", "on " .. boss, { Duration = 3 })
        end
    end)
end

CreateTextBox("Custom target name", "Boss Farm", { CustomText = "NPC name" }, function(t)
    if t and t ~= "" then Farm.target = t end
end)
CreateButton("Farm custom target", "Boss Farm", function()
    if Farm.target then
        farmStart(Farm.target)
        CreateNotification("Farm", "on " .. Farm.target, { Duration = 3 })
    end
end)

-- ── QUEST FARM ────────────────────────────────────────────────
CreateMenu("Quest Farm")
CreateNote("Fires Done / QuestDone on a chosen NPC on a loop", "Quest Farm")

local QuestFarm = { npc = "MerchantAU", running = false, which = "QuestDone", gap = 1.0 }

CreateTextBox("Quest NPC", "Quest Farm", { CustomText = "MerchantAU" }, function(t)
    if t and t ~= "" then QuestFarm.npc = t end
end)
CreateTextBox("Loop gap (s)", "Quest Farm", { CustomText = "1.0" }, function(t)
    QuestFarm.gap = tonumber(t) or QuestFarm.gap
end)

CreateToggle("Use QuestDone (off = Done)", "Quest Farm", function()
    QuestFarm.which = (QuestFarm.which == "QuestDone") and "Done" or "QuestDone"
end)

CreateToggle("Begin Quest Farm", "Quest Farm", function()
    if QuestFarm.running then
        QuestFarm.running = false
        CreateNotification("Quest", "stopped", { Duration = 3 })
        return
    end
    QuestFarm.running = true
    task.spawn(function()
        while QuestFarm.running do
            pcall(fireNPC, QuestFarm.npc, QuestFarm.which)
            task.wait(QuestFarm.gap)
        end
    end)
    CreateNotification("Quest", "farming " .. QuestFarm.npc, { Duration = 3 })
end)

CreateButton("Fire once", "Quest Farm", function()
    local ok, err = fireNPC(QuestFarm.npc, QuestFarm.which)
    CreateNotification("Quest", ok and "fired" or tostring(err), { Duration = 3 })
end)

-- ── LAIR FARM ─────────────────────────────────────────────────
CreateMenu("Lair Farm")
CreateNote("Boss loop with a pause between packs", "Lair Farm")

CreateTextBox("Lair target", "Lair Farm", { CustomText = "Lair boss name" }, function(t)
    if t and t ~= "" then Farm.target = t end
end)
CreateTextBox("Pause length (s)", "Lair Farm", { CustomText = "0.4" }, function(t)
    Farm.pauseLen = tonumber(t) or Farm.pauseLen
end)
CreateToggle("Use pausing", "Lair Farm", function()
    Farm.pauseOn = not Farm.pauseOn
end)
CreateToggle("Begin Lair Farm", "Lair Farm", function()
    if Farm.running then
        farmStop()
        CreateNotification("Lair", "stopped", { Duration = 3 })
    else
        farmStart(Farm.target or "Jotaro Over Heaven")
        CreateNotification("Lair", "farming " .. tostring(Farm.target), { Duration = 3 })
    end
end)

CreateButton("Fire LairStart", "Lair Farm", function() fire("LairStart") end)
CreateButton("Fire LairClear", "Lair Farm", function() fire("LairClear") end)

-- ── LOCALPLAYER ───────────────────────────────────────────────
CreateMenu("LocalPlayer")
CreateNote("Small quality-of-life toggles from the original build", "LocalPlayer")

CreateButton("Open Stand Storage", "LocalPlayer", function()
    local ok = tpToNPC("admpn")
    if ok then CreateNotification("Storage", "at admpn", { Duration = 3 }) end
end)

local AntiAFK = false
CreateToggle("Anti AFK", "LocalPlayer", function()
    AntiAFK = not AntiAFK
    if AntiAFK then
        task.spawn(function()
            local vu = game:GetService("VirtualUser")
            while AntiAFK do
                pcall(function() vu:CaptureController() end)
                pcall(function() vu:ClickButton2(Vector2.new()) end)
                task.wait(25)
            end
        end)
    end
end)

local AutoUmbrella = false
CreateToggle("Auto Umbrella", "LocalPlayer", function()
    AutoUmbrella = not AutoUmbrella
    if AutoUmbrella then
        task.spawn(function()
            while AutoUmbrella do
                local c = char()
                local umb = c and (LP.Backpack:FindFirstChild("Umbrella") or c:FindFirstChild("Umbrella"))
                if umb then
                    local h = hum()
                    if h and umb.Parent == LP.Backpack then
                        pcall(function() h:EquipTool(umb) end)
                    end
                end
                task.wait(1.5)
            end
        end)
    end
end)

CreateButton("Reset Character", "LocalPlayer", function()
    local h = hum()
    if h then pcall(function() h.Health = 0 end) end
end)

-- ── FARM SETTINGS ─────────────────────────────────────────────
CreateMenu("Farm Settings")

local MovesetCache = {}
local function refreshMovesets()
    MovesetCache = getMoveset() or {}
    print("[Movesets] " .. #MovesetCache .. " keys: " .. table.concat(MovesetCache, ", "))
    return MovesetCache
end

CreateButton("Refresh Movesets", "Farm Settings", function()
    refreshMovesets()
    CreateNotification("Farm", #MovesetCache .. " moves", { Duration = 4 })
end)

CreateToggle("Use Custom Moves", "Farm Settings", function()
    Farm.useMoves = not Farm.useMoves
    CreateNotification("Farm", "heavies " .. (Farm.useMoves and "on" or "off"), { Duration = 3 })
end)

CreateTextBox("Heavy move keys", "Farm Settings", { CustomText = "E,R,T" }, function(t)
    local keys = {}
    for piece in string.gmatch(t or "", "[^,%s]+") do
        keys[#keys + 1] = piece
    end
    if #keys > 0 then Farm.heavyKeys = keys end
end)

CreateNote("Heavies fire on the verified StandEvents.Input protocol", "Farm Settings")

-- ── ITEM FARM ─────────────────────────────────────────────────
CreateMenu("Item Farm")

local ItemFarm = { on = false, legit = false }

CreateButton("Instant", "Item Farm", function()
    ItemFarm.legit = false
    CreateNotification("Item", "instant mode", { Duration = 3 })
end)
CreateButton("Legit", "Item Farm", function()
    ItemFarm.legit = true
    CreateNotification("Item", "legit mode", { Duration = 3 })
end)

CreateToggle("Start Farming", "Item Farm", function()
    ItemFarm.on = not ItemFarm.on
    if not ItemFarm.on then return end
    task.spawn(function()
        local cycle = 0
        while ItemFarm.on do
            local t = worldTools()
            if #t > 0 and t[1].part then
                tpToPart(t[1].part, Vector3.new(0, 2, 0))
            else
                local s = itemSpawns()
                if #s > 0 then
                    cycle = cycle % #s + 1
                    if s[cycle].part then tpToPart(s[cycle].part, Vector3.new(0, 3, 0)) end
                end
            end
            task.wait(ItemFarm.legit and 2.5 or 0.6)
        end
    end)
end)

-- ── DIAGNOSTICS ───────────────────────────────────────────────
CreateMenu("Diagnostics")

CreateButton("Remote Health Check", "Diagnostics", function()
    local must = {
        "CoolDownGUI", "SwitchStand", "GetStandTier", "BuyItem", "SellKetchup",
        "NpcPrompt", "UseItem", "LairStart", "LairClear", "PressedPlay",
        "TradeThing", "trade2", "StatsUpdate", "CashNotif", "GeneralNotif",
        "ClientPing", "CheckCMD",
    }
    local missing, found = {}, 0
    for _, n in ipairs(must) do
        if ev(n) then found = found + 1 else missing[#missing + 1] = n end
    end
    print(string.format("[Remotes] %d/%d present", found, #must))
    if #missing > 0 then print("[Missing] " .. table.concat(missing, ", ")) end
    CreateNotification("Diagnostics", found .. "/" .. #must .. " remotes", { Duration = 5 })
end)

CreateButton("Character Health Check", "Diagnostics", function()
    local c = char()
    print("Character:", c and c.Name or "nil")
    print("Humanoid:", hum() and "ok" or "nil")
    print("StandEvents:", standFolder() and "ok" or "nil")
    print("Stand:", standName(), "| Attri:", standAttri())
    print("Moveset keys:", #getMoveset())
end)

CreateButton("World Health Check", "Diagnostics", function()
    print("NPCs:", #allNPCs())
    print("World items:", #worldTools())
    local living = WS:FindFirstChild("Living")
    print("Living:", living and #living:GetChildren() or 0)
end)

-- ── TOGGLE KEY ────────────────────────────────────────────────
-- The library owns the hotkey (default J, override via getgenv().ArcticUiHotkey).
-- No second listener here: two toggles on one frame cancel each other out.

-- ── EXTERNAL API (lets the agent drive everything from outside) ──
getgenv().ArcticAPI = {
    press       = press,
    moveset     = getMoveset,
    standName   = standName,
    standAttri  = standAttri,
    fire        = fire,
    invoke      = invoke,
    fireNPC     = fireNPC,
    npcRemote   = npcRemote,
    allNPCs     = allNPCs,
    tpToNPC     = tpToNPC,
    tpToPosition= tpToPosition,
    worldTools  = worldTools,
    itemSpawns  = itemSpawns,
    useTool     = useTool,
    audit       = Audit,
    ack         = ACK,
    ackReset    = ackReset,
    ackWait     = ackWait,
    mods        = Mods,
    esp         = ESP,
    refreshESP  = refreshESP,
    clearESP    = clearESP,
    setSpeed    = setSpeed,
    setJump     = setJump,
    startFly    = startFly,
    stopFly     = stopFly,
    startNoclip = startNoclip,
    stopNoclip  = stopNoclip,
    -- fake profile
    fake        = Fake,
    fakeStart   = fakeStart,
    fakeStop    = fakeStop,
    fakeApply   = fakeApply,
    fakeStandSpawn = fakeStandSpawn,
    fakeStandClear = fakeStandClear,
    standCatalog   = standCatalog,
    standPretty    = standPretty,
    attriCatalog   = attriCatalog,
    dataValue      = dataValue,
    statsFolder    = statsFolder,
    -- farms
    farm           = Farm,
    farmStart      = farmStart,
    farmStop       = farmStop,
    farmStep       = farmStep,
    landmarks      = LANDMARKS,
}

CreateNotification("Arctic SUR v2", "Loaded. Press J to toggle.", { Duration = 6 })
print("[Arctic SUR v2] loaded | stand=" .. standName() .. " | moves=" .. #getMoveset())
