-- Zoptymalizowany Sqays Hub - Auto Mine + Auto Trial (Combat Fix)
local env = getgenv and getgenv() or _G
if env.NILoaded then return end
env.NILoaded = true; env.NIStop = false

-- ===== EXECUTOR DETECTION =====
local execName = "Unknown"
if identifyexecutor then execName = identifyexecutor() end
local gameName = "Unknown"
pcall(function() gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)

-- ===== SERVICES =====
local P = game:GetService("Players")
local WS = game:GetService("Workspace")
local RS = game:GetService("RunService")
local VU = game:GetService("VirtualUser")
local LP = P.LocalPlayer

-- ===== ANTI-CHEAT BYPASS =====
pcall(function()
    local net = game:GetService("ReplicatedStorage"):FindFirstChild("__Net")
    if net then
        local ak = net:FindFirstChild("AutoKick")
        if ak and ak:IsA("RemoteEvent") then ak.OnClientEvent:Connect(function() end) end
        local mg = net:FindFirstChild("MineralGained")
        if mg then mg.OnClientEvent:Connect(function() end) end
    end
end)
pcall(function()
    if getconnections then for _, c in ipairs(getconnections(game:GetService("ScriptContext").Error)) do c:Disable() end end
end)

-- ===== STATE & CONFIG =====
local S = {
    running = false,
    noclip = false,
    walkSpeed = 165,
}

local T = {
    enabled = false,
    difficulty = "Easy",
    grinding = false,
    testing = false,
    schedulerRunning = false,
    autoAttack = true
}

local TRIAL_COORDS = {
    Easy = Vector3.new(853.23, 11.01, 13443.50),
    Medium = Vector3.new(878.91, 11.03, 13419.06),
    Hard = Vector3.new(905.14, 11.01, 13443.57)
}

local ORES = {"Stone","Coal","Copper","Iron","Silver","Gold","Platinum","Titanium","Uranium","Cobalt","Palladium","Ruby","Aetherite","Celestium","Voidsteel","Infinity"}

-- ===== GHOST MODE & NOCLIP =====
local nc1, nc2, fixedY
local function noclip(on)
    S.noclip = on
    local c = LP.Character or LP.CharacterAdded:Wait()
    local hrp = c:WaitForChild("HumanoidRootPart", 5)
    local hum = c:WaitForChild("Humanoid", 5)
    if not hrp or not hum then return end
    
    if on then
        fixedY = hrp.Position.Y
        hum.JumpPower = 0
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
        
        if not nc1 then nc1 = RS.Stepped:Connect(function()
            if S.noclip and LP.Character then 
                for _, v in ipairs(LP.Character:GetDescendants()) do 
                    if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end 
                end 
            end
        end) end
        
        if not nc2 then nc2 = RS.Heartbeat:Connect(function()
            if not S.noclip then return end
            pcall(function()
                local char = LP.Character
                if not char then return end
                local root = char:FindFirstChild("HumanoidRootPart")
                local h = char:FindFirstChildOfClass("Humanoid")
                if not root or not h then return end
                h.Jump = false
                if math.abs(root.Position.Y - fixedY) > 0.5 then
                    root.CFrame = CFrame.new(Vector3.new(root.Position.X, fixedY, root.Position.Z)) * root.CFrame.Rotation
                end
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
            end)
        end) end
    else
        if nc1 then nc1:Disconnect(); nc1 = nil end
        if nc2 then nc2:Disconnect(); nc2 = nil end
        hum.JumpPower = 50
        hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end
end

-- ===== ANTI-AFK =====
local afkConn
local function antiAFK(on)
    if afkConn then afkConn:Disconnect(); afkConn = nil end
    if not on then return end
    afkConn = LP.Idled:Connect(function() pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end) end)
end
antiAFK(true)

-- ===== NATYWNE CHODZENIE (RUDY) =====
local function isCloseEnough(hrp, targetPos, threshold)
    if not hrp then return false end
    local d = Vector3.new(targetPos.X - hrp.Position.X, 0, targetPos.Z - hrp.Position.Z)
    return d.Magnitude <= threshold
