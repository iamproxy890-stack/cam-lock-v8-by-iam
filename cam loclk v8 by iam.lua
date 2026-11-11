--[[
    AIMBOT PRO SCRIPT - Prensado Camlock v9 (Stealth Mode)
    - GUI oculta usando gethui() (si está disponible)
    - Sistema de Highlight reciclado (menos rastro)
    - Limpieza total al descargar
    Teclas: F (toggle) | INSERT (panel) | DELETE (unload)
]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local HttpService      = game:GetService("HttpService")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===================== CONFIG =====================
local CONFIG = {
    KEY         = Enum.KeyCode.F,
    UNLOAD_KEY  = Enum.KeyCode.Delete,
    PANEL_KEY   = Enum.KeyCode.Insert,

    AIM_PART    = "Head",
    MODE        = "Smooth",
    ACTIVATION  = "Always",

    FOV         = 120,
    SMOOTHNESS  = 0.85,
    TRACK_SPEED = 0.70,
    PREDICTION  = 0.05,
    MAX_DISTANCE= 2000,

    TEAM_CHECK  = true,
    WALL_CHECK  = false,
    SHOW_FOV    = true,
    HIGHLIGHT   = true,

    ESP_ENABLED      = false,
    ESP_BOX          = true,
    ESP_SHOW_DIST    = true,
    ESP_COLOR        = Color3.fromRGB(255, 0, 0),
    ESP_BOX_SIZE     = 1.0,
    ESP_TRANSP       = 0.8,
    ESP_MAX_DIST     = 10000,
    ESP_TEAM_CHECK   = true,

    CHAMS_ENABLED    = false,
    CHAMS_COLOR      = Color3.fromRGB(0, 255, 0),
    CHAMS_TRANSP     = 0.5,

    NO_RECOIL        = false,
    NO_SPREAD        = false,
    AUTO_FIRE        = false,

    IGNORE_LIST      = {},
}

local SAVE_FILE = "AimbotProConfig.json"

local function saveConfig()
    if not writefile then return end
    local data = {
        FOV = CONFIG.FOV,
        SMOOTHNESS = CONFIG.SMOOTHNESS,
        TRACK_SPEED = CONFIG.TRACK_SPEED,
        PREDICTION = CONFIG.PREDICTION,
        AIM_PART = CONFIG.AIM_PART,
        ACTIVATION = CONFIG.ACTIVATION,
        ESP_ENABLED = CONFIG.ESP_ENABLED,
        ESP_BOX = CONFIG.ESP_BOX,
        ESP_COLOR_R = CONFIG.ESP_COLOR.R,
        ESP_COLOR_G = CONFIG.ESP_COLOR.G,
        ESP_COLOR_B = CONFIG.ESP_COLOR.B,
        CHAMS_ENABLED = CONFIG.CHAMS_ENABLED,
        CHAMS_COLOR_R = CONFIG.CHAMS_COLOR.R,
        CHAMS_COLOR_G = CONFIG.CHAMS_COLOR.G,
        CHAMS_COLOR_B = CONFIG.CHAMS_COLOR.B,
    }
    pcall(function()
        writefile(SAVE_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadConfig()
    if not isfile or not readfile then return end
    pcall(function()
        if isfile(SAVE_FILE) then
            local data = HttpService:JSONDecode(readfile(SAVE_FILE))
            CONFIG.FOV = data.FOV or CONFIG.FOV
            CONFIG.SMOOTHNESS = data.SMOOTHNESS or CONFIG.SMOOTHNESS
            CONFIG.TRACK_SPEED = data.TRACK_SPEED or CONFIG.TRACK_SPEED
            CONFIG.PREDICTION = data.PREDICTION or CONFIG.PREDICTION
            CONFIG.AIM_PART = data.AIM_PART or CONFIG.AIM_PART
            CONFIG.ACTIVATION = data.ACTIVATION or CONFIG.ACTIVATION
            CONFIG.ESP_ENABLED = data.ESP_ENABLED or CONFIG.ESP_ENABLED
            CONFIG.ESP_BOX = data.ESP_BOX or CONFIG.ESP_BOX
            if data.ESP_COLOR_R then
                CONFIG.ESP_COLOR = Color3.new(data.ESP_COLOR_R, data.ESP_COLOR_G, data.ESP_COLOR_B)
            end
            CONFIG.CHAMS_ENABLED = data.CHAMS_ENABLED or CONFIG.CHAMS_ENABLED
            if data.CHAMS_COLOR_R then
                CONFIG.CHAMS_COLOR = Color3.new(data.CHAMS_COLOR_R, data.CHAMS_COLOR_G, data.CHAMS_COLOR_B)
            end
        end
    end)
end

loadConfig()
-- ==================================================

local enabled = false
local unloaded = false
local locked = nil
local needRelock = true
local Connections = {}
local ignored = {}

local function conn(c) table.insert(Connections, c); return c end

local function isAlive(plr)
    local char = plr and plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return (hum and hum.Health > 0) and true or false
end

local function isIgnored(plr)
    return ignored[plr.UserId] == true
end

local function getPart(char)
    if not char then return nil end
    local name = CONFIG.AIM_PART
    if name == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild(name) or char:FindFirstChild("HumanoidRootPart")
end

local function predict(pos, vel)
    return pos + (vel * CONFIG.PREDICTION)
end

local function findTarget()
    local best, bestScore
    local center = Camera.ViewportSize / 2
    local camPos = Camera.CFrame.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and not isIgnored(plr) then
            local char = plr.Character
            if char and isAlive(plr) then
                local ok = not (CONFIG.TEAM_CHECK and LP.Team and plr.Team == LP.Team)
                if ok then
                    local part = getPart(char)
                    if part then
                        local worldPos = predict(part.Position, part.AssemblyLinearVelocity)
                        local sp, onScreen = Camera:WorldToViewportPoint(worldPos)
                        if onScreen and sp.Z > 0 then
                            local off = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                            if off <= CONFIG.FOV / 2 then
                                local dist = (part.Position - camPos).Magnitude
                                if dist <= CONFIG.MAX_DISTANCE then
                                    local score = off + dist * 0.05
                                    if not bestScore or score < bestScore then
                                        best, bestScore = plr, score
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local circle
pcall(function()
    circle = Drawing.new("Circle")
    circle.Thickness = 1.5
    circle.NumSides = 64
    circle.Filled = false
    circle.Color = Color3.fromRGB(255, 0, 0)
    circle.Transparency = 0.65
end)

-- ===================== HIGHLIGHT RECICLADO =====================
local visualFolder = Instance.new("Folder")
visualFolder.Name = "Visuals"
visualFolder.Parent = Workspace

local function setHighlight(plr)
    for _, hl in ipairs(visualFolder:GetChildren()) do hl:Destroy() end
    if not CONFIG.HIGHLIGHT or not plr or not plr.Character then return end
    
    local hl = Instance.new("Highlight")
    hl.Name = "AimHighlight"
    hl.Adornee = plr.Character
    hl.FillColor = Color3.fromRGB(255, 0, 0)
    hl.FillTransparency = 0.6
    hl.OutlineColor = Color3.fromRGB(255, 0, 0)
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = visualFolder
end

local function release()
    locked = nil
    setHighlight(nil)
end

local function acquire()
    local t = findTarget()
    if not t then return end
    locked = t
    setHighlight(t)
    if CONFIG.SNAP_ON_LOCK ~= false then
        local part = getPart(t.Character)
        if part then
            Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, part.Position)
        end
    end
end

-- ===================== ESP & CHAMS =====================
local espFolder = Instance.new("Folder")
espFolder.Name = "ESP"
espFolder.Parent = visualFolder

local function buildESP(plr)
    if plr == LP then return end
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    -- CHAMS (Silueta sólida)
    if CONFIG.CHAMS_ENABLED then
        local chamsHl = Instance.new("Highlight")
        chamsHl.Name = "Chams_"..plr.Name
        chamsHl.Adornee = char
        chamsHl.FillColor = CONFIG.CHAMS_COLOR
        chamsHl.FillTransparency = CONFIG.CHAMS_TRANSP
        chamsHl.OutlineColor = CONFIG.CHAMS_COLOR
        chamsHl.OutlineTransparency = 0
        chamsHl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        chamsHl.Parent = espFolder
    end

    -- ESP (Caja y distancia)
    if CONFIG.ESP_ENABLED then
        local bb = Instance.new("BillboardGui")
        bb.Name = "ESP_"..plr.Name
        bb.Size = UDim2.fromOffset(50, 50)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.AlwaysOnTop = true
        bb.Parent = espFolder

        if CONFIG.ESP_BOX then
            local box = Instance.new("Frame")
            box.Size = UDim2.fromScale(1, 1.5) 
            box.Position = UDim2.fromScale(0, -0.25)
            box.BackgroundTransparency = 1
            box.BorderSizePixel = 0
            box.Parent = bb
            
            local stroke = Instance.new("UIStroke")
            stroke.Color = CONFIG.ESP_COLOR
            stroke.Thickness = CONFIG.ESP_BOX_SIZE
            stroke.Transparency = CONFIG.ESP_TRANSP
            stroke.Parent = box
        end

        if CONFIG.ESP_SHOW_DIST then
            local txt = Instance.new("TextLabel")
            txt.Name = "DistTxt"
            txt.Size = UDim2.fromOffset(100, 20)
            txt.Position = UDim2.fromOffset(-25, -20)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = CONFIG.ESP_COLOR
            txt.TextStrokeTransparency = 0.5
            txt.Font = Enum.Font.GothamBold
            txt.TextSize = 12
            txt.Text = ""
            txt.Parent = bb
        end
    end
end

local function refreshESP()
    for _, c in ipairs(espFolder:GetChildren()) do c:Destroy() end
    for _, p in ipairs(Players:GetPlayers()) do buildESP(p) end
end

-- ===================== LÓGICA PRINCIPAL =====================
conn(RunService:BindToRenderStep("AimbotPro",
    Enum.RenderPriority.Camera.Value + 1, function(dt)
    if unloaded then return end
    Camera = Workspace.CurrentCamera

    if circle then
        circle.Position = Camera.ViewportSize / 2
        circle.Radius = CONFIG.FOV / 2
        circle.Visible = CONFIG.SHOW_FOV and enabled
    end

    if not enabled then return end

    local hold = CONFIG.ACTIVATION == "Hold RMB" and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    if CONFIG.ACTIVATION == "Hold RMB" and not hold then
        release()
        return
    end

    if locked and (not isAlive(locked) or not getPart(locked.Character)) then
        release()
        needRelock = true
    end

    if needRelock and not locked then
        acquire()
        if locked then needRelock = false end
    end

    if not locked then return end
    local part = getPart(locked.Character)
    if not part then return end

    local goal = predict(part.Position, part.AssemblyLinearVelocity)
    local goalCF = CFrame.lookAt(Camera.CFrame.Position, goal)

    if CONFIG.MODE == "Snap" then
        Camera.CFrame = goalCF
    else
        local alpha = 1 - (1 - CONFIG.SMOOTHNESS) ^ (math.min(dt, 0.05) * 60)
        Camera.CFrame = Camera.CFrame:Lerp(goalCF, math.clamp(alpha, 0, 1))
    end
end))

conn(RunService.Heartbeat:Connect(function()
    if not CONFIG.ESP_ENABLED and not CONFIG.CHAMS_ENABLED then return end
    
    for _, obj in ipairs(espFolder:GetChildren()) do
        local plrName = obj.Name:gsub("ESP_", ""):gsub("Chams_", "")
        local plr = Players:FindFirstChild(plrName)
        
        if plr and plr.Character and isAlive(plr) then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                local dist = (head.Position - Camera.CFrame.Position).Magnitude
                local isTeam = CONFIG.ESP_TEAM_CHECK and LP.Team and plr.Team == LP.Team
                local show = not isTeam and dist <= CONFIG.ESP_MAX_DIST
                
                if obj:IsA("Highlight") then
                    obj.Enabled = show and CONFIG.CHAMS_ENABLED
                elseif obj:IsA("BillboardGui") then
                    obj.Enabled = show and CONFIG.ESP_ENABLED
                    obj.Adornee = head
                    local txt = obj:FindFirstChild("DistTxt")
                    if txt and CONFIG.ESP_SHOW_DIST then 
                        txt.Text = string.format("[%dm]", math.floor(dist)) 
                    end
                end
            end
        else
            obj.Enabled = false
        end
    end
end))

-- ===================== INTERFAZ GRÁFICA (GETHUI) =====================
local gui = Instance.new("ScreenGui")
gui.Name = "AimbotProUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

-- Intentar usar gethui() para ocultar la GUI de los anticheats
local success, err = pcall(function()
    if gethui then
        gui.Parent = gethui()
    else
        gui.Parent = game:GetService("CoreGui")
    end
end)

if not success or not gui.Parent then
    gui.Parent = game:GetService("CoreGui")
end

local COLOR_BG = Color3.fromRGB(10, 5, 10)
local COLOR_RED = Color3.fromRGB(255, 0, 50)
local COLOR_PURPLE = Color3.fromRGB(150, 50, 255)
local COLOR_TEXT = Color3.fromRGB(240, 240, 240)

local function mkBtn(parent, text, w, h, x, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, h)
    b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
    b.TextColor3 = COLOR_TEXT
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Text = text
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    local s = Instance.new("UIStroke", b)
    s.Color = COLOR_PURPLE
    s.Thickness = 1
    return b
end

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(750, 500)
panel.Position = UDim2.new(0.5, -375, 0.5, -250)
panel.BackgroundColor3 = COLOR_BG
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
local ps = Instance.new("UIStroke", panel)
ps.Color = COLOR_PURPLE
ps.Thickness = 1.5

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 40)
topBar.BackgroundColor3 = Color3.fromRGB(20, 10, 20)
topBar.Parent = panel
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.fromOffset(200, 40)
title.Position = UDim2.fromOffset(20, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 20
title.TextColor3 = COLOR_RED
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "AIMBOT <font color='#FFFFFF'>PRO</font>"
title.RichText = true
title.Parent = topBar

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.fromOffset(150, 40)
statusLabel.Position = UDim2.new(0.5, -75, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamBold
statusLabel.TextSize = 14
statusLabel.TextColor3 = COLOR_RED
statusLabel.Text = "ESTADO: DESACTIVADO"
statusLabel.Parent = topBar

local minBtn = mkBtn(topBar, "_", 30, 30, 670, 5)
minBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 10)
minBtn.MouseButton1Click:Connect(function()
    panel.Visible = false
    floatIcon.Visible = true
end)

local closeBtn = mkBtn(topBar, "X", 30, 30, 710, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 10, 10)
closeBtn.MouseButton1Click:Connect(function()
    unloaded = true
    gui:Destroy()
    if visualFolder then visualFolder:Destroy() end
    if circle then circle:Remove() end
    RunService:UnbindFromRenderStep("AimbotPro")
end)

local floatIcon = Instance.new("TextButton")
floatIcon.Size = UDim2.fromOffset(60, 60)
floatIcon.Position = UDim2.fromOffset(20, 20)
floatIcon.BackgroundColor3 = COLOR_BG
floatIcon.Text = "AP"
floatIcon.TextColor3 = COLOR_RED
floatIcon.Font = Enum.Font.GothamBlack
floatIcon.TextSize = 18
floatIcon.Visible = false
floatIcon.Parent = gui
Instance.new("UICorner", floatIcon).CornerRadius = UDim.new(1, 0)
local fStroke = Instance.new("UIStroke", floatIcon)
fStroke.Color = COLOR_PURPLE
fStroke.Thickness = 2
floatIcon.MouseButton1Click:Connect(function()
    panel.Visible = true
    floatIcon.Visible = false
end)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.fromOffset(180, 420)
sidebar.Position = UDim2.fromOffset(10, 60)
sidebar.BackgroundTransparency = 1
sidebar.Parent = panel

local tabs = {"AIMBOT", "VISUALES", "MISC", "CONFIG"}
local pages = {}

for i, tabName in ipairs(tabs) do
    local b = mkBtn(sidebar, "   " .. tabName, 160, 35, 10, (i-1) * 45)
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.MouseButton1Click:Connect(function()
        for _, p in pairs(pages) do p.Visible = false end
        pages[tabName].Visible = true
        for _, btn in ipairs(sidebar:GetChildren()) do
            if btn:IsA("TextButton") then btn.BackgroundColor3 = Color3.fromRGB(20, 15, 20) end
        end
        b.BackgroundColor3 = Color3.fromRGB(40, 10, 20)
    end)
end

local pageContainer = Instance.new("Frame")
pageContainer.Size = UDim2.new(1, -200, 1, -110)
pageContainer.Position = UDim2.fromOffset(200, 60)
pageContainer.BackgroundTransparency = 1
pageContainer.Parent = panel

local function mkRow(parent, text, y, isToggle, get, set, options)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -10, 0, 35)
    f.Position = UDim2.fromOffset(5, y)
    f.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromOffset(250, 35)
    l.Position = UDim2.fromOffset(10, 0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 13
    l.TextColor3 = COLOR_TEXT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = text
    l.Parent = f
    
    if isToggle then
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.fromOffset(40, 20)
        btn.Position = UDim2.new(1, -50, 0.5, -10)
        btn.BackgroundColor3 = get() and COLOR_RED or Color3.fromRGB(50, 50, 50)
        btn.Text = ""
        btn.Parent = f
        Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
        btn.MouseButton1Click:Connect(function()
            set(not get())
            btn.BackgroundColor3 = get() and COLOR_RED or Color3.fromRGB(50, 50, 50)
        end)
    elseif options then
        local btn = mkBtn(f, get(), 150, 25, 250, 5)
        btn.MouseButton1Click:Connect(function()
            local idx = 1
            for i, v in ipairs(options) do if v == get() then idx = i end end
            local nextIdx = (idx % #options) + 1
            set(options[nextIdx])
            btn.Text = options[nextIdx]
        end)
    end
    return f
end

local function mkSlider(parent, label, y, get, set, min, max)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -10, 0, 40)
    f.Position = UDim2.fromOffset(5, y)
    f.BackgroundColor3 = Color3.fromRGB(20, 15, 20)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 4)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromOffset(200, 40)
    l.Position = UDim2.fromOffset(10, 0)
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 13
    l.TextColor3 = COLOR_TEXT
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = label
    l.Parent = f
    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.fromOffset(200, 6)
    barBg.Position = UDim2.new(0, 220, 0.5, -3)
    barBg.BackgroundColor3 = Color3.fromRGB(50, 20, 50)
    barBg.Parent = f
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new((get() - min) / (max - min), 0, 1, 0)
    barFill.BackgroundColor3 = COLOR_RED
    barFill.Parent = barBg
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(12, 12)
    knob.Position = UDim2.new(1, -6, 0.5, -6)
    knob.BackgroundColor3 = COLOR_PURPLE
    knob.Parent = barFill
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local val = Instance.new("TextLabel")
    val.Size = UDim2.fromOffset(40, 40)
    val.Position = UDim2.new(1, -40, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = string.format("%.0f", get())
    val.TextColor3 = COLOR_TEXT
    val.Parent = f
    local dragging = false
    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local relX = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
            local v = min + (max - min) * relX
            set(v)
            barFill.Size = UDim2.new(relX, 0, 1, 0)
            val.Text = string.format("%.0f", v)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

-- ===================== PAGINA AIMBOT =====================
local aimPage = Instance.new("ScrollingFrame")
aimPage.Size = UDim2.fromScale(1, 1)
aimPage.BackgroundTransparency = 1
aimPage.BorderSizePixel = 0
aimPage.ScrollBarThickness = 2
aimPage.CanvasSize = UDim2.new(0, 0, 0, 500)
aimPage.Parent = pageContainer
pages["AIMBOT"] = aimPage

mkRow(aimPage, "Activar Aimbot", 10, true, 
    function() return enabled end, 
    function(v) 
        enabled = v
        statusLabel.Text = v and "ESTADO: ACTIVADO" or "ESTADO: DESACTIVADO"
        statusLabel.TextColor3 = v and Color3.fromRGB(0,255,0) or COLOR_RED
    end)

mkRow(aimPage, "Modo de Apuntado", 55, false,
    function() return CONFIG.AIM_PART end,
    function(v) CONFIG.AIM_PART = v end,
    {"Head", "Torso", "Closest"})

mkRow(aimPage, "Tecla de Activación", 100, false,
    function() return CONFIG.ACTIVATION end,
    function(v) CONFIG.ACTIVATION = v end,
    {"Always", "Hold RMB"})

mkSlider(aimPage, "Área de FOV", 145, 
    function() return CONFIG.FOV end, 
    function(v) CONFIG.FOV = v end, 20, 800)

mkSlider(aimPage, "Suavizado (Smooth)", 190, 
    function() return CONFIG.SMOOTHNESS * 100 end, 
    function(v) CONFIG.SMOOTHNESS = v / 100 end, 1, 100)

mkSlider(aimPage, "Velocidad de Seguimiento", 235, 
    function() return CONFIG.TRACK_SPEED * 100 end, 
    function(v) CONFIG.TRACK_SPEED = v / 100 end, 1, 100)

-- ===================== PAGINA VISUALES =====================
local visPage = Instance.new("ScrollingFrame")
visPage.Size = UDim2.fromScale(1, 1)
visPage.BackgroundTransparency = 1
visPage.BorderSizePixel = 0
visPage.ScrollBarThickness = 2
visPage.CanvasSize = UDim2.new(0, 0, 0, 500)
visPage.Visible = false
visPage.Parent = pageContainer
pages["VISUALES"] = visPage

mkRow(visPage, "ESP (Cajas)", 10, true,
    function() return CONFIG.ESP_ENABLED end,
    function(v) CONFIG.ESP_ENABLED = v; refreshESP() end)

mkRow(visPage, "CHAMS (Silueta)", 55, true,
    function() return CONFIG.CHAMS_ENABLED end,
    function(v) CONFIG.CHAMS_ENABLED = v; refreshESP() end)

mkRow(visPage, "Mostrar Distancia", 100, true,
    function() return CONFIG.ESP_SHOW_DIST end,
    function(v) CONFIG.ESP_SHOW_DIST = v; refreshESP() end)

mkSlider(visPage, "Tamaño de Caja", 145, 
    function() return CONFIG.ESP_BOX_SIZE end, 
    function(v) CONFIG.ESP_BOX_SIZE = v; refreshESP() end, 1, 5)

mkSlider(visPage, "Opacidad ESP", 190, 
    function() return CONFIG.ESP_TRANSP * 100 end, 
    function(v) CONFIG.ESP_TRANSP = v / 100; refreshESP() end, 0, 100)

mkSlider(visPage, "Opacidad CHAMS", 235, 
    function() return CONFIG.CHAMS_TRANSP * 100 end, 
    function(v) CONFIG.CHAMS_TRANSP = v / 100; refreshESP() end, 0, 100)

-- ===================== PAGINA MISC =====================
local miscPage = Instance.new("Frame")
miscPage.Size = UDim2.fromScale(1, 1)
miscPage.BackgroundTransparency = 1
miscPage.Visible = false
miscPage.Parent = pageContainer
pages["MISC"] = miscPage

mkRow(miscPage, "No Recoil (Visual)", 10, true,
    function() return CONFIG.NO_RECOIL end,
    function(v) CONFIG.NO_RECOIL = v end)

mkRow(miscPage, "No Spread (Visual)", 55, true,
    function() return CONFIG.NO_SPREAD end,
    function(v) CONFIG.NO_SPREAD = v end)

mkRow(miscPage, "Auto Disparo", 100, true,
    function() return CONFIG.AUTO_FIRE end,
    function(v) CONFIG.AUTO_FIRE = v end)

-- ===================== PAGINA CONFIG =====================
local cfgPage = Instance.new("Frame")
cfgPage.Size = UDim2.fromScale(1, 1)
cfgPage.BackgroundTransparency = 1
cfgPage.Visible = false
cfgPage.Parent = pageContainer
pages["CONFIG"] = cfgPage

local resetBtn = mkBtn(cfgPage, "RESTABLECER", 150, 40, 10, 20)
resetBtn.BackgroundColor3 = Color3.fromRGB(50, 10, 50)
resetBtn.MouseButton1Click:Connect(function()
    CONFIG.FOV = 120
    CONFIG.SMOOTHNESS = 0.85
    CONFIG.TRACK_SPEED = 0.70
    print("Configuración restablecida (No guardada)")
end)

local saveBtn = mkBtn(cfgPage, "GUARDAR CONFIG", 150, 40, 170, 20)
saveBtn.BackgroundColor3 = Color3.fromRGB(10, 50, 10)
saveBtn.MouseButton1Click:Connect(function()
    saveConfig()
    print("Configuración Guardada en el dispositivo.")
end)

-- ===================== ARRASTRAR =====================
local dragging, dragStart, startPos
panel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = panel.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType