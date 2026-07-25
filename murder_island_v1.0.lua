--[[
    谋杀之岛2世界 多功能脚本 v1.0
    WindUI + Drawing ESP + Auto Kill + God + Speed + Flight
    作者: b站英吉利超入_
    已适配 Real 执行器 (无goto, pcall Popup)
]]

print("[谋杀之岛] v1.0 加载中...")

-- ====== 服务获取 ======
local P = game:GetService("Players")
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local C = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP = P.LocalPlayer
if not LP then print("[谋杀之岛] 无LocalPlayer"); return end
print("[谋杀之岛] 玩家: " .. LP.Name)

-- ====== 清理旧Gui ======
for _, g in ipairs(C:GetChildren()) do
    if g:IsA("ScreenGui") then
        if g.Name == "A" or g.Name:find("Murder") or g.Name == "WindUI" then
            pcall(function() g:Destroy() end)
        end
    end
end

-- ====== 加载 WindUI ======
print("[谋杀之岛] 正在加载 WindUI...")
local WI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
if not WI then print("[谋杀之岛] WindUI 加载失败"); return end
print("[谋杀之岛] WindUI OK")

-- ====== 游戏服务 ======
local Knit
local ActionPeriodService
local MurdererChoose
local gameReady = false

pcall(function()
    Knit = require(RS.Knit)
    ActionPeriodService = Knit.GetService("ActionPeriodService")
    if ActionPeriodService then
        local rf = RS.Knit.Services.ActionPeriodService:FindFirstChild("RF")
        if rf then
            MurdererChoose = rf:FindFirstChild("MurdererChoose")
        end
    end
    gameReady = true
    print("[谋杀之岛] 游戏服务就绪 MurdererChoose=" .. (MurdererChoose and "OK" or "NIL"))
end)
if not gameReady then print("[谋杀之岛] 游戏服务加载失败(部分功能不可用)") end

-- ====== 设置 ======
local S = {
    AutoKill = false, KillRange = 50, GodMode = false, Speed = false,
    SpeedValue = 30, Flight = false, FlightSpeed = 50,
    EspEnabled = false, EspRange = 500, EspNames = true,
    EspBoxes = true, EspTracers = false, EspWeapon = true,
    Particles = true, Acrylic = true, Transparent = false,
    ParticleColor = Color3.fromRGB(255, 60, 60)
}
local KB = { Toggle = "RightShift" }
local WN, CT = nil, {}
local DrawingCache = {}

-- ====== 工具函数 ======
local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getNearestPlayer(range)
    local hrp = getHRP()
    if not hrp then return nil end
    local pos = hrp.Position
    local nearest = nil
    for _, p in ipairs(P:GetPlayers()) do
        if p ~= LP and p.Character then
            local target = p.Character:FindFirstChild("HumanoidRootPart")
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if target and humanoid and humanoid.Health > 0 then
                local d = (target.Position - pos).Magnitude
                if d <= range + 5 then
                    if not nearest or d < nearest.D then
                        nearest = {Player=p, HRP=target, D=d}
                    end
                end
            end
        end
    end
    return nearest
end

-- ====== 自动杀人 ======
local function doKill()
    if not S.AutoKill then return end
    local target = getNearestPlayer(S.KillRange)
    if not target then return end
    if MurdererChoose then
        local ok, result = pcall(function()
            return MurdererChoose:InvokeServer(target.Player.Name)
        end)
        if ok and result == true then
            print("[杀人] " .. target.Player.Name .. " @" .. math.floor(target.D) .. "m")
        end
    end
end

-- ====== God Mode ======
local function enableGod()
    if S.GodMode then return end
    S.GodMode = true
    local oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if method == "TakeDamage" and typeof(self) == "Instance" and self:IsA("Humanoid") then
            if self.Parent and self.Parent:FindFirstChildWhichIsA("HumanoidRootPart") then
                if self.Parent.Name == LP.Name then
                    return
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    print("[God] 已启用 - TakeDamage 拦截")
end

-- ====== 加速 ======
local function updateSpeed()
    local c = LP.Character
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return end
    h.WalkSpeed = S.Speed and S.SpeedValue or 16
end