end

local function moveToPointWalking(targetPos, tolerance)
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.WalkSpeed = S.walkSpeed
    hum.AutoRotate = true

    while not env.NIStop do
        if not hrp or not hrp.Parent or hum.Health <= 0 then break end
        if not S.running then break end

        local currentPos = hrp.Position
        local diff = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)
        local distance = diff.Magnitude
        
        if distance <= tolerance then
            hum:Move(Vector3.zero) 
            hrp.AssemblyLinearVelocity = Vector3.zero 
            hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)) 
            break 
        end
        
        hum:Move(diff.Unit)
        RS.Heartbeat:Wait()
    end
end

-- ===== ORE DETECTION =====
local function isOreReady(ore)
    if not ore or not ore.Parent then return false end
    if not ore:FindFirstChild("Rock") then return false end
    local ui = ore:FindFirstChild("OresTopUI")
    if ui then 
        local bar = ui:FindFirstChild("Bar")
        if bar then 
            local hp = bar:FindFirstChild("Health")
            if hp and hp.Text == "Respawning..." then return false end
        end
    end
    return true
end

local function getOrePosition(ore)
    local rock = ore:FindFirstChild("Rock")
    if rock and rock:IsA("BasePart") then return rock.Position end
    local ok, pivot = pcall(function() return ore:GetPivot() end)
    if ok and pivot then return pivot.Position end
    return nil
end

local function findBestOre()
    local gc = WS:FindFirstChild("__GAME_CONTENT")
    local of = gc and gc:FindFirstChild("Ores")
    if not of then return nil end
    for i = #ORES, 1, -1 do
        if S["m" .. ORES[i]] then
            for _, o in ipairs(of:GetChildren()) do
                if o.Name == ORES[i] and isOreReady(o) then return o end
            end
        end
    end
    return nil
end

local function isInMine()
    local gc = WS:FindFirstChild("__GAME_CONTENT")
    if not gc then return false end
    local of = gc:FindFirstChild("Ores")
    return of and #of:GetChildren() > 0
end

-- ===== MINING LOOP =====
local function loop()
    while S.running and not env.NIStop do
        if not isInMine() then task.wait(0.5); continue end

        local ore = findBestOre()
        if not ore then task.wait(0.1); continue end

        local c = LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if not hrp then task.wait(0.3); continue end

        local orePos = getOrePosition(ore)
        if not orePos then task.wait(0.1); continue end

        if not isCloseEnough(hrp, orePos, 0.7) then
            moveToPointWalking(orePos, 0.7)
        end
        
        if not S.running or env.NIStop then break end

        local waitStart = tick()
        while S.running and not env.NIStop do
            if not isOreReady(ore) then break end
            if tick() - waitStart > 40 then break end
            task.wait(0.1)
        end
    end
end

-- ===== AUTO TRIAL & COMBAT SYSTEM =====
local function shouldJoinTrial()
    local currentTime = os.date("*t")
    local minute = currentTime.min
    local second = currentTime.sec
    return (minute == 59 or minute == 29) and second == 10
end

local function teleportToTrial()
    local coord = TRIAL_COORDS[T.difficulty]
    if not coord then return false end
    
    local char = LP.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    -- BARDZO WAŻNE: Aktualizacja wysokości Ghost Mode przy teleportacji
    if S.noclip then
        fixedY = coord.Y
    end
    
    hrp.CFrame = CFrame.new(coord)
    hrp.AssemblyLinearVelocity = Vector3.zero
    return true
end

local function getMobPosition(mob)
    if not mob or not mob.Parent then return nil end
    local hrp = mob:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then return hrp.Position end
    return nil
end

local function isMobAlive(mob)
    if not mob or not mob.Parent then return false end
    local hum = mob:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health > 0 end
    return true
end

