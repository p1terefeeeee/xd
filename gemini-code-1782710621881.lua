--[[
	TRIAL AUTO-FARM  •  V39 (Star Farm - TP po kolei od gory folderu)
	- Combat: switch-on-animation (MobDeath = 112069791584815)
	- 15s bez zabicia -> TP do Medium, 30s -> STOP combat
	- Anti-stuck w trialu: podbij Y o 1 gdy postac stoi >1s
	- Trial-end TP: przy 19:58 czekaj 3s -> Realm3 spawn (combat ON)
							lub 2s -> savedPosition (combat OFF)
	- Guzik "Usun zapisane kordynaty" w Ustawieniach
	- V29: wyjscie z triala (Leave) -> RUNNING->OPEN -> TP Realm 3 spawn
	- V30: detekcja po pozycji Leave (879,10,13443) + Realm3 spawn (1019,4,7801)
	       jednolita logika: pauza combat -> 2s -> TP Realm3 -> jesli combat OFF -> savedPos
	- V31: Timer2=59s -> auto-pause combat farm (odblokuj Y); po trialu na Realm3 -> auto-wznow
	- V33: przycisk "WYLACZ SKRYPT CALKOWICIE" (kill switch, 2 klikniecia),
	       dzialajace powiekszanie/pomniejszanie GUI (UIScale + uchwyt resize)
	- V34: czytelniejsza typografia (Gotham Bold/Medium, kontur tekstu, wyzszy kontrast),
	       3 poziomy wielkosci czcionki, karty sekcji, kropka statusu w pasku tytulu
	- V35: wlasna sciezka dla HARD TRIALA (7 wezlow, kordynaty uzytkownika);
	       mechanika farmienia identyczna jak Medium, ustawienia uniwersalne;
	       przycisk Trial przelacza Easy/Medium/Hard i podmienia sciezke
	- V36: FIX combatu - rozpoznawanie TYPU moba (najdluzsze dopasowanie z MOBS)
	- V37: STAR FARM - podlatywanie do gwiazdek z workspace.ClientStars,
	       priorytet mutacji Lunar > Alien > Plasma > Normal,
	       opcja "Postoj przy gwiazdce (sekundy)" w Ustawieniach
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
	SelectedMobs = {},
	StarHoldTime = 3,
	StarSkipCooldown = 0,
	GuiScale = 1,
	GuiW = 372,
	GuiH = 500,
	FontStep = 1
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
		config.StarHoldTime    = tonumber(decoded.StarHoldTime) or config.StarHoldTime
		config.StarSkipCooldown = tonumber(decoded.StarSkipCooldown) or config.StarSkipCooldown
		config.GuiScale        = tonumber(decoded.GuiScale) or config.GuiScale
		config.GuiW            = tonumber(decoded.GuiW) or config.GuiW
		config.GuiH            = tonumber(decoded.GuiH) or config.GuiH
		config.FontStep        = tonumber(decoded.FontStep) or config.FontStep
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
			StarHoldTime = config.StarHoldTime,
			StarSkipCooldown = config.StarSkipCooldown,
			GuiScale = config.GuiScale,
			GuiW = config.GuiW,
			GuiH = config.GuiH,
			FontStep = config.FontStep,
			SavedPosition = savedPosition and {savedPosition:GetComponents()} or nil
		}))
	end)
end

LoadConfig()

-- ===== STATE =====
local deadMobs = setmetatable({}, {__mode = "k"})
local ignoreList = {}

-- ===== V35: SCIEZKI TRIALI =====
-- Kazdy trial ma wlasny zestaw wezlow, podany w KOLEJNOSCI obchodzenia areny.
-- Mechanika farmienia jest DOKLADNIE TA SAMA dla kazdego triala - rozni sie
-- tylko zestaw kordynatow. Ustawienia (predkosc, Ghost Y, cooldown itd.)
-- sa uniwersalne i dzialaja dla wszystkich trialu jednakowo.
local trialPaths = {
	Medium = {
		{Name = "M1_Pirate_Left_Low",     Pos = Vector3_new(749, 11, 13635)},
		{Name = "M2_Pirate_Left_High",    Pos = Vector3_new(723, 11, 13639)},
		{Name = "M3_Ninja_Left_High",     Pos = Vector3_new(694, 11, 13634)},
		{Name = "M4_Pirate_Captain_Top",  Pos = Vector3_new(667, 11, 13620)},
		{Name = "M5_Ninja_Right_High",    Pos = Vector3_new(694, 11, 13606)},
		{Name = "M6_Pirate_Right_Mid",    Pos = Vector3_new(723, 11, 13601)},
		{Name = "M7_Pirate_Right_Low",    Pos = Vector3_new(749, 11, 13605)}
	},
	-- HARD: kordynaty podane przez uzytkownika, w kolejnosci 1..7
	Hard = {
		{Name = "H1_Hard_Step1", Pos = Vector3_new(746.33, 9.15, 13745)},
		{Name = "H2_Hard_Step2", Pos = Vector3_new(720,    9.15, 13749)},
		{Name = "H3_Hard_Step3", Pos = Vector3_new(689,    9.10, 13752)},
		{Name = "H4_Hard_Step4", Pos = Vector3_new(655,    9.20, 13765)},
		{Name = "H5_Hard_Step5", Pos = Vector3_new(690,    9.10, 13779)},
		{Name = "H6_Hard_Step6", Pos = Vector3_new(720,    9.15, 13799)},
		{Name = "H7_Hard_Step7", Pos = Vector3_new(750,    9.15, 13785)}
	}
}

-- Easy korzysta z ukladu Medium (brak osobnych kordynatow)
trialPaths.Easy = trialPaths.Medium

-- Zwraca wezly sciezki dla AKTUALNIE wybranego triala
local function GetPathOrder()
	return trialPaths[config.SelectedTrial] or trialPaths.Medium
end

local gridFolder = workspace:FindFirstChild("AutoFarm_GridConfig")
if not gridFolder then
	gridFolder = Instance.new("Folder")
	gridFolder.Name = "AutoFarm_GridConfig"
	gridFolder.Parent = workspace
end

-- V35: wezly tworzymy dla kazdego triala (Medium + Hard)
for _, nodes in pairs(trialPaths) do
	for _, info in ipairs(nodes) do
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

local function GetClosestNodeIndex(mob)
	local mobPos = GetMobPosition(mob)
	if not mobPos then return nil end

	local closestIndex, shortestDist = nil, math.huge
	for id, info in ipairs(GetPathOrder()) do
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
	for _, info in ipairs(GetPathOrder()) do
		if (Vector3_new(p.X, 0, p.Z) - Vector3_new(info.Pos.X, 0, info.Pos.Z)).Magnitude < 140 then
			return true
		end
	end
	-- Albo blisko DOWOLNEGO moba w tym trialu (uniwersalne dla kazdej areny)
	local room = GetTrialRoom(config.SelectedTrial)
	local mobs = room and room:FindFirstChild("Mobs")
	if mobs then
		for _, mob in ipairs(mobs:GetChildren()) do
			local mp = mob:FindFirstChild("HumanoidRootPart") or (mob:IsA("Model") and mob.PrimaryPart) or nil
			if mp and mp:IsA("BasePart") and (Vector3_new(p.X, 0, p.Z) - Vector3_new(mp.Position.X, 0, mp.Position.Z)).Magnitude < 160 then
				return true
			end
		end
	end
	return false
end