-- ====== 飞行 ======
local FlightBodyVel, FlightBodyGyro = nil, nil
local function toggleFlight()
    local c = LP.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if S.Flight then
        if h then h.PlatformStand = true end
        FlightBodyVel = Instance.new("BodyVelocity")
        FlightBodyVel.Name = "MurderFlightVel"
        FlightBodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        FlightBodyVel.P = 10000
        FlightBodyVel.Parent = hrp
        FlightBodyGyro = Instance.new("BodyGyro")
        FlightBodyGyro.Name = "MurderFlightGyro"
        FlightBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        FlightBodyGyro.D = 100
        FlightBodyGyro.P = 10000
        FlightBodyGyro.Parent = hrp
        print("[飞行] 已启用 速度=" .. S.FlightSpeed)
    else
        if FlightBodyVel then FlightBodyVel:Destroy(); FlightBodyVel = nil end
        if FlightBodyGyro then FlightBodyGyro:Destroy(); FlightBodyGyro = nil end
        if h then h.PlatformStand = false end
        print("[飞行] 已禁用")
    end
end

spawn(function()
    while true do
        if S.Flight and FlightBodyVel and FlightBodyGyro then
            local c = LP.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local cam = workspace.CurrentCamera
                local dir = Vector3.new(0, 0, 0)
                if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
                if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
                local mag = dir.Magnitude
                if mag > 1 then dir = dir / mag end
                FlightBodyVel.Velocity = dir * S.FlightSpeed
                FlightBodyGyro.CFrame = cam.CFrame
            end
        end
        wait(0.02)
    end
end)

-- ====== Drawing ESP (无goto版本, 适配Real) ======
local function clearESP()
    for _, d in pairs(DrawingCache) do
        pcall(function() d:Remove() end)
    end
    DrawingCache = {}
end

local function createESP(player)
    if DrawingCache[player.UserId] then return end
    local drawings = {}
    local box = Drawing.new("Square")
    box.Thickness = 2; box.Filled = false; box.Visible = false
    box.Color = Color3.fromRGB(255, 255, 255); box.Transparency = 1
    drawings.Box = box

    local nameText = Drawing.new("Text")
    nameText.Size = 14; nameText.Center = true; nameText.Outline = true
    nameText.Visible = false; nameText.Color = Color3.fromRGB(255, 255, 255)
    nameText.Transparency = 1; nameText.Font = Drawing.Fonts.UI
    drawings.Name = nameText

    local weaponText = Drawing.new("Text")
    weaponText.Size = 12; weaponText.Center = true; weaponText.Outline = true
    weaponText.Visible = false; weaponText.Color = Color3.fromRGB(255, 200, 100)
    weaponText.Transparency = 1; weaponText.Font = Drawing.Fonts.UI
    drawings.Weapon = weaponText

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1; tracer.Visible = false
    tracer.Color = Color3.fromRGB(255, 255, 255); tracer.Transparency = 1
    drawings.Tracer = tracer

    DrawingCache[player.UserId] = drawings
end

local function updateESP()
    if not S.EspEnabled then return end
    local cam = workspace.CurrentCamera
    local myHrp = getHRP()
    local myPos = myHrp and myHrp.Position

    for _, player in ipairs(P:GetPlayers()) do
        if player ~= LP then
            local c = player.Character
            if c then
                local hrp = c:FindFirstChild("HumanoidRootPart")
                local head = c:FindFirstChild("Head")
                local h = c:FindFirstChildOfClass("Humanoid")
                if hrp and head and h and h.Health > 0 then
                    local d = myPos and (hrp.Position - myPos).Magnitude or 0
                    if d <= S.EspRange then
                        createESP(player)
                        local drawings = DrawingCache[player.UserId]
                        if drawings then
                            local headPos = head.Position + Vector3.new(0, 1.5, 0)
                            local footPos = hrp.Position - Vector3.new(0, 3, 0)
                            local headScreen, onScreen = cam:WorldToScreenPoint(headPos)
                            if onScreen then
                                local footScreen = cam:WorldToScreenPoint(footPos)
                                local hSize = math.abs(headScreen.Y - footScreen.Y)
                                local wSize = hSize * 0.6
                                local x = headScreen.X - wSize / 2
                                local y = headScreen.Y
                                local isSafe = player:GetAttribute("SafeFromMurderer")
                                local color = isSafe and Color3.fromRGB(40, 255, 100) or Color3.fromRGB(255, 40, 40)
                                local role = player:GetAttribute("CharacterId") or "?"

                                if S.EspNames then
                                    drawings.Name.Text = player.DisplayName .. " [" .. math.floor(d) .. "m]"
                                    drawings.Name.Position = Vector2.new(headScreen.X, headScreen.Y - 20)
                                    drawings.Name.Color = color
                                    drawings.Name.Visible = true
                                else
                                    drawings.Name.Visible = false
                                end

                                if S.EspBoxes then
                                    drawings.Box.Size = Vector2.new(wSize, hSize)
                                    drawings.Box.Position = Vector2.new(x, y)
                                    drawings.Box.Color = color
                                    drawings.Box.Visible = true
                                else
                                    drawings.Box.Visible = false
                                end

                                if S.EspWeapon then
                                    drawings.Weapon.Text = role
                                    drawings.Weapon.Position = Vector2.new(headScreen.X, footScreen.Y + 5)
                                    drawings.Weapon.Visible = true
                                else
                                    drawings.Weapon.Visible = false
                                end

                                if S.EspTracers then
                                    drawings.Tracer.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                                    drawings.Tracer.To = Vector2.new(footScreen.X, footScreen.Y)
                                    drawings.Tracer.Color = color
                                    drawings.Tracer.Visible = true
                                else
                                    drawings.Tracer.Visible = false
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

