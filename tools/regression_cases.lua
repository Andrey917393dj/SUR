return function(mock, source, originalControls)
    local passed, failures = 0, {}
    local function expect(condition, message)
        if not condition then error(message, 2) end
    end
    local function test(name, fn)
        local ok, err = pcall(fn)
        if ok then
            passed = passed + 1
            print("PASS: " .. name)
        else
            failures[#failures + 1] = name .. ": " .. tostring(err)
            -- Retain the failure, but do not let its worker leak into the next case.
            if mock.env and mock.env.SUR then pcall(mock.env.SUR.unload) end
        end
    end
    local function fresh()
        local ok, err, errors = mock.run(source, false)
        expect(ok, "load failed: " .. tostring(err))
        expect(#errors == 0, "load background errors")
        expect(mock.env.SUR ~= nil, "SUR API missing")
        return mock.env
    end
    local function advance(seconds)
        local ok = mock.advance(seconds, 100000)
        expect(ok, "scheduler failed")
    end
    local function gui()
        local g = mock.env.ArcticScreenGui
        expect(g and g.Parent, "GUI missing")
        return g
    end
    local function menu(name)
        return gui():FindFirstChild("Frame"):FindFirstChild("Menus"):FindFirstChild(name)
    end
    local function control(name, inMenu)
        local c = menu(inMenu):FindFirstChild(name)
        expect(c, "missing " .. inMenu .. " / " .. name)
        return c
    end
    local function click(name, inMenu)
        control(name, inMenu).MouseButton1Down:Fire()
    end
    local function indicator(name, inMenu)
        local c = control(name, inMenu)
        local f = c:FindFirstChildOfClass("Frame")
        expect(f, "indicator missing")
        local col = f.BackgroundColor3
        local off = mock.env.Color3.fromRGB(10, 10, 13)
        return math.abs(col.R - off.R) > 0.01 or math.abs(col.G - off.G) > 0.01 or math.abs(col.B - off.B) > 0.01
    end
    local function inputText(name, inMenu, text)
        local box = control(name, inMenu):FindFirstChildOfClass("TextBox")
        expect(box, "textbox missing")
        box.Text = text
        box.FocusLost:Fire(true)
    end
    local function player()
        return mock.env.game:GetService("Players").LocalPlayer
    end
    local function npc(name, x, y, z, hp)
        local env = mock.env
        local m = mock.newInstance("Model", name)
        local h = mock.newInstance("Humanoid", "Humanoid")
        h.MaxHealth, h.Health = hp or 100, hp or 100
        h.Parent = m
        local root = mock.newInstance("Part", "HumanoidRootPart")
        root.CFrame = env.CFrame.new(x or 0, y or 0, z or 0)
        root.Parent = m
        local ai = mock.newInstance("Folder", "AI"); ai.Parent = m
        m.Parent = mock.workspace:FindFirstChild("Living")
        return m, h, root
    end
    local function provider(name, x, y, z)
        local env = mock.env
        local m = mock.newInstance("Model", name)
        local root = mock.newInstance("Part", "HumanoidRootPart")
        root.CFrame = env.CFrame.new(x or 0, y or 0, z or 0); root.Parent = m
        local done = mock.newInstance("RemoteEvent", "Done"); done.Parent = m
        m.Parent = mock.workspace.Map.NPCs
        return m, root, done
    end
    local function purgeProviders()
        for _, p in ipairs(mock.workspace.Map.NPCs:GetChildren()) do p:Destroy() end
    end
    local function mouseTarget(target)
        player():GetMouse().Target = target
    end
    local function mouseClick()
        local env = mock.env
        env.game:GetService("UserInputService").InputBegan:Fire({
            UserInputType = env.Enum.UserInputType.MouseButton1,
            KeyCode = env.Enum.KeyCode.Unknown,
        }, false)
    end
    local function unload()
        local api = mock.env.SUR
        if api then api.unload() end
        advance(0.2)
        expect(mock.activeTasks() == 0, "tasks leaked during test cleanup")
        expect(mock.activeConnections() == 0, "connections leaked during test cleanup")
        expect(#mock.errors == 0, "cleanup async error: " .. tostring(mock.errors[1]))
        expect(#mock.warnings == 0, "cleanup warning: " .. tostring(mock.warnings[1]))
    end
    local function cleanErrors()
        expect(#mock.errors == 0, "async errors: " .. tostring(mock.errors[1]))
        expect(#mock.warnings == 0, "warnings: " .. tostring(mock.warnings[1]))
    end

    test("Original ten menus and requested additions retained", function()
        fresh()
        for _, name in ipairs({ "Home", "LocalPlayer", "Shops", "Farm Settings", "Boss Farm", "Lair Farm", "Quest Farm", "Item Farm", "Teleports", "Stand Farm", "Fake", "Auto Kill" }) do
            expect(menu(name), "missing menu " .. name)
        end
        for _, spec in ipairs({
            {"Auto Umbrella", "LocalPlayer"}, {"Anti AFK", "LocalPlayer"},
            {"Auto Sell Ketchup", "Shops"}, {"Use Custom Moves", "Farm Settings"},
            {"Farm: Jotaro Over Heaven", "Boss Farm"}, {"Farm: Johnny Joestar", "Boss Farm"}, {"Farm: Jotaro Part 4", "Boss Farm"},
            {"Select Lair NPC", "Lair Farm"}, {"Begin Lair Farm", "Lair Farm"},
            {"Instant Boss Kill (HP = 0)", "Lair Farm"}, {"Select Quest NPC", "Quest Farm"},
            {"Select NPC", "Quest Farm"}, {"Begin Quest Farm", "Quest Farm"}, {"Start Farming", "Item Farm"},
            {"Instant", "Item Farm"}, {"Legit", "Item Farm"}, {"Begin Stand Farm", "Stand Farm"},
            {"GUID", "Fake"}, {"Damage Boost", "Fake"}, {"Open stand list", "Fake"},
            {"Open attribute list", "Fake"}, {"Open stand model list", "Fake"},
            {"Select target (click boss)", "Auto Kill"}, {"Auto Kill Selected", "Auto Kill"},
        }) do control(spec[1], spec[2]) end
        cleanErrors(); unload()
    end)

    test("Rejected starts leave true function state and indicator OFF", function()
        fresh()
        for _, spec in ipairs({ {"Begin Lair Farm", "Lair Farm"}, {"Begin Quest Farm", "Quest Farm"}, {"Start Farming", "Item Farm"}, {"Begin Stand Farm", "Stand Farm"}, {"Auto Kill Selected", "Auto Kill"} }) do
            click(spec[1], spec[2]); advance(0.01)
            expect(not indicator(spec[1], spec[2]), "rejected toggle painted ON: " .. spec[1])
        end
        expect(#mock.env.SUR.diagnostics().jobs == 0, "rejected job still active")
        cleanErrors(); unload()
    end)

    test("Minimize hides only; L reopens; processed input is ignored", function()
        local env = fresh()
        local frame = gui().Frame
        click("Auto Umbrella", "LocalPlayer")
        local jobs = mock.env.SUR.diagnostics().jobs
        expect(#jobs == 1, "umbrella worker missing")
        local minimized = gui().Frame.Hotbar:FindFirstChild("MinimizeButton")
        minimized.MouseButton1Down:Fire()
        expect(frame.Visible == false, "minimize did not hide")
        expect(#mock.env.SUR.diagnostics().jobs == 1, "minimize stopped worker")
        local uis = env.game:GetService("UserInputService")
        uis.InputBegan:Fire({KeyCode=env.Enum.KeyCode.L, UserInputType=env.Enum.UserInputType.Keyboard}, false)
        expect(frame.Visible == true, "L did not reopen")
        uis.InputBegan:Fire({KeyCode=env.Enum.KeyCode.L}, true)
        expect(frame.Visible == true, "processed L toggled")
        cleanErrors(); unload()
    end)

    test("Close cancels all owned jobs, inputs, callbacks and GUI", function()
        fresh()
        click("Auto Umbrella", "LocalPlayer")
        click("Anti AFK", "LocalPlayer")
        player().Idled:Fire()
        click("Select target (click boss)", "Auto Kill")
        local api = mock.env.SUR
        gui().Frame.Hotbar.CloseButton.MouseButton1Down:Fire()
        expect(mock.env.ArcticScreenGui == nil and mock.env.SUR == nil and mock.env.SUR_unload == nil, "globals survived close")
        expect(api.unload() == true, "second unload failed")
        advance(1.1)
        expect(mock.activeTasks() == 0, "tasks survived close")
        expect(mock.activeConnections() == 0, "connections survived close")
        cleanErrors()
    end)

    test("Reinjection replaces old runtime; old unload cannot erase new", function()
        fresh()
        click("Auto Umbrella", "LocalPlayer")
        local old = mock.env.SUR
        local oldGui = gui()
        local ok, err = mock.reload(source, false)
        expect(ok, tostring(err))
        local newApi, newGui = mock.env.SUR, gui()
        expect(newApi ~= old and newGui ~= oldGui, "runtime not replaced")
        expect(oldGui.Parent == nil, "old GUI survived")
        old.unload()
        expect(mock.env.SUR == newApi and mock.env.ArcticScreenGui == newGui, "old unload touched new injection")
        local uis = mock.env.game:GetService("UserInputService")
        uis.InputBegan:Fire({KeyCode=mock.env.Enum.KeyCode.L}, false)
        expect(newGui.Frame.Visible == false, "L toggled more than once or not at all")
        cleanErrors(); unload()
    end)

    test("Rapid toggles never resurrect an older worker generation", function()
        fresh()
        for _ = 1, 30 do click("Auto Umbrella", "LocalPlayer"); click("Auto Umbrella", "LocalPlayer") end
        click("Auto Umbrella", "LocalPlayer")
        advance(0.5)
        local d = mock.env.SUR.diagnostics()
        expect(#d.jobs == 1 and d.jobs[1] == "umbrella", "more than one logical job")
        expect(d.tasks == 1, "older threads survived rapid toggles")
        expect(indicator("Auto Umbrella", "LocalPlayer"), "active umbrella indicator OFF")
        cleanErrors(); unload()
    end)

    test("Lair ignores every noncanonical world boss", function()
        fresh(); purgeProviders()
        provider("ExplicitLair", 0, 0, 0)
        npc("Jotaro Over Heaven", 200, 0, 0)
        npc("JohnnyJoestar", 300, 0, 0)
        expect(mock.env.SUR.selectLair("ExplicitLair", 15), "provider not selected")
        local before = player().Character.HumanoidRootPart.Position
        mock.env.SUR.lairStart(); advance(3)
        local after = player().Character.HumanoidRootPart.Position
        expect((after-before).Magnitude < 0.01, "teleported to world boss")
        expect(mock.env.SUR.state().bossAlive == nil, "world boss acquired")
        mock.env.SUR.lairStop()
        expect(not indicator("Begin Lair Farm", "Lair Farm"), "external stop left indicator ON")
        cleanErrors(); unload()
    end)

    test("Underneath applies immediately using rotated target local coordinates", function()
        fresh(); purgeProviders(); provider("ExplicitLair", 0, 0, 0)
        local boss, h, root = npc("Boss", 10, 0, 0)
        root.CFrame = mock.env.CFrame.new(10,0,0) * mock.env.CFrame.Angles(0,math.pi/2,0)
        mock.env.SUR.selectLair("ExplicitLair", 15)
        mock.env.SUR.lairStart(); advance(0.5)
        local before = player().Character.HumanoidRootPart.Position
        mock.env.SUR.underneath(true); advance(0.6)
        local after = player().Character.HumanoidRootPart.Position
        local want = (root.CFrame * mock.env.CFrame.new(0,-3,4)).Position
        expect((after - want).Magnitude < 0.01, "wrong local behind/underneath offset")
        expect(before.Y > after.Y, "underneath did not lower position")
        expect(h.Health == 100, "ordinary farm wrote local HP")
        cleanErrors(); unload()
    end)

    test("Lair will not leave its selected arena after disappearance", function()
        fresh(); purgeProviders(); provider("ExplicitLair", 0, 0, 0)
        local boss = npc("Boss", 10,0,0)
        mock.env.SUR.selectLair("ExplicitLair",15); mock.env.SUR.lairStart(); advance(0.6)
        boss:Destroy()
        local far = npc("Boss", 10000,0,0)
        local root = player().Character.HumanoidRootPart
        local before = root.Position
        advance(4)
        expect((root.Position-before).Magnitude < 100, "followed a distant replacement Boss")
        mock.env.SUR.lairStop()
        cleanErrors(); unload()
    end)

    test("Mouse miss never selects the nearest unrelated NPC", function()
        fresh()
        npc("Unrelated", 1,0,0)
        click("Select target (click boss)", "Auto Kill")
        mouseTarget(nil); mouseClick(); advance(0.05)
        expect(mock.env.SUR.state().selectedTarget == nil, "miss chose arbitrary target")
        click("Auto Kill Selected", "Auto Kill")
        expect(not indicator("Auto Kill Selected","Auto Kill"), "no-target start stayed ON")
        cleanErrors(); unload()
    end)

    test("Exact clicked NPC only; player characters excluded", function()
        fresh()
        local other, otherH, otherRoot = npc("Other", 2,0,0)
        local boss, h, root = npc("Selected", 100,0,0)
        click("Select target (click boss)","Auto Kill"); mouseTarget(root); mouseClick()
        expect(mock.env.SUR.state().selectedTarget == "Selected", "wrong exact clicked target")
        click("Auto Kill Selected","Auto Kill"); advance(0.5)
        expect(h.Health == 0 and otherH.Health == 100, "wrong target HP changed")
        local want = (root.CFrame * mock.env.CFrame.new(0,0,6)).Position
        expect((player().Character.HumanoidRootPart.Position - want).Magnitude < 0.01, "teleport did not precede selected local kill")
        click("Select target (click boss)","Auto Kill"); mouseTarget(player().Character.HumanoidRootPart); mouseClick()
        expect(mock.env.SUR.state().selectedTarget == nil, "local player accepted")
        cleanErrors(); unload()
    end)

    test("Stop while picking cancels later gameplay click", function()
        fresh()
        local target, h, root = npc("ClickedLater",10,0,0)
        click("Select target (click boss)","Auto Kill")
        click("Stop Auto Kill","Auto Kill")
        mouseTarget(root); mouseClick(); advance(0.05)
        expect(mock.env.SUR.state().selectedTarget == nil and not mock.env.SUR.state().picking, "stopped picker stayed armed")
        expect(h.Health == 100, "stopped action changed health")
        cleanErrors(); unload()
    end)

    test("Fake profile stop preserves injured health and original fields", function()
        fresh()
        local c, data = player().Character, player().Data
        c.Humanoid.MaxHealth, c.Humanoid.Health = 100, 40
        local original = data.Stand.Value
        inputText("Stand Code","Fake","SP")
        inputText("Stand Health","Fake","999")
        click("Fake Profile ON","Fake"); advance(0.3)
        expect(c.Humanoid.Health == 40, "fake repeatedly healed current health")
        expect(c.Humanoid.MaxHealth == 999, "fake max not applied")
        click("Fake Profile ON","Fake"); advance(0.05)
        expect(c.Humanoid.MaxHealth == 100 and c.Humanoid.Health == 40, "injured health not restored exactly")
        expect(data.Stand.Value == original, "stand baseline not restored")
        local api = mock.env.SUR
        api.unload(); advance(0.2)
        cleanErrors()
    end)

    test("Item method switch retains ON and previous WalkSpeed restores", function()
        fresh()
        local h = player().Character.Humanoid
        h.WalkSpeed = 23
        click("Legit","Item Farm"); click("Start Farming","Item Farm"); advance(0.2)
        expect(h.WalkSpeed == 30, "Legit speed not set")
        click("Instant","Item Farm"); advance(0.1)
        expect(h.WalkSpeed == 23, "mode switch restored hardcoded speed")
        expect(indicator("Start Farming","Item Farm"), "mode switch turned indicator OFF")
        click("Start Farming","Item Farm"); advance(0.1)
        expect(#mock.env.SUR.diagnostics().jobs == 0, "first OFF after switch did not stop")
        cleanErrors(); unload()
    end)

    test("Moving farm owner arbitration stops the previous toggle", function()
        fresh()
        click("Farm: Jotaro Over Heaven","Boss Farm"); advance(0.1)
        click("Instant","Item Farm"); click("Start Farming","Item Farm"); advance(0.1)
        expect(not indicator("Farm: Jotaro Over Heaven","Boss Farm"), "old owner indicator stayed ON")
        local d = mock.env.SUR.diagnostics()
        expect(#d.jobs == 1 and d.jobs[1] == "items", "movement owners fought")
        cleanErrors(); unload()
    end)


    test("Same-name replacement cannot inherit the mouse-selected target", function()
        fresh()
        local chosen, chosenH, chosenRoot = npc("TwinBoss", 10,0,0)
        click("Select target (click boss)", "Auto Kill")
        mouseTarget(chosenRoot); mouseClick()
        chosen:Destroy()
        local replacement, replacementH = npc("TwinBoss",20,0,0)
        click("Auto Kill Selected", "Auto Kill"); advance(0.3)
        expect(replacementH.Health == 100, "replacement with same name was attacked")
        expect(not indicator("Auto Kill Selected", "Auto Kill"), "dead exact selection remained ON")
        cleanErrors(); unload()
    end)

    test("Mouse picker rejects another player and nested stand models", function()
        fresh()
        local plrs = mock.env.game:GetService("Players")
        local otherPlayer = mock.newInstance("Player", "RemotePlayer")
        local character, h, root = npc("RemotePlayer",20,0,0)
        otherPlayer.Character = character; otherPlayer.Parent = plrs
        local nested = mock.newInstance("Model", "Stand")
        local nestedH = mock.newInstance("Humanoid","Humanoid"); nestedH.Parent = nested
        local part = mock.newInstance("Part","VisibleStandPart"); part.Parent = nested
        nested.Parent = character
        click("Select target (click boss)","Auto Kill"); mouseTarget(root); mouseClick()
        expect(mock.env.SUR.state().selectedTarget == nil, "remote player selected")
        click("Select target (click boss)","Auto Kill"); mouseTarget(part); mouseClick()
        expect(mock.env.SUR.state().selectedTarget == nil, "remote player's nested stand selected")
        click("Auto Kill Selected","Auto Kill"); advance(0.2)
        expect(h.Health == 100 and nestedH.Health == 100, "player or stand health changed")
        cleanErrors(); unload()
    end)

    test("Escape and right click cancel pending selection", function()
        local env = fresh()
        local _, h, root = npc("AfterCancel",10,0,0)
        local uis = env.game:GetService("UserInputService")
        for _, input in ipairs({
            {KeyCode=env.Enum.KeyCode.Escape, UserInputType=env.Enum.UserInputType.Keyboard},
            {KeyCode=env.Enum.KeyCode.Unknown, UserInputType=env.Enum.UserInputType.MouseButton2},
        }) do
            click("Select target (click boss)","Auto Kill")
            uis.InputBegan:Fire(input, false)
            mouseTarget(root); mouseClick(); advance(0.02)
            expect(not env.SUR.state().picking and env.SUR.state().selectedTarget == nil, "cancelled picker accepted later click")
        end
        expect(h.Health == 100, "cancelled picker changed health")
        cleanErrors(); unload()
    end)

    test("Unloading cancels a yielded tutorial UI callback", function()
        fresh()
        click("Tutorial","Quest Farm")
        expect(mock.activeTasks() >= 1, "fixture did not keep yielded callback alive")
        unload(); advance(6)
        expect(mock.activeTasks() == 0, "tutorial callback survived unload")
        expect(mock.activeConnections() == 0, "UI subscriptions survived unload")
        expect(mock.env.ArcticScreenGui == nil, "tutorial recreated GUI after close")
        cleanErrors()
    end)

    test("Repeated Fake OFF does not rewind subsequent real Data updates", function()
        fresh()
        inputText("Stand Code","Fake","SP")
        click("Fake Profile ON","Fake"); advance(0.3)
        click("Fake Profile ON","Fake"); advance(0.05)
        player().Data.Stand.Value = "LaterRealStand"
        click("Instant","Item Farm"); click("Start Farming","Item Farm"); advance(0.1)
        unload()
        expect(player().Data.Stand.Value == "LaterRealStand", "inactive fakeStop restored obsolete snapshot")
        cleanErrors()
    end)

    test("Injured Fake health follows subsequent damage instead of healing", function()
        fresh()
        local h = player().Character.Humanoid
        h.MaxHealth, h.Health = 100,40
        inputText("Stand Health","Fake","999")
        click("Fake Profile ON","Fake"); advance(0.25)
        h.Health = 22
        advance(1)
        expect(h.Health == 22, "fake worker erased subsequent damage")
        click("Fake Profile ON","Fake"); advance(0.05)
        expect(h.MaxHealth == 100 and h.Health == 22, "OFF erased subsequent damage")
        cleanErrors(); unload()
    end)

    test("Lair stops on ambiguous duplicate canonical Boss models", function()
        fresh(); purgeProviders(); provider("ExplicitLair",0,0,0)
        npc("Boss",10,0,0); npc("Boss",20,0,0)
        mock.env.SUR.selectLair("ExplicitLair",15)
        local before = player().Character.HumanoidRootPart.Position
        mock.env.SUR.lairStart(); advance(0.2)
        expect((player().Character.HumanoidRootPart.Position-before).Magnitude < 0.01, "ambiguous Boss was followed")
        expect(not mock.env.SUR.state().lairOn and not indicator("Begin Lair Farm","Lair Farm"), "ambiguous job stayed active")
        cleanErrors(); unload()
    end)

    test("Lair acquisition timeout stops rather than retrying forever", function()
        fresh(); purgeProviders(); provider("ExplicitLair",0,0,0)
        mock.env.SUR.selectLair("ExplicitLair",15); mock.env.SUR.lairStart()
        advance(43)
        expect(not mock.env.SUR.state().lairOn, "40-second acquisition limit did not stop")
        expect(not indicator("Begin Lair Farm","Lair Farm"), "timeout indicator still ON")
        expect(#mock.env.SUR.diagnostics().jobs == 0, "timeout job survived")
        cleanErrors(); unload()
    end)

    test("Lair does not follow a moved exact Boss outside captured arena", function()
        fresh(); purgeProviders(); provider("ExplicitLair",0,0,0)
        local boss, h, root = npc("Boss",10,0,0)
        mock.env.SUR.selectLair("ExplicitLair",15); mock.env.SUR.lairStart(); advance(0.3)
        local before = player().Character.HumanoidRootPart.Position
        root.CFrame = mock.env.CFrame.new(10000,0,0)
        advance(1)
        expect((player().Character.HumanoidRootPart.Position-before).Magnitude < 0.01, "followed moved Boss outside arena")
        expect(not mock.env.SUR.state().lairOn, "outside-arena target did not stop")
        cleanErrors(); unload()
    end)

    test("Rejected Auto Kill does not steal another movement owner", function()
        fresh()
        click("Farm: Jotaro Over Heaven","Boss Farm"); advance(0.05)
        click("Auto Kill Selected","Auto Kill"); advance(0.05)
        expect(indicator("Farm: Jotaro Over Heaven","Boss Farm"), "invalid selected action stopped valid boss job")
        expect(mock.env.SUR.state().movement == "boss:Jotaro Over Heaven", "invalid start replaced movement owner")
        cleanErrors(); unload()
    end)

    test("State reads do not invoke the server moveset remote", function()
        fresh()
        local info = player().Character.StandEvents.Info
        local calls = 0
        info.InvokeServer = function() calls = calls + 1; return {} end
        for _ = 1,30 do mock.env.SUR.state() end
        expect(calls == 0, "SUR.state performed network invocation")
        cleanErrors(); unload()
    end)

    test("Moveset refresh keeps connections bounded and normalizes Enum keys", function()
        fresh()
        local env = mock.env
        local cyclic = {}; cyclic.Key = cyclic
        local info = player().Character.StandEvents.Info
        info.InvokeServer = function()
            return {env.Enum.KeyCode.E, env.Enum.KeyCode.E, "Enum.KeyCode.R", env.Enum.UserInputType.MouseButton1, "not_a_key", cyclic}
        end
        click("Refresh Movesets","Farm Settings"); advance(0.25)
        expect(env.SUR.state().moves == 3, "Enum/string moveset dedupe failed")
        control("E","Farm Settings"); control("R","Farm Settings"); control("M1","Farm Settings")
        local count = mock.activeConnections()
        for _=1,20 do click("Refresh Movesets","Farm Settings"); advance(0.25) end
        expect(mock.activeConnections() == count, "refresh leaked owner-bound subscriptions")
        cleanErrors(); unload()
    end)

    test("Combat mouse packet uses Unknown and OFF releases held input", function()
        fresh()
        npc("Jotaro Over Heaven",10,0,0)
        local env = mock.env
        local input = player().Character.StandEvents.Input
        local packets = {}
        input.FireServer = function(_, packet) packets[#packets+1] = packet end
        click("Farm: Jotaro Over Heaven","Boss Farm"); advance(0.45)
        click("Farm: Jotaro Over Heaven","Boss Farm")
        local begins, ends = {},{}
        local mice = 0
        for _,packet in ipairs(packets) do
            local key = tostring(packet.Key) .. "/" .. tostring(packet.Type)
            local target = packet.State == "Begin" and begins or ends
            target[key] = (target[key] or 0)+1
            if packet.Type == env.Enum.UserInputType.MouseButton1 then
                mice=mice+1
                expect(packet.Key == env.Enum.KeyCode.Unknown, "mouse packet used a keyboard key")
            end
        end
        expect(mice > 0, "fixture never sent M1")
        for key,count in pairs(begins) do expect((ends[key] or 0) >= count, "held input not released: " .. key) end
        local before = #packets; advance(2)
        expect(#packets == before, "OFF sent later combat packets")
        cleanErrors(); unload()
    end)

    test("Desired pretty stand match stops before destructive Tool use", function()
        fresh()
        local env = mock.env
        local convert = env.game:GetService("ReplicatedStorage").StandNameConvert
        local entry = convert:FindFirstChild("SP")
        if not entry then entry=mock.newInstance("StringValue","SP"); entry.Parent=convert end
        entry.Value = "Star Platinum"
        player().Data.Stand.Value = "SP"
        local uses = 0
        local tool = mock.newInstance("Tool","Rokakaka"); tool.Parent=player().Backpack
        local use = mock.newInstance("RemoteEvent","Use"); use.Parent=tool
        use.FireServer = function() uses=uses+1 end
        click("Enable Stand Check","Stand Farm"); click("Star Platinum","Stand Farm")
        click("Begin Stand Farm","Stand Farm"); advance(0.2)
        expect(uses == 0, "desired stand was destroyed before comparison")
        expect(not indicator("Begin Stand Farm","Stand Farm"), "found match left farm ON")
        expect(player().Data.Stand.Value == "SP", "desired real stand changed")
        cleanErrors(); unload()
    end)

    test("Failed stand purchases are bounded to three actual requests", function()
        fresh(); purgeProviders(); provider("MerchantAU",0,0,0)
        player().Data.Stand.Value = "None"
        for _,container in ipairs({player().Backpack,player().Character}) do
            for _,item in ipairs(container:GetChildren()) do if item:IsA("Tool") then item:Destroy() end end
        end
        local buys = 0
        local buy = mock.env.game:GetService("ReplicatedStorage").Events.BuyItem
        buy.FireServer = function() buys=buys+1 end
        click("Enable Stand Check","Stand Farm"); click("Star Platinum","Stand Farm")
        click("Auto Buy Selected Arrows","Stand Farm"); click("Begin Stand Farm","Stand Farm")
        advance(17)
        expect(buys == 3, "purchase loop did not stop after three requests: " .. tostring(buys))
        expect(not indicator("Begin Stand Farm","Stand Farm"), "failed purchase farm stayed ON")
        local before=buys; advance(8); expect(buys==before,"failed purchases continued after stop")
        cleanErrors(); unload()
    end)

    test("Stand OFF during merchant wait cannot send delayed purchase", function()
        fresh(); purgeProviders(); provider("MerchantAU",0,0,0)
        player().Data.Stand.Value = "None"
        for _,item in ipairs(player().Backpack:GetChildren()) do if item:IsA("Tool") then item:Destroy() end end
        local buys=0
        mock.env.game:GetService("ReplicatedStorage").Events.BuyItem.FireServer=function() buys=buys+1 end
        click("Enable Stand Check","Stand Farm"); click("Star Platinum","Stand Farm")
        click("Auto Buy Selected Arrows","Stand Farm"); click("Begin Stand Farm","Stand Farm"); advance(0.1)
        click("Begin Stand Farm","Stand Farm"); advance(1)
        expect(buys == 0, "purchase packet fired after OFF")
        expect(not indicator("Begin Stand Farm","Stand Farm"), "cancelled stand farm remained ON")
        cleanErrors(); unload()
    end)

    test("Path cancellation disconnects waypoint listener and halts MoveTo", function()
        fresh()
        local env=mock.env
        local tool=mock.newInstance("Tool","DroppedItem"); tool.Parent=mock.workspace.Items
        local part=mock.newInstance("Part","Handle"); part.CFrame=env.CFrame.new(25,0,0); part.Parent=tool
        local h=player().Character.Humanoid
        local positions={}
        h.MoveTo=function(_, position) positions[#positions+1]=position end
        env.game:GetService("PathfindingService").CreatePath=function()
            return {
                Status=env.Enum.PathStatus.Success,
                ComputeAsync=function() end,
                GetWaypoints=function() return {{Position=part.Position,Action=env.Enum.PathWaypointAction.Walk}} end,
            }
        end
        local baseline=mock.activeConnections()
        click("Legit","Item Farm"); click("Start Farming","Item Farm"); advance(0.1)
        expect(mock.activeConnections()==baseline+1,"pending waypoint subscription missing")
        click("Start Farming","Item Farm")
        expect(mock.activeConnections()==baseline,"cancelled waypoint subscription leaked")
        expect(#positions>=2 and (positions[#positions]-player().Character.HumanoidRootPart.Position).Magnitude<0.01,"cancelled walk not halted")
        local count=#positions; advance(5); expect(#positions==count,"old waypoint worker resumed after OFF")
        cleanErrors(); unload()
    end)

    test("Prompt fallback OFF balances hold begin and hold end", function()
        fresh()
        local env=mock.env
        env.fireproximityprompt=nil
        local tool=mock.newInstance("Tool","PromptItem"); tool.Parent=mock.workspace.Items
        local part=mock.newInstance("Part","Handle"); part.CFrame=env.CFrame.new(10,0,0); part.Parent=tool
        local prompt=mock.newInstance("ProximityPrompt","Pickup"); prompt.HoldDuration=10; prompt.Parent=part
        local begins,ends=0,0
        prompt.InputHoldBegin=function() begins=begins+1 end
        prompt.InputHoldEnd=function() ends=ends+1 end
        click("Instant","Item Farm"); click("Start Farming","Item Farm"); advance(0.3)
        expect(begins==1 and ends==0,"fixture not inside pending prompt hold")
        click("Start Farming","Item Farm")
        expect(ends==begins,"OFF did not release prompt hold")
        local before=begins; advance(12); expect(begins==before,"cancelled prompt worker restarted")
        cleanErrors(); unload()
    end)


    test("Criteria edits cancel stand consumption during delayed equip", function()
        fresh()
        local env=mock.env
        player().Data.Stand.Value="OtherStand"
        local h=player().Character.Humanoid
        local tool=mock.newInstance("Tool","Rokakaka"); tool.Parent=player().Backpack
        local uses=0
        local remote=mock.newInstance("RemoteEvent","Use"); remote.Parent=tool
        remote.FireServer=function() uses=uses+1 end
        h.EquipTool=function() end
        click("Enable Stand Check","Stand Farm"); click("Star Platinum","Stand Farm")
        click("Begin Stand Farm","Stand Farm"); advance(0.1)
        expect(indicator("Begin Stand Farm","Stand Farm"),"fixture never entered delayed equip")
        click("Enable Stand Check","Stand Farm")
        tool.Parent=player().Character; advance(4)
        expect(uses==0,"disabled criterion still allowed consumable remote")
        expect(not indicator("Begin Stand Farm","Stand Farm"),"criterion edit did not stop stand job")
        -- A cancelled job's equipment lock must not block another operation.
        click("Use Rokakaka","LocalPlayer"); advance(0.1)
        expect(uses==1,"cancelled stand equipment lock remained held")
        cleanErrors(); unload()
    end)

    test("Late desired stand is rechecked before delayed consumable use", function()
        fresh()
        player().Data.Stand.Value="OtherStand"
        local h=player().Character.Humanoid
        h.EquipTool=function() end
        local tool=mock.newInstance("Tool","Rokakaka"); tool.Parent=player().Backpack
        local uses=0
        local remote=mock.newInstance("RemoteEvent","Use"); remote.Parent=tool
        remote.FireServer=function() uses=uses+1 end
        click("Enable Stand Check","Stand Farm"); click("Star Platinum","Stand Farm")
        click("Begin Stand Farm","Stand Farm"); advance(0.1)
        player().Data.Stand.Value="SP"; tool.Parent=player().Character
        advance(0.2)
        expect(uses==0,"matching late roll was consumed")
        expect(not indicator("Begin Stand Farm","Stand Farm"),"matching late roll did not stop")
        cleanErrors(); unload()
    end)

    test("Auto Umbrella cannot unequip a consumable operation", function()
        fresh()
        local env=mock.env
        player().Data.Stand.Value="OtherStand"
        local h=player().Character.Humanoid
        local umbrella=player().Backpack:FindFirstChild("Umbrella")
        if not umbrella then umbrella=mock.newInstance("Tool","Umbrella"); umbrella.Parent=player().Backpack end
        local rok=mock.newInstance("Tool","Rokakaka"); rok.Parent=player().Backpack
        local uses,umbrellaEquips=0,0
        local remote=mock.newInstance("RemoteEvent","Use"); remote.Parent=rok
        remote.FireServer=function() uses=uses+1 end
        h.EquipTool=function(_,tool)
            if tool==umbrella then
                umbrellaEquips=umbrellaEquips+1
                if rok.Parent==player().Character then rok.Parent=player().Backpack end
                umbrella.Parent=player().Character
            else
                env.task.delay(0.5,function()
                    umbrella.Parent=player().Backpack
                    tool.Parent=player().Character
                end)
            end
        end
        click("Auto Umbrella","LocalPlayer")
        click("Enable Stand Check","Stand Farm"); click("Star Platinum","Stand Farm")
        click("Begin Stand Farm","Stand Farm"); advance(1.5)
        expect(uses==1,"delayed consumable was not used exactly once")
        expect(rok.Parent==player().Character,"umbrella stole pending consumable equipment")
        expect(umbrellaEquips<=1,"umbrella equipped during held consumable operation")
        click("Begin Stand Farm","Stand Farm"); advance(0.6)
        expect(umbrella.Parent==player().Character,"umbrella did not resume after cancellation")
        cleanErrors(); unload()
    end)


    test("Stand existence flips invalidate a delayed consumable", function()
        for _,spec in ipairs({
            {before="OtherStand", after="None", tool="Rokakaka"},
            {before="None", after="AnotherStand", tool="Stand Arrow"},
        }) do
            fresh()
            player().Data.Stand.Value=spec.before
            player().Character.Humanoid.EquipTool=function() end
            local item=mock.newInstance("Tool",spec.tool); item.Parent=player().Backpack
            local used=0
            local use=mock.newInstance("RemoteEvent","Use"); use.Parent=item
            use.FireServer=function() used=used+1 end
            click("Enable Stand Check","Stand Farm"); click("Star Platinum","Stand Farm")
            click("Begin Stand Farm","Stand Farm"); advance(0.1)
            player().Data.Stand.Value=spec.after; item.Parent=player().Character
            advance(0.15)
            expect(used==0,"stale " .. spec.tool .. " used after stand existence flip")
            click("Begin Stand Farm","Stand Farm")
            cleanErrors(); unload()
        end
    end)

    test("Manual consumable confirmation unload leaves no equipment callbacks", function()
        fresh()
        player().Data.Stand.Value="OtherStand"
        local item=mock.newInstance("Tool","Rokakaka"); item.Parent=player().Backpack
        local use=mock.newInstance("RemoteEvent","Use"); use.Parent=item
        local used=0; use.FireServer=function() used=used+1 end
        player().Character.Humanoid.EquipTool=function(_,tool) tool.Parent=player().Character end
        click("Use Rokakaka","LocalPlayer"); advance(0.2)
        expect(used==1,"manual consumable not used once")
        expect(mock.activeTasks()>0,"manual confirmation callback was not retained")
        unload(); advance(9)
        expect(mock.activeTasks()==0 and mock.activeConnections()==0,"manual callback survived unload")
        expect(used==1,"manual use retried after unload")
        cleanErrors()
    end)


    test("Fallback Activate transition still sends UseItem confirmation once", function()
        fresh()
        player().Data.Stand.Value="OtherStand"
        local tool=mock.newInstance("Tool","Rokakaka"); tool.Parent=player().Backpack
        local activations,confirmations=0,0
        tool.Activate=function() activations=activations+1; player().Data.Stand.Value="None" end
        player().Character.Humanoid.EquipTool=function(_,item) item.Parent=player().Character end
        mock.env.game:GetService("ReplicatedStorage").Events.UseItem.FireServer=function() confirmations=confirmations+1 end
        click("Enable Stand Check","Stand Farm"); click("Star Platinum","Stand Farm")
        click("Begin Stand Farm","Stand Farm"); advance(0.2)
        expect(activations==1 and confirmations==1,"expected transition suppressed fallback confirmation")
        click("Begin Stand Farm","Stand Farm")
        cleanErrors(); unload()
    end)


    test("Every original literal control and menu order remains available", function()
        fresh()
        for _,spec in ipairs(originalControls) do control(spec[1],spec[2]) end
        local expected={"Home","LocalPlayer","Shops","Farm Settings","Boss Farm","Lair Farm","Quest Farm","Item Farm","Teleports","Stand Farm"}
        local got={}
        for _,child in ipairs(gui().Frame.Menus:GetChildren()) do
            if child:IsA("GuiObject") then got[#got+1]=child.Name end
        end
        for i,name in ipairs(expected) do expect(got[i]==name,"original menu order changed at "..tostring(i)) end
        cleanErrors(); unload()
    end)


    test("Fake observes latest independent Data updates before reapplying", function()
        fresh()
        inputText("Stand Code","Fake","SP")
        click("Fake Profile ON","Fake"); advance(0.25)
        player().Data.Stand.Value="LatestReal"
        advance(0.3)
        expect(player().Data.Stand.Value=="SP","fake failed to reapply after external update")
        click("Fake Profile ON","Fake"); advance(0.05)
        expect(player().Data.Stand.Value=="LatestReal","OFF lost latest independent update")
        cleanErrors(); unload()
    end)

    test("Fake only restores its own Max-induced health clamp", function()
        fresh()
        local h=player().Character.Humanoid
        h.MaxHealth,h.Health=100,80
        inputText("Stand Health","Fake","50")
        click("Fake Profile ON","Fake"); advance(0.25)
        expect(h.MaxHealth==50 and h.Health==50,"mock did not model Max clamp")
        click("Fake Profile ON","Fake"); advance(0.05)
        expect(h.MaxHealth==100 and h.Health==80,"owned health clamp not restored")
        cleanErrors(); unload()
    end)

    test("Later damage invalidates an older health clamp snapshot", function()
        fresh()
        local h=player().Character.Humanoid
        h.MaxHealth,h.Health=100,80
        inputText("Stand Health","Fake","50")
        click("Fake Profile ON","Fake"); advance(0.25)
        h.Health=40
        inputText("Stand Health","Fake","30"); advance(0.25)
        expect(h.Health==30,"second Max clamp fixture failed")
        click("Fake Profile ON","Fake"); advance(0.05)
        expect(h.MaxHealth==100 and h.Health==40,"OFF healed independent damage using stale clamp")
        cleanErrors(); unload()
    end)

    test("Fake never revives a dead character during OFF", function()
        fresh()
        local h=player().Character.Humanoid
        h.MaxHealth,h.Health=100,80
        inputText("Stand Health","Fake","50")
        click("Fake Profile ON","Fake"); advance(0.25)
        h.Health=0
        click("Fake Profile ON","Fake"); advance(0.05)
        expect(h.Health==0,"OFF revived a dead humanoid")
        cleanErrors(); unload()
    end)

    test("Fake empty and zero-valued fields restore; clear disables spoof", function()
        fresh()
        local data=player().Data
        local guid=data:FindFirstChild("GUID")
        if not guid then guid=mock.newInstance("StringValue","GUID"); guid.Parent=data end
        guid.Value=""
        local st=player().Character:FindFirstChild("Stats")
        if not st then st=mock.newInstance("Folder","Stats"); st.Parent=player().Character end
        local dmg=st:FindFirstChild("AttackDmg")
        if not dmg then dmg=mock.newInstance("NumberValue","AttackDmg"); dmg.Parent=st end
        dmg.Value=0
        inputText("GUID","Fake","spoof-guid"); inputText("Stand Damage","Fake","500")
        click("Fake Profile ON","Fake"); advance(0.3)
        expect(guid.Value=="spoof-guid" and dmg.Value==500,"spoof fields not written")
        inputText("GUID","Fake",""); inputText("Stand Damage","Fake",""); advance(0.2)
        expect(guid.Value=="" and dmg.Value==0,"empty or zero baseline was not restored on clear")
        click("Fake Profile ON","Fake"); advance(0.05)
        cleanErrors(); unload()
    end)

    test("Fake respawn restores the new character's own baseline", function()
        fresh()
        local original=player().Character
        original.Humanoid.MaxHealth,original.Humanoid.Health=100,40
        inputText("Stand Health","Fake","999")
        click("Fake Profile ON","Fake"); advance(0.25)
        local c,h,root=npc("Respawned",0,0,0,250)
        h.Health=70
        local st=mock.newInstance("Folder","Stats"); st.Parent=c
        local dmg=mock.newInstance("NumberValue","AttackDmg"); dmg.Value=80; dmg.Parent=st
        player().Character=c
        advance(0.3)
        expect(h.MaxHealth==999 and h.Health==70,"new character did not get cosmetic max only")
        click("Fake Profile ON","Fake"); advance(0.05)
        expect(h.MaxHealth==250 and h.Health==70,"new character inherited old health baseline")
        expect(original.Humanoid.MaxHealth==100 and original.Humanoid.Health==40,"old character cleanup corrupted baseline")
        cleanErrors(); unload()
    end)

    test("Fake does not restore an obsolete Data Instance into a replacement", function()
        fresh()
        inputText("Stand Code","Fake","SP")
        click("Fake Profile ON","Fake"); advance(0.25)
        local original=player().Data.Stand
        original.Parent=nil
        local freshStand=mock.newInstance("StringValue","Stand"); freshStand.Value="ReplacementReal"; freshStand.Parent=player().Data
        advance(0.25)
        click("Fake Profile ON","Fake"); advance(0.05)
        expect(freshStand.Value=="ReplacementReal","replacement inherited obsolete Data baseline")
        cleanErrors(); unload()
    end)

    test("Reopening Fake lists retains one current menu and selector", function()
        fresh()
        for _,spec in ipairs({{"Open stand list","Fake: Stands"},{"Open attribute list","Fake: Attributes"},{"Open stand model list","Fake: Models"}}) do
            click(spec[1],"Fake")
            local baseline=mock.activeConnections()
            for _=1,8 do click(spec[1],"Fake") end
            local countMenus,countButtons=0,0
            for _,child in ipairs(gui().Frame.Menus:GetChildren()) do if child.Name==spec[2] then countMenus=countMenus+1 end end
            for _,child in ipairs(gui().Frame.Buttons.Handler:GetChildren()) do if child.Name==spec[2] then countButtons=countButtons+1 end end
            expect(countMenus==1 and countButtons==1,"picker duplicated menu or selector")
            expect(mock.activeConnections()==baseline,"picker rebuild leaked connections")
        end
        cleanErrors(); unload()
    end)

    test("Profile OFF preview follows and sanitizes external references", function()
        fresh()
        local env=mock.env
        local source=mock.newInstance("Model","SP")
        local root=mock.newInstance("Part","HumanoidRootPart"); root.Parent=source
        local other=mock.newInstance("Part","DecorativePart"); other.Parent=source
        local internal=mock.newInstance("Motor6D","InternalJoint"); internal.Part0=root; internal.Part1=other; internal.Parent=root
        local external=mock.newInstance("Weld","ExternalJoint"); external.Part0=root; external.Part1=player().Character.HumanoidRootPart; external.Parent=root
        local script=mock.newInstance("Script","MustNotExecute"); script.Parent=source
        local ref=mock.newInstance("ObjectValue","OutsideRef"); ref.Value=player().Character.HumanoidRootPart; ref.Parent=source
        source.Parent=env.game:GetService("ReplicatedStorage")
        inputText("Stand Code","Fake","SP"); click("Fake stand model ON","Fake"); advance(0.2)
        local model=mock.workspace:FindFirstChild("SUR_FakeStand")
        expect(model,"preview missing")
        expect(not env.SUR.state().fakeOn,"preview implicitly enabled fake profile")
        expect(model:FindFirstChild("InternalJoint",true),"internal joint was wrongly scrubbed")
        expect(not model:FindFirstChild("ExternalJoint",true),"external character joint remained")
        expect(not model:FindFirstChild("MustNotExecute",true),"executable script remained in clone")
        expect(model.OutsideRef.Value==nil,"external ObjectValue remained")
        expect(player().Character.HumanoidRootPart.Anchored==false,"source player root was anchored")
        player().Character.HumanoidRootPart.CFrame=env.CFrame.new(20,0,0)*env.CFrame.Angles(0,math.pi/2,0)
        advance(0.2)
        local want=(player().Character.HumanoidRootPart.CFrame*env.CFrame.new(3,0,0)).Position
        expect((model:GetPivot().Position-want).Magnitude<0.01,"profile-OFF preview did not follow")
        click("Fake stand model OFF","Fake"); advance(0.05)
        expect(model.Parent==nil,"preview survived clear")
        expect(source:FindFirstChild("ExternalJoint",true) and source:FindFirstChild("MustNotExecute",true),"sanitizer mutated source")
        cleanErrors(); unload()
    end)

    test("Wrong-code or nonarchivable swap retains the existing good preview", function()
        fresh()
        local env=mock.env
        local function modelSource(code)
            local m=mock.newInstance("Model",code)
            local p=mock.newInstance("Part","HumanoidRootPart"); p.Parent=m
            m.Parent=env.game:GetService("ReplicatedStorage")
            return m
        end
        local good=modelSource("SP")
        inputText("Stand Code","Fake","SP"); click("Fake stand model ON","Fake"); advance(0.1)
        local before=mock.workspace:FindFirstChild("SUR_FakeStand")
        expect(before,"good preview not created")
        inputText("Stand Code","Fake","MissingCode"); click("Fake stand model ON","Fake")
        expect(mock.workspace:FindFirstChild("SUR_FakeStand")==before,"wrong code replaced or removed good preview")
        local blocked=modelSource("Blocked"); blocked.Archivable=false
        inputText("Stand Code","Fake","Blocked"); click("Fake stand model ON","Fake")
        expect(mock.workspace:FindFirstChild("SUR_FakeStand")==before,"nonarchivable swap removed good preview")
        expect(blocked.Archivable==false,"source Archivable was forcibly changed")
        local count=0; for _,m in ipairs(mock.workspace:GetChildren()) do if m.Name=="SUR_FakeStand" then count=count+1 end end
        expect(count==1,"failed swap left orphan clone")
        cleanErrors(); unload()
    end)

    test("Externally destroyed preview stops its worker without respawning", function()
        fresh()
        local source=mock.newInstance("Model","SP"); source.Parent=mock.env.game:GetService("ReplicatedStorage")
        local p=mock.newInstance("Part","HumanoidRootPart"); p.Parent=source
        inputText("Stand Code","Fake","SP"); click("Fake stand model ON","Fake"); advance(0.1)
        local model=mock.workspace:FindFirstChild("SUR_FakeStand"); expect(model,"preview missing")
        model:Destroy(); advance(1)
        expect(mock.workspace:FindFirstChild("SUR_FakeStand")==nil,"destroyed preview silently respawned")
        expect(#mock.env.SUR.diagnostics().jobs==0,"destroyed preview worker survived")
        cleanErrors(); unload()
    end)

    test("Selected NPC root replacement invalidates exact selection", function()
        fresh()
        local model,h,root=npc("RootSwap",10,0,0)
        click("Select target (click boss)","Auto Kill"); mouseTarget(root); mouseClick()
        root:Destroy()
        local replacement=mock.newInstance("Part","HumanoidRootPart"); replacement.Parent=model
        click("Auto Kill Selected","Auto Kill"); advance(0.2)
        expect(h.Health==100,"changed root inherited stale selected action")
        expect(not indicator("Auto Kill Selected","Auto Kill"),"changed root action stayed ON")
        cleanErrors(); unload()
    end)

    test("Picker expiry cancels later clicks and old expiry cannot clear a new pick", function()
        fresh()
        local _,h,root=npc("AfterExpiry",10,0,0)
        click("Select target (click boss)","Auto Kill"); advance(16)
        expect(not mock.env.SUR.state().picking,"picker did not expire")
        mouseTarget(root); mouseClick()
        expect(mock.env.SUR.state().selectedTarget==nil,"expired picker accepted later click")
        click("Select target (click boss)","Auto Kill"); advance(8)
        click("Select target (click boss)","Auto Kill"); advance(8)
        expect(mock.env.SUR.state().picking,"old expiry cleared new picker")
        mouseTarget(root); mouseClick()
        expect(mock.env.SUR.state().selectedTarget=="AfterExpiry","new picker lost exact target")
        cleanErrors(); unload()
    end)

    test("Failed local CFrame write never reaches selected target HP", function()
        fresh()
        local _,h,root=npc("TeleportFailure",10,0,0)
        click("Select target (click boss)","Auto Kill"); mouseTarget(root); mouseClick()
        local me=player().Character.HumanoidRootPart
        local before=me.Position
        local mt=getmetatable(me)
        local setter=mt.__newindex
        mt.__newindex=function(instance,key,value)
            if key=="CFrame" then error("fixture rejects CFrame write") end
            return setter(instance,key,value)
        end
        click("Auto Kill Selected","Auto Kill"); advance(0.25)
        mt.__newindex=setter
        expect(h.Health==100,"failed teleport still wrote target HP")
        expect((me.Position-before).Magnitude<0.01,"failed write moved local root")
        expect(not indicator("Auto Kill Selected","Auto Kill"),"failed action stayed ON")
        expect(#mock.env.SUR.diagnostics().jobs==0,"failed action worker survived")
        cleanErrors(); unload()
    end)

    test("Selected NPC becoming a player character invalidates the action", function()
        fresh()
        local model,h,root=npc("NewPlayerCharacter",10,0,0)
        click("Select target (click boss)","Auto Kill"); mouseTarget(root); mouseClick()
        local stranger=mock.newInstance("Player","NewPlayer")
        stranger.Character=model; stranger.Parent=mock.env.game:GetService("Players")
        click("Auto Kill Selected","Auto Kill"); advance(0.25)
        expect(h.Health==100,"selected player character HP was changed")
        expect(not indicator("Auto Kill Selected","Auto Kill"),"player rejection stayed ON")
        cleanErrors(); unload()
    end)

    test("Missing or dead local character rejects a selected action", function()
        for _,missing in ipairs({false,true}) do
            fresh()
            local _,h,root=npc("NeedsLiveLocal",10,0,0)
            click("Select target (click boss)","Auto Kill"); mouseTarget(root); mouseClick()
            if missing then player().Character.HumanoidRootPart:Destroy() else player().Character.Humanoid.Health=0 end
            click("Auto Kill Selected","Auto Kill"); advance(0.25)
            expect(h.Health==100,"invalid local character still wrote target HP")
            expect(not indicator("Auto Kill Selected","Auto Kill"),"invalid local action stayed ON")
            cleanErrors(); unload()
        end
    end)

    test("Fake captures late Stats and HUD instances immediately before writing", function()
        fresh()
        local c=player().Character
        local old=c:FindFirstChild("Stats"); if old then old:Destroy() end
        inputText("Stand Code","Fake","SP"); inputText("Stand Damage","Fake","500")
        click("Fake Profile ON","Fake"); advance(0.25)
        local stats=mock.newInstance("Folder","Stats"); stats.Parent=c
        local damage=mock.newInstance("NumberValue","AttackDmg"); damage.Value=25; damage.Parent=stats
        local pg=player():FindFirstChildOfClass("PlayerGui")
        local gameGui=pg:FindFirstChild("PlayerGUI")
        if gameGui then gameGui:Destroy() end
        gameGui=mock.newInstance("ScreenGui","PlayerGUI"); gameGui.Parent=pg
        local ingame=mock.newInstance("Frame","ingame"); ingame.Parent=gameGui
        local hud=mock.newInstance("Frame","Stats"); hud.Parent=ingame
        local holder=mock.newInstance("Frame","StandName"); holder.Parent=hud
        local label=mock.newInstance("TextLabel","TextLabel"); label.Text="Late real HUD"; label.Parent=holder
        local unrelated=mock.newInstance("TextLabel","CoinCount"); unrelated.Text="25"; unrelated.Parent=hud
        advance(0.3)
        expect(damage.Value==500,"late stats were never spoofed")
        expect(label.Text~= "Late real HUD","late stand HUD was never spoofed")
        expect(unrelated.Text=="25","unrelated number label was spoofed")
        click("Fake Profile ON","Fake"); advance(0.05)
        expect(damage.Value==25 and label.Text=="Late real HUD","late exact-instance baseline was not restored")
        cleanErrors(); unload()
    end)

    test("Preview finds exact stand code on other Player.Data, not Character.Data", function()
        fresh()
        local env=mock.env
        local stranger=mock.newInstance("Player","StandOwner"); stranger.Parent=env.game:GetService("Players")
        local data=mock.newInstance("Folder","Data"); data.Parent=stranger
        local code=mock.newInstance("StringValue","Stand"); code.Value="OtherExactCode"; code.Parent=data
        local c=mock.newInstance("Model","StandOwnerCharacter"); c.Parent=mock.workspace; stranger.Character=c
        local wrongData=mock.newInstance("Folder","Data"); wrongData.Parent=c
        local wrongCode=mock.newInstance("StringValue","Stand"); wrongCode.Value="WrongCharacterCode"; wrongCode.Parent=wrongData
        local source=mock.newInstance("Model","Stand"); source.Parent=c
        local p=mock.newInstance("Part","ExactOtherPart"); p.Parent=source
        inputText("Stand Code","Fake","OtherExactCode"); click("Fake stand model ON","Fake"); advance(0.15)
        local preview=mock.workspace:FindFirstChild("SUR_FakeStand")
        expect(preview and preview:FindFirstChild("ExactOtherPart"),"Player.Data exact model not found")
        expect(p.Anchored==false and source.Parent==c,"other player's source mutated")
        cleanErrors(); unload()
    end)

    test("Concrete preview constraints retain internal and remove external attachments", function()
        fresh()
        local env=mock.env
        local source=mock.newInstance("Model","ConstraintCode")
        local p=mock.newInstance("Part","HumanoidRootPart"); p.Parent=source
        local inside=mock.newInstance("Attachment","InsideAttachment"); inside.Parent=p
        local outside=mock.newInstance("Attachment","OutsideAttachment"); outside.Parent=player().Character.HumanoidRootPart
        local internal=mock.newInstance("AlignPosition","InternalAlign"); internal.Attachment0=inside; internal.Parent=p
        local external=mock.newInstance("RopeConstraint","ExternalRope"); external.Attachment0=inside; external.Attachment1=outside; external.Parent=p
        source.Parent=env.game:GetService("ReplicatedStorage")
        expect(internal:IsA("Constraint") and external:IsA("Constraint"),"mock concrete Constraint inheritance missing")
        inputText("Stand Code","Fake","ConstraintCode"); click("Fake stand model ON","Fake"); advance(0.15)
        local preview=mock.workspace:FindFirstChild("SUR_FakeStand")
        expect(preview and preview:FindFirstChild("InternalAlign",true),"internal concrete Constraint removed")
        expect(not preview:FindFirstChild("ExternalRope",true),"external concrete Constraint retained")
        local copied=preview:FindFirstChild("InternalAlign",true)
        expect(copied.Attachment0~=inside and copied.Attachment0:IsDescendantOf(preview),"internal attachment not remapped")
        expect(external.Parent==p and external.Attachment1==outside,"constraint source mutated")
        cleanErrors(); unload()
    end)

    test("Nil clone, failed PivotTo and failed parenting retain good preview with no orphan", function()
        fresh()
        local env=mock.env
        local function modelSource(code)
            local source=mock.newInstance("Model",code)
            local p=mock.newInstance("Part","HumanoidRootPart"); p.Parent=source
            source.Parent=env.game:GetService("ReplicatedStorage")
            return source
        end
        modelSource("GoodTransactionalCode")
        inputText("Stand Code","Fake","GoodTransactionalCode"); click("Fake stand model ON","Fake"); advance(0.15)
        local before=mock.workspace:FindFirstChild("SUR_FakeStand"); expect(before,"initial good preview missing")
        local blocked=modelSource("BrokenTransactionalCode")
        local normalClone=blocked.Clone
        blocked.Clone=function() return nil end
        inputText("Stand Code","Fake","BrokenTransactionalCode")
        expect(mock.workspace:FindFirstChild("SUR_FakeStand")==before,"nil clone replaced good preview")
        local failedPivot
        blocked.Clone=function(instance)
            failedPivot=normalClone(instance)
            failedPivot.PivotTo=function() error("fixture rejects PivotTo") end
            return failedPivot
        end
        click("Fake stand model ON","Fake")
        expect(failedPivot and failedPivot.__destroyed,"failed PivotTo leaked candidate")
        expect(mock.workspace:FindFirstChild("SUR_FakeStand")==before,"failed PivotTo replaced good preview")
        local failedParent
        blocked.Clone=function(instance)
            failedParent=normalClone(instance)
            local mt=getmetatable(failedParent); local setter=mt.__newindex
            mt.__newindex=function(target,key,value)
                if key=="Parent" and value==mock.workspace then error("fixture rejects Workspace Parent") end
                return setter(target,key,value)
            end
            return failedParent
        end
        click("Fake stand model ON","Fake")
        expect(failedParent and failedParent.__destroyed,"failed parenting leaked candidate")
        expect(mock.workspace:FindFirstChild("SUR_FakeStand")==before,"failed parenting replaced good preview")
        local count=0; for _,m in ipairs(mock.workspace:GetChildren()) do if m.Name=="SUR_FakeStand" then count=count+1 end end
        expect(count==1,"failed transaction left multiple previews")
        cleanErrors(); unload()
    end)

    test("Lair entry adopts the observed arrival once, not the launch location", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        local requests,attacks=0,0
        local bossHum
        player().Character.StandEvents.Input.FireServer=function(_,packet)
            if packet.State=="Begin" and packet.Type==env.Enum.UserInputType.MouseButton1 then attacks=attacks+1 end
        end
        done.FireServer=function()
            requests=requests+1
            env.task.delay(0.05,function()
                player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0)
                local _,h=npc("Boss",10010,0,0); bossHum=h
            end)
        end
        expect(env.SUR.selectLair("ExplicitLair",15),"provider selection failed")
        env.SUR.lairStart(); advance(2)
        expect(requests==1,"more than one in-flight entry request")
        expect(env.SUR.state().lairOn and indicator("Begin Lair Farm","Lair Farm"),"legitimate entry painted OFF")
        expect(attacks>0,"exact arrival Boss never attacked")
        expect(bossHum.Health==100,"normal entry farm wrote local HP")
        expect(env.SUR.state().lairPhase=="fight","arrival did not enter fight phase")
        expect(env.SUR.state().lairAnchor.X>9000,"launch anchor remained after entry")
        cleanErrors(); unload()
    end)

    test("Lair arrival waits for delayed Boss without pulling back to the provider", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        local requests=0
        done.FireServer=function()
            requests=requests+1
            env.task.delay(0.05,function() player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0) end)
            env.task.delay(3,function() npc("Boss",10010,0,0) end)
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(1)
        expect(env.SUR.state().lairOn,"OFF before delayed Boss could stream")
        expect(player().Character.HumanoidRootPart.Position.X>9000,"pulled back to origin provider during entry")
        expect(requests==1,"entry spammed provider while waiting")
        advance(3.5)
        expect(env.SUR.state().lairOn and env.SUR.state().lairPhase=="fight","delayed arrival Boss not acquired")
        cleanErrors(); unload()
    end)

    test("Origin provider streaming out after entry does not stop the current Boss", function()
        fresh(); purgeProviders()
        local origin,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        done.FireServer=function()
            env.task.delay(0.05,function()
                player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0)
                npc("Boss",10010,0,0)
                origin.Parent=nil
            end)
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(2)
        expect(env.SUR.state().lairOn and env.SUR.state().lairPhase=="fight","unstreamed origin stopped valid arena fight")
        cleanErrors(); unload()
    end)

    test("Entry displacement never broadens Boss name or adopts a distant replacement", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        local requests=0
        done.FireServer=function()
            requests=requests+1
            env.task.delay(0.05,function()
                player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0)
                npc("Jotaro Over Heaven",10010,0,0)
                npc("Boss",20000,0,0)
            end)
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(2)
        expect(player().Character.HumanoidRootPart.Position.X==10000,"followed arbitrary world/distant boss")
        advance(40)
        expect(not env.SUR.state().lairOn,"unconfirmed entry waited forever")
        expect(requests==1,"unconfirmed entry repeatedly sent provider Done")
        expect(env.SUR.state().lairStopReason=="entry_timeout","missing entry timeout reason")
        cleanErrors(); unload()
    end)

    test("A completed arena cannot rebase itself into an unrelated later arena", function()
        fresh(); purgeProviders(); provider("ExplicitLair",0,0,0)
        local boss=npc("Boss",10,0,0)
        local env=mock.env
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(0.5)
        boss:Destroy()
        player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0)
        npc("Boss",10010,0,0)
        advance(1.5)
        expect(not env.SUR.state().lairOn,"post-fight displacement was treated as a new entry")
        expect(env.SUR.state().lairStopReason=="arena_left","missing post-fight arena exit reason")
        cleanErrors(); unload()
    end)

    test("Lair OFF during entry cancels acquisition without delayed teleport or attack", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        done.FireServer=function()
            env.task.delay(0.1,function()
                player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0)
                npc("Boss",10010,0,0)
            end)
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); env.SUR.lairStop()
        advance(2)
        expect(not env.SUR.state().lairOn and not indicator("Begin Lair Farm","Lair Farm"),"OFF entry resurrected")
        expect(player().Character.HumanoidRootPart.Position.X==10000,"cancelled entry worker moved to spawned Boss")
        expect(#env.SUR.diagnostics().jobs==0,"entry worker leaked after OFF")
        cleanErrors(); unload()
    end)

    test("Entry phase cannot inherit a respawned local character", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        done.FireServer=function()
            env.task.delay(0.05,function()
                local replacement=npc("RespawnedPlayer",10000,0,0)
                player().Character=replacement
                npc("Boss",10010,0,0)
            end)
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(2)
        expect(not env.SUR.state().lairOn,"entry inherited another local character")
        expect(env.SUR.state().lairStopReason=="character_changed","respawn stopped without explicit reason")
        cleanErrors(); unload()
    end)

    test("A synchronous entry jump followed by failed Done cannot be adopted", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        done.FireServer=function()
            player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0)
            npc("Boss",10010,0,0)
            error("fixture rejects entry request")
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(2)
        expect(not env.SUR.state().lairOn,"failed entry request was adopted")
        expect(env.SUR.state().lairStopReason=="entry_request_failed","missing failed entry request reason")
        cleanErrors(); unload()
    end)

    test("Second pending arrival displacement is not adopted", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        done.FireServer=function()
            env.task.delay(0.05,function() player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0) end)
            env.task.delay(0.5,function()
                player().Character.HumanoidRootPart.CFrame=env.CFrame.new(20000,0,0)
                npc("Boss",20010,0,0)
            end)
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(2)
        expect(not env.SUR.state().lairOn and env.SUR.state().lairStopReason=="entry_changed","second pending displacement adopted")
        expect(player().Character.HumanoidRootPart.Position.X==20000,"worker followed second destination Boss")
        cleanErrors(); unload()
    end)

    test("Duplicate exact Boss at arrival does not select either", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        done.FireServer=function()
            env.task.delay(0.05,function()
                player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0)
                npc("Boss",10010,0,0); npc("Boss",10020,0,0)
            end)
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(2)
        expect(not env.SUR.state().lairOn and env.SUR.state().lairStopReason=="boss_ambiguous","duplicate arrival Boss accepted")
        expect(player().Character.HumanoidRootPart.Position.X==10000,"moved to ambiguous arrival Boss")
        cleanErrors(); unload()
    end)

    test("Reselecting provider invalidates an already pending arrival", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        provider("ReplacementLair",1,0,0)
        local env=mock.env
        done.FireServer=function()
            env.task.delay(0.05,function()
                player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0)
                npc("Boss",10010,0,0)
            end)
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart()
        expect(env.SUR.selectLair("ReplacementLair",15),"replacement provider selection failed")
        advance(2)
        expect(not env.SUR.state().lairOn and env.SUR.state().lairStopReason=="provider_changed","reselection did not invalidate pending arrival")
        expect(player().Character.HumanoidRootPart.Position.X==10000,"reselected worker moved to old Boss")
        cleanErrors(); unload()
    end)

    test("New movement owner invalidates pending lair acquisition", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        done.FireServer=function()
            env.task.delay(0.05,function()
                player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0)
                npc("Boss",10010,0,0)
            end)
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart()
        click("Farm: Jotaro Over Heaven","Boss Farm"); advance(2)
        expect(not env.SUR.state().lairOn and env.SUR.state().movement=="boss:Jotaro Over Heaven","new movement owner lost to stale entry")
        expect(player().Character.HumanoidRootPart.Position.X==10000,"stale acquisition moved after ownership change")
        cleanErrors(); unload()
    end)

    test("Scripted provider approach updates request origin but is not an arrival", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ApproachedLair",400,0,0)
        local env=mock.env
        local requests=0
        done.FireServer=function()
            requests=requests+1
            npc("Boss",410,0,0)
        end
        expect(env.SUR.selectLair("ApproachedLair",500),"far same-area provider not selected")
        env.SUR.lairStart(); advance(1)
        expect(requests==1 and env.SUR.state().lairOn,"bounded provider approach failed")
        expect(env.SUR.state().lairAnchor.X>390 and env.SUR.state().lairAnchor.X<410,"approach confused request origin with external arrival")
        cleanErrors(); unload()
    end)

    test("Synchronous successful entry transfer is captured before first wait", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        done.FireServer=function()
            player().Character.HumanoidRootPart.CFrame=env.CFrame.new(10000,0,0)
            npc("Boss",10010,0,0)
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(1)
        expect(env.SUR.state().lairOn and env.SUR.state().lairAnchor.X==10000,"synchronous successful transfer lost")
        cleanErrors(); unload()
    end)

    test("Own behind offset near arena radius cannot make the next tick stop", function()
        fresh(); purgeProviders(); provider("ExplicitLair",0,0,0)
        local env=mock.env
        local _,_,root=npc("Boss",499,0,0)
        root.CFrame=env.CFrame.new(499,0,0)*env.CFrame.Angles(0,math.pi/2,0)
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(1.5)
        expect(env.SUR.state().lairOn,"own behind offset tripped arena-left guard")
        expect(player().Character.HumanoidRootPart.Position.X>500,"boundary fixture never moved beyond radius")
        cleanErrors(); unload()
    end)

    test("Manual teleport during entry cancels lair before any arrival adoption", function()
        fresh(); purgeProviders()
        local _,_,done=provider("ExplicitLair",0,0,0)
        local env=mock.env
        done.FireServer=function() end
        local stranger=mock.newInstance("Player","ManualDestination"); stranger.Parent=env.game:GetService("Players")
        local c=mock.newInstance("Model","ManualCharacter"); c.Parent=mock.workspace; stranger.Character=c
        local root=mock.newInstance("Part","HumanoidRootPart"); root.CFrame=env.CFrame.new(10000,0,0); root.Parent=c
        npc("Boss",10010,0,0)
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(0.1)
        inputText("Teleport To","Teleports","ManualDestination"); advance(1)
        expect(not env.SUR.state().lairOn,"manual teleport was adopted as entry")
        expect(env.SUR.state().lairStopReason=="manual_teleport","manual teleport has no explicit cancellation reason")
        expect(player().Character.HumanoidRootPart.Position.X==10000,"stale lair worker pulled manual destination toward Boss")
        cleanErrors(); unload()
    end)

    test("Captured Lair Boss root replacement stops exact-target combat", function()
        fresh(); purgeProviders(); provider("ExplicitLair",0,0,0)
        local env=mock.env
        local boss,h,root=npc("Boss",10,0,0)
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(0.5)
        root:Destroy()
        local replacement=mock.newInstance("Part","HumanoidRootPart"); replacement.CFrame=env.CFrame.new(15,0,0); replacement.Parent=boss
        advance(1)
        expect(not env.SUR.state().lairOn and env.SUR.state().lairStopReason=="boss_changed","changed Boss root inherited captured combat")
        expect(h.Health==100,"root replacement changed local HP")
        cleanErrors(); unload()
    end)

    test("Renamed captured Lair Boss stops before another combat input", function()
        fresh(); purgeProviders(); provider("ExplicitLair",0,0,0)
        local env=mock.env
        local boss=npc("Boss",10,0,0)
        local attacks=0
        player().Character.StandEvents.Input.FireServer=function(_,packet)
            if packet.State=="Begin" and packet.Type==env.Enum.UserInputType.MouseButton1 then attacks=attacks+1 end
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(0.5)
        boss.Name="UnrelatedRole"
        local before=attacks
        advance(1)
        expect(not env.SUR.state().lairOn and env.SUR.state().lairStopReason=="boss_changed","renamed Boss still farmed")
        expect(attacks==before,"another attack sent after Boss rename")
        cleanErrors(); unload()
    end)

    test("Reacquisition respects a fixed deadline and never attacks a late Boss", function()
        fresh(); purgeProviders(); provider("ExplicitLair",0,0,0)
        local env=mock.env
        local boss=npc("Boss",10,0,0)
        local attacks=0
        player().Character.StandEvents.Input.FireServer=function(_,packet)
            if packet.State=="Begin" and packet.Type==env.Enum.UserInputType.MouseButton1 then attacks=attacks+1 end
        end
        env.SUR.selectLair("ExplicitLair",15); env.SUR.lairStart(); advance(0.5)
        boss:Destroy()
        advance(41)
        expect(not env.SUR.state().lairOn and env.SUR.state().lairStopReason=="boss_timeout","reacquisition deadline did not stop")
        local before=attacks
        npc("Boss",10,0,0); advance(1)
        expect(attacks==before and not env.SUR.state().lairOn,"late Boss revived timed-out acquisition")
        cleanErrors(); unload()
    end)

    return #failures == 0, passed, failures
end