-- Agresywny skaner mobów
local function findTargetMob()
    local potentialTargets = {}
    
    local gc = WS:FindFirstChild("__GAME_CONTENT")
    local trials = gc and gc:FindFirstChild("Trials")
    local mobsFolder = trials and trials:FindFirstChild("Mobs")
    
    if mobsFolder then
        for _, v in ipairs(mobsFolder:GetChildren()) do table.insert(potentialTargets, v) end
    end
    
    local wsMobs = WS:FindFirstChild("Mobs") or WS:FindFirstChild("Enemies")
    if wsMobs then
        for _, v in ipairs(wsMobs:GetChildren()) do table.insert(potentialTargets, v) end
    end
    
    if #potentialTargets == 0 then
        for _, v in ipairs(WS:GetChildren()) do
            if v:FindFirstChildOfClass("Humanoid") and v ~= LP.Character then
                table.insert(potentialTargets, v)
            end
        end
    end

    -- Szukanie konkretnych (Goblin, itp)
    local mobPriority = {"Goblin", "Skeleton", "Orc"}
    for _, mobType in ipairs(mobPriority) do
        for _, mob in ipairs(potentialTargets) do
            if string.find(mob.Name, mobType) and isMobAlive(mob) then
                return mob
            end
        end
    end
    
    -- Szukanie byle czego
    for _, mob in ipairs(potentialTargets) do
        if isMobAlive(mob) and mob.Name ~= LP.Name then
            return mob
        end
    end
    
    return nil
end

-- PĘTLA WALKI (Z naprawionym poruszaniem MoveTo)
local function executeCombatLoop(stateKey)
    while T[stateKey] and not env.NIStop do
        local mob = findTargetMob()
        if not mob then
            task.wait(0.5)
            continue
        end
        
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then task.wait(0.5); continue end
        
        hum.AutoRotate = true
        
        if T.autoAttack then
            VU:ClickButton1(Vector2.new(0,0))
        end
        
        local mobPos = getMobPosition(mob)
        if not mobPos then task.wait(0.1); continue end
        
        local diff = Vector3.new(mobPos.X - hrp.Position.X, 0, mobPos.Z - hrp.Position.Z)
        local distance = diff.Magnitude
        
        if distance > 4 then
            hum.WalkSpeed = S.walkSpeed
            hum:MoveTo(mobPos) -- Używamy MoveTo by postać płynnie obiegła przeszkody do moba
        else
            hum:Move(Vector3.zero)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(mobPos.X, hrp.Position.Y, mobPos.Z))
        end
        
        task.wait(0.05)
    end
end

local function grindTrial()
    T.grinding = true
    executeCombatLoop("grinding")
end

local function testTrialLogic()
    T.testing = true
    executeCombatLoop("testing")
end

local function trialScheduler()
    T.schedulerRunning = true
    while T.enabled and not env.NIStop do
        if shouldJoinTrial() then
            if teleportToTrial() then
                task.wait(2)
                if T.enabled then task.spawn(grindTrial) end
            end
            task.wait(60)
        else
            task.wait(1)
        end
    end
    T.schedulerRunning = false
end

-- ===== RAYFIELD UI =====
local Rayfield = nil
local ok, result = pcall(function() return loadstring(game:HttpGet('https://sirius.menu/rayfield'))() end)
if ok and result then Rayfield = result end
if not Rayfield then warn("[Sqays Hub] Failed to load Rayfield UI"); return end

local Window = Rayfield:CreateWindow({
    Name = "Zoptymalizowany Sqays Hub",
    LoadingTitle = "Ładowanie...",
    LoadingSubtitle = "Oparty na Rayfield",
    Theme = "DarkBlue",
    ToggleUIKeybind = Enum.KeyCode.K,
    ConfigurationSaving = { Enabled = false }
})

local Main = Window:CreateTab("⛏ Mine")
local TrialTab = Window:CreateTab("⚔ Auto Trial")
local SetTab = Window:CreateTab("⚙ Settings")