spawn(function()
    while true do
        if S.EspEnabled then pcall(updateESP) end
        wait(0.03)
    end
end)

-- ====== 粒子 ======
local PR, PS, PC = false, {}, nil
local function sP()
    if PR then return end
    if PC then pcall(function() local p=PC.Parent; if p then p:Destroy() end end) PC=nil end
    PS={}; wait(0.3)
    local sg=Instance.new("ScreenGui"); sg.Name="MP"; sg.ResetOnSpawn=false; sg.DisplayOrder=999999; sg.IgnoreGuiInset=true; sg.Parent=C
    PC=Instance.new("Frame"); PC.Size=UDim2.new(1,0,1,0); PC.BackgroundTransparency=1; PC.BorderSizePixel=0; PC.Parent=sg
    for i=1,50 do
        local d=Instance.new("Frame"); local sz=math.random(5,10)
        d.Size=UDim2.new(0,sz,0,sz); d.Position=UDim2.new(0.2+math.random()*0.6,0,0.2+math.random()*0.6,0)
        d.BackgroundColor3=S.ParticleColor; d.BackgroundTransparency=0.3+math.random()*0.5; d.BorderSizePixel=0; d.Parent=PC
        Instance.new("UICorner",d).CornerRadius=UDim.new(0,10)
        local a=math.random()*6.28; local sp=0.0008+math.random()*0.002
        table.insert(PS,{F=d,Sx=d.Position.X.Scale,Sy=d.Position.Y.Scale,Vx=math.cos(a)*sp,Vy=math.sin(a)*sp,Ph=math.random()*6.28,Sz=sz})
    end
    PR=true
    spawn(function() local t=0; while PR and PC do t=t+0.03
        pcall(function() local c=S.ParticleColor; for _,p in ipairs(PS) do if p.F and p.F.Parent then
            local sx=math.max(0.05,math.min(0.95,p.Sx+p.Vx)); local sy=math.max(0.05,math.min(0.95,p.Sy+p.Vy))
            if sx>=0.95 or sx<=0.05 then p.Vx=-p.Vx end; if sy>=0.95 or sy<=0.05 then p.Vy=-p.Vy end
            p.Sx=sx; p.Sy=sy; p.F.Position=UDim2.new(sx,0,sy,0); p.F.BackgroundColor3=c
            p.F.BackgroundTransparency=0.3+math.sin(t*0.8+p.Ph)*0.4
            p.F.Size=UDim2.new(0,math.max(2,p.Sz+math.sin(t+p.Ph)*1.5),0,math.max(2,p.Sz+math.sin(t+p.Ph)*1.5))
    end end end) wait(0.03) end end)
end
local function xP() PR=false; if PC then pcall(function() local p=PC.Parent; if p then p:Destroy() end end) PC=nil end; PS={} end

-- ====== 主题 ======
local tc_t = {Dark=Color3.fromRGB(255,60,60),Light=Color3.fromRGB(200,40,40),Rose=Color3.fromRGB(255,130,170),Plant=Color3.fromRGB(120,255,130),Ocean=Color3.fromRGB(60,190,240),Sunset=Color3.fromRGB(255,180,70),Midnight=Color3.fromRGB(130,100,240),Forest=Color3.fromRGB(60,210,90),Lavender=Color3.fromRGB(190,140,255),Coral=Color3.fromRGB(255,140,90),Mint=Color3.fromRGB(80,230,190),Sky=Color3.fromRGB(100,190,255),Blood=Color3.fromRGB(255,40,40),Lemon=Color3.fromRGB(230,210,70),Cyber=Color3.fromRGB(0,235,210)}
local function tc(n) return tc_t[n] or Color3.fromRGB(255,60,60) end

