-- p1_v3.3.lua - Rebirth Engine - Modern Modular UI Framework [Base v1.7 + Core Stability Fix + Customization Overhaul + Input Fields + Expanded Layout + Quad Loop + Hybrid Movement System + Fluent Settings Patch + Full Upgrades Integration + ID Conflict Fix]
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

-- === SCRIPT LIFECYCLE ===
local scriptRunning = true

-- === ENVIRONMENT MATRIX ===
local env = getgenv and getgenv() or _G
env.SqaysConfig = env.SqaysConfig or {}
env.SqaysConfig.MiningSpeed = env.SqaysConfig.MiningSpeed or 0.01
env.SqaysConfig.TierSpeed = env.SqaysConfig.TierSpeed or 0.50
env.SqaysConfig.RuneSpeed = env.SqaysConfig.RuneSpeed or 0.50
env.SqaysConfig.TreeSpeed = env.SqaysConfig.TreeSpeed or 0.50
env.SqaysConfig.WaterPumpSpeed = env.SqaysConfig.WaterPumpSpeed or 0.50
env.SqaysConfig.IceConvertSpeed = env.SqaysConfig.IceConvertSpeed or 0.50
env.SqaysConfig.AshConvertSpeed = env.SqaysConfig.AshConvertSpeed or 1.0
env.SqaysConfig.BlazeQuestSpeed = env.SqaysConfig.BlazeQuestSpeed or 5.0
env.SqaysConfig.ExchangeGemsSpeed = env.SqaysConfig.ExchangeGemsSpeed or 10.0
env.SqaysConfig.SelectedIceLevel = env.SqaysConfig.SelectedIceLevel or 0
env.SqaysConfig.MiningTarget = env.SqaysConfig.MiningTarget or "Voidsteel + Celestium + Aetherite + Ruby Loop"
env.SqaysConfig.MovementMethod = env.SqaysConfig.MovementMethod or "Walking"

-- Konfiguracja Ulepszeń
env.SqaysConfig.AutoUpgradeNoob = env.SqaysConfig.AutoUpgradeNoob or false
env.SqaysConfig.AutoUpgradeGems = env.SqaysConfig.AutoUpgradeGems or false
env.SqaysConfig.AutoUpgradePlanks = env.SqaysConfig.AutoUpgradePlanks or false
env.SqaysConfig.AutoUpgradeWater = env.SqaysConfig.AutoUpgradeWater or false
env.SqaysConfig.UpgradeNoobSpeed = env.SqaysConfig.UpgradeNoobSpeed or 1
env.SqaysConfig.UpgradeGemsSpeed = env.SqaysConfig.UpgradeGemsSpeed or 1
env.SqaysConfig.UpgradePlanksSpeed = env.SqaysConfig.UpgradePlanksSpeed or 1
env.SqaysConfig.UpgradeWaterSpeed = env.SqaysConfig.UpgradeWaterSpeed or 1
env.SqaysConfig.SelectedNoobUpgrades = env.SqaysConfig.SelectedNoobUpgrades or {}
env.SqaysConfig.SelectedGemUpgrades = env.SqaysConfig.SelectedGemUpgrades or {}
env.SqaysConfig.SelectedPlankUpgrades = env.SqaysConfig.SelectedPlankUpgrades or {}
env.SqaysConfig.SelectedWaterUpgrades = env.SqaysConfig.SelectedWaterUpgrades or {}

env.SqaysConfig.AutoRollTier = env.SqaysConfig.AutoRollTier or false
env.SqaysConfig.AutoHitTree = env.SqaysConfig.AutoHitTree or false
env.SqaysConfig.AutoWaterPump = env.SqaysConfig.AutoWaterPump or false
env.SqaysConfig.AutoBlazeQuest = env.SqaysConfig.AutoBlazeQuest or false
env.SqaysConfig.AutoConvertWoodToAsh = env.SqaysConfig.AutoConvertWoodToAsh or false
env.SqaysConfig.AutoExchangeGems = env.SqaysConfig.AutoExchangeGems or false
env.SqaysConfig.AutoRollRunes = env.SqaysConfig.AutoRollRunes or false
env.SqaysConfig.AntiAFK = env.SqaysConfig.AntiAFK or false

-- === BASE LINE CONSTANTS ===
local Settings = {
    CustomWalkSpeed = 160,       
    WaitTimeOnOre = 0.50,      
    UseNoclip = false,
    UITheme = "Darker",
    UIAcrylic = true,
    UIAccentColor = Color3.fromRGB(150, 150, 255)
}

local looping = false
local totalMined = 0            
local minedInLast5Mins = 0      
local display5MinMined = 0      
local estPerHour = 0            
local celestiumMined = 0        
local voidsteelMined = 0        
local aetheriteMined = 0
local rubyMined = 0
local runTime = 0 
local history5min = {}          

local RuneNames = {"Basic", "Super", "Advanced", "Cosmic Prism", "Hacker", "Snowy", "Deepcore"}
local GemNames = {"All", "Coal", "Iron", "Sliver", "Gold", "Platinum", "Titanium", "Emerald", "Diamond", "Opal", "Jade", "Amber", "Topaz", "Ruby", "Amethyst", "Quartz", "Sapphire", "Uranium", "Crystal", "Obsidian"}

local RuneSettings = {}
for _, name in ipairs(RuneNames) do RuneSettings[name] = false end

local GemsToExchange = {}
local GemsSelectedMap = {}

local saveFileName = "p1_Rebirth_Storage.json"
local presetFileName = "p1_GUI_Presets.json"

local function saveSettings()
    local data = {
        SqaysConfig = env.SqaysConfig,
        Settings = Settings,
        RuneSettings = RuneSettings,
        GemsSelectedMap = GemsSelectedMap
    }
    pcall(function() if writefile then writefile(saveFileName, HttpService:JSONEncode(data)) end end)
end

local function loadSettings()
    pcall(function()
        if readfile and isfile and isfile(saveFileName) then
            local raw = readfile(saveFileName)
            local data = HttpService:JSONDecode(raw)
            if data then
                if data.SqaysConfig then for k, v in pairs(data.SqaysConfig) do env.SqaysConfig[k] = v end end
                if data.Settings then for k, v in pairs(data.Settings) do Settings[k] = v end end
                if data.RuneSettings then for k, v in pairs(data.RuneSettings) do RuneSettings[k] = v end end
                if data.GemsSelectedMap then for k, v in pairs(data.GemsSelectedMap) do GemsSelectedMap[k] = v end end
            end
        end
    end)