-- Mining Tab
local tiers = {
    {"🔷 High Tier", {"Infinity", "Voidsteel", "Celestium", "Aetherite", "Ruby"}},
    {"🔶 Mid Tier",   {"Palladium", "Cobalt", "Uranium", "Titanium", "Platinum"}},
    {"🔹 Low Tier",   {"Gold", "Silver", "Iron", "Copper", "Coal", "Stone"}},
}

for _, tier in ipairs(tiers) do
    Main:CreateSection(tier[1])
    for _, n in ipairs(tier[2]) do
        local flag = "m" .. n
        Main:CreateToggle({
            Name = "Kop " .. n,
            CurrentValue = false,
            Callback = function(v)
                S[flag] = v
                if v and not S.running then
                    if not isInMine() then
                        Rayfield:Notify({Title = "Błąd", Content = "Wejdź najpierw do kopalni!", Duration = 3})
                        return
                    end
                    S.running = true
                    task.spawn(loop)
                end
            end
        })
    end
end

-- Auto Trial Tab
TrialTab:CreateSection("Zarządzanie Walką")

TrialTab:CreateToggle({
    Name = "Włącz Harmonogram (Czeka na xx:29 / xx:59)",
    CurrentValue = false,
    Callback = function(v)
        T.enabled = v
        if v and not T.schedulerRunning then
            task.spawn(trialScheduler)
            Rayfield:Notify({Title = "Harmonogram włączony", Content = "Oczekiwanie na właściwy czas (xx:29:10 lub xx:59:10).", Duration = 5})
        elseif not v then
            T.grinding = false
        end
    end
})

TrialTab:CreateButton({
    Name = "⚔️ Wymuś Start (Teleport & Walcz TERAZ)",
    Callback = function()
        T.enabled = true
        teleportToTrial()
        task.wait(1)
        if not T.grinding then
            task.spawn(grindTrial)
        end
        Rayfield:Notify({Title = "Auto Trial", Content = "Rozpoczynanie walki na wybranym poziomie!", Duration = 4})
    end
})

TrialTab:CreateToggle({
    Name = "🧪 Test Chodzenia i Bicia (Szuka na żywo wokół)",
    CurrentValue = false,
    Callback = function(v)
        T.testing = v
        if v then
            task.spawn(testTrialLogic)
            Rayfield:Notify({Title = "Test Mode", Content = "Szukanie żywego moba w pobliżu...", Duration = 3})
        end
    end
})

TrialTab:CreateSection("Opcje")

TrialTab:CreateDropdown({
    Name = "Wybierz Poziom Trudności",
    Options = {"Easy", "Medium", "Hard"},
    CurrentOption = {"Easy"},
    MultipleOptions = false,
    Callback = function(v)
        T.difficulty = type(v) == "table" and v[1] or v
    end
})

TrialTab:CreateToggle({
    Name = "Wymuszaj Lewy Klik (Auto Atak)",
    CurrentValue = true,
    Callback = function(v) T.autoAttack = v end
})

TrialTab:CreateButton({
    Name = "Zatrzymaj Auto Trial / Test",
    Callback = function()
        T.enabled = false
        T.grinding = false
        T.testing = false
        Rayfield:Notify({Title = "Zatrzymano", Content = "Zatrzymano walkę oraz testy.", Duration = 3})
    end
})

-- Settings Tab
SetTab:CreateSection("Zabezpieczenia i Ruch")
SetTab:CreateSlider({
    Name = "Prędkość Chodzenia (WalkSpeed)",
    Range = {16, 350},
    Increment = 1,
    CurrentValue = S.walkSpeed,
    Callback = function(v) S.walkSpeed = v end
})

SetTab:CreateToggle({
    Name = "Ghost Mode (Noclip)",
    CurrentValue = false,
    Callback = function(v) noclip(v) end
})

SetTab:CreateButton({
    Name = "Zabij Skrypt (Kill)",
    Callback = function()
        env.NIStop = true
        S.running = false
        T.enabled = false
        T.testing = false
        noclip(false)
        antiAFK(false)
        Rayfield:Destroy()
    end
})
