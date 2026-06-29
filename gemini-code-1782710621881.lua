-- p1_v4.0.lua - Rebirth Engine - Modern Modular UI Framework [UI-FIRST ARCHITECTURE + EXTREME OPTIMIZATION + HYBRID MOVEMENT]
local Players = game:GetService("Players"); local HS = game:GetService("HttpService")
local RS = game:GetService("RunService"); local VU = game:GetService("VirtualUser")
local RepS = game:GetService("ReplicatedStorage"); local WS = game:GetService("Workspace")
local player = Players.LocalPlayer; local scriptRunning = true
local env = getgenv and getgenv() or _G

local function n(v, d) return v == nil and d or v end
local function t(v) return type(v) == "table" and v or {} end
local function fire(...) local r = RepS:FindFirstChild("__Net"); r = r and r:FindFirstChild("MainRemote"); if r then pcall(r.FireServer, r, ...) end end
local function tw(x) task.wait(x) end; local function go(f) task.spawn(f) end

env.SqaysConfig = env.SqaysConfig or {}
local C = env.SqaysConfig

local cfg = {
    MiningSpeed=0.01, TierSpeed=0.5, RuneSpeed=0.5, TreeSpeed=0.5, WaterPumpSpeed=0.5, IceConvertSpeed=0.5,
    AshConvertSpeed=1.0, BlazeQuestSpeed=5.0, ExchangeGemsSpeed=10.0, SelectedIceLevel=0, 
    MiningTarget="Voidsteel + Celestium + Aetherite + Ruby Loop", MovementMethod="Walking",
    AutoUpgradeNoob=false, AutoUpgradeGems=false, AutoUpgradePlanks=false, AutoUpgradeWater=false,
    UpgradeNoobSpeed=1, UpgradeGemsSpeed=1, UpgradePlanksSpeed=1, UpgradeWaterSpeed=1,
    AutoRollTier=false, AutoHitTree=false, AutoWaterPump=false, AutoBlazeQuest=false,
    AutoConvertWoodToAsh=false, AutoExchangeGems=false, AutoRollRunes=false, AntiAFK=false
}
for k, v in pairs(cfg) do C[k] = n(C[k], v) end

C.SelectedNoobUpgrades = t(C.SelectedNoobUpgrades); C.SelectedGemUpgrades = t(C.SelectedGemUpgrades)
C.SelectedPlankUpgrades = t(C.SelectedPlankUpgrades); C.SelectedWaterUpgrades = t(C.SelectedWaterUpgrades)

local Settings = {CustomWalkSpeed=160, WaitTimeOnOre=0.50, UseNoclip=false, UITheme="Darker", UIAcrylic=true, UIAccentColor=Color3.fromRGB(150,150,255)}
local looping, total, last5, d5, est, cel, vs, aeth, ruby, rt, h5 = false, 0, 0, 0, 0, 0, 0, 0, 0, 0, {}
local RNames = {"Basic", "Super", "Advanced", "Cosmic Prism", "Hacker", "Snowy", "Deepcore"}
local GNames = {"All","Coal","Iron","Sliver","Gold","Platinum","Titanium","Emerald","Diamond","Opal","Jade","Amber","Topaz","Ruby","Amethyst","Quartz","Sapphire","Uranium","Crystal","Obsidian"}
local RSet, GToEx, GMap = {}, {}, {}
for _, nm in ipairs(RNames) do RSet[nm] = false end
local saveFile, presetFile = "p1_Rebirth_Storage.json", "p1_GUI_Presets.json"

local function save() pcall(function() if writefile then writefile(saveFile, HS:JSONEncode({C=C,S=Settings,R=RSet,G=GMap})) end end) end
pcall(function() if readfile and isfile and isfile(saveFile) then local d=HS:JSONDecode(readfile(saveFile)); if d then if d.C then for k,v in pairs(d.C) do C[k]=v end end; if d.S then for k,v in pairs(d.S) do Settings[k]=v end end; if d.R then for k,v in pairs(d.R) do RSet[k]=v end end; if d.G then for k,v in pairs(d.G) do GMap[k]=v end end end end end)
C.SelectedNoobUpgrades=t(C.SelectedNoobUpgrades);C.SelectedGemUpgrades=t(C.SelectedGemUpgrades);C.SelectedPlankUpgrades=t(C.SelectedPlankUpgrades);C.SelectedWaterUpgrades=t(C.SelectedWaterUpgrades)
local function rbGems() table.clear(GToEx); for k,v in pairs(GMap) do if v then table.insert(GToEx,k) end end end; rbGems()
for k,v in pairs(C) do _G[k] = v end