-- ====== UI ======
local function mW()
    WN = WI:CreateWindow({
        Title="Murder Island 2", Author="b站英吉利超入_", Icon="solar:skull-bold",
        Size=UDim2.fromOffset(750,560), ToggleKey=Enum.KeyCode.RightShift,
        Folder="murder-script", Acrylic=true, Resizable=false,
        ScrollBarEnabled=true, HideSearchBar=true,
        OnClose=function()
            xP(); S.AutoKill=false; S.EspEnabled=false; clearESP()
            if S.Flight then S.Flight=false; toggleFlight() end
            for _,ct in pairs(CT) do if ct and type(ct.Set)=="function" then pcall(function() ct:Set(false) end) end end
        end,
        OnOpen=function() if S.Particles then sP() end end
    })
    spawn(function() wait(0.8) pcall(function() if WN and WN.Parent then WN.Parent.ClipsDescendants=true end end) end)

    local t1=WN:Tab({Title="主控面板", Icon="solar:slider-vertical-bold"})
    CT.AutoKill=t1:Toggle({Flag="AutoKill", Title="自动杀人(杀手时)", Value=false, Callback=function(v) S.AutoKill=v end})
    CT.GodMode=t1:Toggle({Flag="GodMode", Title="无敌模式", Value=false, Callback=function(v) if v then enableGod() end end})
    CT.Speed=t1:Toggle({Flag="Speed", Title="加速", Value=false, Callback=function(v) S.Speed=v; updateSpeed() end})
    CT.SpeedSlider=t1:Slider({Flag="SpeedValue", Title="速度", Step=2, Value={Min=20,Max=100,Default=30}, Width=200, Callback=function(v) S.SpeedValue=v; if S.Speed then updateSpeed() end end})
    CT.Flight=t1:Toggle({Flag="Flight", Title="飞行 (WASD+空格+Shift)", Value=false, Callback=function(v) S.Flight=v; toggleFlight() end})
    CT.FlightSlider=t1:Slider({Flag="FlightSpeed", Title="飞行速度", Step=5, Value={Min=10,Max=200,Default=50}, Width=200, Callback=function(v) S.FlightSpeed=v end})
    CT.KillRange=t1:Slider({Flag="KillRange", Title="杀人范围", Step=5, Value={Min=10,Max=200,Default=50}, Width=200, IsTextbox=true, Callback=function(v) S.KillRange=v end})

    local t2=WN:Tab({Title="透视", Icon="solar:eye-bold"})
    CT.EspEnabled=t2:Toggle({Flag="EspEnabled", Title="玩家ESP (Drawing)", Value=false, Callback=function(v) S.EspEnabled=v; if not v then clearESP() end end})
    t2:Space()
    CT.EspNames=t2:Toggle({Flag="EspNames", Title="显示名字+距离", Value=true, Callback=function(v) S.EspNames=v end})
    CT.EspBoxes=t2:Toggle({Flag="EspBoxes", Title="显示方框", Value=true, Callback=function(v) S.EspBoxes=v end})
    CT.EspTracers=t2:Toggle({Flag="EspTracers", Title="显示射线", Value=false, Callback=function(v) S.EspTracers=v end})
    CT.EspWeapon=t2:Toggle({Flag="EspWeapon", Title="显示身份", Value=true, Callback=function(v) S.EspWeapon=v end})
    t2:Space()
    CT.EspRange=t2:Slider({Flag="EspRange", Title="ESP范围", Step=50, Value={Min=50,Max=2000,Default=500}, Width=200, IsTextbox=true, Callback=function(v) S.EspRange=v end})

    local t3=WN:Tab({Title="快捷键", Icon="solar:settings-bold"})
    t3:Keybind({Flag="ToggleKey", Title="窗口开关", Value="RightShift", Callback=function(v) KB.Toggle=v end})

    local t4=WN:Tab({Title="UI设置", Icon="solar:monitor-bold"})
    CT.Particles=t4:Toggle({Flag="Particles", Title="粒子背景", Value=true, Callback=function(v) S.Particles=v; if v then sP() else xP() end end})
    t4:Toggle({Flag="Acrylic", Title="毛玻璃", Value=true, Callback=function(v) S.Acrylic=v; pcall(function() WI:ToggleAcrylic(v) end) end})
    t4:Toggle({Flag="Transparent", Title="透明", Value=false, Callback=function(v) S.Transparent=v; pcall(function() WN:ToggleTransparency(v) end) end})
    local tns={"Dark","Light","Rose","Plant","Ocean","Sunset","Midnight","Forest","Lavender","Coral","Mint","Sky","Blood","Lemon","Cyber"}
    t4:Dropdown({Flag="Theme", Title="主题", Values=tns, Value="Dark", Callback=function(v) pcall(function() WI:SetTheme(v) end); S.ParticleColor=tc(v) end})

    local t5=WN:Tab({Title="信息统计", Icon="solar:chart-bold"})
    local sPlayers=t5:Paragraph({Title="玩家: ..."})
    local sRole=t5:Paragraph({Title="你的身份: " .. (LP:GetAttribute("CharacterId") or "未知")})

    local t6=WN:Tab({Title="配置管理", Icon="solar:diskette-bold"})
    pcall(function()
        local CM=WN.ConfigManager; if not CM then return end
        local cni=t6:Input({Flag="CN", Title="配置名称", Value="default", Icon="solar:file-text-bold", Callback=function(v) end})
        t6:Space(); local AC={}; pcall(function() AC=CM:AllConfigs() end)
        local DV=nil; for _,v in ipairs(AC) do if v=="default" then DV="default"; break end end
        local ACD=t6:Dropdown({Title="已有配置", Values=AC, Value=DV, Callback=function(v) if v then pcall(function() cni:Set(v) end) end end})
        t6:Space()
        t6:Button({Title="保存", Icon="solar:check-circle-bold", Justify="Center", Color=Color3.fromHex("#305dff"), Callback=function()
            if not CM then return end; local c=CM:Config("default")
            if c and c:Save() then WI:Notify({Title="已保存", Content="OK", Duration=3, Icon="solar:check-circle-bold"})
                pcall(function() ACD:Refresh(CM:AllConfigs()) end) end end})
        t6:Space()
        t6:Button({Title="加载", Icon="solar:refresh-circle-bold", Justify="Center", Color=Color3.fromHex("#10C550"), Callback=function()
            if not CM then return end; local c=CM:CreateConfig("default",false)
            if c and c:Load() then WI:Notify({Title="已加载", Content="OK", Duration=3, Icon="solar:refresh-circle-bold"}) end end})
        t6:Space()
        t6:Button({Title="删除", Icon="solar:trash-bin-trash-bold", Justify="Center", Color=Color3.fromHex("#ff3040"), Callback=function()
            if not CM then return end; local c=CM:Config("default")
            if c and c:Delete() then WI:Notify({Title="已删除", Content="OK", Duration=3, Icon="solar:trash-bin-trash-bold"})
                pcall(function() ACD:Refresh(CM:AllConfigs()) end) end end})
        spawn(function() wait(1) pcall(function() CM:CreateConfig("default",true) end) end)
    end)

    local t7=WN:Tab({Title="关于", Icon="solar:info-square-bold"})
    t7:Paragraph({Title="Murder Island 2 v1.0"}); t7:Divider()
    t7:Paragraph({Title="作者", Desc="b站英吉利超入_"})
    t7:Paragraph({Title="功能", Desc="自动杀人/无敌/加速/飞行/ESP透视"})

    UIS.InputBegan:Connect(function(input, gpe)
        if gpe or input.UserInputType~=Enum.UserInputType.Keyboard then return end
        local kn = input.KeyCode and input.KeyCode.Name or ""
        if kn==KB.Toggle and WN then pcall(function() WN:Toggle() end) end
    end)

    return sPlayers, sRole
