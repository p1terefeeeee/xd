--[[
	TRIAL AUTO-FARM  •  V33 (Hard: sekwencyjna sciezka z Pivot/WorldPivot)
	- Combat: switch-on-animation (MobDeath = 112069791584815)
	- Combat: >20s bez zabicia -> pomin moba (combat NIGDY sam sie nie wylacza)
	- Anti-stuck w trialu: podbij Y o 1 gdy postac stoi >1s
	- Trial-end TP: przy 19:58 czekaj 3s -> Realm3 spawn (combat ON)
							lub 2s -> savedPosition (combat OFF)
	- Guzik "Usun zapisane kordynaty" w Ustawieniach
	- V29: wyjscie z triala (Leave) -> RUNNING->OPEN -> TP Realm 3 spawn
	- V30: detekcja po pozycji Leave (879,10,13443) + Realm3 spawn (1019,4,7801)
	       jednolita logika: pauza combat -> 2s -> TP Realm3 -> jesli combat OFF -> savedPos
	- V31: Timer2=59s -> auto-pause combat farm (odblokuj Y); po trialu na Realm3 -> auto-wznow
	- V32: combat bez auto-wylaczania, dokladne dopasowanie mobow (Pirate != Pirate Captain),
	       nizsze GUI + reczny resize (uchwyt), guzik "Ukryj GUI", brak TP gdy AutoFarm OFF
	- V33: HARD TRIAL - bieg po sciezce w podanej KOLEJNOSCI; kordynaty czytane w runtime
	       z Pivot > WorldPivot > Position; przycisk Trial przelacza Medium/Hard/Easy
]]

-- ===== SERVICES =====
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local CoreGui       = game:GetService("CoreGui")
local VirtualUser   = game:GetService("VirtualUser")
local HttpService   = game:GetService("HttpService")
local LogService    = game:GetService("LogService")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Lokalizacja gorących funkcji (mikro-optymalizacja + czytelność)
local Vector3_new   = Vector3.new
local CFrame_new    = CFrame.new
local fromRGB       = Color3.fromRGB
local UDim2_new     = UDim2.new
local tick          = tick
local Heartbeat     = RunService.Heartbeat

local player = Players.LocalPlayer

-- ===== KONFIG SKRYPTU =====
local webhookUrl = "https://discord.com/api/webhooks/1527716691599949874/yGNmiUbtq3bObMy2r9IHuICO4vv6KdelvDlSRM1rvv4x-7tn3MPjq-R84Pvkx1HQQQdj"
local animationIdToWait = "112069791584815"
local configFileName = "TrialAutoFarmConfig.json"

-- ===== CLEANUP =====
_G.TrialAutoFarmRunning = false
task.wait(0.2)

if CoreGui:FindFirstChild("TrialAutofarmGUI") then
	CoreGui.TrialAutofarmGUI:Destroy()
end

for _, v in ipairs(workspace:GetDescendants()) do
	if v:IsA("BillboardGui") and v.Name == "MobNumberTag" then
		v:Destroy()
	end
end

_G.TrialAutoFarmRunning = true

-- ===== CONFIG (zapisywalny) =====
local config = {
	Speed = 150,
	Cooldown = 0.08,
	WaveWaitTime = 2,
	SelectedTrial = "Medium",
	IsFarming = false,
	GhostModeY = 100,
	CombatGhostY = 100,
	TimeToStartSec = 15,
	AutoChestType = "None",
	CombatTweenSpeed = 0.3,
	SelectedMobs = {}
}

local savedPosition = nil

local function LoadConfig()
	if not (isfile and isfile(configFileName)) then return end
	pcall(function()
		local decoded = HttpService:JSONDecode(readfile(configFileName))
		if not decoded then return end
		config.Speed           = decoded.Speed or config.Speed
		config.Cooldown        = decoded.Cooldown or config.Cooldown
		config.WaveWaitTime    = decoded.WaveWaitTime or config.WaveWaitTime
		config.SelectedTrial   = decoded.SelectedTrial or config.SelectedTrial
		config.GhostModeY      = decoded.GhostModeY or config.GhostModeY
		config.CombatGhostY    = decoded.CombatGhostY or config.CombatGhostY
		config.TimeToStartSec  = decoded.TimeToStartSec or config.TimeToStartSec
		config.AutoChestType   = decoded.AutoChestType or "None"
		config.CombatTweenSpeed = decoded.CombatTweenSpeed or config.CombatTweenSpeed
		config.SelectedMobs    = decoded.SelectedMobs or config.SelectedMobs
		if type(decoded.SavedPosition) == "table" and #decoded.SavedPosition >= 12 then
			pcall(function() savedPosition = CFrame_new(table.unpack(decoded.SavedPosition)) end)
		end
	end)
end

local function SaveConfig()
	if not writefile then return end
	pcall(function()
		writefile(configFileName, HttpService:JSONEncode({
			Speed = config.Speed,
			Cooldown = config.Cooldown,
			WaveWaitTime = config.WaveWaitTime,
			SelectedTrial = config.SelectedTrial,
			GhostModeY = config.GhostModeY,
			CombatGhostY = config.CombatGhostY,
			TimeToStartSec = config.TimeToStartSec,
			AutoChestType = config.AutoChestType,
			CombatTweenSpeed = config.CombatTweenSpeed,
			SelectedMobs = config.SelectedMobs,
			SavedPosition = savedPosition and {savedPosition:GetComponents()} or nil
		}))
	end)
end

LoadConfig()

-- ===== STATE =====
local deadMobs = setmetatable({}, {__mode = "k"})
local ignoreList = {}

local pathOrder = {
	{Name = "1_Pirate_Left_Low",     Pos = Vector3_new(749, 11, 13635)},
	{Name = "2_Pirate_Left_High",    Pos = Vector3_new(723, 11, 13639)},
	{Name = "3_Ninja_Left_High",     Pos = Vector3_new(694, 11, 13634)},
	{Name = "4_Pirate_Captain_Top",  Pos = Vector3_new(667, 11, 13620)},
	{Name = "5_Ninja_Right_High",    Pos = Vector3_new(694, 11, 13606)},
	{Name = "6_Pirate_Right_Mid",    Pos = Vector3_new(723, 11, 13601)},
	{Name = "7_Pirate_Right_Low",    Pos = Vector3_new(749, 11, 13605)}
}

-- ===== V33: SEKWENCYJNA SCIEZKA HARD TRIALA =====
-- Kolejnosc krokow wskazana przez uzytkownika w:
--   workspace.__GAME_CONTENT.Trials.HardTrialRoom.Mobs
-- Selektor: {Index = n} -> Mobs:GetChildren()[n],  {Name = "X"} -> Mobs["X"].
-- UWAGA: pozycje NIE sa zapisane na stalo - czytamy je W RUNTIME z
--        Pivot > WorldPivot > Position (czyli slot:GetPivot().Position).
local hardPathOrder = {
	{Index = 5},
	{Name  = "Samurai"},
	{Name  = "Samurai Master"},
	{Name  = "Dark Commander"},
	{Index = 6},
	{Name  = "Samurai"},
	{Index = 4},
}

