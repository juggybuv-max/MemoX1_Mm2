local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local window = Rayfield:CreateWindow({
    name = "🎃 MM2 Halloween Hub",
    subtitle = "Rayfield Gen2",
    sidebarLayout = true,
})

-- Services & Variables
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local visitedPositions = {}
local isActive = false
local flySpeed = 15
local collected = 0
local startTime = 0
local antiAFK = false

-- ESP Toggles & Storage
local espInnocents = false
local espSheriff = false
local espMurderer = false
local espGun = false
local roles = {}
local Murder, Sheriff, Hero

-- Aimlock Variables
local aimlockActive = false
local aimlockConnection = nil

-- Bullet TP Variables
local bulletTpActive = false
local tpRemote = nil
local tpCurrentTarget = nil

-- Fling Variables
local selectedFlingTarget = nil
local playerDropdown = nil

-- Auto Grab Gun Variables
local autoGrabGunActive = false
local autoGrabDebounce = false

-- Shared Draggable Toggle for Mini Buttons
local miniUiDraggable = false

player.CharacterAdded:Connect(function(char)
	character = char
	rootPart = char:WaitForChild("HumanoidRootPart")
	visitedPositions = {}
end)

-- Sound
local collectSound = Instance.new("Sound")
collectSound.SoundId = "rbxassetid://12221967"
collectSound.Volume = 1
collectSound.Parent = rootPart

-- Helper Functions
local function flyTo(pos, speed)
	if not rootPart then return end
	local dist = (pos - rootPart.Position).Magnitude
	local tween = TweenService:Create(
		rootPart,
		TweenInfo.new(dist / speed, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(pos) }
	)
	tween:Play()
	tween.Completed:Wait()
end

-- Helper: Get Player Names List
local function getPlayerList()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            table.insert(names, p.Name)
        end
    end
    if #names == 0 then table.insert(names, "None") end
    return names
end

-- Helper: Find Dropped Gun Instance (GunDrop in Workspace)
local function getDroppedGun()
    local directGun = Workspace:FindFirstChild("GunDrop")
    if directGun then return directGun end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name == "GunDrop" then return v end
    end
    return nil
end

-- Teleport to Grab Gun Logic
local function performGrabGun()
    local droppedGun = getDroppedGun()
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

    if droppedGun and myHrp then
        local oldPos = myHrp.CFrame
        local gunCFrame = droppedGun:IsA("BasePart") and droppedGun.CFrame or droppedGun:GetPivot()
        
        myHrp.CFrame = gunCFrame
        task.wait(0.15)
        myHrp.CFrame = oldPos
        window:Notify({ title = "Grab Gun", content = "Teleported to GunDrop and returned!" })
    else
        window:Notify({ title = "Grab Gun", content = "No GunDrop found in Workspace!" })
    end
end

-- Auto Grab Gun Loop
task.spawn(function()
    while true do
        task.wait(0.3)
        if autoGrabGunActive and not autoGrabDebounce then
            local droppedGun = getDroppedGun()
            local backpack = player:FindFirstChildOfClass("Backpack")
            local myChar = player.Character
            local hasGun = (myChar and myChar:FindFirstChild("Gun")) or (backpack and backpack:FindFirstChild("Gun"))

            if droppedGun and not hasGun then
                autoGrabDebounce = true
                performGrabGun()
                task.wait(2)
                autoGrabDebounce = false
            end
        end
    end
end)

-- Bullet TP Target Retrieval via Remote Data
local function getMurder()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local extras = remotes and remotes:FindFirstChild("Extras")
    local remote = extras and extras:FindFirstChild("GetPlayerData")
    if not remote then return nil end

    local success, data = pcall(function()
        return remote:InvokeServer()
    end)
    if not success or not data or type(data) ~= "table" then return nil end

    for i, plr in pairs(data) do
        if plr.Role == "Murderer" then
            local murd = Players:FindFirstChild(i)
            if murd and murd.Character and murd.Character:FindFirstChild("HumanoidRootPart") then
                return murd.Character.HumanoidRootPart
            end
        end
    end
    return nil
end

local function getRemote()
    local backpack = player:FindFirstChildOfClass("Backpack")
    local char = player.Character

    if backpack and backpack:FindFirstChild("Gun") then
        return backpack:FindFirstChild("Gun"):FindFirstChild("Shoot", true)
    elseif char and char:FindFirstChild("Gun") then
        return char:FindFirstChild("Gun"):FindFirstChild("Shoot", true)
    end