-- ===== GUI REFS =====
local farmBtnRef, singleTimerLabelRef, savedCoordsLabelRef, combatBtnRef, combatStatusLabelRef
local starBtnRef, starStatusLabelRef

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
-- ===== V37: STAN STAR FARMU =====
local starConfig = { IsStarFarming = false }
local ToggleStarFarming

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

	while (config.IsFarming or combatConfig.IsCombatFarming or starConfig.IsStarFarming) and _G.TrialAutoFarmRunning do
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

				local targetMob, targetMobPos = GetTargetMob(mobFolder)
				if not targetMob or not targetMobPos then
					ToggleGhostMode(false)
					task.wait(config.WaveWaitTime)
					killedMobsCount = 0
					deadMobs = setmetatable({}, {__mode = "k"})
					ignoreList = {}
					return
				end

				ToggleGhostMode(true)
				moveToPoint(targetMobPos, root)
				if not config.IsFarming or not _G.TrialAutoFarmRunning then return end

				if WaitForDeathAnimation(targetMob) then
					deadMobs[targetMob] = true
					killedMobsCount += 1
					if killedMobsCount >= 7 then
						ToggleGhostMode(false)
						task.wait(config.WaveWaitTime)
						killedMobsCount = 0
						deadMobs = setmetatable({}, {__mode = "k"})
						ignoreList = {}
					else
						task.wait(config.Cooldown)
					end
				else
					ignoreList[targetMob] = tick() + 4
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

-- Normalizuje nazwe: male litery, bez spacji/podkreslnikow/lacznikow/kropek.
local function NormalizeMobName(str)
	local s = string.lower(str or "")
	s = string.gsub(s, "[%s_%-%.]+", "")
	return s
end

-- Zbiera wszystkie mozliwe nazwy slotu/moba
local function CollectMobNames(mob)
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
	return names
end

-- ===== V36: ROZPOZNAWANIE TYPU MOBA =====
-- Z listy MOBS wybieramy NAJDLUZSZA nazwe pasujaca do slotu:
--   "Pirate_3" -> Pirate,  "Pirate Captain" -> Pirate Captain (nie Pirate)
local function DetectMobType(mob)
	local names = CollectMobNames(mob)
	local best, bestLen = nil, 0
	for _, candidate in ipairs(MOBS) do
		local nc = NormalizeMobName(candidate)
		if nc ~= "" and #nc > bestLen then
			for _, nm in ipairs(names) do
				local nnm = NormalizeMobName(nm)
				if nnm ~= "" and (nnm == nc or string.find(nnm, nc, 1, true)) then
					best, bestLen = candidate, #nc
					break
				end
			end
		end
	end
	return best
end

-- Dziala dla DOWOLNEJ liczby zaznaczonych typow naraz.
local function IsMobSelected(mob)
	local t = DetectMobType(mob)
	if t then
		return config.SelectedMobs[t] == true
	end

	local names = CollectMobNames(mob)
	for sel, on in pairs(config.SelectedMobs) do
		if on then
			local nsel = NormalizeMobName(sel)
			if nsel ~= "" then
				for _, nm in ipairs(names) do
					if NormalizeMobName(nm) == nsel then return true end
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

-- ===== V37: STAR FARM (workspace.ClientStars) =====
-- Podlatuje do gwiazdek dokladnie tak jak combat farm podlatuje do mobow.
-- Priorytet mutacji: Lunar > Alien > Plasma > Normal.
-- Przy remisie priorytetu wybierana jest NAJBLIZSZA gwiazdka.
local STAR_PRIORITY = { Lunar = 4, Alien = 3, Plasma = 2, Normal = 1 }
local starIgnore = {}

local function GetStarsFolder()
	return workspace:FindFirstChild("ClientStars")
end

-- Mutacja czytana z ATRYBUTOW gwiazdki. Nazwa atrybutu bywa rozna,
-- wiec szukamy atrybutu, ktorego WARTOSC to Lunar/Alien/Plasma/Normal.
local function GetStarMutation(star)
	local ok, attrs = pcall(function() return star:GetAttributes() end)
	if ok and type(attrs) == "table" then
		-- najpierw typowe nazwy atrybutu
		for _, key in ipairs({"Mutation", "mutation", "Mutacja", "Type", "Rarity"}) do
			local v = attrs[key]
			if type(v) == "string" then
				for name in pairs(STAR_PRIORITY) do
					if string.lower(v) == string.lower(name) then return name end
				end
			end
		end
		-- potem DOWOLNY atrybut pasujacy wartoscia
		for _, v in pairs(attrs) do
			if type(v) == "string" then
				for name in pairs(STAR_PRIORITY) do
					if string.lower(v) == string.lower(name) then return name end
				end
			end
		end
	end
	-- fallback: nazwa obiektu
	local n = string.lower(star.Name or "")
	for name in pairs(STAR_PRIORITY) do
		if string.find(n, string.lower(name), 1, true) then return name end
	end
	return "Normal"
end

-- ===== V39: KORDY Z StarPart -> Pivot -> PivotOffset.Position =====
-- Kolejnosc zrodel:
--   1. star.StarPart.PivotOffset.Position   (dokladnie to, co widzisz w Properties)
--   2. star.StarPart:GetPivot().Position    (pivot w swiecie, gdy offset jest zerowy)
--   3. star.StarPart.Position               (fallback)
local function GetStarPart(star)
	if not star or not star.Parent then return nil end
	if star:IsA("BasePart") and star.Name == "StarPart" then return star end
	local p = star:FindFirstChild("StarPart", true)
	if p and p:IsA("BasePart") then return p end
	if star:IsA("BasePart") then return star end
	return star:FindFirstChildWhichIsA("BasePart", true)
end

local function GetStarPosition(star)
	local part = GetStarPart(star)
	if not part then return nil end

	-- 1. PivotOffset.Position (surowe kordy z Properties)
	local ok, off = pcall(function() return part.PivotOffset.Position end)
	if ok and off and off == off and off.Magnitude > 25 then
		return off
	end

	-- 2. Pivot w przestrzeni swiata
	local ok2, piv = pcall(function() return part:GetPivot().Position end)
	if ok2 and piv and piv == piv and piv.Magnitude > 0 then
		return piv
	end

	-- 3. Zwykla pozycja partu
	local p = part.Position
	if p == p then return p end
	return nil
end

-- Zwraca: gwiazdka, pozycja, mutacja, ile gwiazdek widocznych
local function FindBestStar()
	local folder = GetStarsFolder()
	if not folder then return nil, nil, nil, 0 end

	local hrp = GetHRP()
	local origin = hrp and hrp.Position or Vector3.zero

	local best, bestPos, bestMut = nil, nil, nil
	local bestPrio, bestDist, total = -1, math.huge, 0

	for _, star in ipairs(folder:GetChildren()) do
		if not (starIgnore[star] and tick() < starIgnore[star]) then
			local pos = GetStarPosition(star)
			if pos then
				total += 1
				local mut  = GetStarMutation(star)
				local prio = STAR_PRIORITY[mut] or 0
				local d    = (pos - origin).Magnitude
				if prio > bestPrio or (prio == bestPrio and d < bestDist) then
					best, bestPos, bestMut, bestPrio, bestDist = star, pos, mut, prio, d
				end
			end
		end
	end
	return best, bestPos, bestMut, total
end

local function SetStarStatus(txt)
	if starStatusLabelRef then starStatusLabelRef.Text = txt end