-- Aktualny krok sciezki Hard (1..#hardPathOrder)
local hardStepIndex = 1

local gridFolder = workspace:FindFirstChild("AutoFarm_GridConfig")
if not gridFolder then
	gridFolder = Instance.new("Folder")
	gridFolder.Name = "AutoFarm_GridConfig"
	gridFolder.Parent = workspace
end

for _, info in ipairs(pathOrder) do
	if not gridFolder:FindFirstChild(info.Name) then
		local part = Instance.new("Part")
		part.Name = info.Name
		part.Size = Vector3_new(3, 3, 3)
		part.Position = info.Pos
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 0.5
		part.Color = fromRGB(0, 255, 127)
		part.Parent = gridFolder
	end
end

local MOBS = {"Goblin","Skeleton","Orc","Pirate","Ninja","Warrior","Pirate Captain","Samurai","Pirate Admiral","Dark Commander","Samurai Master","Dark Knight","Ancient Boss"}

local combatConfig = {
	IsCombatFarming = false,
	CombatActiveTween = nil,
	LastMobName = nil,
	PausedForTrial = false,
	-- FIX: obsluga smierci postaci i limit dystansu
	MaxCombatDistance = 600,
	RecentDeathAt = 0,
	DeathCountShort = 0,
	PausedForRespawn = false,
	-- FIX: 15s -> TP Medium, 30s -> STOP combat
	StuckTeleported = false,
	StuckStopAt = 0
}

-- ===== WSPÓLNE HELPERY =====
-- Zwraca HumanoidRootPart gracza (lub nil)
local function GetHRP()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

-- Zwraca zewnętrzny model pokoju danego triala: __GAME_CONTENT.Trials.{Trial}TrialRoom
local function GetTrialRoom(trialName)
	local gc = workspace:FindFirstChild("__GAME_CONTENT")
	local trials = gc and gc:FindFirstChild("Trials")
	return trials and trials:FindFirstChild(trialName .. "TrialRoom")
end

local function GetMobPosition(mob)
	if not mob or not mob.Parent then return nil end

	-- STABILNA pozycja: NAJPIERW pojedyncza czesc-root (HumanoidRootPart/Torso/...),
	-- a NIE bounding box. Podczas respawnu model bywa "w trakcie skladania" (czesci
	-- w origin) i wtedy srodek bounding boxa wypada gdzies daleko -> gracz podchodzi
	-- w zle miejsce i "nie bije" moba. Pojedyncza czesc jest odporna na ten glitch.
	local part = mob:FindFirstChild("HumanoidRootPart")
		or mob:FindFirstChild("Torso")
		or mob:FindFirstChild("UpperTorso")
		or (mob:IsA("Model") and mob.PrimaryPart)
	if not part then
		local hum = mob:FindFirstChildOfClass("Humanoid")
		if hum and hum.RootPart then part = hum.RootPart end
	end
	if part and part:IsA("BasePart") then
		local p = part.Position
		if p == p and p.Magnitude > 1 then return p end -- odrzuca NaN oraz ~origin (respawn)
	end

	-- Fallback: srodek CALEGO modelu (bounding box), tez z odrzuceniem NaN/origin.
	if mob:IsA("Model") then
		local ok, cf = pcall(function() return (mob:GetBoundingBox()) end)
		if ok and cf then
			local pos = cf.Position
			if pos == pos and pos.Magnitude > 1 then return pos end -- odrzuca NaN oraz ~origin
		end
	end

	local ok, pivot = pcall(function() return mob:GetPivot() end)
	if ok and pivot and pivot.Position.Magnitude > 1 then return pivot.Position end

	for _, child in ipairs(mob:GetChildren()) do
		if child:IsA("BasePart") and child.Position.Magnitude > 1 then return child.Position end
	end

	return nil
end

-- ===== V33: HELPERY SCIEZKI HARD =====
-- Zamienia selektor sciezki na konkretny slot w folderze Mobs.
local function ResolvePathSlot(mobFolder, sel)
	if not mobFolder or not sel then return nil end
	if sel.Index then
		local kids = mobFolder:GetChildren()
		return kids[sel.Index]
	end
	if sel.Name then
		return mobFolder:FindFirstChild(sel.Name)
	end
	return nil
end

-- Pozycja slotu czytana DOKLADNIE tak jak w Explorerze: Pivot > WorldPivot > Position.
-- GetPivot() zwraca WorldPivot modelu, wiec .Position to szukane kordynaty.
local function GetSlotPivotPosition(slot)
	if not slot or not slot.Parent then return nil end

	local ok, pivot = pcall(function() return slot:GetPivot() end)
	if ok and pivot then
		local p = pivot.Position
		if p == p and p.Magnitude > 1 then return p end -- odrzuca NaN oraz ~origin
	end

	if slot:IsA("BasePart") then
		local p = slot.Position
		if p == p and p.Magnitude > 1 then return p end
	end

	-- Ostatnia deska ratunku: standardowa detekcja pozycji moba
	return GetMobPosition(slot)
end

-- Czy slot sciezki jest "zywy" (jest kogo bic)?
local function IsPathSlotAlive(slot)
	if not slot or not slot.Parent then return false end
	if deadMobs[slot] then return false end

	local hum = slot:FindFirstChildOfClass("Humanoid")
	if hum then return hum.Health > 0 end

	local char = slot:FindFirstChild("MobCharacter")
	if char then
		local h2 = char:FindFirstChildOfClass("Humanoid")
		if h2 then return h2.Health > 0 end
		return true
	end

	return slot:FindFirstChildWhichIsA("BasePart", true) ~= nil
end

local function GetClosestNodeIndex(mob)
	local mobPos = GetMobPosition(mob)
	if not mobPos then return nil end

	local closestIndex, shortestDist = nil, math.huge
	for id, info in ipairs(pathOrder) do
		local node = gridFolder:FindFirstChild(info.Name)
		if node then
			local dist = (node.Position - mobPos).Magnitude
			if dist < shortestDist then
				shortestDist = dist
				closestIndex = id
			end
		end
	end
	return closestIndex
end

local function UpdateMobTags(mobFolder)
	for _, mob in ipairs(mobFolder:GetChildren()) do
		if deadMobs[mob] then continue end

		local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso") or mob:FindFirstChild("UpperTorso") or mob
		if mobRoot and not mobRoot:FindFirstChild("MobNumberTag") then
			local nodeIndex = GetClosestNodeIndex(mob)
			if nodeIndex then
				pcall(function()
					local bgu = Instance.new("BillboardGui")
					bgu.Name = "MobNumberTag"
					bgu.Size = UDim2_new(0, 120, 0, 40)
					bgu.AlwaysOnTop = true
					bgu.StudsOffset = Vector3_new(0, 4, 0)
					bgu.Parent = mobRoot

					local tl = Instance.new("TextLabel")
					tl.Size = UDim2_new(1, 0, 1, 0)
					tl.BackgroundTransparency = 1
					tl.Text = "Krok [" .. nodeIndex .. "]"
					tl.TextColor3 = fromRGB(255, 230, 0)
					tl.TextStrokeTransparency = 0
					tl.TextStrokeColor3 = Color3.new(0, 0, 0)
					tl.Font = Enum.Font.GothamBold
					tl.TextSize = 20
					tl.Parent = bgu
				end)
			end
		end
	end
end

-- ===== TP LOKACJE + DETEKCJA TRIALU =====
local tpLocations = {
	Easy   = CFrame_new(853.2357788085938, 11.014291763305664, 13443.501953125),
	Medium = CFrame_new(878.9148559570312, 11.030077934265137, 13419.0625),
	Hard   = CFrame_new(905.1489868164062, 11.014291763305664, 13443.5712890625)
}

-- ===== REALM 3 SPAWN (docelowa pozycja po zakonczeniu trialu) =====
-- V30: Realm 3 spawn - dokladne kordynaty podane przez uzytkownika
local realm3SpawnCFrame = CFrame_new(1019, 4, 7801)

-- V30: Leave-zone (gdzie gra teleportuje po kliknieciu Leave w trialu).
-- Rozroznienie od kola wejscia Medium (878.91, 11.03, 13419.06):
--   Medium wejscie: X~878.9, Z=13419  (kolo do wejscia)
--   Leave landing:  X~879,   Z=13443  (24 study dalej po Z)
-- Uzywamy XZ-radius=15, wiec Medium wejscie NIE lapie sie w te strefe.
local LEAVE_ZONE = Vector3_new(879, 10, 13443)
local LEAVE_ZONE_XZ_RADIUS = 15
local LEAVE_ZONE_Y_TOL = 12

local function IsAtLeaveZone(hrp)
	if not hrp then return false end
	local p = hrp.Position
	local dx = p.X - LEAVE_ZONE.X
	local dy = p.Y - LEAVE_ZONE.Y
	local dz = p.Z - LEAVE_ZONE.Z
	if math.abs(dy) > LEAVE_ZONE_Y_TOL then return false end
	return (dx * dx + dz * dz) <= (LEAVE_ZONE_XZ_RADIUS * LEAVE_ZONE_XZ_RADIUS)
end

local function CheckIfInTrial()
	if not GetTrialRoom(config.SelectedTrial) then return false end
	local hrp = GetHRP()
	if not hrp then return false end
	local p = hrp.Position
	-- Blisko punktu wejscia (TP)
	local tp = tpLocations[config.SelectedTrial].Position
	if (Vector3_new(p.X, 0, p.Z) - Vector3_new(tp.X, 0, tp.Z)).Magnitude < 250 then
		return true
	end
	-- Albo blisko areny walki (dowolny wezel sciezki) - dzieki temu farm nie "wychodzi"
	-- z triala gdy podejdzie do mobow oddalonych od punktu TP.
	-- V33: stale wezly sciezki dotycza tylko Medium/Easy.
	-- Hard ma pozycje dynamiczne (z Pivot/WorldPivot), wiec go tu pomijamy,
	-- zeby arena Medium nie dawala falszywego "jestem w trialu".
	if config.SelectedTrial ~= "Hard" then
		for _, info in ipairs(pathOrder) do
			if (Vector3_new(p.X, 0, p.Z) - Vector3_new(info.Pos.X, 0, info.Pos.Z)).Magnitude < 140 then
				return true
			end
		end
	end
	-- Albo blisko DOWOLNEGO moba w tym trialu (uniwersalne dla kazdej areny)
	local room = GetTrialRoom(config.SelectedTrial)
	local mobs = room and room:FindFirstChild("Mobs")
	if mobs then
		for _, mob in ipairs(mobs:GetChildren()) do
			-- V33: pozycja z Pivot/WorldPivot -> dziala tez dla slotow Hard
			-- ktore nie maja wlasnego HumanoidRootPart.
			local mp = GetSlotPivotPosition(mob)
			if mp and (Vector3_new(p.X, 0, p.Z) - Vector3_new(mp.X, 0, mp.Z)).Magnitude < 160 then
				return true
			end
		end
	end
	return false
end

-- ===== GUI REFS =====
local farmBtnRef, singleTimerLabelRef, savedCoordsLabelRef, combatBtnRef, combatStatusLabelRef

-- ===== ANTI-AFK =====
local afkConn
local function antiAFK(on)
	if afkConn then afkConn:Disconnect(); afkConn = nil end
	if not on then return end
	afkConn = player.Idled:Connect(function()
		if _G.TrialAutoFarmRunning then
			pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)
		end
	end)
end
antiAFK(true)

-- ===== GHOST MODE =====
local NoclipConnection, AxisLockConnection
local isGhostMode = false
local ghostTargetY = config.GhostModeY

-- V28: SafeTeleport - TP na dowolna CFrame BEZ nadpisywania Y przez GhostMode.
-- Przed teleportem podnosimy ghostTargetY do Y celu, wykonujemy TP, potem
-- utrzymujemy Y przez ~holdSec sekund (Heartbeat co klatka "pilnuje" Y).
local function SafeTeleport(hrp, cframe, holdSec)
	if not hrp or not cframe then return end
	local targetY = cframe.Position.Y
	ghostTargetY = targetY -- wylacza natychmiastowy re-clamp GhostMode do 100
	pcall(function()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = cframe
	end)
	if holdSec and holdSec > 0 then
		task.spawn(function()
			local t0 = tick()
			while tick() - t0 < holdSec do
				ghostTargetY = targetY
				task.wait(0.05)
			end
		end)
	end
end

local function ToggleGhostMode(on, yOverride)
	if on then ghostTargetY = yOverride or config.GhostModeY end
	if isGhostMode == on then return end
	isGhostMode = on

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	if on then
		humanoid.JumpPower = 0
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
		end)

		if not NoclipConnection then
			NoclipConnection = RunService.Stepped:Connect(function()
				if isGhostMode and player.Character then
					for _, v in ipairs(player.Character:GetDescendants()) do
						if v:IsA('BasePart') and v.CanCollide then v.CanCollide = false end
					end
				end
			end)
		end

		if not AxisLockConnection then
			AxisLockConnection = Heartbeat:Connect(function()
				if isGhostMode and player.Character then
					local char = player.Character
					local h = char:FindFirstChildOfClass("Humanoid")
					local r = char:FindFirstChild("HumanoidRootPart")
					if h and r then
						h.Jump = false
						if math.abs(r.Position.Y - ghostTargetY) > 0.5 then
							r.CFrame = CFrame_new(Vector3_new(r.Position.X, ghostTargetY, r.Position.Z)) * r.CFrame.Rotation
						end
						r.AssemblyLinearVelocity = Vector3_new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z)
					end
				end
			end)
		end
	else
		if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil end
		if AxisLockConnection then AxisLockConnection:Disconnect(); AxisLockConnection = nil end
		humanoid.JumpPower = 50
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
		end)
	end
end

-- ===== DETEKCJA SMIERCI POSTACI =====
local function InstallDeathWatcher(character)
	if not character then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	hum.Died:Connect(function()
		if not combatConfig.IsCombatFarming then return end
		local now = tick()
		if now - combatConfig.RecentDeathAt < 20 then
			combatConfig.DeathCountShort = combatConfig.DeathCountShort + 1
		else
			combatConfig.DeathCountShort = 1
		end
		combatConfig.RecentDeathAt = now
		combatConfig.PausedForRespawn = true
		ToggleGhostMode(false)
		if combatStatusLabelRef then combatStatusLabelRef.Text = "Status: Smierc - pauza 4s" end
		task.delay(4, function() combatConfig.PausedForRespawn = false end)
		if combatConfig.DeathCountShort >= 2 and ToggleCombatFarming then
			task.defer(function() ToggleCombatFarming(false) end)
		end
	end)
end
InstallDeathWatcher(player.Character)
player.CharacterAdded:Connect(function(char)
	task.wait(0.2)
	InstallDeathWatcher(char)
end)