end

RunService.RenderStepped:Connect(function()
    if bulletTpActive then
        tpRemote = getRemote()
        tpCurrentTarget = getMurder()
    end
end)

-- Hook Metamethod for Bullet TP
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local args = {...}
    local method = getnamecallmethod()

    if bulletTpActive and tpRemote and self == tpRemote and method == "FireServer" then
        if not tpCurrentTarget then return oldNamecall(self, ...) end

        args[1] = tpCurrentTarget.CFrame + Vector3.new(0,3,0)
        args[2] = tpCurrentTarget.CFrame

        return oldNamecall(self, unpack(args))
    end

    return oldNamecall(self, ...)
end)

-- Fixed MM2 Hub Fling Function (Anti-Void Return)
local function flingTarget(target)
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local myChar = player.Character
    local tChar = target.Character
    if myChar and myChar:FindFirstChild("HumanoidRootPart") then
        local myHRP = myChar.HumanoidRootPart
        local tHRP = tChar.HumanoidRootPart
        local old = myHRP.CFrame
        
        local vel = Instance.new("BodyVelocity")
        vel.Velocity = Vector3.new(999999, 999999, 999999)
        vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        vel.Parent = myHRP
        
        for _, p in pairs(myChar:GetChildren()) do 
            if p:IsA("BasePart") then p.CanCollide = false end 
        end
        
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if tHRP and myHRP then
                myHRP.CFrame = tHRP.CFrame * CFrame.Angles(math.rad(math.random(0,360)), math.rad(math.random(0,360)), math.rad(math.random(0,360)))
            end
        end)
        
        task.wait(1.5)
        
        conn:Disconnect()
        vel:Destroy()
        
        myHRP.Anchored = true
        myHRP.AssemblyLinearVelocity = Vector3.zero
        myHRP.AssemblyAngularVelocity = Vector3.zero
        myHRP.Velocity = Vector3.zero
        
        myHRP.CFrame = old
        task.wait(0.05)
        myHRP.Anchored = false
    end
end