end

loadSettings()

local function rebuildGemsToExchangeList()
    table.clear(GemsToExchange)
    for gName, isSelected in pairs(GemsSelectedMap) do if isSelected then table.insert(GemsToExchange, gName) end end
end
rebuildGemsToExchangeList()

local function syncGlobals()
    _G.MiningSpeed = env.SqaysConfig.MiningSpeed
    _G.TierSpeed = env.SqaysConfig.TierSpeed
    _G.RuneSpeed = env.SqaysConfig.RuneSpeed
    _G.TreeSpeed = env.SqaysConfig.TreeSpeed
    _G.WaterPumpSpeed = env.SqaysConfig.WaterPumpSpeed
    _G.IceConvertSpeed = env.SqaysConfig.IceConvertSpeed
    _G.AshConvertSpeed = env.SqaysConfig.AshConvertSpeed
    _G.BlazeQuestSpeed = env.SqaysConfig.BlazeQuestSpeed
    _G.ExchangeGemsSpeed = env.SqaysConfig.ExchangeGemsSpeed
    _G.AutoRollTier = env.SqaysConfig.AutoRollTier
    _G.AutoHitTree = env.SqaysConfig.AutoHitTree
    _G.AutoWaterPump = env.SqaysConfig.AutoWaterPump
    _G.AutoBlazeQuest = env.SqaysConfig.AutoBlazeQuest
    _G.AutoConvertWoodToAsh = env.SqaysConfig.AutoConvertWoodToAsh
    _G.AutoExchangeGems = env.SqaysConfig.AutoExchangeGems
    _G.AutoRollRunes = env.SqaysConfig.AutoRollRunes
    _G.AntiAFK = env.SqaysConfig.AntiAFK
end
syncGlobals()

local master_routes = {
    ["Voidsteel + Celestium + Aetherite + Ruby Loop"] = {
        {name = "Voidsteel_1", pos = Vector3.new(699.21, 7.74, 2827.68)},
        {name = "Voidsteel_2", pos = Vector3.new(683.25, 7.74, 2858.61)},
        {name = "Voidsteel_3", pos = Vector3.new(705.66, 7.74, 2852.43)},
        {name = "Voidsteel_4", pos = Vector3.new(723.42, 7.74, 2874.51)},
        {name = "Voidsteel_5", pos = Vector3.new(727.90, 7.74, 2836.23)},
        {name = "Celestium_4", pos = Vector3.new(725.19, 7.87, 2804.33)},
        {name = "Celestium_5", pos = Vector3.new(730.71, 7.87, 2780.08)}, 
        {name = "Celestium_3", pos = Vector3.new(713.99, 7.87, 2764.92)}, 
        {name = "Celestium_2", pos = Vector3.new(687.15, 7.87, 2772.15)},
        {name = "Celestium_1", pos = Vector3.new(692.65, 7.87, 2799.67)},
        {name = "Aetherite_5", pos = Vector3.new(659.25, 7.34, 2783.24)},
        {name = "Aetherite_4", pos = Vector3.new(645.36, 7.34, 2760.03)},
        {name = "Aetherite_3", pos = Vector3.new(611.97, 7.34, 2769.11)},
        {name = "Aetherite_2", pos = Vector3.new(593.95, 7.34, 2790.59)},
        {name = "Aetherite_1", pos = Vector3.new(628.22, 7.34, 2793.83)},
        {name = "Ruby_4", pos = Vector3.new(621.25, 9.18, 2840.62)},
        {name = "Ruby_1", pos = Vector3.new(598.23, 9.18, 2856.87)},
        {name = "Ruby_2", pos = Vector3.new(616.18, 9.72, 2871.34)},
        {name = "Ruby_3", pos = Vector3.new(641.74, 9.18, 2870.04)},
        {name = "Ruby_5", pos = Vector3.new(652.05, 9.18, 2845.19)}
    },
    ["Voidsteel + Celestium Loop"] = {
        {name = "Celestium_4", pos = Vector3.new(725.19, 7.87, 2804.33)},
        {name = "Celestium_5", pos = Vector3.new(730.71, 7.87, 2780.08)}, 
        {name = "Celestium_3", pos = Vector3.new(713.99, 7.87, 2764.92)}, 
        {name = "Celestium_2", pos = Vector3.new(687.15, 7.87, 2772.15)},
        {name = "Celestium_1", pos = Vector3.new(692.65, 7.87, 2799.67)},
        {name = "Voidsteel_1", pos = Vector3.new(699.21, 7.74, 2827.68)},
        {name = "Voidsteel_2", pos = Vector3.new(683.25, 7.74, 2858.61)},
        {name = "Voidsteel_4", pos = Vector3.new(723.42, 7.74, 2874.51)},
        {name = "Voidsteel_3", pos = Vector3.new(705.66, 7.74, 2852.43)},
        {name = "Voidsteel_5", pos = Vector3.new(727.90, 7.74, 2836.23)}
    }
}