-- ===== CUSTOM MOVEMENT (Trial) =====
-- FIX: anti-stuck. Jesli postac stoi w miejscu >1s (XZ nie zmienia sie o >0.5),
-- podbijamy Y o 1, po chwili wracamy do bazowego Y (config.GhostModeY albo aktualne).
local function moveToPoint(targetPos, hrp)
	local speed = config.Speed
	local humanoid = hrp.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.AutoRotate = false end

	local lastXZ = Vector3_new(hrp.Position.X, 0, hrp.Position.Z)
	local lastMoveAt = tick()
	local baseY = hrp.Position.Y -- Y z ustawien / aktualnego ghost target
	local bumped = false
	local bumpedAt = 0

	while (config.IsFarming or combatConfig.IsCombatFarming) and _G.TrialAutoFarmRunning do
		if not hrp or not hrp.Parent or (humanoid and humanoid.Health <= 0) then break end

		local currentPos = hrp.Position
		local diff = Vector3_new(targetPos.X - currentPos.X, 0, targetPos.Z - currentPos.Z)
		local distance = diff.Magnitude
		local step = speed * Heartbeat:Wait()

		hrp.AssemblyLinearVelocity = Vector3.zero

		-- ANTI-STUCK: sprawdz czy XZ sie zmienilo
		local curXZ = Vector3_new(currentPos.X, 0, currentPos.Z)
		if (curXZ - lastXZ).Magnitude > 0.5 then
			lastXZ = curXZ
			lastMoveAt = tick()
			if not bumped then baseY = currentPos.Y end -- zapamietaj Y z ustawien
		else
			if not bumped and tick() - lastMoveAt > 1 and distance > 0.4 then
				-- STOI >1s -> podbij Y o 1
				bumped = true
				bumpedAt = tick()
				pcall(function()
					hrp.CFrame = CFrame.new(currentPos.X, baseY + 1, currentPos.Z) * (hrp.CFrame - hrp.CFrame.Position)
				end)
			elseif bumped and tick() - bumpedAt > 0.35 then
				-- Wracamy do bazowego Y
				bumped = false
				lastMoveAt = tick()
				lastXZ = Vector3_new(hrp.Position.X, 0, hrp.Position.Z)
				pcall(function()
					hrp.CFrame = CFrame.new(hrp.Position.X, baseY, hrp.Position.Z) * (hrp.CFrame - hrp.CFrame.Position)
				end)
			end
		end

		if distance <= step or distance <= 0.4 then
			hrp.CFrame = CFrame.lookAt(currentPos, Vector3_new(targetPos.X, currentPos.Y, targetPos.Z))
			if humanoid then humanoid:Move(Vector3.zero) end
			break
		end

		local newPos = currentPos + (diff.Unit * step)
		hrp.CFrame = CFrame.lookAt(newPos, Vector3_new(targetPos.X, currentPos.Y, targetPos.Z))
	end
	if humanoid then humanoid.AutoRotate = true end
end

-- ===== WEBHOOKS =====
local httpRequest = (syn and syn.request) or (http and http.request) or request
local function SendWebhook(message, isError)
	if isError then warn("[TRIAL AUTO] " .. tostring(message)) else print("[TRIAL AUTO] " .. tostring(message)) end
	if not httpRequest then return end
	local prefix = isError and "\226\157\140 **[ERROR]**\n" or "\226\156\133 **[LOG]**\n"
	pcall(function()
		httpRequest({
			Url = webhookUrl, Method = "POST",
			Headers = {["Content-Type"] = "application/json"},
			Body = HttpService:JSONEncode({["content"] = prefix .. "`\n" .. tostring(message) .. "\n`", ["username"] = "Trial Auto-Script"})
		})
	end)
end

local lastConsoleErrorTime = 0
local ignoredConsolePatterns = { "invocation queue exhausted", "OnClientEvent", "MineralGained", "Com_CoinExchange", "ProductAmount" }
local consoleConnection = LogService.MessageOut:Connect(function(message, messageType)
	if not _G.TrialAutoFarmRunning then return end
	if messageType == Enum.MessageType.MessageError then
		for _, pat in ipairs(ignoredConsolePatterns) do
			if string.find(message, pat, 1, true) then return end
		end
		if tick() - lastConsoleErrorTime > 5 then
			lastConsoleErrorTime = tick()
			SendWebhook("Blad konsoli gry:\n" .. message, true)
		end
	end
end)

-- Drena kolejke RemoteEventow wysylanych bez klienckiego handlera (np. __Net.MineralGained)
task.spawn(function()
	pcall(function()
		local net = ReplicatedStorage:FindFirstChild("__Net")
		if not net then return end
		for _, remoteName in ipairs({"MineralGained"}) do
			local ev = net:FindFirstChild(remoteName)
			if ev and ev:IsA("RemoteEvent") then ev.OnClientEvent:Connect(function() end) end
		end
	end)
end)

-- ===== TRIAL AUTOFARM (ścieżka) =====
local function GetMobFolder(trialName)
	local room = GetTrialRoom(trialName)
	return room and room:FindFirstChild("Mobs")
end

local function GetTargetMob(mobFolder)
	UpdateMobTags(mobFolder)

	-- Wczytujemy pozycje WSZYSTKICH zywych mobow i wybieramy NAJBLIZSZEGO do gracza.
	-- Kolejne zabijanie najblizszych = najoptymalniejsza trasa (nearest-neighbor).
	local hrp = GetHRP()
	local origin = hrp and hrp.Position or Vector3.zero

	local bestMob, bestPos, bestDist = nil, nil, math.huge
	for _, mob in ipairs(mobFolder:GetChildren()) do
		if not deadMobs[mob] and not (ignoreList[mob] and tick() < ignoreList[mob]) then
			local hum = mob:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health <= 0 then
				deadMobs[mob] = true
			else
				local pos = GetMobPosition(mob)
				if pos then
					local d = (Vector3_new(pos.X, 0, pos.Z) - Vector3_new(origin.X, 0, origin.Z)).Magnitude
					if d < bestDist then
						bestDist, bestMob, bestPos = d, mob, pos
					end
				end
			end
		end
	end

	return bestMob, bestPos
end

-- ===== V33: CEL DLA HARD - SCISLE PO KOLEJNOSCI hardPathOrder =====
-- Idziemy krok po kroku. Jesli dany krok jest juz zabity / nie istnieje /
-- jest w cooldownie, przechodzimy do nastepnego (bez blokowania petli).
local function GetHardSequentialTarget(mobFolder)
	local total = #hardPathOrder
	if total == 0 then return nil, nil end

	for _ = 1, total do
		if hardStepIndex < 1 or hardStepIndex > total then hardStepIndex = 1 end

		local sel  = hardPathOrder[hardStepIndex]
		local slot = ResolvePathSlot(mobFolder, sel)

		if IsPathSlotAlive(slot) and not (ignoreList[slot] and tick() < ignoreList[slot]) then
			local pos = GetSlotPivotPosition(slot)
			if pos then
				return slot, pos
			end
		end

		hardStepIndex += 1 -- ten krok odpada -> nastepny w kolejnosci
	end

	return nil, nil
end

local function WaitForDeathAnimation(mob)
	local animPlayed = false
	local connection
	local animationCore = mob:FindFirstChildOfClass("Humanoid") or mob:FindFirstChildOfClass("AnimationController")

	if not animationCore then
		for _, desc in ipairs(mob:GetDescendants()) do
			if desc:IsA("Humanoid") or desc:IsA("AnimationController") then animationCore = desc break end
		end
	end

	local animator = animationCore and animationCore:FindFirstChildOfClass("Animator")
	if animator then
		connection = animator.AnimationPlayed:Connect(function(animTrack)
			pcall(function()
				if animTrack and animTrack.Animation and animTrack.Animation.AnimationId and string.match(animTrack.Animation.AnimationId, animationIdToWait) then
					animPlayed = true
				end
			end)
		end)
	end

	local t = tick()
	while not animPlayed and mob and mob.Parent and (tick() - t < 15) and config.IsFarming and _G.TrialAutoFarmRunning do
		local hum = mob:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health <= 0 then animPlayed = true break end

		local root = GetHRP()
		local mobPos = GetMobPosition(mob)
		if root and mobPos and (Vector3_new(mobPos.X, 0, mobPos.Z) - Vector3_new(root.Position.X, 0, root.Position.Z)).Magnitude > 1.0 then
			moveToPoint(mobPos, root)
		end
		Heartbeat:Wait()
	end

	if connection then connection:Disconnect() end
	return animPlayed or not (mob and mob.Parent)
end

local function ToggleFarming(state)
	config.IsFarming = state
	if not config.IsFarming then
		if farmBtnRef then farmBtnRef.Text = "\226\150\182 Start AutoFarm"; farmBtnRef.BackgroundColor3 = fromRGB(46, 204, 113) end
		ToggleGhostMode(false)
		local hrp = GetHRP()
		if hrp then hrp.Anchored = false end
		return
	end

	if farmBtnRef then farmBtnRef.Text = "\226\143\184 Zatrzymaj AutoFarm"; farmBtnRef.BackgroundColor3 = fromRGB(230, 126, 34) end
	SendWebhook("Rozpoczeto nowa sciezke kordynatow: " .. config.SelectedTrial, false)

	hardStepIndex = 1 -- V33: start farmu -> sciezka Hard od kroku 1

	task.spawn(function()
		local killedMobsCount = 0
		while config.IsFarming and _G.TrialAutoFarmRunning do
			local ok = pcall(function()
				if not CheckIfInTrial() then
					task.wait(0.5)
					return
				end

				local char = player.Character or player.CharacterAdded:Wait()
				local root = char:WaitForChild("HumanoidRootPart")
				local mobFolder = GetMobFolder(config.SelectedTrial)

				if not mobFolder then
					ToggleGhostMode(false)
					task.wait(0.5)
					return
				end

				-- V33: Hard -> sekwencyjnie po hardPathOrder (Pivot/WorldPivot).
				--      Medium/Easy -> jak dotad: najblizszy mob (nearest-neighbor).
				local targetMob, targetMobPos
				if config.SelectedTrial == "Hard" then
					targetMob, targetMobPos = GetHardSequentialTarget(mobFolder)
				else
					targetMob, targetMobPos = GetTargetMob(mobFolder)
				end

				if not targetMob or not targetMobPos then
					ToggleGhostMode(false)
					task.wait(config.WaveWaitTime)
					killedMobsCount = 0
					deadMobs = setmetatable({}, {__mode = "k"})
					ignoreList = {}
					hardStepIndex = 1 -- nowa fala -> sciezka Hard od poczatku
					return
				end

				ToggleGhostMode(true)
				moveToPoint(targetMobPos, root)
				if not config.IsFarming or not _G.TrialAutoFarmRunning then return end

				if WaitForDeathAnimation(targetMob) then
					deadMobs[targetMob] = true
					killedMobsCount += 1
					hardStepIndex += 1 -- V33: kolejny krok sciezki Hard
					if killedMobsCount >= #hardPathOrder then
						ToggleGhostMode(false)
						task.wait(config.WaveWaitTime)
						killedMobsCount = 0
						deadMobs = setmetatable({}, {__mode = "k"})
						ignoreList = {}
						hardStepIndex = 1
					else
						task.wait(config.Cooldown)
					end
				else
					ignoreList[targetMob] = tick() + 4
					hardStepIndex += 1 -- V33: nieudany krok nie blokuje sciezki
				end
			end)
			if not ok then task.wait(0.5) end
			task.wait(0.02)
		end
	end)