end

-- ====== 启动 ======
pcall(function() WI:SetTheme("Dark") end)
S.ParticleColor = tc("Dark")

-- Popup在Real执行器可能无权限创建UI,跳过直接开窗口
local popupOk = pcall(function()
    local PP = false
    WI:Popup({
        Title="Murder Island 2 v1.0",
        Content="自动杀人 / 无敌 / 加速 / 飞行 / ESP透视",
        Buttons={
            {Title="加载", Callback=function() PP=true end, Variant="Primary"},
            {Title="取消", Callback=function() return end}
        }
    })
    while not PP do wait(0.1) end
end)
if not popupOk then
    print("[谋杀之岛] Popup跳过(Real限制), 直接开窗口...")
end

spawn(function()
    local sPlayers, sRole = mW()
    print("[谋杀之岛] v1.0 运行中")
    local last = 0
    while true do
        if S.AutoKill then pcall(doKill) end
        wait(0.5)
        if S.Speed then updateSpeed() end
        local now = tick()
        if now - last > 3 then
            last = now
            if sPlayers then pcall(function() sPlayers:SetTitle("玩家: " .. #P:GetPlayers() .. "人") end) end
            if sRole then pcall(function() sRole:SetTitle("你的身份: " .. (LP:GetAttribute("CharacterId") or "未知")) end) end
        end
        wait(0.5)
    end
end)