-- Dragging Logic Helper
local function makeDraggable(button)
    local dragging = false
    local dragStart, startPos

    button.InputBegan:Connect(function(input)
        if not miniUiDraggable then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = button.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and miniUiDraggable and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            button.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

-- ──────────────────────────────────────────────
-- MINI UI 1: AIMLOCK BUTTON
-- ──────────────────────────────────────────────
local aimGui = Instance.new("ScreenGui")
aimGui.Name = "MM2_Aimlock_MiniUI"
aimGui.ResetOnSpawn = false
aimGui.Enabled = false
aimGui.Parent = player:WaitForChild("PlayerGui")

local aimBtn = Instance.new("TextButton")
aimBtn.Name = "AimButton"
aimBtn.Size = UDim2.fromOffset(65, 65)
aimBtn.Position = UDim2.new(0.8, 0, 0.45, 0)
aimBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
aimBtn.Text = "🎯 Aimlock\nOFF"
aimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
aimBtn.Font = Enum.Font.GothamBold
aimBtn.TextSize = 11
aimBtn.Active = true
aimBtn.Parent = aimGui

Instance.new("UICorner", aimBtn).CornerRadius = UDim.new(1, 0)
local aimStroke = Instance.new("UIStroke", aimBtn)
aimStroke.Color = Color3.fromRGB(255, 120, 0)
aimStroke.Thickness = 2

makeDraggable(aimBtn)

aimBtn.MouseButton1Click:Connect(function()
    aimlockActive = not aimlockActive
    if aimlockActive then
        aimBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
        aimBtn.Text = "🎯 Aimlock\nON"
        
        aimlockConnection = RunService.RenderStepped:Connect(function()
            if aimlockActive then
                local murdChar = getMurdererCharacter()
                if murdChar and murdChar:FindFirstChild("HumanoidRootPart") then
                    camera.CFrame = CFrame.new(camera.CFrame.Position, murdChar.HumanoidRootPart.Position)
                end
            end
        end)
    else
        aimBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
        aimBtn.Text = "🎯 Aimlock\nOFF"
        if aimlockConnection then
            aimlockConnection:Disconnect()
            aimlockConnection = nil
        end
    end
end)

-- Helper for aimlock target lookup
function getMurdererCharacter()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local extras = remotes and remotes:FindFirstChild("Extras")
    local remote = extras and extras:FindFirstChild("GetPlayerData")
    if not remote then return nil end
    local success, data = pcall(function() return remote:InvokeServer() end)
    if not success or not data or type(data) ~= "table" then return nil end
    for i, plr in pairs(data) do
        if plr.Role == "Murderer" then
            local murd = Players:FindFirstChild(i)
            if murd and murd.Character then return murd.Character end
        end
    end
    return nil
end

-- ──────────────────────────────────────────────
-- MINI UI 2: BULLET TP BUTTON
-- ──────────────────────────────────────────────
local bulletGui = Instance.new("ScreenGui")
bulletGui.Name = "MM2_BulletTP_MiniUI"
bulletGui.ResetOnSpawn = false
bulletGui.Enabled = false
bulletGui.Parent = player:WaitForChild("PlayerGui")

local bulletBtn = Instance.new("TextButton")
bulletBtn.Name = "BulletButton"
bulletBtn.Size = UDim2.fromOffset(70, 65)
bulletBtn.Position = UDim2.new(0.8, 0, 0.58, 0)
bulletBtn.BackgroundColor3 = Color3.fromRGB(20, 80, 120)
bulletBtn.Text = "🔫 Bullet TP\nOFF"
bulletBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
bulletBtn.Font = Enum.Font.GothamBold
bulletBtn.TextSize = 11
bulletBtn.Active = true
bulletBtn.Parent = bulletGui

Instance.new("UICorner", bulletBtn).CornerRadius = UDim.new(0, 12)
local bulletStroke = Instance.new("UIStroke", bulletBtn)
bulletStroke.Color = Color3.fromRGB(255, 120, 0)
bulletStroke.Thickness = 2

makeDraggable(bulletBtn)

bulletBtn.MouseButton1Click:Connect(function()
    bulletTpActive = not bulletTpActive
    if bulletTpActive then
        bulletBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
        bulletBtn.Text = "🔫 Bullet TP\nON"
        window:Notify({ title = "Bullet TP", content = "Bullet TP Enabled!" })
    else
        bulletBtn.BackgroundColor3 = Color3.fromRGB(20, 80, 120)
        bulletBtn.Text = "🔫 Bullet TP\nOFF"
        window:Notify({ title = "Bullet TP", content = "Bullet TP Disabled!" })
    end
end)

-- ──────────────────────────────────────────────
-- MINI UI 3: GRAB GUN BUTTON
-- ──────────────────────────────────────────────
local grabGunGui = Instance.new("ScreenGui")
grabGunGui.Name = "MM2_GrabGun_MiniUI"
grabGunGui.ResetOnSpawn = false
grabGunGui.Enabled = false
grabGunGui.Parent = player:WaitForChild("PlayerGui")

local grabGunBtn = Instance.new("TextButton")
grabGunBtn.Name = "GrabGunButton"
grabGunBtn.Size = UDim2.fromOffset(70, 65)
grabGunBtn.Position = UDim2.new(0.8, 0, 0.71, 0)
grabGunBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 140)
grabGunBtn.Text = "🔫\nGrab Gun"
grabGunBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
grabGunBtn.Font = Enum.Font.GothamBold
grabGunBtn.TextSize = 11
grabGunBtn.Active = true
grabGunBtn.Parent = grabGunGui

Instance.new("UICorner", grabGunBtn).CornerRadius = UDim.new(0, 12)
local grabGunStroke = Instance.new("UIStroke", grabGunBtn)
grabGunStroke.Color = Color3.fromRGB(255, 120, 0)
grabGunStroke.Thickness = 2

makeDraggable(grabGunBtn)

grabGunBtn.MouseButton1Click:Connect(function()
    performGrabGun()
end)

-- Anti-AFK Listener
player.Idled:Connect(function()
	if antiAFK then
		VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
		task.wait(1)
		VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	end
end)

-- No-Collide Listener
RunService.Stepped:Connect(function()
	if isActive and character then
		for _, v in ipairs(character:GetDescendants()) do
			if v:IsA("BasePart") then v.CanCollide = false end
		end
	end
end)

-- ──────────────────────────────────────────────
-- TAB 1: COMBAT (GRID GROUP LAYOUT)
-- ──────────────────────────────────────────────
local CombatTab = window:CreateTab({ name = "Combat", icon = 10747373176 })

local combatGrid = CombatTab:CreateGroup()

-- Left Column: Gun & Auto Grab Tools
local combatLeft = combatGrid:CreateGroup({ direction = "column" })