end

-- =========================================================================
-- ===== SYSTEM TIMERÓW / STATUSÓW  (NAPRAWIONE)  =========================
-- =========================================================================
-- Etykiety (TextLabel) w BillboardGui na TouchPart pokoju triala:
--   Timer1   -> "The trial opens in Xm Ys..."                  (ZAMKNIETY)
--   Timer2   -> "The trial is open, you have X seconds ..."    (OTWARTY / okno wejscia)
--   IsActive -> "The trial has been running for ...!"          (TRWA)
-- Format czasu w grze: "%dm %ds" oraz "%d seconds".

local function ParseTimerSeconds(text)
	if not text then return -1 end
	-- "Xm Ys"
	local m, s = string.match(text, "(%d+)%s*m%s*(%d+)%s*s")
	if m then return tonumber(m) * 60 + tonumber(s) end
	-- "MM:SS" (np. 19:59)
	local cm, cs = string.match(text, "(%d+):(%d+)")
	if cm then return tonumber(cm) * 60 + tonumber(cs) end
	-- "X seconds" / "X second"
	local secWord = string.match(text, "(%d+)%s*seconds?")
	if secWord then return tonumber(secWord) end
	-- "Xs"
	local secShort = string.match(text, "(%d+)%s*s")
	if secShort then return tonumber(secShort) end
	return -1
end

local function GetWorkspaceBillboardGui()
	local room = GetTrialRoom(config.SelectedTrial)
	if not room then return nil end
	local innerRoom = room:FindFirstChild("__Trial" .. config.SelectedTrial .. "Room")
	local touchPart = innerRoom and innerRoom:FindFirstChild("TouchPart")
	return touchPart and touchPart:FindFirstChild("BillboardGui")
end

-- Zwraca (label, tekst) dla nazwanej etykiety w BillboardGui
local function ReadLabel(bg, name)
	if not bg then return nil, nil end
	local lbl = bg:FindFirstChild(name)
	if lbl and lbl:IsA("TextLabel") then
		local txt = lbl.ContentText
		if txt == nil or txt == "" then txt = lbl.Text end
		return lbl, txt
	end
	return nil, nil
end

local ToggleCombatFarming

-- V31: flaga czy combat byl auto-paused przy 59s Timer2
-- true  = byl wlaczony recznie i skrypt go zatrzymal przed trialem
-- false = byl juz wylaczony (nie wznawiamy automatycznie)
local combatPausedForJoin = false

-- V31: sprawdza czy gracz jest przy Realm 3 spawn (1019, 4, 7801)
local function IsAtRealm3Spawn(hrp)
	if not hrp then return false end
	local p = hrp.Position
	local r = realm3SpawnCFrame.Position
	local dx = p.X - r.X
	local dz = p.Z - r.Z
	return (dx * dx + dz * dz) <= (25 * 25)
end

-- ===== V30/V31: HANDLE TRIAL EXIT (jednolita logika Leave + trial-end) =====
-- Sekwencja:
--   1. Natychmiast pauzuj gonienie mobow triala (PausedForTrial=true).
--   2. Odczekaj 2s.
--   3. TP na Realm 3 spawn (1019, 4, 7801).
--   4a. Jesli combat byl auto-paused (V31) -> wznow combat farm, odblokuj PausedForTrial.
--   4b. Jesli combat byl recznie OFF i mamy savedPosition -> po 1s TP na savedPosition.
--   4c. Jesli combat byl recznie ON -> odblokuj PausedForTrial (lapie Realm3 moby).
--   5. Reset debounce po 5s (na kolejny cykl).
local trialExitHandled = false
local function HandleTrialExit(reason)
	if trialExitHandled then return end
	trialExitHandled = true
	task.spawn(function()
		SendWebhook("Wyjscie z triala (" .. tostring(reason) .. ") -> TP Realm 3 za 2s", false)
		-- 1. Pauzuj gonienie mobow z triala + anuluj aktywny tween combatu
		combatConfig.PausedForTrial = true
		if combatConfig.CombatActiveTween then
			pcall(function() combatConfig.CombatActiveTween:Cancel() end)
			combatConfig.CombatActiveTween = nil
		end
		-- 2. Odczekaj 2s
		task.wait(2)
		-- 3. TP na Realm 3 spawn
		local hrp = GetHRP()
		if hrp then
			SafeTeleport(hrp, realm3SpawnCFrame, 3)
		end
		task.wait(0.5) -- czekaj az SafeTeleport sie ustabilizuje
		-- 4. Rozgalezienie
		local hrpCheck = GetHRP()
		if combatPausedForJoin then
			-- 4a: Combat byl auto-paused przy 59s -> wznow na Realm 3
			combatPausedForJoin = false
			if hrpCheck and IsAtRealm3Spawn(hrpCheck) then
				ToggleCombatFarming(true)
				SendWebhook("Combat farm auto-wznowiony na Realm 3 spawn", false)
			else
				-- gracz nie jest na Realm3 (cos poszlo nie tak) - wznow mimo to
				ToggleCombatFarming(true)
				SendWebhook("Combat farm auto-wznowiony (poza Realm3)", false)
			end
			combatConfig.PausedForTrial = false
		elseif not combatConfig.IsCombatFarming then
			-- 4b: Combat byl recznie wylaczony -> TP na zapisana pozycje
			if savedPosition then
				task.wait(1)
				local hrp2 = GetHRP()
				if hrp2 then
					SafeTeleport(hrp2, savedPosition, 3)
					SendWebhook("Combat farm OFF -> TP na zapisana pozycje", false)
				end
			else
				SendWebhook("Combat farm OFF, brak savedPosition - pozostaje na Realm 3", false)
			end
			combatConfig.PausedForTrial = false
		else
			-- 4c: Combat byl recznie wlaczony -> kontynuuj przy Realm 3
			SendWebhook("Combat farm ON -> kontynuacja przy Realm 3 mobach", false)
			combatConfig.PausedForTrial = false
		end
		-- 5. Reset debounce po 5s
		task.wait(5)
		trialExitHandled = false
	end)
end

-- ===== V30: POSITION-BASED LEAVE DETECTION =====
-- Petla sprawdza pozycje HRP co 0.4s. Gdy gracz wyladuje w Leave-zone
-- (~879, 10, 13443) - po kliknieciu Leave w trialu - odpala HandleTrialExit.
-- Detekcja pozycyjna dziala nawet gdy stan GUI nie zmieni sie od razu.
task.spawn(function()
	while _G.TrialAutoFarmRunning do
		pcall(function()
			if not trialExitHandled then
				local hrp = GetHRP()
				if config.IsFarming and hrp and IsAtLeaveZone(hrp) then
					HandleTrialExit("leave-zone-position")
				end
			end
		end)
		task.wait(0.4)
	end
end)

task.spawn(function()
	local teleportDebounce = false   -- teleport do triala tylko raz na cykl
	local trialWasActive   = false   -- true gdy trial TRWA (RUNNING); powrot po jego zakonczeniu
	local joinArmed        = false   -- true dopiero gdy odliczanie bylo POWYZEJ progu
	local returnedThisCycle = false  -- powrot na zapisana pozycje tylko raz na cykl
	local prevState        = nil     -- poprzedni stan (do wykrycia przejscia -> CLOSED)
	local endTeleported    = false   -- V26: debounce dla trial-end TP (raz na cykl)

	while _G.TrialAutoFarmRunning do
		pcall(function()
			local bg = GetWorkspaceBillboardGui()
			local t1Lbl, t1Text = ReadLabel(bg, "Timer1")
			local t2Lbl, t2Text = ReadLabel(bg, "Timer2")
			local iaLbl, iaText = ReadLabel(bg, "IsActive")

			-- Stan wg widocznej etykiety (z fallbackiem na sensowny tekst bez "...")
			local state, displayText
			if t2Lbl and t2Lbl.Visible then
				state, displayText = "OPEN", t2Text
			elseif iaLbl and iaLbl.Visible then
				state, displayText = "RUNNING", iaText
			elseif t1Lbl and t1Lbl.Visible then
				state, displayText = "CLOSED", t1Text
			elseif t2Text and t2Text ~= "" and not string.find(t2Text, "%.%.%.") then
				state, displayText = "OPEN", t2Text
			elseif iaText and iaText ~= "" and not string.find(iaText, "%.%.%.") then
				state, displayText = "RUNNING", iaText
			else
				state, displayText = "CLOSED", t1Text
			end

			if singleTimerLabelRef and displayText and displayText ~= "" then
				singleTimerLabelRef.Text = displayText
			end

			-- FIX V32: cala automatyka triala (teleport do portalu, auto-pauza
			-- combatu, powrot po trialu) dziala TYLKO gdy AutoFarm jest wlaczony.
			-- Gdy AutoFarm OFF -> aktualizujemy tylko etykiete, gracza NIE ruszamy.
			if not config.IsFarming then
				prevState = state
				return
			end

			if state == "CLOSED" then
				-- Trial sie WLASNIE zamknal (RUNNING/OPEN -> CLOSED).
				-- V30: uzywamy HandleTrialExit dla jednolitej logiki (jak przy Leave).
				if not returnedThisCycle and prevState ~= nil and prevState ~= "CLOSED" then
					returnedThisCycle = true
					trialWasActive = false
					HandleTrialExit("trial-end-closed")
				end
				teleportDebounce = false
				joinArmed = false
				endTeleported = false -- reset debounce dla nastepnego cyklu
				-- combatPausedForJoin resetowany jest wewnatrz HandleTrialExit
				-- combatConfig.PausedForTrial resetowany jest wewnatrz HandleTrialExit

			elseif state == "OPEN" then
				returnedThisCycle = false
				local secLeft = ParseTimerSeconds(displayText)

				-- V31: Auto-pause combat farm przy Timer2 = 59s.
				-- Cel: wylaczyc GhostMode Y-lock zanim gracz teleportuje sie do triala,
				-- zeby CFrame z zewnetrznego skryptu lub SafeTeleport dzialal poprawnie
				-- (bez konfliktu z AxisLockConnection na Y=100 powodujacego lad pod ziemia).
				if secLeft > 0 and secLeft <= 59 and not combatPausedForJoin
					and combatConfig.IsCombatFarming then
					combatPausedForJoin = true
					ToggleGhostMode(false)          -- odblokuj Y natychmiast
					ToggleCombatFarming(false)      -- zatrzymaj combat loop
					SetCombatStatus("Status: Auto-pause przed trialem (59s)")
					SendWebhook("Timer2 <= 59s -> auto-pause combat farm, Y odblokowany", false)
				end

				-- Uzbrajamy dopiero gdy licznik jest POWYZEJ progu.
				-- Dzieki temu teleport NIE odpala od razu po otwarciu,
				-- tylko gdy odliczanie zejdzie do <= TimeToStartSec.
				if secLeft > config.TimeToStartSec then
					joinArmed = true
				end

				if joinArmed and secLeft > 0 and secLeft <= config.TimeToStartSec
					and not teleportDebounce and not CheckIfInTrial() then
					teleportDebounce = true
					combatConfig.PausedForTrial = true

					if combatConfig.CombatActiveTween then
						pcall(function() combatConfig.CombatActiveTween:Cancel() end)
						combatConfig.CombatActiveTween = nil
					end

					local hrp = GetHRP()
					if hrp then
						SafeTeleport(hrp, tpLocations[config.SelectedTrial], 2)
						SendWebhook("Teleport do triala (" .. secLeft .. "s do konca okna wejscia)", false)
					end
				end

			elseif state == "RUNNING" then
				-- Trial TRWA: nie teleportujemy nigdzie, focus na trialu.
				returnedThisCycle = false
				trialWasActive = true
				combatConfig.PausedForTrial = true

				-- V30: TRIAL-END TP (early trigger przy 19:58, przed CLOSED).
				-- Uzywamy HandleTrialExit dla jednolitej logiki.
				if not endTeleported then
					local secElapsed = ParseTimerSeconds(displayText) or 0
					local textHit = displayText and string.find(displayText, "19:58", 1, true) ~= nil
					if textHit or secElapsed >= (19 * 60 + 58) then
						endTeleported = true
						HandleTrialExit("trial-end-19:58")
					end
				end
			end

			prevState = state
		end)
		task.wait(0.5)
	end
end)