-- === SYSTEMY ANALITYKI I WEBHOOKÓW ===
local function getTrendData()
    local currentHourMined = totalMined - (history5min[#history5min - 12] or history5min[1] or 0)
    local prevHourMined = (history5min[#history5min - 12] or 0) - (history5min[#history5min - 24] or 0)
    local trendText = "0%"
    if prevHourMined > 0 then
        local diff = currentHourMined - prevHourMined
        local pct = (diff / prevHourMined) * 100
        trendText = string.format("%.1f%%", pct)
        if diff > 0 then trendText = "+" .. trendText end
    elseif currentHourMined > 0 and prevHourMined == 0 then trendText = "+100% 📈" end
    return trendText
end

local function dispatchStatsWebhook()
    if not request then return end
    if not looping then return end 
    
    local hours = math.floor(runTime / 3600)
    local minutes = math.floor((runTime % 3600) / 60)
    local trend = getTrendData()

    local payload = {
        embeds = {{
            title = "⚡ p1 Engine Core - Analytics Broadcast",
            color = 16724636, 
            fields = {
                {name = "⏳ Runtime", value = string.format("`%dh %dm`", hours, minutes), inline = true},
                {name = "🔋 Total Mined", value = string.format("`%d ores`", totalMined), inline = true},
                {name = "📈 Efficiency Rate", value = string.format("`%d /h`", estPerHour), inline = true},
                {name = "⏱️ Last 5 Mins", value = string.format("`%d ores`", display5MinMined), inline = true},
                {name = "📊 Hourly Trend", value = string.format("`%s`", trend), inline = true},
                {name = "💎 Celestium", value = string.format("`%d`", celestiumMined), inline = true},
                {name = "💜 Voidsteel", value = string.format("`%d`", voidsteelMined), inline = true},
                {name = "💙 Aetherite", value = string.format("`%d`", aetheriteMined), inline = true},
                {name = "❤️ Ruby", value = string.format("`%d`", rubyMined), inline = true}
            },
            footer = { text = "p1 v3.3" },
            timestamp = DateTime.now():ToIsoDate()
        }}
    }
    pcall(function()
        request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

local function getMainRemote() return ReplicatedStorage:FindFirstChild("__Net") and ReplicatedStorage.__Net:FindFirstChild("MainRemote") end

-- === STRUCTURAL MOVEMENT CONTROLS ===
local NoclipConnection, AxisLockConnection, fixedY
local function noclip()
    Settings.UseNoclip = true
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")
    fixedY = hrp.Position.Y
    humanoid.JumpPower = 0
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

    if not NoclipConnection then
        NoclipConnection = RunService.Stepped:Connect(function()
            if Settings.UseNoclip and player.Character ~= nil then
                for _, v in pairs(player.Character:GetDescendants()) do
                    if v:IsA('BasePart') and v.CanCollide then v.CanCollide = false end
                end
            end
        end)
    end
    if not AxisLockConnection then
        AxisLockConnection = RunService.Heartbeat:Connect(function()
            if Settings.UseNoclip and character and hrp and humanoid then
                humanoid.Jump = false
                local currentPos = hrp.Position
                if math.abs(currentPos.Y - fixedY) > 0.5 then 
                    hrp.CFrame = CFrame.new(Vector3.new(currentPos.X, fixedY, currentPos.Z)) * hrp.CFrame.Rotation 
                end
                hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
            end
        end)
    end
end

local function clip()
    Settings.UseNoclip = false
    if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil end
    if AxisLockConnection then AxisLockConnection:Disconnect(); AxisLockConnection = nil end
    local character = player.Character
    if character and character:FindFirstChildOfClass("Humanoid") then
        character:FindFirstChildOfClass("Humanoid").JumpPower = 50
        character:FindFirstChildOfClass("Humanoid"):SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
    end
end

if Settings.UseNoclip then task.spawn(noclip) end

local antiIdleConnection = nil
local function setAntiIdle(enabled)
    env.SqaysConfig.AntiAFK = enabled; _G.AntiAFK = enabled
    if antiIdleConnection then antiIdleConnection:Disconnect(); antiIdleConnection = nil end
    if not enabled then return end
    antiIdleConnection = player.Idled:Connect(function()
        if scriptRunning then
            pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
        end
    end)
end
setAntiIdle(env.SqaysConfig.AntiAFK)

local cachedFrame = nil
local function applyTextOutlines()
    pcall(function()
        if not cachedFrame then
            local coreGui = (gethui and gethui()) or game:GetService("CoreGui")
            for _, child in ipairs(coreGui:GetChildren()) do
                if child:IsA("ScreenGui") then
                    for _, desc in ipairs(child:GetDescendants()) do
                        if desc:IsA("TextLabel") and (desc.Text == "p1" or desc.Text == "p1 v3.3") then
                            local current = desc
                            while current.Parent and current.Parent ~= child do
                                current = current.Parent
                            end
                            if current:IsA("Frame") or current:IsA("CanvasGroup") then
                                cachedFrame = current
                                break
                            end
                        end
                    end
                end
                if cachedFrame then break end
            end
        end
        
        if cachedFrame then
            for _, desc in ipairs(cachedFrame:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text ~= "" then
                    if not desc:FindFirstChild("p1_UIOutline") then
                        local stroke = Instance.new("UIStroke")
                        stroke.Name = "p1_UIOutline"
                        stroke.Color = Color3.fromRGB(10, 10, 10)
                        stroke.Thickness = 1.1
                        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
                        stroke.Parent = desc
                    end
                end
            end
        end
    end)
end

-- === HIBRYDOWY SYSTEM RUCHU ===
local function moveToPointAntiSlip(targetPos, hrp)
    if env.SqaysConfig.MovementMethod == "Teleport" then
        hrp.CFrame = CFrame.new(Vector3.new(targetPos.X, hrp.Position.Y, targetPos.Z)) * hrp.CFrame.Rotation
        hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
        return
    end

    local speed = Settings.CustomWalkSpeed
    local humanoid = hrp.Parent:FindFirstChildOfClass("Humanoid")
    
    if humanoid then humanoid.AutoRotate = false end
    hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)

    while scriptRunning do
        if not looping or env.SqaysConfig.MovementMethod == "Teleport" then break end
        
        local currentPos = hrp.Position
        local diff = Vector3.new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)
        local distance = diff.Magnitude
        
        local deltaTime = RunService.Heartbeat:Wait()
        local step = speed * deltaTime
        
        if distance <= step or distance < 1.2 then
            hrp.CFrame = CFrame.new(Vector3.new(targetPos.X, currentPos.Y, targetPos.Z)) * hrp.CFrame.Rotation
            hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
            break
        end
        
        local newPos = currentPos + (diff.Unit * step)
        hrp.CFrame = CFrame.lookAt(newPos, Vector3.new(targetPos.X, currentPos.Y, targetPos.Z))
    end

    if humanoid then humanoid.AutoRotate = true end
end

-- === ZINTEGROWANE PĘTLE ULEPSZEŃ (UPGRADES LOOPS) ===
task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoUpgradeNoob then
            local MainRemote = getMainRemote()
            if MainRemote then
                for _, noobType in ipairs(env.SqaysConfig.SelectedNoobUpgrades) do
                    pcall(function()
                        MainRemote:FireServer(table.unpack({
                            [1] = "UpgradeNoobMax",
                            [2] = noobType,
                        }))
                    end)
                end
            end
            task.wait(env.SqaysConfig.UpgradeNoobSpeed)
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoUpgradeGems then
            local MainRemote = getMainRemote()
            if MainRemote then
                for _, gemType in ipairs(env.SqaysConfig.SelectedGemUpgrades) do
                    pcall(function()
                        MainRemote:FireServer(table.unpack({
                            [1] = "UpgradeUpgrade",
                            [2] = "Gem",
                            [3] = gemType,
                        }))
                    end)
                end
            end
            task.wait(env.SqaysConfig.UpgradeGemsSpeed)
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoUpgradePlanks then
            local MainRemote = getMainRemote()
            if MainRemote then
                for _, plankType in ipairs(env.SqaysConfig.SelectedPlankUpgrades) do
                    pcall(function()
                        MainRemote:FireServer(table.unpack({
                            [1] = "UpgradeUpgrade",
                            [2] = "Planks",
                            [3] = plankType,
                        }))
                    end)
                end
            end
            task.wait(env.SqaysConfig.UpgradePlanksSpeed)
        else
            task.wait(0.1)
        end
    end
end)

task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoUpgradeWater then
            local MainRemote = getMainRemote()
            if MainRemote then
                for _, waterType in ipairs(env.SqaysConfig.SelectedWaterUpgrades) do
                    pcall(function()
                        MainRemote:FireServer(table.unpack({
                            [1] = "UpgradeUpgrade",
                            [2] = "Water",
                            [3] = waterType,
                        }))
                    end)
                end
            end
            task.wait(env.SqaysConfig.UpgradeWaterSpeed)
        else
            task.wait(0.1)
        end
    end
end)

-- === CONTEXTUAL LOOPS SYSTEMS ===
task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoRollTier then
            local MainRemote = getMainRemote()
            if MainRemote then MainRemote:FireServer("RollTier") end
        end
        task.wait(env.SqaysConfig.TierSpeed)
    end
end)

task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoRollRunes then
            local MainRemote = getMainRemote()
            if MainRemote then
                for _, name in ipairs(RuneNames) do
                    if RuneSettings[name] and scriptRunning then 
                        MainRemote:FireServer("RollRune", name) 
                    end
                end
            end
        end
        task.wait(env.SqaysConfig.RuneSpeed)
    end
end)