end

-- ===== V39: SEKWENCYJNY OBCHOD FOLDERA + TELEPORT =====
-- Idziemy po workspace.ClientStars OD GORY DO DOLU (kolejnosc GetChildren),
-- teleport na kordy StarPart.PivotOffset.Position, postoj X sekund,
-- potem nastepne dziecko. Po ostatnim wracamy na gore i tak w kolko.
local starIndex = 1

local function StarLoop()
	starIgnore = {}
	starIndex = 1

	while starConfig.IsStarFarming and _G.TrialAutoFarmRunning do
		-- Trial i AutoFarm maja PRIORYTET nad zbieraniem gwiazdek
		if CheckIfInTrial() or combatConfig.PausedForTrial or config.IsFarming then
			SetStarStatus("Status: Wstrzymano (priorytet Trial/AutoFarm)")
			task.wait(0.4)
			continue
		end

		local ok, err = pcall(function()
			local folder = GetStarsFolder()
			if not folder then
				SetStarStatus("Status: Brak folderu workspace.ClientStars")
				task.wait(0.5)
				return
			end

			local list = folder:GetChildren()
			if #list == 0 then
				starIndex = 1
				SetStarStatus("Status: Brak gwiazdek (czekam)")
				task.wait(0.5)
				return
			end

			-- zawijanie na gore folderu
			if starIndex > #list then starIndex = 1 end

			local star = list[starIndex]
			local idx  = starIndex
			starIndex += 1  -- nastepny obieg = nastepne dziecko, zawsze do przodu

			if not star or not star.Parent then return end

			local pos = GetStarPosition(star)
			if not pos then
				SetStarStatus(string.format("Status: [%d/%d] %s - brak kordow, pomijam", idx, #list, star.Name))
				return
			end

			local hrp = GetHRP()
			if not hrp then return end

			local mut = GetStarMutation(star)

			-- ===== TELEPORT NA KORDY (bez lotu) =====
			ToggleGhostMode(true, pos.Y)
			SafeTeleport(hrp, CFrame_new(pos), 0.2)
			SetStarStatus(string.format("Status: [%d/%d] TP %s [%s]", idx, #list, star.Name, tostring(mut)))

			-- ===== POSTOJ NA KORDACH (czas z Ustawien) =====
			local hold = tonumber(config.StarHoldTime) or 3
			if hold < 0 then hold = 0 end

			local hs = tick()
			while starConfig.IsStarFarming and _G.TrialAutoFarmRunning and (tick() - hs) < hold do
				if CheckIfInTrial() or config.IsFarming then break end
				ghostTargetY = pos.Y
				pcall(function()
					hrp.AssemblyLinearVelocity = Vector3.zero
					hrp.CFrame = CFrame_new(pos) * (hrp.CFrame - hrp.CFrame.Position)
				end)
				task.wait(0.05)
			end

			SetStarStatus(string.format("Status: [%d/%d] koniec postoju -> nastepna", idx, #list))
		end)

		if not ok then
			warn("[STAR ERROR] " .. tostring(err))
			SetStarStatus("Status: Blad!")
			task.wait(0.3)
		end

		-- przerwa miedzy gwiazdkami
		local gap = tonumber(config.StarSkipCooldown) or 0
		if gap > 0 then task.wait(gap) else task.wait(0.05) end
	end

	if not config.IsFarming and not combatConfig.IsCombatFarming then
		ToggleGhostMode(false)
	end
	SetStarStatus("Status: Zatrzymano")
end

ToggleStarFarming = function(state)
	starConfig.IsStarFarming = state
	if state then
		if starBtnRef then
			starBtnRef.Text = "\226\143\184 Stop Star Farm"
			starBtnRef.BackgroundColor3 = fromRGB(230, 126, 34)
		end
		task.spawn(StarLoop)
	else
		if starBtnRef then
			starBtnRef.Text = "\226\173\144 Start Star Farm"
			starBtnRef.BackgroundColor3 = fromRGB(46, 204, 113)
		end
	end
end

-- ===== V33/V34: PELNE WYLACZENIE SKRYPTU (KILL SWITCH) =====
local guiConnections = {}
local function trackConn(c)
	if c then table.insert(guiConnections, c) end
	return c
end

local isShuttingDown = false
local ShutdownScript

ShutdownScript = function(silent)
	if isShuttingDown then return end
	isShuttingDown = true

	-- 1) Zatrzymaj wszystkie petle (kazda sprawdza te flage)
	_G.TrialAutoFarmRunning = false

	-- 2) Wylacz tryby farmienia
	pcall(function() if config.IsFarming then ToggleFarming(false) end end)
	pcall(function() if combatConfig.IsCombatFarming then ToggleCombatFarming(false) end end)
	pcall(function() if starConfig.IsStarFarming and ToggleStarFarming then ToggleStarFarming(false) end end)
	config.IsFarming = false
	combatConfig.IsCombatFarming = false
	starConfig.IsStarFarming = false
	config.AutoChestType = "None"

	-- 3) Anuluj aktywne tweeny ruchu
	pcall(function()
		if combatConfig.CombatActiveTween then
			combatConfig.CombatActiveTween:Cancel()
			combatConfig.CombatActiveTween = nil
		end
	end)

	-- 4) Rozlacz WSZYSTKIE polaczenia skryptu
	pcall(function() antiAFK(false) end)
	pcall(function() ToggleGhostMode(false) end)
	pcall(function() if NoclipConnection then NoclipConnection:Disconnect(); NoclipConnection = nil end end)
	pcall(function() if AxisLockConnection then AxisLockConnection:Disconnect(); AxisLockConnection = nil end end)
	pcall(function() if consoleConnection then consoleConnection:Disconnect() end end)
	for _, c in ipairs(guiConnections) do
		pcall(function() c:Disconnect() end)
	end
	guiConnections = {}

	-- 5) Przywroc postac do normalnego stanu
	pcall(function()
		local char = player.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
			hrp.AssemblyLinearVelocity = Vector3_new(0, 0, 0)
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.JumpPower = 50
			hum.WalkSpeed = 16
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
			hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
		end
		for _, v in ipairs(char:GetDescendants()) do
			if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
				v.CanCollide = true
			end
		end
	end)

	-- 6) Posprzataj obiekty stworzone przez skrypt
	pcall(function()
		for _, v in ipairs(workspace:GetDescendants()) do
			if v:IsA("BillboardGui") and v.Name == "MobNumberTag" then v:Destroy() end
		end
	end)
	pcall(function()
		local grid = workspace:FindFirstChild("AutoFarm_GridConfig")
		if grid then grid:Destroy() end
	end)
	pcall(function()
		local g = CoreGui:FindFirstChild("TrialAutofarmGUI")
		if g then g:Destroy() end
	end)

	-- 7) Zapisz konfiguracje i zwolnij globale
	pcall(SaveConfig)
	if not silent then
		pcall(function() SendWebhook("Skrypt zostal calkowicie wylaczony (kill switch)", false) end)
	end
	_G.TrialAutoFarmShutdown = nil
end

-- Mozna tez wywolac recznie z konsoli: _G.TrialAutoFarmShutdown()
_G.TrialAutoFarmShutdown = ShutdownScript