-- ===== AUTO CHEST LOOP =====
local chestLoopRunning = false
local function OpenChestLoop()
	if chestLoopRunning then return end
	chestLoopRunning = true
	task.spawn(function()
		while config.AutoChestType ~= "None" and _G.TrialAutoFarmRunning do
			pcall(function()
				local chestName = (config.AutoChestType == "T2") and "T2TrialChest" or "T1TrialChest"
				ReplicatedStorage.__Net.MainRemote:FireServer("OpenChest", chestName, 7)

				local gui = player:FindFirstChild("PlayerGui")
				local fs = gui and gui:FindFirstChild("FullScreen")
				local popups = fs and fs:FindFirstChild("Popups")
				if popups then
					for _, child in ipairs(popups:GetChildren()) do
						local n = string.lower(child.Name)
						if string.match(n, "chest") or string.match(n, "reward") then
							child:Destroy()
						end
					end
				end
			end)
			task.wait(0.5)
		end
		chestLoopRunning = false
	end)
end

if config.AutoChestType ~= "None" then OpenChestLoop() end

-- ===== COMBAT FARM SYSTEM =====
-- Kazdy wpis w __GAME_CONTENT.Mobs to "slot". Zywy mob to slot.MobCharacter.
-- Gdy MobCharacter zniknie = mob zabity i respi sie (potem MobCharacter wraca).
local function GetMobCharacter(slot)
	if not slot or not slot.Parent then return nil end
	return slot:FindFirstChild("MobCharacter")
end

local function IsMobAlive(mob)
	if not mob or not mob.Parent then return false end
	local char = mob:FindFirstChild("MobCharacter")
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then return hum.Health > 0 end
		return true
	end
	-- Fallback dla struktur bez MobCharacter
	local hum = mob:FindFirstChildOfClass("Humanoid")
	if hum then return hum.Health > 0 end
	return false
end

-- Stabilna pozycja moba dla combatu: pojedyncza czesc (root), NIE bounding box.
-- Podczas respawnu model bywa "w trakcie skladania" (czesci w origin) i wtedy
-- srodek bounding boxa wypada gdzies daleko -> stad losowe teleporty w dal.
local function GetCombatMobPosition(char)
	if not char or not char.Parent then return nil end
	local part = char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("UpperTorso")
		or (char:IsA("Model") and char.PrimaryPart)
		or nil
	if not part then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.RootPart then part = hum.RootPart end
	end
	if part and part:IsA("BasePart") then
		local p = part.Position
		if p == p and p.Magnitude > 1 then return p end -- odrzuca NaN oraz ~origin (respawn)
		return nil
	end
	local pos = GetMobPosition(char)
	if pos and pos.Magnitude > 1 then return pos end
	return nil
end

local combatDeadMobs = setmetatable({}, {__mode = "k"})
local combatIgnore = {}

-- Czeka na animacje smierci moba - ten sam mechanizm co w trialach.
-- Zwraca true gdy zagrala animacja zabicia (animationIdToWait) albo mob zdechl/zniknal.
local function WaitForCombatMobDeath(mob)
    local animPlayed = false
    local connection
    local char = GetMobCharacter(mob)
    if not char then return true end -- MobCharacter juz nie istnieje = zabity

    local animationCore = char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("AnimationController")
    if not animationCore then
        for _, desc in ipairs(char:GetDescendants()) do
            if desc:IsA("Humanoid") or desc:IsA("AnimationController") then animationCore = desc break end
        end
    end

    local animator = animationCore and animationCore:FindFirstChildOfClass("Animator")
    if animator then
        connection = animator.AnimationPlayed:Connect(function(animTrack)
            if string.match(animTrack.Animation.AnimationId, animationIdToWait) then animPlayed = true end
        end)
    end

    local t = tick()
    while not animPlayed
        and combatConfig.IsCombatFarming and _G.TrialAutoFarmRunning
        and not (CheckIfInTrial() or combatConfig.PausedForTrial)
        and (tick() - t < 15) do

        local curChar = GetMobCharacter(mob)
        if not curChar then animPlayed = true break end -- MobCharacter zniknal = zabity / respi sie
        local hum = curChar:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health <= 0 then animPlayed = true break end

        -- podazaj za mobem TAK SAMO jak w trialu (moveToPoint + ghost)
        local root = GetHRP()
        local mobPos = GetMobPosition(curChar)
        if root and mobPos and (Vector3_new(mobPos.X, 0, mobPos.Z) - Vector3_new(root.Position.X, 0, root.Position.Z)).Magnitude > 1.0 then
            moveToPoint(mobPos, root)
        end
        Heartbeat:Wait()
    end

    if connection then connection:Disconnect() end
    return animPlayed or (GetMobCharacter(mob) == nil)
end

-- Normalizuje nazwe (male litery, bez spacji) do porownan
local function NormalizeMobName(str)
	return (string.gsub(string.lower(str or ""), "%s+", ""))
end

-- Czy dany mob jest zaznaczony w GUI? Dopasowanie odporne na drobne roznice
-- (spacje / wielkosc liter oraz nazwy zawierajace sie w sobie) + atrybuty / StringValue.
local function IsMobSelected(mob)
	local names = { mob.Name }
	local char = mob:FindFirstChild("MobCharacter")
	if char then table.insert(names, char.Name) end
	local dn = mob:FindFirstChild("DisplayName") or mob:FindFirstChild("MobName")
	if dn and dn:IsA("StringValue") then table.insert(names, dn.Value) end
	local attr = mob:GetAttribute("DisplayName") or mob:GetAttribute("MobName") or mob:GetAttribute("Name")
	if attr then table.insert(names, tostring(attr)) end
	if char then
		local cattr = char:GetAttribute("DisplayName") or char:GetAttribute("MobName") or char:GetAttribute("Name")
		if cattr then table.insert(names, tostring(cattr)) end
	end

	for sel, on in pairs(config.SelectedMobs) do
		if on then
			local nsel = NormalizeMobName(sel)
			if nsel ~= "" then
				for _, nm in ipairs(names) do
					local nnm = NormalizeMobName(nm)
					-- FIX V32: TYLKO dokladne dopasowanie (Pirate NIE laczy sie z Pirate Captain)
						if nnm ~= "" and nnm == nsel then
						return true
					end
				end
			end
		end
	end
	return false
end

local function FindBestCombatMob()
	local gc = workspace:FindFirstChild("__GAME_CONTENT")
	local mf = gc and gc:FindFirstChild("Mobs")
	if not mf then return nil, 0, nil end

	local hrp = GetHRP()
	local origin = hrp and hrp.Position or Vector3.zero

	-- Kazdy wpis w Mobs to slot; zywy mob to slot.MobCharacter (brak = zabity/respi sie).
	-- Nearest-neighbor sposrod zaznaczonych, zywych, nie-w-cooldownie -> wiele typow naraz + respy.
	local bestMob, bestPos, bestDist, totalMobs = nil, nil, math.huge, 0
	for _, slot in ipairs(mf:GetChildren()) do
		if IsMobSelected(slot) and IsMobAlive(slot) and not (combatIgnore[slot] and tick() < combatIgnore[slot]) then
			local char = GetMobCharacter(slot)
			local pos = char and GetCombatMobPosition(char)
			if pos then
				totalMobs += 1
				local d = (Vector3_new(pos.X, 0, pos.Z) - Vector3_new(origin.X, 0, origin.Z)).Magnitude
				if d < bestDist then
					bestDist, bestMob, bestPos = d, slot, pos
				end
			end
		end
	end
	return bestMob, totalMobs, bestPos
end

local function SetCombatStatus(txt)
	if combatStatusLabelRef then combatStatusLabelRef.Text = txt end
end