local routes = {
    ["Voidsteel + Celestium + Aetherite + Ruby Loop"] = {
        {n="V1",p=Vector3.new(699.21,7.74,2827.68)},{n="V2",p=Vector3.new(683.25,7.74,2858.61)},{n="V3",p=Vector3.new(705.66,7.74,2852.43)},{n="V4",p=Vector3.new(723.42,7.74,2874.51)},{n="V5",p=Vector3.new(727.90,7.74,2836.23)},
        {n="C4",p=Vector3.new(725.19,7.87,2804.33)},{n="C5",p=Vector3.new(730.71,7.87,2780.08)},{n="C3",p=Vector3.new(713.99,7.87,2764.92)},{n="C2",p=Vector3.new(687.15,7.87,2772.15)},{n="C1",p=Vector3.new(692.65,7.87,2799.67)},
        {n="A5",p=Vector3.new(659.25,7.34,2783.24)},{n="A4",p=Vector3.new(645.36,7.34,2760.03)},{n="A3",p=Vector3.new(611.97,7.34,2769.11)},{n="A2",p=Vector3.new(593.95,7.34,2790.59)},{n="A1",p=Vector3.new(628.22,7.34,2793.83)},
        {n="R4",p=Vector3.new(621.25,9.18,2840.62)},{n="R1",p=Vector3.new(598.23,9.18,2856.87)},{n="R2",p=Vector3.new(616.18,9.72,2871.34)},{n="R3",p=Vector3.new(641.74,9.18,2870.04)},{n="R5",p=Vector3.new(652.05,9.18,2845.19)}
    },
    ["Voidsteel + Celestium Loop"] = {
        {n="C4",p=Vector3.new(725.19,7.87,2804.33)},{n="C5",p=Vector3.new(730.71,7.87,2780.08)},{n="C3",p=Vector3.new(713.99,7.87,2764.92)},{n="C2",p=Vector3.new(687.15,7.87,2772.15)},{n="C1",p=Vector3.new(692.65,7.87,2799.67)},
        {n="V1",p=Vector3.new(699.21,7.74,2827.68)},{n="V2",p=Vector3.new(683.25,7.74,2858.61)},{n="V4",p=Vector3.new(723.42,7.74,2874.51)},{n="V3",p=Vector3.new(705.66,7.74,2852.43)},{n="V5",p=Vector3.new(727.90,7.74,2836.23)}
    }
}