combatLeft:CreateButton({
    name = "📖 How to use Bullet TP",
    callback = function()
        window:Notify({
            title = "Bullet TP Guide",
            content = "it tp bullet to murd works 35% times, to use it make it on then tap"
        })
    end,
})

combatLeft:CreateToggle({
    name = "🔫 Bullet TP",
    callback = function(value)
        bulletTpActive = value
        bulletGui.Enabled = value
        if bulletTpActive then
            bulletBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
            bulletBtn.Text = "🔫 Bullet TP\nON"
            window:Notify({ title = "Bullet TP", content = "Bullet TP Enabled & Button Spawned!" })
        else
            bulletBtn.BackgroundColor3 = Color3.fromRGB(20, 80, 120)
            bulletBtn.Text = "🔫 Bullet TP\nOFF"
            window:Notify({ title = "Bullet TP", content = "Bullet TP Disabled!" })
        end
    end,
})

combatLeft:CreateToggle({
    name = "⚡ Auto Grab Gun (Instant)",
    callback = function(value)
        autoGrabGunActive = value
        if value then
            window:Notify({ title = "Auto Grab Gun", content = "Will automatically TP to GunDrop when dropped!" })
        else
            window:Notify({ title = "Auto Grab Gun", content = "Auto Grab Disabled!" })
        end
    end,
})

combatLeft:CreateToggle({
    name = "🔫 Show Grab Gun Mini Button",
    callback = function(value)
        grabGunGui.Enabled = value
        if value then
            window:Notify({ title = "Grab Gun UI", content = "Mini UI Button Spawned!" })
        end
    end,
})

-- Right Column: Player Fling, Bring & Aimlock
local combatRight = combatGrid:CreateGroup({ direction = "column" })

playerDropdown = combatRight:CreateDropdown({
    name = "Select Player to Fling",
    options = getPlayerList(),
    currentOption = "",
    callback = function(option)
        selectedFlingTarget = option
    end,
})

combatRight:CreateButton({
    name = "🔄 Refresh Player List",
    callback = function()
        if playerDropdown and playerDropdown.Refresh then
            playerDropdown:Refresh(getPlayerList())
            window:Notify({ title = "Fling", content = "Player list refreshed successfully!" })
        end
    end,
})

combatRight:CreateButton({
    name = "🌀 Fling Selected Player",
    callback = function()
        if not selectedFlingTarget or selectedFlingTarget == "" or selectedFlingTarget == "None" then
            window:Notify({ title = "Fling Error", content = "Please select a valid player first!" })
            return
        end

        local targetPlr = Players:FindFirstChild(selectedFlingTarget)
        if targetPlr and targetPlr.Character then
            window:Notify({ title = "Flinging", content = "Executing BodyVelocity fling on " .. selectedFlingTarget .. "..." })
            flingTarget(targetPlr)
            window:Notify({ title = "Fling Complete", content = "Successfully returned to starting position!" })
        else
            window:Notify({ title = "Fling Error", content = "Target player character not found!" })
        end
    end,
})

combatRight:CreateButton({
    name = "📖 How to use Bring All",
    callback = function()
        window:Notify({
            title = "How to use Bring All",
            content = "Hold your knife, then tap 'Client Bring All Players' to teleport everyone to you and win as murderer easily!"
        })
    end,
})

combatRight:CreateButton({
    name = "🔪 Client Bring All Players",
    callback = function()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if not hrp then
            window:Notify({ title = "Error", content = "Character not found!" })
            return
        end

        local broughtCount = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local otherHrp = p.Character:FindFirstChild("HumanoidRootPart")
                if otherHrp then
                    otherHrp.CFrame = hrp.CFrame + (hrp.CFrame.LookVector * 3)
                    broughtCount = broughtCount + 1
                end
            end
        end

        window:Notify({
            title = "Bring All",
            content = "Brought " .. broughtCount .. " players to you!"
        })
    end,
})

combatRight:CreateToggle({
    name = "🎯 Show Aimlock Button",
    callback = function(value)
        aimGui.Enabled = value
        if value then
            window:Notify({ title = "Aimlock", content = "Mini Button Spawned!" })
        end
    end,
})