-- ===== INTERFEJS GUI (V34 - czytelna typografia, lekki UI) =====
local function CreateGUI()
	local UserInputService = game:GetService("UserInputService")

	-- Paleta o wyzszym kontrascie (WCAG-friendly na ciemnym tle)
	local C = {
		bg      = fromRGB(15, 16, 22),
		panel   = fromRGB(26, 28, 38),
		panel2  = fromRGB(38, 41, 55),
		stroke  = fromRGB(70, 75, 100),
		text    = fromRGB(247, 248, 253),
		sub     = fromRGB(185, 190, 212),
		dim     = fromRGB(150, 156, 180),
		green   = fromRGB(35, 176, 96),
		orange  = fromRGB(214, 112, 26),
		red     = fromRGB(206, 56, 44),
		blue    = fromRGB(70, 110, 245),
		purple  = fromRGB(142, 88, 208),
		teal    = fromRGB(0, 214, 186),
	}

	-- Czcionki: Gotham Bold/Medium = najlepsza czytelnosc w Roblox
	local F_BOLD = Enum.Font.GothamBold
	local F_MED  = Enum.Font.GothamMedium

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
		st.Transparency = (tr == nil) and 0.45 or tr
		st.Parent = inst
		return st
	end

	-- Czytelnosc tekstu: kontur cienia bez dodatkowych instancji
	local function readable(inst, strong)
		inst.TextStrokeColor3 = fromRGB(0, 0, 0)
		inst.TextStrokeTransparency = strong and 0.55 or 0.75
		return inst
	end

	-- Lekki hover: JEDEN tween koloru, zero dodatkowych instancji
	local function hoverable(btn)
		btn.AutoButtonColor = false
		local base
		trackConn(btn.MouseEnter:Connect(function()
			base = btn.BackgroundColor3
			local l = Color3.new(
				math.min(base.R + 0.10, 1),
				math.min(base.G + 0.10, 1),
				math.min(base.B + 0.10, 1)
			)
			TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = l}):Play()
		end))
		trackConn(btn.MouseLeave:Connect(function()
			if base then
				TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = base}):Play()
			end
		end))
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TrialAutofarmGUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = CoreGui

	-- ===== GLOWNA RAMKA =====
	local startW = math.clamp(tonumber(config.GuiW) or 372, 300, 700)
	local startH = math.clamp(tonumber(config.GuiH) or 500, 220, 820)

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "Main"
	mainFrame.Size = UDim2_new(0, startW, 0, startH)
	mainFrame.Position = UDim2_new(0.5, -startW / 2, 0.5, -startH / 2)
	mainFrame.BackgroundColor3 = C.bg
	mainFrame.BorderSizePixel = 0
	mainFrame.Active = true
	mainFrame.Draggable = false -- wlasny drag (Draggable kolidowal z uchwytem resize)
	corner(mainFrame, 14)
	addStroke(mainFrame, C.stroke, 1.4, 0.25)
	mainFrame.Parent = screenGui

	-- Skalowanie calego GUI
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = math.clamp(tonumber(config.GuiScale) or 1, 0.6, 2)
	uiScale.Parent = mainFrame

	-- ===== PASEK TYTULU =====
	local title = Instance.new("Frame")
	title.Name = "Title"
	title.Size = UDim2_new(1, 0, 0, 46)
	title.BackgroundColor3 = C.blue
	title.BorderSizePixel = 0
	title.Active = true
	corner(title, 14)
	title.Parent = mainFrame

	local titleGrad = Instance.new("UIGradient")
	titleGrad.Rotation = 12
	titleGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, fromRGB(48, 82, 214)),
		ColorSequenceKeypoint.new(1, fromRGB(122, 70, 190)),
	})
	titleGrad.Parent = title

	-- maskowanie dolnych zaokraglen paska tytulu
	local titleFix = Instance.new("Frame")
	titleFix.Size = UDim2_new(1, 0, 0, 14)
	titleFix.Position = UDim2_new(0, 0, 1, -14)
	titleFix.BackgroundColor3 = fromRGB(108, 72, 196)
	titleFix.BorderSizePixel = 0
	titleFix.ZIndex = 0
	titleFix.Parent = title

	-- Kropka statusu (zielona = cos dziala, szara = bezczynny)
	local statusDot = Instance.new("Frame")
	statusDot.Size = UDim2_new(0, 10, 0, 10)
	statusDot.Position = UDim2_new(0, 14, 0.5, -5)
	statusDot.BackgroundColor3 = C.dim
	statusDot.BorderSizePixel = 0
	corner(statusDot, 5)
	statusDot.Parent = title

	local titleText = Instance.new("TextLabel")
	titleText.Size = UDim2_new(1, -170, 1, 0)
	titleText.Position = UDim2_new(0, 32, 0, 0)
	titleText.BackgroundTransparency = 1
	titleText.RichText = true
	titleText.Text = "TRIAL AUTO-FARM <font color=\"rgb(214,220,255)\">V37</font>"
	titleText.TextColor3 = fromRGB(255, 255, 255)
	titleText.TextXAlignment = Enum.TextXAlignment.Left
	titleText.Font = F_BOLD
	titleText.TextSize = 16
	titleText.Parent = title
	readable(titleText, true)

	-- Male przyciski w pasku tytulu
	local function titleButton(txt, xOff, w)
		local b = Instance.new("TextButton")
		b.Size = UDim2_new(0, w or 28, 0, 28)
		b.Position = UDim2_new(1, xOff, 0, 9)
		b.BackgroundColor3 = fromRGB(24, 26, 40)
		b.BackgroundTransparency = 0.25
		b.Text = txt
		b.TextColor3 = fromRGB(255, 255, 255)
		b.Font = F_BOLD
		b.TextSize = 16
		b.BorderSizePixel = 0
		corner(b, 8)
		b.Parent = title
		hoverable(b)
		readable(b, true)
		return b
	end

	local minusBtn = titleButton("-", -140)

	local scaleLabel = Instance.new("TextLabel")
	scaleLabel.Size = UDim2_new(0, 46, 0, 28)
	scaleLabel.Position = UDim2_new(1, -110, 0, 9)
	scaleLabel.BackgroundTransparency = 1
	scaleLabel.Text = "100%"
	scaleLabel.TextColor3 = fromRGB(240, 242, 255)
	scaleLabel.Font = F_BOLD
	scaleLabel.TextSize = 13
	scaleLabel.Parent = title
	readable(scaleLabel, true)

	local plusBtn = titleButton("+", -64)
	local minBtn  = titleButton("\226\128\148", -32)

	local function setScale(v, save)
		v = math.clamp(v, 0.6, 2)
		uiScale.Scale = v
		config.GuiScale = v
		scaleLabel.Text = tostring(math.floor(v * 100 + 0.5)) .. "%"
		if save ~= false then SaveConfig() end
	end
	setScale(uiScale.Scale, false)

	trackConn(minusBtn.MouseButton1Click:Connect(function() setScale(uiScale.Scale - 0.1) end))
	trackConn(plusBtn.MouseButton1Click:Connect(function() setScale(uiScale.Scale + 0.1) end))

	-- ===== ZAKLADKI =====
	local tabBar = Instance.new("Frame")
	tabBar.Size = UDim2_new(1, -24, 0, 36)
	tabBar.Position = UDim2_new(0, 12, 0, 54)
	tabBar.BackgroundColor3 = C.panel
	tabBar.BorderSizePixel = 0
	corner(tabBar, 10)
	tabBar.Parent = mainFrame

	local function makeTab(txt, xScale)
		local b = Instance.new("TextButton")
		b.Size = UDim2_new(0.5, -6, 1, -8)
		b.Position = UDim2_new(xScale, xScale == 0 and 4 or 2, 0, 4)
		b.Text = txt
		b.Font = F_BOLD
		b.TextSize = 14
		b.TextColor3 = C.text
		b.BackgroundColor3 = C.panel
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		corner(b, 8)
		b.Parent = tabBar
		readable(b)
		return b
	end

	local mainTabBtn = makeTab("SCIEZKA FARMU", 0)
	local settingsTabBtn = makeTab("USTAWIENIA", 0.5)

	-- ===== KONTENERY ZAKLADEK =====
	local function makeScroll()
		local f = Instance.new("ScrollingFrame")
		f.Size = UDim2_new(1, -24, 1, -146)
		f.Position = UDim2_new(0, 12, 0, 98)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.ScrollBarThickness = 4
		f.ScrollBarImageColor3 = C.stroke
		f.ScrollingDirection = Enum.ScrollingDirection.Y
		f.CanvasSize = UDim2_new(0, 0, 0, 0)
		f.AutomaticCanvasSize = Enum.AutomaticSize.Y
		f.Parent = mainFrame

		local l = Instance.new("UIListLayout")
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, 10)
		l.Parent = f

		local p = Instance.new("UIPadding")
		p.PaddingBottom = UDim.new(0, 12)
		p.PaddingRight = UDim.new(0, 6)
		p.Parent = f
		return f
	end

	local mainTabFrame = makeScroll()
	local settingsTabFrame = makeScroll()
	settingsTabFrame.Visible = false

	local ord = 0
	local function nextOrd()
		ord = ord + 1
		return ord
	end

	-- ===== KARTA SEKCJI =====
	local function makeCard(parent, headerTxt, accent)
		local card = Instance.new("Frame")
		card.Size = UDim2_new(1, 0, 0, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.BackgroundColor3 = C.panel
		card.BorderSizePixel = 0
		card.LayoutOrder = nextOrd()
		corner(card, 12)
		addStroke(card, C.stroke, 1, 0.65)
		card.Parent = parent

		local p = Instance.new("UIPadding")
		p.PaddingTop = UDim.new(0, 10)
		p.PaddingBottom = UDim.new(0, 10)
		p.PaddingLeft = UDim.new(0, 10)
		p.PaddingRight = UDim.new(0, 10)
		p.Parent = card

		local l = Instance.new("UIListLayout")
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Padding = UDim.new(0, 8)
		l.Parent = card

		if headerTxt then
			local head = Instance.new("Frame")
			head.Size = UDim2_new(1, 0, 0, 18)
			head.LayoutOrder = nextOrd()
			head.BackgroundTransparency = 1
			head.Parent = card

			local bar = Instance.new("Frame")
			bar.Size = UDim2_new(0, 3, 0, 14)
			bar.Position = UDim2_new(0, 0, 0, 2)
			bar.BackgroundColor3 = accent or C.blue
			bar.BorderSizePixel = 0
			corner(bar, 2)
			bar.Parent = head

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2_new(1, -12, 1, 0)
			lbl.Position = UDim2_new(0, 12, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = headerTxt
			lbl.TextColor3 = accent or C.sub
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Font = F_BOLD
			lbl.TextSize = 13
			lbl.Parent = head
			readable(lbl)
		end

		return card
	end

	-- ===== FABRYKI ELEMENTOW =====
	local function actionButton(parent, h, txt, color, textSize)
		local b = Instance.new("TextButton")
		b.Size = UDim2_new(1, 0, 0, h)
		b.LayoutOrder = nextOrd()
		b.Text = txt
		b.Font = F_BOLD
		b.TextSize = textSize or 15
		b.TextColor3 = fromRGB(255, 255, 255)
		b.BackgroundColor3 = color
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		corner(b, 10)
		b.Parent = parent
		hoverable(b)
		readable(b, true)
		return b
	end

	-- ===== STOPKA: KILL SWITCH (zawsze widoczny) =====
	local footer = Instance.new("Frame")
	footer.Size = UDim2_new(1, -24, 0, 38)
	footer.Position = UDim2_new(0, 12, 1, -48)
	footer.BackgroundTransparency = 1
	footer.Parent = mainFrame

	local killBtn = Instance.new("TextButton")
	killBtn.Name = "KillSwitch"
	killBtn.Size = UDim2_new(1, -28, 1, 0)
	killBtn.BackgroundColor3 = C.red
	killBtn.Text = "\240\159\155\145  WYLACZ SKRYPT CALKOWICIE"
	killBtn.TextColor3 = fromRGB(255, 255, 255)
	killBtn.Font = F_BOLD
	killBtn.TextSize = 14
	killBtn.BorderSizePixel = 0
	killBtn.AutoButtonColor = false
	corner(killBtn, 10)
	killBtn.Parent = footer
	hoverable(killBtn)
	readable(killBtn, true)

	-- ===== ZAKLADKA: SCIEZKA FARMU =====
	local statusCard = makeCard(mainTabFrame, "STATUS TRIALA", C.teal)

	singleTimerLabelRef = Instance.new("TextLabel")
	singleTimerLabelRef.Size = UDim2_new(1, 0, 0, 34)
	singleTimerLabelRef.LayoutOrder = nextOrd()
	singleTimerLabelRef.BackgroundTransparency = 1
	singleTimerLabelRef.Text = "Inicjalizacja systemu timerow..."
	singleTimerLabelRef.TextColor3 = C.teal
	singleTimerLabelRef.TextXAlignment = Enum.TextXAlignment.Left
	singleTimerLabelRef.TextYAlignment = Enum.TextYAlignment.Top
	singleTimerLabelRef.Font = F_BOLD
	singleTimerLabelRef.TextSize = 14
	singleTimerLabelRef.TextWrapped = true
	singleTimerLabelRef.Parent = statusCard
	readable(singleTimerLabelRef, true)

	local trialCard = makeCard(mainTabFrame, "TRIAL", C.blue)
	local trialBtn   = actionButton(trialCard, 38, "Trial: " .. config.SelectedTrial, C.blue, 15)
	local savePosBtn = actionButton(trialCard, 34, "\240\159\147\140  Zapisz Pozycje Bazy", C.purple, 14)
	farmBtnRef       = actionButton(trialCard, 48, "\226\150\182 Start AutoFarm", C.green, 18)
	local chestBtn   = actionButton(trialCard, 34, "Auto Chest: OFF", C.red, 14)

	local combatCard = makeCard(mainTabFrame, "COMBAT FARM", fromRGB(255, 128, 128))
	combatBtnRef = actionButton(combatCard, 42, "\226\150\182 Start Combat Farm", C.green, 16)

	local statusPill = Instance.new("Frame")
	statusPill.Size = UDim2_new(1, 0, 0, 28)
	statusPill.LayoutOrder = nextOrd()
	statusPill.BackgroundColor3 = C.panel2
	statusPill.BorderSizePixel = 0
	corner(statusPill, 8)
	statusPill.Parent = combatCard

	combatStatusLabelRef = Instance.new("TextLabel")
	combatStatusLabelRef.Size = UDim2_new(1, -16, 1, 0)
	combatStatusLabelRef.Position = UDim2_new(0, 8, 0, 0)
	combatStatusLabelRef.BackgroundTransparency = 1
	combatStatusLabelRef.Text = "Status: Nieaktywny"
	combatStatusLabelRef.TextColor3 = C.sub
	combatStatusLabelRef.TextXAlignment = Enum.TextXAlignment.Left
	combatStatusLabelRef.Font = F_MED
	combatStatusLabelRef.TextSize = 13
	combatStatusLabelRef.Parent = statusPill
	readable(combatStatusLabelRef)

	-- ===== V37: KARTA STAR FARM =====
	local starCard = makeCard(mainTabFrame, "STAR FARM (ClientStars)", fromRGB(255, 214, 102))
	starBtnRef = actionButton(starCard, 42, "\226\173\144 Start Star Farm", C.green, 16)

	local starPill = Instance.new("Frame")
	starPill.Size = UDim2_new(1, 0, 0, 28)
	starPill.LayoutOrder = nextOrd()
	starPill.BackgroundColor3 = C.panel2
	starPill.BorderSizePixel = 0
	corner(starPill, 8)
	starPill.Parent = starCard

	starStatusLabelRef = Instance.new("TextLabel")
	starStatusLabelRef.Size = UDim2_new(1, -16, 1, 0)
	starStatusLabelRef.Position = UDim2_new(0, 8, 0, 0)
	starStatusLabelRef.BackgroundTransparency = 1
	starStatusLabelRef.Text = "Status: Nieaktywny"
	starStatusLabelRef.TextColor3 = C.sub
	starStatusLabelRef.TextXAlignment = Enum.TextXAlignment.Left
	starStatusLabelRef.Font = F_MED
	starStatusLabelRef.TextSize = 13
	starStatusLabelRef.Parent = starPill
	readable(starStatusLabelRef)

	local starPrioLabel = Instance.new("TextLabel")
	starPrioLabel.Size = UDim2_new(1, 0, 0, 16)
	starPrioLabel.LayoutOrder = nextOrd()
	starPrioLabel.BackgroundTransparency = 1
	starPrioLabel.Text = "Priorytet: Lunar > Alien > Plasma > Normal"
	starPrioLabel.TextColor3 = C.dim
	starPrioLabel.TextXAlignment = Enum.TextXAlignment.Left
	starPrioLabel.Font = F_MED
	starPrioLabel.TextSize = 12
	starPrioLabel.Parent = starCard
	readable(starPrioLabel)

	local function UpdateChestButton()
		if config.AutoChestType == "None" then
			chestBtn.Text = "Auto Chest: OFF"
			chestBtn.BackgroundColor3 = C.red
		elseif config.AutoChestType == "T1" then
			chestBtn.Text = "Auto Chest: T1"
			chestBtn.BackgroundColor3 = C.green
		else
			chestBtn.Text = "Auto Chest: T2"
			chestBtn.BackgroundColor3 = C.purple
		end
	end
	UpdateChestButton()

	-- ===== ZAKLADKA: USTAWIENIA =====
	local paramsCard = makeCard(settingsTabFrame, "PARAMETRY FARMU", C.blue)

	local function CreateInput(labelStr, default)
		local holder = Instance.new("Frame")
		holder.Size = UDim2_new(1, 0, 0, 52)
		holder.LayoutOrder = nextOrd()
		holder.BackgroundTransparency = 1
		holder.Parent = paramsCard

		local label = Instance.new("TextLabel")
		label.Size = UDim2_new(1, 0, 0, 16)
		label.BackgroundTransparency = 1
		label.Text = labelStr
		label.TextColor3 = C.sub
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Font = F_MED
		label.TextSize = 12
		label.Parent = holder
		readable(label)

		local box = Instance.new("TextBox")
		box.Size = UDim2_new(1, 0, 0, 32)
		box.Position = UDim2_new(0, 0, 0, 19)
		box.BackgroundColor3 = C.panel2
		box.TextColor3 = C.text
		box.PlaceholderColor3 = C.dim
		box.Text = default
		box.Font = F_BOLD
		box.TextSize = 14
		box.ClearTextOnFocus = false
		box.BorderSizePixel = 0
		corner(box, 8)
		addStroke(box, C.stroke, 1, 0.55)
		box.Parent = holder
		readable(box)
		return box
	end

	local speedBox    = CreateInput("Predkosc lotu (Trial)", tostring(config.Speed))
	local cooldownBox = CreateInput("Cooldown po zabiciu", tostring(config.Cooldown))
	local waveWaitBox = CreateInput("Czas na nowa fale", tostring(config.WaveWaitTime))
	local ghostYBox   = CreateInput("Wysokosc Ghost Mode (Y)", tostring(config.GhostModeY))
	local startSecBox = CreateInput("Teleport gdy <= X sek (otwarty portal)", tostring(config.TimeToStartSec))
	local combatYBox  = CreateInput("Wysokosc Combat Ghost (Y)", tostring(config.CombatGhostY))
	local starHoldBox = CreateInput("Postoj przy gwiazdce (sekundy)", tostring(config.StarHoldTime))
	local starCdBox   = CreateInput("Przerwa miedzy gwiazdkami (sekundy)", tostring(config.StarSkipCooldown))

	local combatInfoLabel = Instance.new("TextLabel")
	combatInfoLabel.Size = UDim2_new(1, 0, 0, 34)
	combatInfoLabel.LayoutOrder = nextOrd()
	combatInfoLabel.BackgroundTransparency = 1
	combatInfoLabel.Text = "Combat Farm uzywa predkosci i cooldownu Triala, ale ma WLASNA wysokosc (Combat Ghost Y)."
	combatInfoLabel.TextColor3 = C.dim
	combatInfoLabel.TextWrapped = true
	combatInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
	combatInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
	combatInfoLabel.Font = F_MED
	combatInfoLabel.TextSize = 12
	combatInfoLabel.Parent = paramsCard
	readable(combatInfoLabel)

	local posCard = makeCard(settingsTabFrame, "POZYCJA BAZY", C.purple)
	savedCoordsLabelRef = Instance.new("TextLabel")
	savedCoordsLabelRef.Size = UDim2_new(1, 0, 0, 20)
	savedCoordsLabelRef.LayoutOrder = nextOrd()
	savedCoordsLabelRef.BackgroundTransparency = 1
	savedCoordsLabelRef.Text = savedPosition
		and string.format("Zapisane Kordynaty: %.1f, %.1f, %.1f", savedPosition.X, savedPosition.Y, savedPosition.Z)
		or "Zapisane Kordynaty: Brak"
	savedCoordsLabelRef.TextColor3 = fromRGB(198, 160, 246)
	savedCoordsLabelRef.TextXAlignment = Enum.TextXAlignment.Left
	savedCoordsLabelRef.Font = F_BOLD
	savedCoordsLabelRef.TextSize = 13
	savedCoordsLabelRef.Parent = posCard
	readable(savedCoordsLabelRef)

	local clearSavedPosBtn = actionButton(posCard, 30, "Usun zapisane kordynaty", C.red, 13)

	local mobCard = makeCard(settingsTabFrame, "MOBY DO FARMIENIA", C.green)
	local mobContainer = Instance.new("ScrollingFrame")
	mobContainer.Name = "MobContainer"
	mobContainer.Size = UDim2_new(1, 0, 0, 148)
	mobContainer.LayoutOrder = nextOrd()
	mobContainer.BackgroundColor3 = fromRGB(20, 22, 30)
	mobContainer.BorderSizePixel = 0
	mobContainer.ScrollBarThickness = 4
	mobContainer.ScrollBarImageColor3 = C.stroke
	mobContainer.CanvasSize = UDim2_new(0, 0, 0, 0)
	mobContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	corner(mobContainer, 9)
	mobContainer.Parent = mobCard

	local mobPad = Instance.new("UIPadding")
	mobPad.PaddingTop = UDim.new(0, 7)
	mobPad.PaddingBottom = UDim.new(0, 7)
	mobPad.PaddingLeft = UDim.new(0, 7)
	mobPad.PaddingRight = UDim.new(0, 7)
	mobPad.Parent = mobContainer

	local mobListLayout = Instance.new("UIGridLayout")
	mobListLayout.CellSize = UDim2_new(0.5, -5, 0, 30)
	mobListLayout.CellPadding = UDim2_new(0, 6, 0, 6)
	mobListLayout.Parent = mobContainer

	local MOB_OFF = fromRGB(58, 44, 52)
	for _, mobName in ipairs(MOBS) do
		local btn = Instance.new("TextButton")
		btn.Name = "Mob_" .. mobName
		btn.Text = mobName
		btn.Font = F_BOLD
		btn.TextSize = 12
		btn.TextScaled = false
		btn.TextColor3 = fromRGB(255, 255, 255)
		btn.BorderSizePixel = 0
		btn.AutoButtonColor = false
		local isActive = config.SelectedMobs[mobName] == true
		btn.BackgroundColor3 = isActive and C.green or MOB_OFF
		corner(btn, 7)
		btn.Parent = mobContainer
		readable(btn, true)
		trackConn(btn.MouseButton1Click:Connect(function()
			config.SelectedMobs[mobName] = not (config.SelectedMobs[mobName] or false)
			btn.BackgroundColor3 = config.SelectedMobs[mobName] and C.green or MOB_OFF
			SaveConfig()
		end))
	end

	local uiCard = makeCard(settingsTabFrame, "INTERFEJS", C.teal)

	local scaleRow = Instance.new("Frame")
	scaleRow.Size = UDim2_new(1, 0, 0, 32)
	scaleRow.LayoutOrder = nextOrd()
	scaleRow.BackgroundTransparency = 1
	scaleRow.Parent = uiCard

	local function rowButton(txt, xScale, xOff)
		local b = Instance.new("TextButton")
		b.Size = UDim2_new(0.5, -4, 1, 0)
		b.Position = UDim2_new(xScale, xOff, 0, 0)
		b.Text = txt
		b.Font = F_BOLD
		b.TextSize = 13
		b.TextColor3 = fromRGB(255, 255, 255)
		b.BackgroundColor3 = C.panel2
		b.BorderSizePixel = 0
		b.AutoButtonColor = false
		corner(b, 8)
		b.Parent = scaleRow
		hoverable(b)
		readable(b)
		return b
	end
	local scaleDownBtn = rowButton("-  Pomniejsz GUI", 0, 0)
	local scaleUpBtn   = rowButton("+  Powieksz GUI", 0.5, 4)

	local fontBtn    = actionButton(uiCard, 32, "Czcionka: Standard", C.panel2, 13)
	local resetBtn   = actionButton(uiCard, 30, "Reset rozmiaru i skali GUI", C.panel2, 13)
	local hideGuiBtn = actionButton(uiCard, 30, "Ukryj GUI (pokaz: klawisz L)", C.panel2, 13)

	-- ===== SYSTEM POWIEKSZANIA CZCIONKI =====
	-- Zapamietuje bazowy TextSize kazdego elementu i dodaje wybrany bonus.
	local textNodes = {}
	for _, d in ipairs(mainFrame:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			textNodes[#textNodes + 1] = {obj = d, base = d.TextSize}
		end
	end

	local FONT_STEPS = {0, 2, 4}
	local FONT_NAMES = {"Standard", "Duza", "Bardzo duza"}
	local fontStep = math.clamp(tonumber(config.FontStep) or 1, 1, 3)

	local function applyFont(step, save)
		fontStep = math.clamp(step, 1, 3)
		local bonus = FONT_STEPS[fontStep]
		for _, n in ipairs(textNodes) do
			if n.obj.Parent then n.obj.TextSize = n.base + bonus end
		end
		fontBtn.Text = "Czcionka: " .. FONT_NAMES[fontStep]
		config.FontStep = fontStep
		if save ~= false then SaveConfig() end
	end
	applyFont(fontStep, false)

	trackConn(fontBtn.MouseButton1Click:Connect(function()
		applyFont(fontStep % 3 + 1)
	end))

	-- ===== ZAKLADKI / MINIMALIZACJA =====
	local currentTabIsMain = true
	local isMinimized = false
	local expandedSize = mainFrame.Size

	local function setTab(main)
		currentTabIsMain = main
		mainTabFrame.Visible = main
		settingsTabFrame.Visible = not main
		mainTabBtn.BackgroundColor3 = main and C.blue or C.panel
		settingsTabBtn.BackgroundColor3 = main and C.panel or C.blue
		mainTabBtn.TextColor3 = main and fromRGB(255, 255, 255) or C.dim
		settingsTabBtn.TextColor3 = main and C.dim or fromRGB(255, 255, 255)
	end
	trackConn(mainTabBtn.MouseButton1Click:Connect(function() setTab(true) end))
	trackConn(settingsTabBtn.MouseButton1Click:Connect(function() setTab(false) end))

	local resizeHandle -- forward

	local function setMinimized(min)
		isMinimized = min
		tabBar.Visible = not min
		footer.Visible = not min
		if resizeHandle then resizeHandle.Visible = not min end
		if min then
			mainTabFrame.Visible = false
			settingsTabFrame.Visible = false
			mainFrame.Size = UDim2_new(0, expandedSize.X.Offset, 0, 46)
			minBtn.Text = "+"
		else
			mainFrame.Size = expandedSize
			setTab(currentTabIsMain)
			minBtn.Text = "\226\128\148"
		end
	end
	trackConn(minBtn.MouseButton1Click:Connect(function() setMinimized(not isMinimized) end))

	-- ===== UCHWYT ZMIANY ROZMIARU =====
	resizeHandle = Instance.new("TextButton")
	resizeHandle.Name = "ResizeHandle"
	resizeHandle.Size = UDim2_new(0, 22, 0, 22)
	resizeHandle.Position = UDim2_new(1, -24, 1, -24)
	resizeHandle.BackgroundColor3 = C.panel2
	resizeHandle.Text = "\226\151\162"
	resizeHandle.TextColor3 = C.sub
	resizeHandle.Font = F_BOLD
	resizeHandle.TextSize = 13
	resizeHandle.BorderSizePixel = 0
	resizeHandle.AutoButtonColor = false
	resizeHandle.ZIndex = 8
	corner(resizeHandle, 7)
	resizeHandle.Parent = mainFrame
	hoverable(resizeHandle)

	-- ===== DRAG + RESIZE =====
	local dragging, dragStart, dragStartPos = false, nil, nil
	local resizing, resizeStart, resizeStartSize = false, nil, nil

	local function isDragInput(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	trackConn(title.InputBegan:Connect(function(input)
		if not isDragInput(input) then return end
		dragging = true
		dragStart = input.Position
		dragStartPos = mainFrame.Position
	end))

	trackConn(resizeHandle.InputBegan:Connect(function(input)
		if not isDragInput(input) or isMinimized then return end
		resizing = true
		resizeStart = input.Position
		resizeStartSize = Vector2.new(mainFrame.Size.X.Offset, mainFrame.Size.Y.Offset)
	end))

	trackConn(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if dragging and dragStart then
			local d = input.Position - dragStart
			mainFrame.Position = UDim2_new(
				dragStartPos.X.Scale, dragStartPos.X.Offset + d.X,
				dragStartPos.Y.Scale, dragStartPos.Y.Offset + d.Y
			)
		elseif resizing and resizeStart then
			local d = input.Position - resizeStart
			local s = uiScale.Scale
			local w = math.clamp(resizeStartSize.X + d.X / s, 300, 700)
			local h = math.clamp(resizeStartSize.Y + d.Y / s, 220, 820)
			mainFrame.Size = UDim2_new(0, w, 0, h)
			expandedSize = mainFrame.Size
			config.GuiW = math.floor(w)
			config.GuiH = math.floor(h)
		end
	end))

	trackConn(UserInputService.InputEnded:Connect(function(input)
		if not isDragInput(input) then return end
		if resizing then SaveConfig() end
		dragging = false
		resizing = false
	end))

	-- Klawisz L: ukryj / pokaz GUI
	trackConn(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.L then
			mainFrame.Visible = not mainFrame.Visible
		end
	end))

	-- ===== KROPKA STATUSU (lekko: co 1 s, bez per-klatka) =====
	task.spawn(function()
		while _G.TrialAutoFarmRunning and statusDot.Parent do
			local active = config.IsFarming or combatConfig.IsCombatFarming
			statusDot.BackgroundColor3 = active and fromRGB(70, 235, 140) or C.dim
			task.wait(1)
		end
	end)

	-- ===== POLACZENIA USTAWIEN =====
	trackConn(speedBox.FocusLost:Connect(function() config.Speed = tonumber(speedBox.Text) or config.Speed; speedBox.Text = tostring(config.Speed); SaveConfig() end))
	trackConn(cooldownBox.FocusLost:Connect(function() config.Cooldown = tonumber(cooldownBox.Text) or config.Cooldown; cooldownBox.Text = tostring(config.Cooldown); SaveConfig() end))
	trackConn(waveWaitBox.FocusLost:Connect(function() config.WaveWaitTime = tonumber(waveWaitBox.Text) or config.WaveWaitTime; waveWaitBox.Text = tostring(config.WaveWaitTime); SaveConfig() end))
	trackConn(ghostYBox.FocusLost:Connect(function() config.GhostModeY = tonumber(ghostYBox.Text) or config.GhostModeY; ghostYBox.Text = tostring(config.GhostModeY); SaveConfig() end))
	trackConn(combatYBox.FocusLost:Connect(function() config.CombatGhostY = tonumber(combatYBox.Text) or config.CombatGhostY; combatYBox.Text = tostring(config.CombatGhostY); SaveConfig() end))
	trackConn(starHoldBox.FocusLost:Connect(function() config.StarHoldTime = tonumber(starHoldBox.Text) or config.StarHoldTime; if config.StarHoldTime < 0 then config.StarHoldTime = 0 end; starHoldBox.Text = tostring(config.StarHoldTime); SaveConfig() end))
	trackConn(starCdBox.FocusLost:Connect(function() config.StarSkipCooldown = tonumber(starCdBox.Text) or config.StarSkipCooldown; if config.StarSkipCooldown < 0 then config.StarSkipCooldown = 0 end; starCdBox.Text = tostring(config.StarSkipCooldown); SaveConfig() end))
	trackConn(startSecBox.FocusLost:Connect(function() config.TimeToStartSec = tonumber(startSecBox.Text) or config.TimeToStartSec; startSecBox.Text = tostring(config.TimeToStartSec); SaveConfig() end))

	trackConn(scaleDownBtn.MouseButton1Click:Connect(function() setScale(uiScale.Scale - 0.1) end))
	trackConn(scaleUpBtn.MouseButton1Click:Connect(function() setScale(uiScale.Scale + 0.1) end))

	trackConn(resetBtn.MouseButton1Click:Connect(function()
		setScale(1, false)
		applyFont(1, false)
		mainFrame.Size = UDim2_new(0, 372, 0, 500)
		expandedSize = mainFrame.Size
		config.GuiW, config.GuiH = 372, 500
		SaveConfig()
	end))

	trackConn(hideGuiBtn.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
	end))

	trackConn(clearSavedPosBtn.MouseButton1Click:Connect(function()
		savedPosition = nil
		SaveConfig()
		if savedCoordsLabelRef then
			savedCoordsLabelRef.Text = "Zapisane Kordynaty: Brak"
		end
		clearSavedPosBtn.Text = "Usunieto!"
		clearSavedPosBtn.BackgroundColor3 = C.green
		task.delay(1.5, function()
			if clearSavedPosBtn.Parent then
				clearSavedPosBtn.Text = "Usun zapisane kordynaty"
				clearSavedPosBtn.BackgroundColor3 = C.red
			end
		end)
	end))

	trackConn(trialBtn.MouseButton1Click:Connect(function()
		if config.IsFarming then return end
		if config.SelectedTrial == "Easy" then config.SelectedTrial = "Medium"
		elseif config.SelectedTrial == "Medium" then config.SelectedTrial = "Hard"
		else config.SelectedTrial = "Easy" end
		trialBtn.Text = "Trial: " .. config.SelectedTrial
		SaveConfig()
	end))

	trackConn(savePosBtn.MouseButton1Click:Connect(function()
		local hrp = GetHRP()
		if not hrp then return end
		savedPosition = hrp.CFrame
		SaveConfig()
		if savedCoordsLabelRef then
			savedCoordsLabelRef.Text = string.format("Zapisane Kordynaty: %.1f, %.1f, %.1f", savedPosition.X, savedPosition.Y, savedPosition.Z)
		end
		savePosBtn.Text = "Pozycja Zapisana!"
		savePosBtn.BackgroundColor3 = C.green
		task.delay(1.5, function()
			if savePosBtn.Parent then
				savePosBtn.Text = "\240\159\147\140  Zapisz Pozycje Bazy"
				savePosBtn.BackgroundColor3 = C.purple
			end
		end)
	end))

	trackConn(farmBtnRef.MouseButton1Click:Connect(function()
		ToggleFarming(not config.IsFarming)
	end))

	trackConn(chestBtn.MouseButton1Click:Connect(function()
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
	end))

	trackConn(combatBtnRef.MouseButton1Click:Connect(function()
		ToggleCombatFarming(not combatConfig.IsCombatFarming)
	end))

	trackConn(starBtnRef.MouseButton1Click:Connect(function()
		ToggleStarFarming(not starConfig.IsStarFarming)
	end))

	-- ===== KILL SWITCH (2 klikniecia = potwierdzenie) =====
	local killArmed = false
	trackConn(killBtn.MouseButton1Click:Connect(function()
		if not killArmed then
			killArmed = true
			killBtn.Text = "\226\154\160 KLIKNIJ PONOWNIE ABY WYLACZYC"
			killBtn.BackgroundColor3 = C.orange
			task.delay(3, function()
				if killArmed and killBtn.Parent then
					killArmed = false
					killBtn.Text = "\240\159\155\145  WYLACZ SKRYPT CALKOWICIE"
					killBtn.BackgroundColor3 = C.red
				end
			end)
			return
		end
		killBtn.Text = "Wylaczanie..."
		killBtn.BackgroundColor3 = C.panel2
		task.defer(ShutdownScript)
	end))

	setTab(true)
end

CreateGUI()