task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoHitTree then
            local MainRemote = getMainRemote()
            if MainRemote and player:FindFirstChild("FEATURES") and player.FEATURES:FindFirstChild("TREE") and player.FEATURES.TREE:FindFirstChild("IsSpawned") and player.FEATURES.TREE.IsSpawned.Value then 
                MainRemote:FireServer("HitTree") 
            end
        end
        task.wait(env.SqaysConfig.TreeSpeed)
    end
end)

task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoWaterPump then
            local MainRemote = getMainRemote()
            if MainRemote then MainRemote:FireServer("GainWater") end
        end
        task.wait(env.SqaysConfig.WaterPumpSpeed)
    end
end)

task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoBlazeQuest then
            local MainRemote = getMainRemote()
            if MainRemote then 
                MainRemote:FireServer("SetUpgradeAutomationPaused", "Fire", false) 
                MainRemote:FireServer("Blaze") 
            end
        end
        task.wait(env.SqaysConfig.BlazeQuestSpeed)
    end
end)

task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoConvertWoodToAsh then
            local MainRemote = getMainRemote()
            if MainRemote then MainRemote:FireServer("ConvertWoodToAsh") end
        end
        task.wait(env.SqaysConfig.AshConvertSpeed)
    end
end)

task.spawn(function()
    while scriptRunning do
        local currentLvl = env.SqaysConfig.SelectedIceLevel or 0
        if currentLvl > 0 then 
            pcall(function()
                local MainRemote = getMainRemote()
                if MainRemote then MainRemote:FireServer("PressButton", currentLvl) end 
            end)
        end
        task.wait(env.SqaysConfig.IceConvertSpeed)
    end
end)

task.spawn(function()
    while scriptRunning do
        if env.SqaysConfig.AutoExchangeGems then
            pcall(function()
                local MainRemote = getMainRemote()
                if MainRemote and #GemsToExchange > 0 then 
                    for _, gem in ipairs(GemsToExchange) do 
                        if not env.SqaysConfig.AutoExchangeGems or not scriptRunning then break end 
                        if gem == "All" then MainRemote:FireServer("ExchangeAllMinerals"); break end 
                        local amt = 0 
                        local currencies = player:FindFirstChild("CURRENCIES") 
                        local folder = currencies and currencies:FindFirstChild(gem) 
                        local amountFolder = folder and folder:FindFirstChild("Amount") 
                        local v = amountFolder and amountFolder:FindFirstChild("1") 
                        if v then amt = tonumber(v.Value) or 0 end 
                        if amt > 0 then MainRemote:FireServer("ExchangeMineral", gem) end 
                    end
                end
            end)
        end
        task.wait(env.SqaysConfig.ExchangeGemsSpeed)
    end
end)

local runTimer = 0
task.spawn(function()
    while scriptRunning do
        task.wait(1)
        if looping then
            runTime = runTime + 1 
            runTimer = runTimer + 1
            if runTimer >= 300 then 
                display5MinMined = minedInLast5Mins; minedInLast5Mins = 0 
                table.insert(history5min, totalMined) 
                if #history5min > 25 then table.remove(history5min, 1) end 
                dispatchStatsWebhook()
                runTimer = 0
            end
        end
    end
end)

-- === MAIN DISTRIBUTOR ROUTER ===
task.spawn(function()
    while scriptRunning do
        if looping then
            local mode = env.SqaysConfig.MiningTarget or "Voidsteel + Celestium + Aetherite + Ruby Loop"
            local activeRoute = master_routes[mode]
            
            if activeRoute then
                for _, target in ipairs(activeRoute) do
                    if not looping or not scriptRunning then break end
                    
                    local char = player.Character or player.CharacterAdded:Wait() 
                    local hrp = char:WaitForChild("HumanoidRootPart", 5) 
                    if hrp then
                        moveToPointAntiSlip(target.pos, hrp)
                        if not scriptRunning then break end
                        totalMined = totalMined + 1 
                        minedInLast5Mins = minedInLast5Mins + 1 
                        
                        if string.find(target.name, "Celestium") then celestiumMined = celestiumMined + 1 
                        elseif string.find(target.name, "Voidsteel") then voidsteelMined = voidsteelMined + 1  
                        elseif string.find(target.name, "Aetherite") then aetheriteMined = aetheriteMined + 1
                        elseif string.find(target.name, "Ruby") then rubyMined = rubyMined + 1 end
                        
                        task.wait(Settings.WaitTimeOnOre) 
                    end
                end
            else
                task.wait(0.5) 
            end
        else
            task.wait(0.1) 
        end
    end
end)