local req = request or http_request or (syn and syn.request)
local function hook()
    if not req or not looping then return end
    local tr = "0%"; local cH = total - (h5[#h5-12] or h5[1] or 0); local pH = (h5[#h5-12] or 0) - (h5[#h5-24] or 0)
    if pH>0 then local d=cH-pH; tr=string.format("%.1f%%",(d/pH)*100); if d>0 then tr="+"..tr end elseif cH>0 and pH==0 then tr="+100% 📈" end
    pcall(function() req({Url="https://discord.com/api/webhooks/1365446577895899146/SxMWrfvAneXfOZlDCrSGcEQEt7etkcOyV4B_to-3EdESavkbefwPFo3L9L_W-kJVFbxG", Method="POST", Headers={["Content-Type"]="application/json"}, Body=HS:JSONEncode({embeds={{title="⚡ p1 Engine", color=16724636, fields={{name="⏳ Runtime", value=string.format("`%dh %dm`",math.floor(rt/3600),math.floor((rt%3600)/60)), inline=true},{name="🔋 Total", value="`"..total.."`", inline=true},{name="📈 Rate", value="`"..est.."/h`", inline=true},{name="⏱️ Last 5m", value="`"..d5.."`", inline=true},{name="📊 Trend", value="`"..tr.."`", inline=true},{name="💎 Cel", value="`"..cel.."`", inline=true},{name="💜 Void", value="`"..vs.."`", inline=true},{name="💙 Aeth", value="`"..aeth.."`", inline=true},{name="❤️ Ruby", value="`"..ruby.."`", inline=true}}, footer={text="p1 v4.0"}, timestamp=DateTime.now():ToIsoDate()}}})}) end)
end

local nC, aC, fY
local function nc()
    Settings.UseNoclip=true; local c=player.Character or player.CharacterAdded:Wait(); local h=c:WaitForChild("HumanoidRootPart"); local hum=c:WaitForChild("Humanoid"); fY=h.Position.Y; hum.JumpPower=0; hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
    if not nC then nC=RS.Stepped:Connect(function() if Settings.UseNoclip and player.Character then for _,v in pairs(player.Character:GetDescendants()) do if v:IsA('BasePart') and v.CanCollide then v.CanCollide=false end end end end) end
    if not aC then aC=RS.Heartbeat:Connect(function() if Settings.UseNoclip and c and h and hum then hum.Jump=false; if math.abs(h.Position.Y-fY)>0.5 then h.CFrame=CFrame.new(Vector3.new(h.Position.X,fY,h.Position.Z))*h.CFrame.Rotation end; h.AssemblyLinearVelocity=Vector3.new(h.AssemblyLinearVelocity.X,0,h.AssemblyLinearVelocity.Z) end end) end
end
local function cp() Settings.UseNoclip=false; if nC then nC:Disconnect() nC=nil end; if aC then aC:Disconnect() aC=nil end; local c=player.Character; if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpPower=50; c.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end end
local aI; local function sAfk(e) C.AntiAFK=e; _G.AntiAFK=e; if aI then aI:Disconnect() aI=nil end; if not e then return end; aI=player.Idled:Connect(function() if scriptRunning then pcall(function() VU:CaptureController(); VU:ClickButton2(Vector2.new()) end) end end) end

local function mv(p, h)
    if C.MovementMethod=="Teleport" then h.CFrame=CFrame.new(Vector3.new(p.X,h.Position.Y,p.Z))*h.CFrame.Rotation; h.AssemblyLinearVelocity=Vector3.new(0,h.AssemblyLinearVelocity.Y,0) return end
    local s, hum = Settings.CustomWalkSpeed, h.Parent:FindFirstChildOfClass("Humanoid"); if hum then hum.AutoRotate=false end; h.AssemblyLinearVelocity=Vector3.new(0,h.AssemblyLinearVelocity.Y,0)
    while scriptRunning do
        if not looping or C.MovementMethod=="Teleport" then break end
        local cP, df = h.Position, Vector3.new(p.X-h.Position.X,0,p.Z-h.Position.Z); local d, st = df.Magnitude, s * RS.Heartbeat:Wait()
        if d<=st or d<1.2 then h.CFrame=CFrame.new(Vector3.new(p.X,cP.Y,p.Z))*h.CFrame.Rotation; h.AssemblyLinearVelocity=Vector3.new(0,h.AssemblyLinearVelocity.Y,0) break end
        h.CFrame=CFrame.lookAt(cP+(df.Unit*st), Vector3.new(p.X,cP.Y,p.Z))
    end
    if hum then hum.AutoRotate=true end
end

local Fl = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Win = Fl:CreateWindow({Title="p1 v4.0", SubTitle="MiniCore", TabWidth=120, Size=UDim2.fromOffset(580,380), Acrylic=Settings.UIAcrylic, Theme=Settings.UITheme, MinimizeKey=Enum.KeyCode.N})
local Tabs = {M=Win:AddTab({Title="Mining"}), A=Win:AddTab({Title="Automation"}), U=Win:AddTab({Title="Upgrades"}), C=Win:AddTab({Title="Customize"}), S=Win:AddTab({Title="Settings"})}
local function tog(t,l,k,d,cb) local x=t:AddToggle(k,{Title=l,Default=d}); x:OnChanged(function(v) C[k]=v; if cb then cb(v) end save() end) end
local function inp(t,l,k,d,cb) local x=t:AddInput(k,{Title=l,Default=tostring(d),Numeric=true,Finished=true}); x:OnChanged(function(v) local n=tonumber(v); if n then if cb then cb(n) else C[k]=math.max(n,0.001) end save() end end) end
local function drp(t,l,k,o,m,d,cb) local x=t:AddDropdown(k,{Title=l,Values=o,Multi=m,Default=d}); x:OnChanged(function(v) if m then table.clear(C[k]); for a,b in pairs(v) do if type(a)=="string" and b then table.insert(C[k],a) elseif type(b)=="string" then table.insert(C[k],b) end end else C[k]=v end; if cb then cb(v) end save() end) end

Tabs.M:AddSection("Control"); Tabs.M:AddToggle("Exec",{Title="Execute Sequence", Default=false}):OnChanged(function(v) looping=v end)
local rOpts = {}; for n,_ in pairs(routes) do table.insert(rOpts,n) end
drp(Tabs.M,"Ore Route","MiningTarget",rOpts,false,C.MiningTarget)
drp(Tabs.M,"Move Method","MovementMethod",{"Walking","Teleport"},false,C.MovementMethod)
inp(Tabs.M,"WalkSpeed [16-350]","WS",Settings.CustomWalkSpeed,function(v) Settings.CustomWalkSpeed=math.clamp(v,16,350); local h=player.Character and player.Character:FindFirstChild("Humanoid"); if h then h.WalkSpeed=v end end)
inp(Tabs.M,"Ore Break (s)","OB",Settings.WaitTimeOnOre,function(v) Settings.WaitTimeOnOre=math.clamp(v,0.2,3) end)
local TPara = Tabs.M:AddParagraph({Title="Stats (v4.0)", Content="..."})
Tabs.M:AddSection("Exchange"); tog(Tabs.M,"Auto Exchange","AutoExchangeGems",C.AutoExchangeGems)
local dG={}; for k,v in pairs(GMap) do if v then table.insert(dG,k) end end
local gd=Tabs.M:AddDropdown("G",{Title="Minerals",Values=GNames,Multi=true,Default=dG}); gd:OnChanged(function(v) table.clear(GMap); for a,b in pairs(v) do GMap[type(a)=="string" and a or b]=true end rbGems(); save() end)
inp(Tabs.M,"Exch Interval","ExchangeGemsSpeed",C.ExchangeGemsSpeed)

Tabs.A:AddSection("Runes"); tog(Tabs.A,"Auto Roll Runes","AutoRollRunes",C.AutoRollRunes)
local dR={}; for k,v in pairs(RSet) do if v then table.insert(dR,k) end end
local rd=Tabs.A:AddDropdown("R",{Title="Runes",Values=RNames,Multi=true,Default=dR}); rd:OnChanged(function(v) table.clear(RSet); for a,b in pairs(v) do RSet[type(a)=="string" and a or b]=true end save() end)
inp(Tabs.A,"Rune Interval","RuneSpeed",C.RuneSpeed)
Tabs.A:AddSection("World"); tog(Tabs.A,"Auto Roll Tier","AutoRollTier",C.AutoRollTier); inp(Tabs.A,"Tier Speed","TierSpeed",C.TierSpeed)
tog(Tabs.A,"Auto Hit Tree","AutoHitTree",C.AutoHitTree); inp(Tabs.A,"Tree Speed","TreeSpeed",C.TreeSpeed)
tog(Tabs.A,"Auto Pump","AutoWaterPump",C.AutoWaterPump); inp(Tabs.A,"Pump Speed","WaterPumpSpeed",C.WaterPumpSpeed)
Tabs.A:AddSection("Process"); tog(Tabs.A,"Auto Quest","AutoBlazeQuest",C.AutoBlazeQuest); inp(Tabs.A,"Quest Speed","BlazeQuestSpeed",C.BlazeQuestSpeed)
tog(Tabs.A,"Auto Ash","AutoConvertWoodToAsh",C.AutoConvertWoodToAsh); inp(Tabs.A,"Ash Speed","AshConvertSpeed",C.AshConvertSpeed)
local iO={"None"}; for i=1,12 do table.insert(iO,"Level "..i) end
drp(Tabs.A,"Auto Ice","SelectedIceLevel",iO,false,C.SelectedIceLevel==0 and "None" or "Level "..C.SelectedIceLevel,function(v) C.SelectedIceLevel=v=="None" and 0 or tonumber(v:match("%d+")) end)
inp(Tabs.A,"Ice Speed","IceConvertSpeed",C.IceConvertSpeed)

local function upg(l,k,tk,sk,o,a1,a2)
    Tabs.U:AddSection(l); tog(Tabs.U,"Auto "..l,k,C[k]); local df={}; for _,v in pairs(C[tk]) do table.insert(df,v) end
    drp(Tabs.U,"Select "..l,tk,o,true,df); inp(Tabs.U,"Speed (s)",sk,C[sk])
    go(function() while scriptRunning do if C[k] then for _,v in ipairs(C[tk]) do if a2 then fire(a1,a2,v) else fire(a1,v) end end end tw(C[sk] or 1) end end)
end
upg("Noobs","AutoUpgradeNoob","SelectedNoobUpgrades","UpgradeNoobSpeed",{"Fisherman","Knight","Explorer","Magician"},"UpgradeNoobMax")
upg("Gems","AutoUpgradeGems","SelectedGemUpgrades","UpgradeGemsSpeed",{"MoreGems","MoreOreStats","MoreOof"},"UpgradeUpgrade","Gem")
upg("Planks","AutoUpgradePlanks","SelectedPlankUpgrades","UpgradePlanksSpeed",{"WaterFromPlanks","MorePlanks"},"UpgradeUpgrade","Planks")
upg("Water","AutoUpgradeWater","SelectedWaterUpgrades","UpgradeWaterSpeed",{"MoreGems","MorePlanks"},"UpgradeUpgrade","Water")

Tabs.C:AddSection("Visual"); local thD=Tabs.C:AddDropdown("T",{Title="Theme",Values={"Darker","Dark","Light","Aqua","Amethyst","Rose"},Multi=false,Default=Settings.UITheme})
thD:OnChanged(function(v) Settings.UITheme=v; Fl:SetTheme(v); save() end)
local acT=Tabs.C:AddToggle("A",{Title="Acrylic",Default=Settings.UIAcrylic}); acT:OnChanged(function(v) Settings.UIAcrylic=v; save() end)
Tabs.C:AddColorpicker("C",{Title="Accent",Default=Settings.UIAcrylic}):OnChanged(function(v) Settings.UIAccentColor=v; save() end)
Tabs.S:AddSection("Security"); tog(Tabs.S,"Anti-AFK Shield","AntiAFK",C.AntiAFK,sAfk); tog(Tabs.S,"Ghost Mode","N",Settings.UseNoclip,function(v) if v then nc() else cp() end end)
Tabs.S:AddButton({Title="Del Script",Callback=function() scriptRunning=false; looping=false; cp(); sAfk(false); if Win then Win:Destroy() end end})

Win:SelectTab(1); Fl:Notify({Title="p1 v4.0 Opti", Content="GUI & Engine Fully Loaded", Duration=5})
if Settings.UseNoclip then go(nc) end; sAfk(C.AntiAFK)

-- ENGINE
local function bL(f, sKey, cb) go(function() while scriptRunning do if C[f] then cb() end tw(C[sKey]) end end) end
bL("AutoRollTier", "TierSpeed", function() fire("RollTier") end)
bL("AutoRollRunes", "RuneSpeed", function() for _, n in ipairs(RNames) do if RSet[n] then fire("RollRune", n) end end end)
bL("AutoHitTree", "TreeSpeed", function() local f=player:FindFirstChild("FEATURES"); local t=f and f:FindFirstChild("TREE"); local s=t and t:FindFirstChild("IsSpawned"); if s and s.Value then fire("HitTree") end end)
bL("AutoWaterPump", "WaterPumpSpeed", function() fire("GainWater") end)
bL("AutoBlazeQuest", "BlazeQuestSpeed", function() fire("SetUpgradeAutomationPaused","Fire",false); fire("Blaze") end)
bL("AutoConvertWoodToAsh", "AshConvertSpeed", function() fire("ConvertWoodToAsh") end)
bL("AutoExchangeGems", "ExchangeGemsSpeed", function() if #GToEx>0 then for _,g in ipairs(GToEx) do if g=="All" then fire("ExchangeAllMinerals") break end local a=currency(g); if a and a>0 then fire("ExchangeMineral",g) end end end end)
go(function() while scriptRunning do local c = C.SelectedIceLevel or 0; if c>0 then fire("PressButton", c) end tw(C.IceConvertSpeed) end end)

local rT = 0
go(function() while scriptRunning do tw(1) if looping then rt+=1; rT+=1 if rT>=300 then d5=last5; last5=0; table.insert(h5,total); if #h5>25 then table.remove(h5,1) end; hook(); rT=0 end TPara:SetDesc(string.format("Status: 🟢 ACTIVE\n⏱️ 5m: %d | 📈: %d/h\n🔋: %d | ⏳: %dh %dm\n💎: %d | 💜: %d | 💙: %d",d5,est,total,math.floor(rt/3600),math.floor((rt%3600)/60),cel,vs,aeth)) else TPara:SetDesc("Status: 🔴 PAUSED") end end end)

go(function() while scriptRunning do if looping then local r=routes[C.MiningTarget]; if r then for _,t in ipairs(r) do if not looping or not scriptRunning then break end local c=player.Character; local h=c and c:FindFirstChild("HumanoidRootPart"); if h then mv(t.p,h); if not scriptRunning then break end total+=1; last5+=1; local tn=t.n; if tn:sub(1,1)=="C" then cel+=1 elseif tn:sub(1,1)=="V" then vs+=1 elseif tn:sub(1,1)=="A" then aeth+=1 elseif tn:sub(1,1)=="R" then ruby+=1 end tw(Settings.WaitTimeOnOre) end end else tw(0.5) end else tw(0.1) end end end)