local function CombatLoop()
	combatDeadMobs = setmetatable({}, {__mode = "k"})
	combatIgnore = {}
	while combatConfig.IsCombatFarming and _G.TrialAutoFarmRunning do
		if CheckIfInTrial() or combatConfig.PausedForTrial then
			if not config.IsFarming then ToggleGhostMode(false) end
			SetCombatStatus("Status: Wstrzymano (Priorytet Trial)")
			task.wait(0.4)
			continue
		end

		-- FIX: pauza po smierci
		if combatConfig.PausedForRespawn then
			SetCombatStatus("Status: Pauza po smierci...")
			task.wait(0.3)
			continue
		end

		local ok, err = pcall(function()
			-- Czyscimy wygasle cooldowny co petle -> respawny sa brane od razu
			for k, v in pairs(combatIgnore) do
				if tick() >= v or not (k and k.Parent) then combatIgnore[k] = nil end
			end

			local mob, totalMobs, mobPos = FindBestCombatMob()
			if not mob then
				-- WAZNE: NIE wylaczamy ghost mode gdy brak celu.
				-- Wczesniej gracz spadal z wysokosci Y i ginal od upadku -> respawn na spawnie.
				-- Teraz po prostu zawisa w miejscu i czeka na respawn moba.
				local hrp = GetHRP()
				if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
				SetCombatStatus(totalMobs == 0 and "Status: Brak mobow (czekam na respawn)" or ("Status: " .. totalMobs .. " mobow w cooldownie"))
				task.wait(0.1)
				return
			end

			if not mobPos then
				SetCombatStatus("Status: Nie mozna pobrac pozycji")
				task.wait(0.1)
				return
			end

			-- FIX: limit dystansu (moby poza zasiegiem = zwykle niedostepna strefa)
			local hrpChk = GetHRP()
			if hrpChk then
				local dToMob = (Vector3_new(mobPos.X, 0, mobPos.Z) - Vector3_new(hrpChk.Position.X, 0, hrpChk.Position.Z)).Magnitude
				if dToMob > combatConfig.MaxCombatDistance then
					combatIgnore[mob] = tick() + 10
					SetCombatStatus(string.format("Status: %s poza zasiegiem (%dst)", mob.Name, math.floor(dToMob)))
					task.wait(0.05)
					return
				end
			end

			ToggleGhostMode(true, config.CombatGhostY)

			SetCombatStatus("Status: Atakowanie: " .. mob.Name)
			combatConfig.LastMobName = mob.Name

			-- ===== SWITCH-ON-ANIMATION (tak samo jak w trialu) =====
			-- Listener AnimationPlayed na Animatorze aktualnego MobCharacter.
			-- Gdy zagra animacja smierci (animationIdToWait = 112069791584815 -> MobDeath),
			-- natychmiast breakujemy inner-loop -> nastepny cel wybierany od razu.
			local killStart = tick()
			local killed = false
			local deathAnimPlayed = false
			local animConnection = nil
			local currentAnimator = nil

			local function AttachAnimListener()
				local char = GetMobCharacter(mob)
				if not char then return end
				local core = char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("AnimationController")
				if not core then
					for _, d in ipairs(char:GetDescendants()) do
						if d:IsA("Humanoid") or d:IsA("AnimationController") then core = d; break end
					end
				end
				local anim = core and core:FindFirstChildOfClass("Animator")
				if anim and anim ~= currentAnimator then
					if animConnection then animConnection:Disconnect() end
					currentAnimator = anim
					animConnection = anim.AnimationPlayed:Connect(function(animTrack)
						pcall(function()
							if animTrack and animTrack.Animation and animTrack.Animation.AnimationId
								and string.match(animTrack.Animation.AnimationId, animationIdToWait) then
								deathAnimPlayed = true
							end
						end)
					end)
				end
			end
			AttachAnimListener()

			local humanoidRef = nil
			local lastGoodPos = mobPos
			local lastAnimReattach = tick()
			while combatConfig.IsCombatFarming and _G.TrialAutoFarmRunning
				and not (CheckIfInTrial() or combatConfig.PausedForTrial) do

				-- Animacja smierci zagrala -> koniec, NATYCHMIAST do nastepnego moba
				if deathAnimPlayed then killed = true break end

				local hrp = GetHRP()
				if not hrp then break end
				humanoidRef = (hrp.Parent and hrp.Parent:FindFirstChildOfClass("Humanoid")) or humanoidRef
				if humanoidRef then humanoidRef.AutoRotate = false end

				if not IsMobAlive(mob) then killed = true break end

				-- Reattach animatora co ~0.3s (MobCharacter podmienia sie przy respi)
				if tick() - lastAnimReattach > 0.3 then
					lastAnimReattach = tick()
					AttachAnimListener()
				end

				local char = GetMobCharacter(mob)
				local cpos = char and GetCombatMobPosition(char)
				if cpos and lastGoodPos and (cpos - lastGoodPos).Magnitude > 350 then
					cpos = nil
				end
				if cpos then
					lastGoodPos = cpos
					local cur = hrp.Position
					local diff = Vector3_new(cpos.X - cur.X, 0, cpos.Z - cur.Z)
					local dist = diff.Magnitude
					local step = config.Speed * Heartbeat:Wait()
					hrp.AssemblyLinearVelocity = Vector3.zero
					if dist > 0.4 then
						local move = (dist <= step) and diff or (diff.Unit * step)
						local newPos = cur + move
						local targetLook = Vector3_new(cpos.X, cur.Y, cpos.Z)
						if (targetLook - newPos).Magnitude < 0.01 then
							targetLook = newPos + Vector3_new(0, 0, 1)
						end
						pcall(function() hrp.CFrame = CFrame.lookAt(newPos, targetLook) end)
					end
				else
					Heartbeat:Wait()
				end

				-- FIX V32: dlugi brak zabicia -> POMIJAMY tego moba (cooldown) i lecimy dalej.
				-- NIGDY nie wylaczamy combat farmu ani nie teleportujemy do triala (Medium).
				local elapsed = tick() - killStart
				if elapsed > 20 then
					combatIgnore[mob] = tick() + 12
					combatConfig.StuckTeleported = false
					SetCombatStatus("Status: " .. mob.Name .. " nieosiagalny -> pomijam")
					break
				end
			end
			if animConnection then animConnection:Disconnect() end
			if humanoidRef then humanoidRef.AutoRotate = true end

			if killed then
				-- Ignore 1.5s = pewnosc ze przeskoczymy na innego moba, a nie zwloki/respa
				combatIgnore[mob] = tick() + 1.5
				combatConfig.StuckTeleported = false -- reset stuck-timer po zabiciu
				SetCombatStatus("Status: Zabito " .. mob.Name .. " -> nastepny")
				-- BEZ task.wait(config.Cooldown) - lecimy od razu do nastepnego celu
			else
				combatIgnore[mob] = tick() + 3
				SetCombatStatus("Status: Pomijam " .. mob.Name)
			end
		end)
		if not ok then
			warn("[COMBAT ERROR] " .. tostring(err))
			SetCombatStatus("Status: Blad!")
			task.wait(0.3)
		end
		task.wait(0.02)
	end
	ToggleGhostMode(false)
	SetCombatStatus("Status: Zatrzymano")
end

ToggleCombatFarming = function(state)
	combatConfig.IsCombatFarming = state
	if state then
		if combatBtnRef then
			combatBtnRef.Text = "\226\143\184 Stop Combat Farm"
			combatBtnRef.BackgroundColor3 = fromRGB(230, 126, 34)
		end
		SendWebhook("Rozpoczeto Combat Farm", false)
		task.spawn(CombatLoop)
	else
		if combatBtnRef then
			combatBtnRef.Text = "\226\150\182 Start Combat Farm"
			combatBtnRef.BackgroundColor3 = fromRGB(46, 204, 113)
		end
		if combatConfig.CombatActiveTween then
			pcall(function() combatConfig.CombatActiveTween:Cancel() end)
			combatConfig.CombatActiveTween = nil
		end
		SendWebhook("Zatrzymano Combat Farm", false)
	end
end