-- ========================================================
-- HIGH-END FLUENT UI INTERFACE DESIGN "p1 v3.3"
-- ========================================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))() 

local Window = Fluent:CreateWindow({
    Title = "p1 v3.3",
    SubTitle = "Rebirth Engine",
    TabWidth = 120, 
    Size = UDim2.fromOffset(580, 380),
    Acrylic = Settings.UIAcrylic,  
    Theme = Settings.UITheme, 
    MinimizeKey = Enum.KeyCode.N 
})

local Tabs = {
    Mining = Window:AddTab({ Title = "Mining", Icon = "gem" }),  
    Auto = Window:AddTab({ Title = "Automation", Icon = "bot" }), 
    Upgrades = Window:AddTab({ Title = "Upgrades", Icon = "trending-up" }),
    Customize = Window:AddTab({ Title = "Customize", Icon = "palette" }), 
    SettingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

Window:SelectTab(1) 

-- ================== MINING TAB ==================
Tabs.Mining:AddSection("Sequence Control") 

local ExecuteToggle = Tabs.Mining:AddToggle("ExecSeq", {Title = "Execute Sequence", Default = false}) 
ExecuteToggle:OnChanged(function(Value) looping = Value end) 

local dropOptions = {} 
for name, _ in pairs(master_routes) do table.insert(dropOptions, name) end 
table.sort(dropOptions, function(a, b) 
    if a == "Voidsteel + Celestium + Aetherite + Ruby Loop" then return true end
    if b == "Voidsteel + Celestium + Aetherite + Ruby Loop" then return false end
    return a < b
end)

local OreTargetDropdown = Tabs.Mining:AddDropdown("OreSelect", { 
    Title = "Ore Selection", 
    Description = "Choose automated structure path.", 
    Values = dropOptions, 
    Multi = false, 
    Default = env.SqaysConfig.MiningTarget or "Voidsteel + Celestium + Aetherite + Ruby Loop" 
})
OreTargetDropdown:OnChanged(function(Value) 
    env.SqaysConfig.MiningTarget = Value 
    saveSettings() 
end)

local MoveMethodDropdown = Tabs.Mining:AddDropdown("MoveMethod", {
    Title = "Movement Method",
    Description = "Choose between walking or direct teleportation.",
    Values = {"Walking", "Teleport"},
    Multi = false,
    Default = env.SqaysConfig.MovementMethod
})
MoveMethodDropdown:OnChanged(function(Value)
    env.SqaysConfig.MovementMethod = Value
    saveSettings()
end)

local WalkSpeedInput = Tabs.Mining:AddInput("WalkSpeedInput", { 
    Title = "WalkSpeed [16 - 350]", 
    Default = tostring(Settings.CustomWalkSpeed), 
    Placeholder = "Wpisz wartość (bazowo 160)...", 
    Numeric = true, 
    Finished = true 
})
WalkSpeedInput:OnChanged(function(Value) 
    local num = tonumber(Value) 
    if num then 
        num = math.clamp(num, 16, 350) 
        Settings.CustomWalkSpeed = num 
        local char = player.Character 
        local hum = char and char:FindFirstChildOfClass("Humanoid") 
        if hum then hum.WalkSpeed = num end 
        saveSettings() 
    end
end)

local OreBreakInput = Tabs.Mining:AddInput("OreWaitInput", { 
    Title = "Ore Break (s) [0.20 - 3.0]", 
    Default = tostring(Settings.WaitTimeOnOre), 
    Placeholder = "Wpisz wartość (bazowo 0.50)...", 
    Numeric = true, 
    Finished = true 
})
OreBreakInput:OnChanged(function(Value) 
    local num = tonumber(Value) 
    if num then 
        num = math.clamp(num, 0.20, 3.0) 
        Settings.WaitTimeOnOre = num 
        saveSettings() 
    end
end)

Tabs.Mining:AddSection("Telemetry") 
local TelemetryPara = Tabs.Mining:AddParagraph({ 
    Title = "Stats (v3.3)", Content = "Waiting for execution..."
})

-- NAPRAWIONO: Bezpieczna pętla odświeżania statystyk bez zakleszczeń GUI
task.spawn(function()
    while scriptRunning do
        task.wait(1)
        if runTime > 0 then estPerHour = math.floor((totalMined / runTime) * 3600) end 
        local hours = math.floor(runTime / 3600) 
        local minutes = math.floor((runTime % 3600) / 60) 
        local trend = getTrendData() 
        local statusText = looping and "🟢 ACTIVE" or "🔴 PAUSED" 

        TelemetryPara:SetDesc(string.format(
            "Status: %s\n⏱️ Last 5m: %d | 📈 Rate: %d/h\n🔋 Mined: %d | ⏳ Uptime: %dh %dm\n📊 Trend: %s\n💎 Celestium: %d | 💜 Voidsteel: %d\n💙 Aetherite: %d | ❤️ Ruby: %d",
            statusText, display5MinMined, estPerHour, totalMined, hours, minutes, trend, celestiumMined, voidsteelMined, aetheriteMined, rubyMined
        ))
        applyTextOutlines()
    end
end)

Tabs.Mining:AddSection("Ore Exchange") 
local AutoExchToggle = Tabs.Mining:AddToggle("AutoExch", {Title = "Auto Exchange", Default = env.SqaysConfig.AutoExchangeGems}) 
AutoExchToggle:OnChanged(function(Value) env.SqaysConfig.AutoExchangeGems = Value; syncGlobals(); saveSettings() end) 

local defGems = {} 
for k, v in pairs(GemsSelectedMap) do if v then table.insert(defGems, k) end end 

local GemDropdown = Tabs.Mining:AddDropdown("GemsDrop", {Title = "Minerals", Values = GemNames, Multi = true, Default = defGems}) 
GemDropdown:OnChanged(function(Value) 
    table.clear(GemsSelectedMap) 
    for k, v in pairs(Value) do 
        if type(k) == "string" and v == true then 
            GemsSelectedMap[k] = true 
        elseif type(v) == "string" then 
            GemsSelectedMap[v] = true 
        end
    end
    rebuildGemsToExchangeList() 
    saveSettings() 
end)

local GemExchIntervalInput = Tabs.Mining:AddInput("GemExchIntervalInput", { 
    Title = "Exchange Interval (s) [5 - 60]", 
    Default = tostring(env.SqaysConfig.ExchangeGemsSpeed), 
    Placeholder = "Wpisz wartość (bazowo 10)...", 
    Numeric = true, 
    Finished = true 
})
GemExchIntervalInput:OnChanged(function(Value) 
    local num = tonumber(Value) 
    if num then 
        num = math.clamp(num, 5, 60) 
        env.SqaysConfig.ExchangeGemsSpeed = num 
        syncGlobals() 
        saveSettings() 
    end
end)

-- ================== AUTOMATION TAB ==================
Tabs.Auto:AddSection("Runes") 
local AutoRuneToggle = Tabs.Auto:AddToggle("AutoRune", {Title = "Auto Roll Runes", Default = env.SqaysConfig.AutoRollRunes}) 
AutoRuneToggle:OnChanged(function(Value) env.SqaysConfig.AutoRollRunes = Value; syncGlobals(); saveSettings() end) 

local defRunes = {} 
for k, v in pairs(RuneSettings) do if v then table.insert(defRunes, k) end end 

local RuneDropdown = Tabs.Auto:AddDropdown("RunesDrop", {Title = "Runes Selected", Values = RuneNames, Multi = true, Default = defRunes}) 
RuneDropdown:OnChanged(function(Value) 
    table.clear(RuneSettings) 
    for k, v in pairs(Value) do 
        if type(k) == "string" and v == true then 
            RuneSettings[k] = true 
        elseif type(v) == "string" then 
            RuneSettings[v] = true 
        end
    end
    saveSettings() 
end)

local RuneIntervalInput = Tabs.Auto:AddInput("RuneIntervalInput", { 
    Title = "Rune Interval (s) [0.001 - 2.0]", 
    Default = tostring(env.SqaysConfig.RuneSpeed), 
    Placeholder = "Wpisz wartość (bazowo 0.50)...", 
    Numeric = true, 
    Finished = true 
})
RuneIntervalInput:OnChanged(function(Value) 
    local num = tonumber(Value) 
    if num then 
        num = math.clamp(num, 0.001, 2.0) 
        env.SqaysConfig.RuneSpeed = num 
        syncGlobals() 
        saveSettings() 
    end
end)

Tabs.Auto:AddSection("World Automation") 
local TierToggle = Tabs.Auto:AddToggle("AutoTier", {Title = "Auto Roll Tier", Default = env.SqaysConfig.AutoRollTier}) 
TierToggle:OnChanged(function(Value) env.SqaysConfig.AutoRollTier = Value; syncGlobals(); saveSettings() end) 

local TierSpeedInput = Tabs.Auto:AddInput("TierSpeedInput", { 
    Title = "Tier Speed (s) [0.001 - 2.0]", 
    Default = tostring(env.SqaysConfig.TierSpeed), 
    Placeholder = "Wpisz wartość (bazowo 0.50)...", 
    Numeric = true, 
    Finished = true 
})
TierSpeedInput:OnChanged(function(Value) 
    local num = tonumber(Value) 
    if num then 
        num = math.clamp(num, 0.001, 2.0) 
        env.SqaysConfig.TierSpeed = num 
        syncGlobals() 
        saveSettings() 
    end
end)

local TreeToggle = Tabs.Auto:AddToggle("AutoTree", {Title = "Auto Hit Tree", Default = env.SqaysConfig.AutoHitTree}) 
TreeToggle:OnChanged(function(Value) env.SqaysConfig.AutoHitTree = Value; syncGlobals(); saveSettings() end) 

local TreeSpeedInput = Tabs.Auto:AddInput("TreeSpeedInput", { 
    Title = "Tree Speed (s) [0.001 - 2.0]", 
    Default = tostring(env.SqaysConfig.TreeSpeed), 
    Placeholder = "Wpisz wartość (bazowo 0.50)...", 
    Numeric = true, 
    Finished = true 
})
TreeSpeedInput:OnChanged(function(Value) 
    local num = tonumber(Value) 
    if num then 
        num = math.clamp(num, 0.001, 2.0) 
        env.SqaysConfig.TreeSpeed = num 
        saveSettings() 
    end
end)

local PumpToggle = Tabs.Auto:AddToggle("AutoPump", {Title = "Auto Water Pump", Default = env.SqaysConfig.AutoWaterPump}) 
PumpToggle:OnChanged(function(Value) env.SqaysConfig.AutoWaterPump = Value; syncGlobals(); saveSettings() end) 

local PumpSpeedInput = Tabs.Auto:AddInput("PumpSpeedInput", { 
    Title = "Pump Speed (s) [0.001 - 2.0]", 
    Default = tostring(env.SqaysConfig.WaterPumpSpeed), 
    Placeholder = "Wpisz wartość (bazowo 0.50)...", 
    Numeric = true, 
    Finished = true 
})
PumpSpeedInput:OnChanged(function(Value) 
    local num = tonumber(Value) 
    if num then 
        num = math.clamp(num, 0.001, 2.0) 
        env.SqaysConfig.WaterPumpSpeed = num 
        saveSettings() 
    end
end)

Tabs.Auto:AddSection("Processing") 
local QuestToggle = Tabs.Auto:AddToggle("AutoQuest", {Title = "Auto Quest (Blaze)", Default = env.SqaysConfig.AutoBlazeQuest}) 
QuestToggle:OnChanged(function(Value) env.SqaysConfig.AutoBlazeQuest = Value; syncGlobals(); saveSettings() end) 

local QuestSpeedInput = Tabs.Auto:AddInput("QuestSpeedInput", { 
    Title = "Quest Speed (s) [1.0 - 10.0]", 
    Default = tostring(env.SqaysConfig.BlazeQuestSpeed), 
    Placeholder = "Wpisz wartość (bazowo 5)...", 
    Numeric = true, 
    Finished = true 
})
QuestSpeedInput:OnChanged(function(Value)  
    local num = tonumber(Value) 
    if num then 
        num = math.clamp(num, 1.0, 10.0) 
        env.SqaysConfig.BlazeQuestSpeed = num 
        syncGlobals() 
        saveSettings() 
    end
end)

local AshToggle = Tabs.Auto:AddToggle("AutoAsh", {Title = "Auto Wood to Ash", Default = env.SqaysConfig.AutoConvertWoodToAsh}) 
AshToggle:OnChanged(function(Value) env.SqaysConfig.AutoConvertWoodToAsh = Value; syncGlobals(); saveSettings() end) 

local AshSpeedInput = Tabs.Auto:AddInput("AshSpeedInput", { 
    Title = "Ash Speed (s) [0.001 - 5.0]", 
    Default = tostring(env.SqaysConfig.AshConvertSpeed), 
    Placeholder = "Wpisz wartość (bazowo 1)...", 
    Numeric = true, 
    Finished = true 
})
AshSpeedInput:OnChanged(function(Value) 
    local num = tonumber(Value) 
    if num then 
        num = math.clamp(num, 0.001, 5.0) 
        env.SqaysConfig.AshConvertSpeed = num 
        syncGlobals() 
        saveSettings() 
    end
end)

local IceDropdown = Tabs.Auto:AddDropdown("IceDrop", {Title = "Auto Ice Convert", Values = iceOpts, Multi = false, Default = currentIceText}) 
IceDropdown:OnChanged(function(Value) 
    if Value == "None" then env.SqaysConfig.SelectedIceLevel = 0 else env.SqaysConfig.SelectedIceLevel = tonumber(string.match(Value, "%d+")) end 
    saveSettings() 
end)

local IceSpeedInput = Tabs.Auto:AddInput("IceSpeedInput", { 
    Title = "Ice Speed (s) [0.001 - 2.0]", 
    Default = tostring(env.SqaysConfig.IceConvertSpeed), 
    Placeholder = "Wpisz wartość (bazowo 0.50)...", 
    Numeric = true, 
    Finished = true 
})
IceSpeedInput:OnChanged(function(Value) 
    local num = tonumber(Value) 
    if num then 
        num = math.clamp(num, 0.001, 2.0) 
        env.SqaysConfig.IceConvertSpeed = num 
        saveSettings() 
    end
end)

-- ================== UPGRADES TAB (NAPRAWIONE UNIKALNE ID) ==================
Tabs.Upgrades:AddSection("Noob Upgrades")

local AutoNoobTog = Tabs.Upgrades:AddToggle("U_AutoNoob", {Title = "Auto Upgrade Noobs", Default = env.SqaysConfig.AutoUpgradeNoob})
AutoNoobTog:OnChanged(function(Value) env.SqaysConfig.AutoUpgradeNoob = Value; saveSettings() end)

local NoobDrop = Tabs.Upgrades:AddDropdown("U_NoobTypes", {
    Title = "Select Noob Types",
    Values = {"Fisherman", "Knight", "Explorer", "Magician"},
    Multi = true,
    Default = env.SqaysConfig.SelectedNoobUpgrades or {}
})
NoobDrop:OnChanged(function(Value)
    table.clear(env.SqaysConfig.SelectedNoobUpgrades)
    for k, v in pairs(Value) do
        if type(k) == "string" and v == true then table.insert(env.SqaysConfig.SelectedNoobUpgrades, k)
        elseif type(v) == "string" then table.insert(env.SqaysConfig.SelectedNoobUpgrades, v) end
    end
    saveSettings()
end)

local NoobSpeedInput = Tabs.Upgrades:AddInput("U_NoobSpeed", {
    Title = "Upgrade Speed (s)",
    Default = tostring(env.SqaysConfig.UpgradeNoobSpeed),
    Placeholder = "Wpisz interwał w sekundach...",
    Numeric = true,
    Finished = true
})
NoobSpeedInput:OnChanged(function(Value)
    local num = tonumber(Value)
    if num then env.SqaysConfig.UpgradeNoobSpeed = math.max(num, 0.001); saveSettings() end
end)

Tabs.Upgrades:AddSection("Upgrades With Gems")

local AutoGemUpgradeTog = Tabs.Upgrades:AddToggle("U_AutoGemUpgrade", {Title = "Auto Upgrade Gems", Default = env.SqaysConfig.AutoUpgradeGems})
AutoGemUpgradeTog:OnChanged(function(Value) env.SqaysConfig.AutoUpgradeGems = Value; saveSettings() end)

local GemUpgradeDrop = Tabs.Upgrades:AddDropdown("U_GemUpgrades", {
    Title = "Select Gem Upgrades",
    Values = {"MoreGems", "MoreOreStats", "MoreOof"},
    Multi = true,
    Default = env.SqaysConfig.SelectedGemUpgrades or {}
})
GemUpgradeDrop:OnChanged(function(Value)
    table.clear(env.SqaysConfig.SelectedGemUpgrades)
    for k, v in pairs(Value) do
        if type(k) == "string" and v == true then table.insert(env.SqaysConfig.SelectedGemUpgrades, k)
        elseif type(v) == "string" then table.insert(env.SqaysConfig.SelectedGemUpgrades, v) end
    end
    saveSettings()
end)

local GemSpeedInput = Tabs.Upgrades:AddInput("U_GemUpgradeSpeed", {
    Title = "Upgrade Speed (s)",
    Default = tostring(env.SqaysConfig.UpgradeGemsSpeed),
    Placeholder = "Wpisz interwał w sekundach...",
    Numeric = true,
    Finished = true
})
GemSpeedInput:OnChanged(function(Value)
    local num = tonumber(Value)
    if num then env.SqaysConfig.UpgradeGemsSpeed = math.max(num, 0.001); saveSettings() end
end)

Tabs.Upgrades:AddSection("Upgrades With Planks")

local AutoPlankUpgradeTog = Tabs.Upgrades:AddToggle("U_AutoPlankUpgrade", {Title = "Auto Upgrade Planks", Default = env.SqaysConfig.AutoUpgradePlanks})
AutoPlankUpgradeTog:OnChanged(function(Value) env.SqaysConfig.AutoUpgradePlanks = Value; saveSettings() end)

local PlankUpgradeDrop = Tabs.Upgrades:AddDropdown("U_PlankUpgrades", {
    Title = "Select Plank Upgrades",
    Values = {"WaterFromPlanks", "MorePlanks"},
    Multi = true,
    Default = env.SqaysConfig.SelectedPlankUpgrades or {}
})
PlankUpgradeDrop:OnChanged(function(Value)
    table.clear(env.SqaysConfig.SelectedPlankUpgrades)
    for k, v in pairs(Value) do
        if type(k) == "string" and v == true then table.insert(env.SqaysConfig.SelectedPlankUpgrades, k)
        elseif type(v) == "string" then table.insert(env.SqaysConfig.SelectedPlankUpgrades, v) end
    end
    saveSettings()
end)

local PlankSpeedInput = Tabs.Upgrades:AddInput("U_PlankUpgradeSpeed", {
    Title = "Upgrade Speed (s)",
    Default = tostring(env.SqaysConfig.UpgradePlanksSpeed),
    Placeholder = "Wpisz interwał w sekundach...",
    Numeric = true,
    Finished = true
})
PlankSpeedInput:OnChanged(function(Value)
    local num = tonumber(Value)
    if num then env.SqaysConfig.UpgradePlanksSpeed = math.max(num, 0.001); saveSettings() end
end)

Tabs.Upgrades:AddSection("Upgrades With Water")

local AutoWaterUpgradeTog = Tabs.Upgrades:AddToggle("U_AutoWaterUpgrade", {Title = "Auto Upgrade Water", Default = env.SqaysConfig.AutoUpgradeWater})
AutoWaterUpgradeTog:OnChanged(function(Value) env.SqaysConfig.AutoUpgradeWater = Value; saveSettings() end)

local WaterUpgradeDrop = Tabs.Upgrades:AddDropdown("U_WaterUpgrades", {
    Title = "Select Water Upgrades",
    Values = {"MoreGems", "MorePlanks"},
    Multi = true,
    Default = env.SqaysConfig.SelectedWaterUpgrades or {}
})
WaterUpgradeDrop:OnChanged(function(Value)
    table.clear(env.SqaysConfig.SelectedWaterUpgrades)
    for k, v in pairs(Value) do
        if type(k) == "string" and v == true then table.insert(env.SqaysConfig.SelectedWaterUpgrades, k)
        elseif type(v) == "string" then table.insert(env.SqaysConfig.SelectedWaterUpgrades, v) end
    end
    saveSettings()
end)

local WaterSpeedInput = Tabs.Upgrades:AddInput("U_WaterUpgradeSpeed", {
    Title = "Upgrade Speed (s)",
    Default = tostring(env.SqaysConfig.UpgradeWaterSpeed),
    Placeholder = "Wpisz interwał w sekundach...",
    Numeric = true,
    Finished = true
})
WaterSpeedInput:OnChanged(function(Value)
    local num = tonumber(Value)
    if num then env.SqaysConfig.UpgradeWaterSpeed = math.max(num, 0.001); saveSettings() end
end)

-- ================== CUSTOMIZATION TAB (NAPRAWIONE) ==================
Tabs.Customize:AddSection("Visual Overhaul") 

local ThemeDropdown = Tabs.Customize:AddDropdown("C_ThemeDrop", { 
    Title = "UI Theme", 
    Values = {"Darker", "Dark", "Light", "Aqua", "Amethyst", "Rose"}, 
    Multi = false, 
    Default = Settings.UITheme, 
})
ThemeDropdown:OnChanged(function(Value) 
    Settings.UITheme = Value 
    Fluent:SetTheme(Value) 
    saveSettings() 
end)

local AcrylicToggle = Tabs.Customize:AddToggle("C_AcrylicTog", { 
    Title = "Enable Acrylic Blur",  
    Default = Settings.UIAcrylic 
})
AcrylicToggle:OnChanged(function(Value)  
    Settings.UIAcrylic = Value 
    saveSettings() 
end)

local AccentColorPicker = Tabs.Customize:AddColorpicker("C_AccentColor", { 
    Title = "Accent Color", 
    Default = Settings.UIAccentColor 
})
AccentColorPicker:OnChanged(function(Value) 
    Settings.UIAccentColor = Value 
    saveSettings() 
end)

Tabs.Customize:AddSection("Preset Management") 

local PresetInput = Tabs.Customize:AddInput("C_PresetName", { 
    Title = "Preset Name", 
    Default = "MyLayout", 
    Placeholder = "Enter preset name...", 
    Numeric = false, 
    Finished = false 
})

Tabs.Customize:AddButton({ 
    Title = "Save GUI Preset", 
    Description = "Saves current UI layout and colors to local storage.", 
    Callback = function() 
        local pName = PresetInput.Value 
        local presetData = {Theme = Settings.UITheme, Acrylic = Settings.UIAcrylic} 
        pcall(function()  
            if writefile then writefile(presetFileName, HttpService:JSONEncode(presetData)) end 
            Fluent:Notify({Title = "Preset Saved", Content = "Layout '"..pName.."' saved successfully.", Duration = 3}) 
        end)
    end
})

Tabs.Customize:AddButton({ 
    Title = "Load GUI Preset", 
    Description = "Restores UI layout from local storage.", 
    Callback = function() 
        pcall(function() 
            if readfile and isfile and isfile(presetFileName) then 
                local raw = readfile(presetFileName) 
                local pData = HttpService:JSONDecode(raw) 
                if pData then 
                    if pData.Theme then ThemeDropdown:SetValue(pData.Theme) end 
                    if pData.Acrylic ~= nil then AcrylicToggle:SetValue(pData.Acrylic) end 
                    Fluent:Notify({Title = "Preset Loaded", Content = "GUI layout restored.", Duration = 3}) 
                end
            end
        end)
    end
})

-- ================== SETTINGS TAB (NAPRAWIONE) ==================
Tabs.SettingsTab:AddSection("Security Controls")

local AFKToggle = Tabs.SettingsTab:AddToggle("S_AntiAFK", {Title = "Anti-AFK Shield", Default = env.SqaysConfig.AntiAFK}) 
AFKToggle:OnChanged(function(Value) setAntiIdle(Value); saveSettings() end) 

local GhostToggle = Tabs.SettingsTab:AddToggle("S_GhostMode", {Title = "Ghost Mode (Noclip)", Default = Settings.UseNoclip}) 
GhostToggle:OnChanged(function(Value) if Value then noclip() else clip() end; saveSettings() end) 

Tabs.SettingsTab:AddSection("Danger Zone") 

Tabs.SettingsTab:AddButton({ 
    Title = "Del Script", 
    Description = "Completely unloads script and GUI.", 
    Callback = function() 
        scriptRunning = false 
        looping = false 
        clip() 
        setAntiIdle(false) 
        
        for k, _ in pairs(env.SqaysConfig) do 
            if type(env.SqaysConfig[k]) == "boolean" then 
                env.SqaysConfig[k] = false 
            end
        end
        syncGlobals() 
        
        if Window then Window:Destroy() end 
    end
})

Fluent:Notify({
    Title = "p1 v3.3 (Custom GUI) Loaded",
    Content = "Press N to toggle GUI. Interface key conflicts resolved.",
    Duration = 5
})