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