-- ===== INTERFEJS GUI =====
local function CreateGUI()
    -- Paleta kolorow
    local C = {
        bg     = fromRGB(20, 20, 27),
        panel  = fromRGB(29, 30, 40),
        panel2 = fromRGB(37, 38, 51),
        stroke = fromRGB(74, 76, 100),
        text   = fromRGB(236, 237, 245),
        sub    = fromRGB(150, 152, 172),
        green  = fromRGB(46, 204, 113),
        orange = fromRGB(230, 126, 34),
        red    = fromRGB(231, 76, 60),
        blue   = fromRGB(80, 120, 255),
        purple = fromRGB(162, 102, 222),
        teal   = fromRGB(0, 220, 190),
    }

    local function corner(inst, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 8)
        c.Parent = inst
        return c
    end

    local function addStroke(inst, col, th, tr)
        local st = Instance.new("UIStroke")
        st.Color = col or C.stroke
        st.Thickness = th or 1
        st.Transparency = (tr == nil) and 0.4 or tr
        st.Parent = inst
        return st
    end

    local function shade(inst)
        local g = Instance.new("UIGradient")
        g.Rotation = 90
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Color3.new(0.85, 0.85, 0.85)),
        })
        g.Parent = inst
        return g
    end

    -- Efekt hover niezalezny od koloru tla (glow + delikatne skalowanie)
    local function interactive(btn, accent)
        btn.AutoButtonColor = false
        local scale = Instance.new("UIScale")
        scale.Parent = btn
        local st = addStroke(btn, accent or C.stroke, 1.4, 0.55)
        btn.MouseEnter:Connect(function()
            TweenService:Create(st, TweenInfo.new(0.15), {Transparency = 0.05}):Play()
            TweenService:Create(scale, TweenInfo.new(0.15), {Scale = 1.03}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(st, TweenInfo.new(0.15), {Transparency = 0.55}):Play()
            TweenService:Create(scale, TweenInfo.new(0.15), {Scale = 1}):Play()
        end)
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(scale, TweenInfo.new(0.08), {Scale = 0.97}):Play()
        end)
        btn.MouseButton1Up:Connect(function()
            TweenService:Create(scale, TweenInfo.new(0.08), {Scale = 1.03}):Play()
        end)
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TrialAutofarmGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = CoreGui

    -- Glowna ramka
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "Main"
    mainFrame.Size = UDim2_new(0, 346, 0, 470)
    mainFrame.Position = UDim2_new(0.5, -173, 0.5, -235)
    mainFrame.BackgroundColor3 = C.bg
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    corner(mainFrame, 16)
    addStroke(mainFrame, C.stroke, 1.2, 0.25)
    mainFrame.Parent = screenGui

    -- Pasek tytulu (gradient)
    local title = Instance.new("Frame")
    title.Size = UDim2_new(1, 0, 0, 48)
    title.BackgroundColor3 = C.blue
    title.BorderSizePixel = 0
    corner(title, 16)
    title.Parent = mainFrame

    local titleGrad = Instance.new("UIGradient")
    titleGrad.Rotation = 20
    titleGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.blue),
        ColorSequenceKeypoint.new(1, C.purple),
    })
    titleGrad.Parent = title

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2_new(1, -24, 1, 0)
    titleText.Position = UDim2_new(0, 16, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.RichText = true
    titleText.Text = "\240\159\142\175  Dokladna Sciezka  \226\128\162  V33   <font size=\"11\" color=\"rgb(150,152,172)\"><s>L = ukryj GUI</s></font>"
    titleText.TextColor3 = fromRGB(255, 255, 255)
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 17
    titleText.Parent = title

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2_new(0, 28, 0, 28)
    minBtn.Position = UDim2_new(1, -38, 0, 10)
    minBtn.BackgroundColor3 = C.panel2
    minBtn.Text = "\226\128\148"
    minBtn.TextColor3 = fromRGB(255, 255, 255)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 18
    minBtn.BorderSizePixel = 0
    corner(minBtn, 8)
    minBtn.Parent = title

    -- Zakladki
    local tabRow = Instance.new("Frame")
    tabRow.Size = UDim2_new(1, -24, 0, 34)
    tabRow.Position = UDim2_new(0, 12, 0, 56)
    tabRow.BackgroundTransparency = 1
    tabRow.Parent = mainFrame

    local function makeTab(txt, xScale, xOff)
        local b = Instance.new("TextButton")
        b.Size = UDim2_new(0.5, -4, 1, 0)
        b.Position = UDim2_new(xScale, xOff, 0, 0)
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.TextColor3 = C.text
        b.BackgroundColor3 = C.panel2
        b.BorderSizePixel = 0
        b.AutoButtonColor = false
        corner(b, 8)
        b.Parent = tabRow
        return b
    end

    local mainTabBtn = makeTab("Sciezka Farmu", 0, 0)
    local settingsTabBtn = makeTab("Ustawienia", 0.5, 4)

    local mainTabFrame = Instance.new("ScrollingFrame")
    mainTabFrame.Size = UDim2_new(1, -24, 1, -102)
    mainTabFrame.Position = UDim2_new(0, 12, 0, 98)
    mainTabFrame.BackgroundTransparency = 1
    mainTabFrame.BorderSizePixel = 0
    mainTabFrame.ScrollBarThickness = 4
    mainTabFrame.ScrollBarImageColor3 = C.stroke
    mainTabFrame.CanvasSize = UDim2_new(0, 0, 0, 420)
    mainTabFrame.Parent = mainFrame

    local settingsTabFrame = Instance.new("ScrollingFrame")
    settingsTabFrame.Size = UDim2_new(1, -24, 1, -102)
    settingsTabFrame.Position = UDim2_new(0, 12, 0, 98)
    settingsTabFrame.BackgroundTransparency = 1
    settingsTabFrame.BorderSizePixel = 0
    settingsTabFrame.ScrollBarThickness = 4
    settingsTabFrame.ScrollBarImageColor3 = C.stroke
    settingsTabFrame.CanvasSize = UDim2_new(0, 0, 0, 628)
    settingsTabFrame.Visible = false
    settingsTabFrame.Parent = mainFrame

    local currentTabIsMain = true
    local isMinimized = false
    local expandedSize = mainFrame.Size

    local function setTab(main)
        currentTabIsMain = main
        mainTabFrame.Visible = main
        settingsTabFrame.Visible = not main
        mainTabBtn.BackgroundColor3 = main and C.blue or C.panel2
        settingsTabBtn.BackgroundColor3 = main and C.panel2 or C.blue
        mainTabBtn.TextColor3 = main and fromRGB(255, 255, 255) or C.sub
        settingsTabBtn.TextColor3 = main and C.sub or fromRGB(255, 255, 255)
    end
    mainTabBtn.MouseButton1Click:Connect(function() setTab(true) end)
    settingsTabBtn.MouseButton1Click:Connect(function() setTab(false) end)

    local function setMinimized(min)
        isMinimized = min
        tabRow.Visible = not min
        if min then
            mainTabFrame.Visible = false
            settingsTabFrame.Visible = false
            mainFrame.Size = UDim2_new(0, expandedSize.X.Offset, 0, 48)
            minBtn.Text = "+"
        else
            mainFrame.Size = expandedSize
            setTab(currentTabIsMain)
            minBtn.Text = "\226\128\148"
        end
    end
    minBtn.MouseButton1Click:Connect(function() setMinimized(not isMinimized) end)

    local UserInputService = game:GetService("UserInputService")
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.L then
            mainFrame.Visible = not mainFrame.Visible
        end
    end)

    -- Fabryka przyciskow akcji
    local function actionButton(parent, y, h, txt, color, textSize)
        local b = Instance.new("TextButton")
        b.Size = UDim2_new(1, 0, 0, h)
        b.Position = UDim2_new(0, 0, 0, y)
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = textSize or 15
        b.TextColor3 = fromRGB(255, 255, 255)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 0
        corner(b, 10)
        shade(b)
        b.Parent = parent
        interactive(b, color)
        return b
    end

    -- ===== ZAKLADKA: SCIEZKA FARMU =====
    local statusCard = Instance.new("Frame")
    statusCard.Size = UDim2_new(1, 0, 0, 50)
    statusCard.Position = UDim2_new(0, 0, 0, 0)
    statusCard.BackgroundColor3 = C.panel
    statusCard.BorderSizePixel = 0
    corner(statusCard, 10)
    addStroke(statusCard, C.teal, 1, 0.55)
    statusCard.Parent = mainTabFrame

    singleTimerLabelRef = Instance.new("TextLabel")
    singleTimerLabelRef.Size = UDim2_new(1, -20, 1, 0)
    singleTimerLabelRef.Position = UDim2_new(0, 10, 0, 0)
    singleTimerLabelRef.BackgroundTransparency = 1
    singleTimerLabelRef.Text = "Inicjalizacja systemu timerow..."
    singleTimerLabelRef.TextColor3 = C.teal
    singleTimerLabelRef.Font = Enum.Font.GothamBold
    singleTimerLabelRef.TextSize = 13
    singleTimerLabelRef.TextWrapped = true
    singleTimerLabelRef.Parent = statusCard

    local function TrialBtnText()
        local mode = (config.SelectedTrial == "Hard") and "sekwencja" or "najblizszy"
        return "Trial: " .. config.SelectedTrial .. "  (" .. mode .. ")"
    end
    local trialBtn   = actionButton(mainTabFrame, 60,  40, TrialBtnText(), C.blue, 15)
    local savePosBtn = actionButton(mainTabFrame, 108, 36, "\240\159\147\140 Zapisz Pozycje Bazy", C.purple, 14)
    farmBtnRef       = actionButton(mainTabFrame, 152, 50, "\226\150\182 Start AutoFarm", C.green, 18)
    local chestBtn   = actionButton(mainTabFrame, 210, 36, "\226\157\140 Auto Chest (OFF)", C.red, 14)
    local killBtn    = actionButton(mainTabFrame, 252, 36, "\240\159\155\145 Wylacz skrypt calkowicie", C.red, 14)

    local divider = Instance.new("Frame")
    divider.Size = UDim2_new(1, 0, 0, 1)
    divider.Position = UDim2_new(0, 0, 0, 300)
    divider.BackgroundColor3 = C.stroke
    divider.BackgroundTransparency = 0.3
    divider.BorderSizePixel = 0
    divider.Parent = mainTabFrame

    local combatLabel = Instance.new("TextLabel")
    combatLabel.Size = UDim2_new(1, 0, 0, 20)
    combatLabel.Position = UDim2_new(0, 2, 0, 310)
    combatLabel.BackgroundTransparency = 1
    combatLabel.Text = "\226\154\148 Combat Farm"
    combatLabel.TextColor3 = fromRGB(255, 120, 120)
    combatLabel.TextXAlignment = Enum.TextXAlignment.Left
    combatLabel.Font = Enum.Font.GothamBold
    combatLabel.TextSize = 14
    combatLabel.Parent = mainTabFrame

    combatBtnRef = actionButton(mainTabFrame, 334, 42, "\226\150\182 Start Combat Farm", C.green, 16)

    local statusPill = Instance.new("Frame")
    statusPill.Size = UDim2_new(1, 0, 0, 26)
    statusPill.Position = UDim2_new(0, 0, 0, 382)
    statusPill.BackgroundColor3 = C.panel
    statusPill.BorderSizePixel = 0
    corner(statusPill, 8)
    statusPill.Parent = mainTabFrame

    combatStatusLabelRef = Instance.new("TextLabel")
    combatStatusLabelRef.Size = UDim2_new(1, -16, 1, 0)
    combatStatusLabelRef.Position = UDim2_new(0, 8, 0, 0)
    combatStatusLabelRef.BackgroundTransparency = 1
    combatStatusLabelRef.Text = "Status: Nieaktywny"
    combatStatusLabelRef.TextColor3 = C.sub
    combatStatusLabelRef.TextXAlignment = Enum.TextXAlignment.Left
    combatStatusLabelRef.Font = Enum.Font.GothamSemibold
    combatStatusLabelRef.TextSize = 12
    combatStatusLabelRef.Parent = statusPill

    local function UpdateChestButton()
        if config.AutoChestType == "None" then
            chestBtn.Text = "\226\157\140 Auto Chest (OFF)"
            chestBtn.BackgroundColor3 = C.red
        elseif config.AutoChestType == "T1" then
            chestBtn.Text = "\240\159\147\166 Auto Chest (T1)"
            chestBtn.BackgroundColor3 = C.green
        else
            chestBtn.Text = "\240\159\142\129 Auto Chest (T2)"
            chestBtn.BackgroundColor3 = C.purple
        end
    end
    UpdateChestButton()

    -- ===== ZAKLADKA: USTAWIENIA =====
    local function CreateInput(y, labelStr, default)
        local label = Instance.new("TextLabel")
        label.Size = UDim2_new(1, 0, 0, 16)
        label.Position = UDim2_new(0, 2, 0, y)
        label.BackgroundTransparency = 1
        label.Text = labelStr
        label.TextColor3 = C.sub
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.GothamSemibold
        label.TextSize = 12
        label.Parent = settingsTabFrame

        local box = Instance.new("TextBox")
        box.Size = UDim2_new(1, 0, 0, 30)
        box.Position = UDim2_new(0, 0, 0, y + 18)
        box.BackgroundColor3 = C.panel2
        box.TextColor3 = C.text
        box.Text = default
        box.Font = Enum.Font.Gotham
        box.TextSize = 13
        box.ClearTextOnFocus = false
        box.BorderSizePixel = 0
        corner(box, 8)
        addStroke(box, C.stroke, 1, 0.5)
        box.Parent = settingsTabFrame
        return box
    end

    local speedBox       = CreateInput(6,   "Predkosc lotu (Trial):", tostring(config.Speed))
    local cooldownBox    = CreateInput(56,  "Cooldown po zabiciu:", tostring(config.Cooldown))
    local waveWaitBox    = CreateInput(106, "Czas na nowa fale:", tostring(config.WaveWaitTime))
    local ghostYBox      = CreateInput(156, "Wysokosc Ghost Mode (Y):", tostring(config.GhostModeY))
    local startSecBox    = CreateInput(206, "Teleport gdy <= X sek (otwarty portal):", tostring(config.TimeToStartSec))
    local combatYBox     = CreateInput(254, "Wysokosc Combat Ghost (Y):", tostring(config.CombatGhostY))
    local combatInfoLabel = Instance.new("TextLabel")
    combatInfoLabel.Size = UDim2_new(1, 0, 0, 40)
    combatInfoLabel.Position = UDim2_new(0, 2, 0, 306)
    combatInfoLabel.BackgroundTransparency = 1
    combatInfoLabel.Text = "\226\154\148 Combat Farm uzywa predkosci/cooldownu Triala, ale ma WLASNA wysokosc (Combat Ghost Y powyzej)."
    combatInfoLabel.TextColor3 = C.sub
    combatInfoLabel.TextWrapped = true
    combatInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    combatInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
    combatInfoLabel.Font = Enum.Font.Gotham
    combatInfoLabel.TextSize = 11
    combatInfoLabel.Parent = settingsTabFrame

    savedCoordsLabelRef = Instance.new("TextLabel")
    savedCoordsLabelRef.Size = UDim2_new(1, 0, 0, 20)
    savedCoordsLabelRef.Position = UDim2_new(0, 2, 0, 350)
    savedCoordsLabelRef.BackgroundTransparency = 1
    savedCoordsLabelRef.Text = savedPosition and string.format("Zapisane Kordynaty: %.1f, %.1f, %.1f", savedPosition.X, savedPosition.Y, savedPosition.Z) or "Zapisane Kordynaty: Brak"
    savedCoordsLabelRef.TextColor3 = C.purple
    savedCoordsLabelRef.TextXAlignment = Enum.TextXAlignment.Left
    savedCoordsLabelRef.Font = Enum.Font.GothamSemibold
    savedCoordsLabelRef.TextSize = 13
    savedCoordsLabelRef.Parent = settingsTabFrame

    -- V27: guzik do wyczyszczenia zapisanej pozycji
    local clearSavedPosBtn = Instance.new("TextButton")
    clearSavedPosBtn.Size = UDim2_new(1, -4, 0, 26)
    clearSavedPosBtn.Position = UDim2_new(0, 2, 0, 372)
    clearSavedPosBtn.Text = "\240\159\151\145 Usun zapisane kordynaty"
    clearSavedPosBtn.Font = Enum.Font.GothamBold
    clearSavedPosBtn.TextSize = 12
    clearSavedPosBtn.TextColor3 = fromRGB(255, 255, 255)
    clearSavedPosBtn.BackgroundColor3 = C.red
    clearSavedPosBtn.BorderSizePixel = 0
    clearSavedPosBtn.AutoButtonColor = false
    corner(clearSavedPosBtn, 6)
    clearSavedPosBtn.Parent = settingsTabFrame

    clearSavedPosBtn.MouseButton1Click:Connect(function()
        savedPosition = nil
        SaveConfig()
        if savedCoordsLabelRef then
            savedCoordsLabelRef.Text = "Zapisane Kordynaty: Brak"
        end
        clearSavedPosBtn.Text = "\226\156\133 Usunieto!"
        clearSavedPosBtn.BackgroundColor3 = C.green
        task.delay(1.5, function()
            clearSavedPosBtn.Text = "\240\159\151\145 Usun zapisane kordynaty"
            clearSavedPosBtn.BackgroundColor3 = C.red
        end)
    end)

    local mobSelectLabel = Instance.new("TextLabel")
    mobSelectLabel.Size = UDim2_new(1, 0, 0, 18)
    mobSelectLabel.Position = UDim2_new(0, 2, 0, 410)
    mobSelectLabel.BackgroundTransparency = 1
    mobSelectLabel.Text = "Wybierz moby do farmienia:"
    mobSelectLabel.TextColor3 = C.sub
    mobSelectLabel.TextXAlignment = Enum.TextXAlignment.Left
    mobSelectLabel.Font = Enum.Font.GothamSemibold
    mobSelectLabel.TextSize = 12
    mobSelectLabel.Parent = settingsTabFrame

    local mobContainer = Instance.new("ScrollingFrame")
    mobContainer.Name = "MobContainer"
    mobContainer.Size = UDim2_new(1, 0, 0, 140)
    mobContainer.Position = UDim2_new(0, 0, 0, 432)
    mobContainer.BackgroundColor3 = C.panel
    mobContainer.BorderSizePixel = 0
    mobContainer.ScrollBarThickness = 4
    mobContainer.ScrollBarImageColor3 = C.stroke
    mobContainer.CanvasSize = UDim2_new(0, 0, 0, 0)
    corner(mobContainer, 8)
    mobContainer.Parent = settingsTabFrame

    local mobPad = Instance.new("UIPadding")
    mobPad.PaddingTop = UDim.new(0, 6)
    mobPad.PaddingLeft = UDim.new(0, 6)
    mobPad.PaddingRight = UDim.new(0, 6)
    mobPad.Parent = mobContainer

    local mobListLayout = Instance.new("UIGridLayout")
    mobListLayout.CellSize = UDim2_new(0.315, -6, 0, 28)
    mobListLayout.CellPadding = UDim2_new(0, 6, 0, 6)
    mobListLayout.Parent = mobContainer

    for _, mobName in ipairs(MOBS) do
        local btn = Instance.new("TextButton")
        btn.Name = "Mob_" .. mobName
        btn.Text = mobName
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 10
        btn.TextColor3 = fromRGB(255, 255, 255)
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        local isActive = config.SelectedMobs[mobName] == true
        btn.BackgroundColor3 = isActive and C.green or fromRGB(150, 55, 55)
        corner(btn, 6)
        btn.Parent = mobContainer
        btn.MouseButton1Click:Connect(function()
            config.SelectedMobs[mobName] = not (config.SelectedMobs[mobName] or false)
            btn.BackgroundColor3 = config.SelectedMobs[mobName] and C.green or fromRGB(150, 55, 55)
            SaveConfig()
        end)
    end

    mobListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        mobContainer.CanvasSize = UDim2_new(0, 0, 0, mobListLayout.AbsoluteContentSize.Y + 12)
    end)

    -- ===== POLACZENIA =====
    speedBox.FocusLost:Connect(function() config.Speed = tonumber(speedBox.Text) or config.Speed; speedBox.Text = tostring(config.Speed); SaveConfig() end)
    cooldownBox.FocusLost:Connect(function() config.Cooldown = tonumber(cooldownBox.Text) or config.Cooldown; cooldownBox.Text = tostring(config.Cooldown); SaveConfig() end)
    waveWaitBox.FocusLost:Connect(function() config.WaveWaitTime = tonumber(waveWaitBox.Text) or config.WaveWaitTime; waveWaitBox.Text = tostring(config.WaveWaitTime); SaveConfig() end)
    ghostYBox.FocusLost:Connect(function() config.GhostModeY = tonumber(ghostYBox.Text) or config.GhostModeY; ghostYBox.Text = tostring(config.GhostModeY); SaveConfig() end)
    combatYBox.FocusLost:Connect(function() config.CombatGhostY = tonumber(combatYBox.Text) or config.CombatGhostY; combatYBox.Text = tostring(config.CombatGhostY); SaveConfig() end)
    startSecBox.FocusLost:Connect(function() config.TimeToStartSec = tonumber(startSecBox.Text) or config.TimeToStartSec; startSecBox.Text = tostring(config.TimeToStartSec); SaveConfig() end)

    trialBtn.MouseButton1Click:Connect(function()
        if config.IsFarming then return end
        -- V33: Medium -> Hard -> Easy -> Medium
        if config.SelectedTrial == "Medium" then config.SelectedTrial = "Hard"
        elseif config.SelectedTrial == "Hard" then config.SelectedTrial = "Easy"
        else config.SelectedTrial = "Medium" end
        hardStepIndex = 1
        trialBtn.Text = TrialBtnText()
        SaveConfig()
    end)

    savePosBtn.MouseButton1Click:Connect(function()
        local hrp = GetHRP()
        if hrp then
            savedPosition = hrp.CFrame
            SaveConfig()
            if savedCoordsLabelRef then
                savedCoordsLabelRef.Text = string.format("Zapisane Kordynaty: %.1f, %.1f, %.1f", savedPosition.X, savedPosition.Y, savedPosition.Z)
            end
            savePosBtn.Text = "\226\156\133 Pozycja Zapisana!"
            savePosBtn.BackgroundColor3 = C.green
            task.delay(1.5, function()
                savePosBtn.Text = "\240\159\147\140 Zapisz Pozycje Bazy"
                savePosBtn.BackgroundColor3 = C.purple
            end)
        end
    end)

    farmBtnRef.MouseButton1Click:Connect(function() ToggleFarming(not config.IsFarming) end)

    chestBtn.MouseButton1Click:Connect(function()
        if config.AutoChestType == "None" then
            config.AutoChestType = "T1"
        elseif config.AutoChestType == "T1" then
            config.AutoChestType = "T2"
        else
            config.AutoChestType = "None"
        end
        UpdateChestButton()
        SaveConfig()
        if config.AutoChestType ~= "None" then OpenChestLoop() end
    end)

    combatBtnRef.MouseButton1Click:Connect(function()
        ToggleCombatFarming(not combatConfig.IsCombatFarming)
    end)

    killBtn.MouseButton1Click:Connect(function()
        _G.TrialAutoFarmRunning = false
        if config.IsFarming then ToggleFarming(false) end
        if combatConfig.IsCombatFarming then ToggleCombatFarming(false) end
        antiAFK(false); ToggleGhostMode(false)
        if consoleConnection then consoleConnection:Disconnect() end
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BillboardGui") and v.Name == "MobNumberTag" then v:Destroy() end
        end
        if workspace:FindFirstChild("AutoFarm_GridConfig") then workspace.AutoFarm_GridConfig:Destroy() end
        screenGui:Destroy()
    end)

    -- ===== V32: Przycisk UKRYJ GUI (w Ustawieniach) =====
    local hideGuiBtn = Instance.new("TextButton")
    hideGuiBtn.Size = UDim2_new(1, -4, 0, 32)
    hideGuiBtn.Position = UDim2_new(0, 2, 0, 582)
    hideGuiBtn.Text = "\240\159\145\129 Ukryj GUI (pokaz ponownie: klawisz L)"
    hideGuiBtn.Font = Enum.Font.GothamBold
    hideGuiBtn.TextSize = 12
    hideGuiBtn.TextColor3 = fromRGB(255, 255, 255)
    hideGuiBtn.BackgroundColor3 = C.panel2
    hideGuiBtn.BorderSizePixel = 0
    hideGuiBtn.AutoButtonColor = false
    corner(hideGuiBtn, 8)
    addStroke(hideGuiBtn, C.stroke, 1, 0.5)
    hideGuiBtn.Parent = settingsTabFrame
    hideGuiBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
    end)

    -- ===== V32: RECZNA zmiana rozmiaru GUI (uchwyt w prawym dolnym rogu) =====
    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Name = "ResizeHandle"
    resizeHandle.Size = UDim2_new(0, 18, 0, 18)
    resizeHandle.Position = UDim2_new(1, -21, 1, -21)
    resizeHandle.AnchorPoint = Vector2.new(0, 0)
    resizeHandle.BackgroundColor3 = C.panel2
    resizeHandle.Text = "\226\135\152"
    resizeHandle.TextColor3 = C.sub
    resizeHandle.Font = Enum.Font.GothamBold
    resizeHandle.TextSize = 13
    resizeHandle.BorderSizePixel = 0
    resizeHandle.AutoButtonColor = false
    resizeHandle.ZIndex = 6
    corner(resizeHandle, 6)
    resizeHandle.Parent = mainFrame

    local resizing = false
    local resizeStartMouse = nil
    local resizeStartSize = nil
    resizeHandle.MouseButton1Down:Connect(function()
        if isMinimized then return end
        resizing = true
        resizeStartMouse = UserInputService:GetMouseLocation()
        resizeStartSize = mainFrame.AbsoluteSize
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local cur = UserInputService:GetMouseLocation()
            local newW = math.clamp(resizeStartSize.X + (cur.X - resizeStartMouse.X), 280, 620)
            local newH = math.clamp(resizeStartSize.Y + (cur.Y - resizeStartMouse.Y), 130, 720)
            mainFrame.Size = UDim2_new(0, newW, 0, newH)
            expandedSize = mainFrame.Size
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
        end
    end)

    setTab(true)
end

CreateGUI()