combatRight:CreateToggle({
    name = "✋ Draggable Mini Buttons",
    callback = function(value)
        miniUiDraggable = value
        if value then
            aimStroke.Color = Color3.fromRGB(0, 255, 0)
            bulletStroke.Color = Color3.fromRGB(0, 255, 0)
            grabGunStroke.Color = Color3.fromRGB(0, 255, 0)
            window:Notify({ title = "Mini Buttons", content = "You can now drag and place mini UI buttons." })
        else
            aimStroke.Color = Color3.fromRGB(255, 120, 0)
            bulletStroke.Color = Color3.fromRGB(255, 120, 0)
            grabGunStroke.Color = Color3.fromRGB(255, 120, 0)
            window:Notify({ title = "Mini Buttons", content = "Mini UI button positions locked." })
        end
    end,
})

-- ──────────────────────────────────────────────
-- TAB 2: AUTO FARM
-- ──────────────────────────────────────────────
local FarmTab = window:CreateTab({ name = "Auto Farm", icon = 10734950309 })

FarmTab:CreateToggle({
    name = "🎃 Auto Farm",
    callback = function(value)
        isActive = value
        if isActive then
            collected = 0
            startTime = tick()
            visitedPositions = {}
            window:Notify({ title = "Auto Farm", content = "Farming Started!" })

            task.spawn(function()
                while isActive do
                    character = player.Character or player.CharacterAdded:Wait()
                    rootPart = character:FindFirstChild("HumanoidRootPart")
                    if rootPart then
                        local closest, shortest = nil, math.huge
                        for _, obj in ipairs(workspace:GetDescendants()) do
                            if obj:IsA("BasePart") and obj.Name == "Coin_Server" then
                                local dist = (obj.Position - rootPart.Position).Magnitude
                                if dist < shortest and dist < 250 and not visitedPositions[obj] then
                                    closest = obj
                                    shortest = dist
                                end
                            end
                        end
                        if closest and closest.Parent and closest:IsDescendantOf(workspace) then
                            flyTo(closest.Position, flySpeed)
                            if closest and closest.Parent and closest:IsDescendantOf(workspace) then
                                visitedPositions[closest] = true
                                collected = collected + 1
                                if collectSound and collectSound.Parent then
                                    collectSound:Play()
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        else
            window:Notify({ title = "Auto Farm", content = "Farming Stopped!" })
        end
    end,
})

FarmTab:CreateSlider({
    name = "💨 Tween Speed",
    range = { 10, 25 },
    increment = 1,
    value = 15,
    suffix = " spd",
    callback = function(value)
        flySpeed = value
    end,
})

FarmTab:CreateToggle({
    name = "👻 Anti-AFK",
    callback = function(value)
        antiAFK = value
    end,
})

FarmTab:CreateButton({
    name = "📊 Check Farm Stats",
    callback = function()
        local elapsed = startTime > 0 and math.floor(tick() - startTime) or 0
        local rate = elapsed > 0 and math.floor((collected / elapsed) * 3600) or 0
        window:Notify({
            title = "Farm Stats",
            content = "Collected: " .. collected .. " | Time: " .. elapsed .. "s | Coins/Hr: " .. rate
        })
    end,
})

FarmTab:CreateButton({
    name = "🔄 Reset Counter",
    callback = function()
        collected = 0
        startTime = tick()
        window:Notify({ title = "Reset", content = "Coin counter has been reset." })
    end,
})

-- ──────────────────────────────────────────────
-- TAB 3: ESP (STICKY ROLE MODULE + GUN ESP)
-- ──────────────────────────────────────────────
local EspTab = window:CreateTab({ name = "ESP", icon = 10723415903 })

local espGrid = EspTab:CreateGroup()

-- Left Column: Guide & Role ESP Toggles
local espLeft = espGrid:CreateGroup({ direction = "column" })

espLeft:CreateButton({
    name = "❓ ESP Meanings",
    callback = function()
        window:Notify({
            title = "ESP Colors",
            content = "🟢 = Innocent | 🔴 = Murderer | 🔵 = Sheriff | 🟡 = Hero | 🟣 = Dropped Gun (GunDrop)"
        })
    end,
})

espLeft:CreateToggle({
    name = "🟢 ESP Innocents",
    callback = function(value)
        espInnocents = value
    end,
})

espLeft:CreateToggle({
    name = "🔵 ESP Sheriff / Hero",
    callback = function(value)
        espSheriff = value
    end,
})

-- Right Column: High Priority ESP Toggles
local espRight = espGrid:CreateGroup({ direction = "column" })

espRight:CreateToggle({
    name = "🔴 ESP Murderer",
    callback = function(value)
        espMurderer = value
    end,
})

espRight:CreateToggle({
    name = "🟣 ESP Dropped Gun",
    callback = function(value)
        espGun = value
    end,
})

-- Sticky Helper functions for role-based ESP
local function CreateHighlight()
	for _, v in pairs(Players:GetChildren()) do
		if v ~= player and v.Character then
			local hl = v.Character:FindFirstChild("MM2_Role_Highlight")
			if not hl then
				hl = Instance.new("Highlight")
				hl.Name = "MM2_Role_Highlight"
				hl.Parent = v.Character           
			end
		end
	end
end

local function IsAlive(Player)
	if not roles then return false end
	for i, v in pairs(roles) do
		if Player.Name == i then
			if not v.Killed and not v.Dead then
				return true
			else
				return false
			end
		end
	end
	return false
end

local function UpdateHighlights()
	for _, v in pairs(Players:GetChildren()) do
		if v ~= player and v.Character then
			local hl = v.Character:FindFirstChild("MM2_Role_Highlight")
			if hl then
				local show = false
				local color = Color3.fromRGB(0, 225, 0)

				if roles and roles[v.Name] then
					if v.Name == Sheriff and IsAlive(v) and espSheriff then
						color = Color3.fromRGB(50, 150, 255)
						show = true
					elseif v.Name == Murder and IsAlive(v) and espMurderer then
						color = Color3.fromRGB(255, 50, 50)
						show = true
					elseif v.Name == Hero and IsAlive(v) and not IsAlive(Players:FindFirstChild(Sheriff or "")) and espSheriff then
						color = Color3.fromRGB(255, 250, 0)
						show = true
					elseif espInnocents and IsAlive(v) then
						color = Color3.fromRGB(0, 225, 0)
						show = true
					end
				end

				if show then
					hl.Enabled = true
					hl.FillColor = color
					hl.OutlineColor = Color3.fromRGB(255, 255, 255)
				else
					hl.Enabled = false
				end
			end
		end
	end
end

-- RenderStepped ESP Loop (Sticky Roles + Workspace.GunDrop)
RunService.RenderStepped:Connect(function()
    -- Fetch roles safely every frame without crashing loop
    local success, res = pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        local extras = remotes and remotes:FindFirstChild("Extras")
        local remote = extras and extras:FindFirstChild("GetPlayerData")
        return remote and remote:InvokeServer()
    end)
    
    if success and res and type(res) == "table" then
        roles = res
        Murder, Sheriff, Hero = nil, nil, nil
        for i, v in pairs(roles) do
            if v.Role == "Murderer" then
                Murder = i
            elseif v.Role == 'Sheriff' then
                Sheriff = i
            elseif v.Role == 'Hero' then
                Hero = i
            end
        end
    end

    CreateHighlight()
    UpdateHighlights()

    -- Workspace.GunDrop ESP (Purple 🟣 + "GUN" Tag)
    local droppedGun = getDroppedGun()
    if droppedGun then
        local hl = droppedGun:FindFirstChild("MM2_Gun_Highlight")
        local bbGui = droppedGun:FindFirstChild("MM2_Gun_TextESP")
        
        if espGun then
            if not hl then
                hl = Instance.new("Highlight")
                hl.Name = "MM2_Gun_Highlight"
                hl.Parent = droppedGun
            end
            hl.Enabled = true
            hl.FillColor = Color3.fromRGB(170, 0, 255)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)

            if not bbGui then
                bbGui = Instance.new("BillboardGui")
                bbGui.Name = "MM2_Gun_TextESP"
                bbGui.Size = UDim2.new(0, 100, 0, 30)
                bbGui.StudsOffset = Vector3.new(0, 2, 0)
                bbGui.AlwaysOnTop = true
                bbGui.Parent = droppedGun

                local txtLabel = Instance.new("TextLabel")
                txtLabel.Name = "GunLabel"
                txtLabel.Size = UDim2.new(1, 0, 1, 0)
                txtLabel.BackgroundTransparency = 1
                txtLabel.Text = "🔫 GUN"
                txtLabel.TextColor3 = Color3.fromRGB(200, 80, 255)
                txtLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                txtLabel.TextStrokeTransparency = 0
                txtLabel.Font = Enum.Font.GothamBold
                txtLabel.TextSize = 14
                txtLabel.Parent = bbGui
            end
            bbGui.Enabled = true
        else
            if hl then hl:Destroy() end
            if bbGui then bbGui:Destroy() end
        end
    end
end)
