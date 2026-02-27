local TargetPage = ...
if not TargetPage then warn("Module harus di-load dari Kzoyz Index!") return end

-- [[ FIX SCROLL MENTOK ]] --
TargetPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
TargetPage.CanvasSize = UDim2.new(0, 0, 0, 0)
local listLayout = TargetPage:FindFirstChildWhichIsA("UIListLayout")
if listLayout then
    TargetPage.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 30)
    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TargetPage.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 30)
    end)
end
------------------------------

getgenv().ScriptVersion = "Pabrik v0.74-SaplingOnly" 

-- ========================================== --
-- [[ SETTING KECEPATAN BASE ]]
getgenv().PlaceDelay = 0.05  
getgenv().DropDelay = 0.5      
getgenv().StepDelay = 0.1   
getgenv().BreakDelay = 0.15 
-- ========================================== --

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser") 
local RunService = game:GetService("RunService")

local PlayerMovement
pcall(function() PlayerMovement = require(LP.PlayerScripts:WaitForChild("PlayerMovement")) end)

LP.Idled:Connect(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end)

-- [[ CLEANUP PABRIK HEARTBEAT ]] --
if getgenv().KzoyzHeartbeatPabrik then getgenv().KzoyzHeartbeatPabrik:Disconnect(); getgenv().KzoyzHeartbeatPabrik = nil end

-- [[ VARIABEL GLOBAL ]] --
getgenv().GridSize = 4.5; 
getgenv().HitCount = 3    
getgenv().EnablePabrik = false
getgenv().PabrikStartX = 0; getgenv().PabrikEndX = 10; getgenv().PabrikYPos = 37
getgenv().GrowthTime = 30 
getgenv().BreakPosX = 0; getgenv().BreakPosY = 0
getgenv().DropPosX = 0; getgenv().DropPosY = 0

getgenv().BlockThreshold = 20 
getgenv().KeepSeedAmt = 20    

getgenv().SelectedSeed = ""; getgenv().SelectedBlock = "" 
getgenv().IsGhosting = false
getgenv().HoldCFrame = nil

-- [[ HEARTBEAT UNTUK GHOSTING FASE 4 ]] --
getgenv().KzoyzHeartbeatPabrik = RunService.Heartbeat:Connect(function()
    if getgenv().IsGhosting then
        if getgenv().HoldCFrame then
            local char = LP.Character
            if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = getgenv().HoldCFrame end
        end
        if PlayerMovement then
            pcall(function()
                PlayerMovement.VelocityY = 0; PlayerMovement.VelocityX = 0; PlayerMovement.VelocityZ = 0; PlayerMovement.Grounded = true; PlayerMovement.Jumping = false
            end)
        end
    end
end)

-- Modul Game Internal --
local InventoryMod
pcall(function() InventoryMod = require(RS:WaitForChild("Modules"):WaitForChild("Inventory")) end)
local UIManager
pcall(function() UIManager = require(RS:WaitForChild("Managers"):WaitForChild("UIManager")) end)

local function GetSlotByItemID(targetID)
    if not InventoryMod or not InventoryMod.Stacks then return nil end
    for slotIndex, data in pairs(InventoryMod.Stacks) do
        if type(data) == "table" and data.Id and tostring(data.Id) == tostring(targetID) then
            if not data.Amount or data.Amount > 0 then return slotIndex end
        end
    end
    return nil
end

local function GetItemAmountByID(targetID)
    local total = 0
    if not InventoryMod or not InventoryMod.Stacks then return total end
    for _, data in pairs(InventoryMod.Stacks) do
        if type(data) == "table" and data.Id and tostring(data.Id) == tostring(targetID) then
            total = total + (data.Amount or 1)
        end
    end
    return total
end

local function ScanAvailableItems()
    local items = {}; local dict = {}
    pcall(function()
        if InventoryMod and InventoryMod.Stacks then
            for _, data in pairs(InventoryMod.Stacks) do
                if type(data) == "table" and data.Id then
                    local itemID = tostring(data.Id)
                    if not dict[itemID] then dict[itemID] = true; table.insert(items, itemID) end
                end
            end
        end
    end)
    if #items == 0 then items = {"Kosong"} end
    return items
end

-- SISTEM DETEKSI DROP (ONLY SAPLING HARDCODED NYALA) --
local function CheckDropsAtGrid(TargetGridX, TargetGridY)
    local TargetFolders = { workspace:FindFirstChild("Drops"), workspace:FindFirstChild("Gems") }
    for _, folder in ipairs(TargetFolders) do
        if folder then
            for _, obj in pairs(folder:GetChildren()) do
                local pos = nil
                if obj:IsA("BasePart") then pos = obj.Position
                elseif obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position
                elseif obj:IsA("Model") then
                    local firstPart = obj:FindFirstChildWhichIsA("BasePart")
                    if firstPart then pos = firstPart.Position end
                end
                
                if pos then
                    local dX = math.floor(pos.X / getgenv().GridSize + 0.5)
                    local dY = math.floor(pos.Y / getgenv().GridSize + 0.5)
                    
                    if dX == TargetGridX and dY == TargetGridY then
                        -- Cek apakah drop ini adalah Sapling
                        local isSapling = false
                        for _, attrValue in pairs(obj:GetAttributes()) do
                            if type(attrValue) == "string" and string.find(string.lower(attrValue), "sapling") then isSapling = true; break end
                        end
                        if not isSapling then
                            for _, child in ipairs(obj:GetDescendants()) do
                                if child:IsA("StringValue") and string.find(string.lower(child.Value), "sapling") then isSapling = true; break end
                                for _, attrValue in pairs(child:GetAttributes()) do
                                    if type(attrValue) == "string" and string.find(string.lower(attrValue), "sapling") then isSapling = true; break end
                                end
                                if isSapling then break end
                            end
                        end
                        
                        -- Cuma me-return True kalau dia beneran Sapling
                        if isSapling then return true end
                    end
                end
            end
        end
    end
    return false
end

-- SISTEM DROP 
local function DropItemLogic(targetID, dropAmount)
    local slot = GetSlotByItemID(targetID)
    if not slot then return false end
    local dropRemote = RS:WaitForChild("Remotes"):FindFirstChild("PlayerDrop") or RS:WaitForChild("Remotes"):FindFirstChild("PlayerDropItem")
    local promptRemote = RS:WaitForChild("Managers"):WaitForChild("UIManager"):FindFirstChild("UIPromptEvent")
    
    if dropRemote and promptRemote then
        pcall(function() dropRemote:FireServer(slot) end)
        task.wait(0.2) 
        pcall(function() promptRemote:FireServer({ ButtonAction = "drp", Inputs = { amt = tostring(dropAmount) } }) end)
        task.wait(0.1)
        
        pcall(function()
            for _, gui in pairs(LP.PlayerGui:GetDescendants()) do
                if gui:IsA("Frame") and string.find(string.lower(gui.Name), "prompt") then gui.Visible = false end
            end
        end)
        return true
    end
    return false
end

-- Fix UI Global 
local function ForceRestoreUI()
    pcall(function()
        if UIManager and type(UIManager.ClosePrompt) == "function" then UIManager:ClosePrompt() end
        for _, gui in pairs(LP.PlayerGui:GetDescendants()) do
            if gui:IsA("Frame") and string.find(string.lower(gui.Name), "prompt") then gui.Visible = false end
        end
    end)
    task.wait(0.1)
    pcall(function()
        if UIManager then
            if type(UIManager.ShowHUD) == "function" then UIManager:ShowHUD() end
            if type(UIManager.ShowUI) == "function" then UIManager:ShowUI() end
        end
    end)
    pcall(function()
        local targetUIs = { "topbar", "gems", "playerui", "hotbar", "crosshair", "mainhud", "stats", "inventory", "backpack", "menu", "bottombar", "buttons" }
        for _, gui in pairs(LP.PlayerGui:GetDescendants()) do
            if gui:IsA("Frame") or gui:IsA("ScreenGui") or gui:IsA("ImageLabel") then
                local gName = string.lower(gui.Name)
                for _, tName in ipairs(targetUIs) do
                    if string.find(gName, tName) and not string.find(gName, "prompt") then
                        if gui:IsA("ScreenGui") then gui.Enabled = true else gui.Visible = true end
                    end
                end
            end
        end
    end)
    pcall(function()
        for _, gui in pairs(LP.PlayerGui:GetDescendants()) do
            if gui:IsA("TextButton") and string.find(string.lower(gui.Text), "drop") then
                if gui.Parent then gui.Parent.Visible = true end
            end
        end
    end)
end

local function WalkToGrid(tX, tY, isPabrik)
    local HitboxFolder = workspace:FindFirstChild("Hitbox")
    local MyHitbox = HitboxFolder and HitboxFolder:FindFirstChild(LP.Name)
    if not MyHitbox then return end

    local startZ = MyHitbox.Position.Z
    local currentX = math.floor(MyHitbox.Position.X / getgenv().GridSize + 0.5)
    local currentY = math.floor(MyHitbox.Position.Y / getgenv().GridSize + 0.5)

    while (currentX ~= tX or currentY ~= tY) do
        if isPabrik and not getgenv().EnablePabrik then break end
        if currentX ~= tX then currentX = currentX + (tX > currentX and 1 or -1)
        elseif currentY ~= tY then currentY = currentY + (tY > currentY and 1 or -1) end
        
        local newWorldPos = Vector3.new(currentX * getgenv().GridSize, currentY * getgenv().GridSize, startZ)
        MyHitbox.CFrame = CFrame.new(newWorldPos)
        if PlayerMovement then pcall(function() PlayerMovement.Position = newWorldPos end) end
        task.wait(getgenv().StepDelay)
    end
end

-- [[ UI SETUP ]] --
local Theme = { Item = Color3.fromRGB(45, 45, 45), Text = Color3.fromRGB(255, 255, 255), Purple = Color3.fromRGB(140, 80, 255) }

function CreateToggle(Parent, Text, Var) local Btn = Instance.new("TextButton", Parent); Btn.BackgroundColor3 = Theme.Item; Btn.Size = UDim2.new(1, -10, 0, 35); Btn.Text = ""; local C = Instance.new("UICorner", Btn); C.CornerRadius = UDim.new(0, 6); local T = Instance.new("TextLabel", Btn); T.Text = Text; T.TextColor3 = Theme.Text; T.Font = Enum.Font.GothamSemibold; T.TextSize = 12; T.Size = UDim2.new(1, -40, 1, 0); T.Position = UDim2.new(0, 10, 0, 0); T.BackgroundTransparency = 1; T.TextXAlignment = Enum.TextXAlignment.Left; local IndBg = Instance.new("Frame", Btn); IndBg.Size = UDim2.new(0, 36, 0, 18); IndBg.Position = UDim2.new(1, -45, 0.5, -9); IndBg.BackgroundColor3 = Color3.fromRGB(30,30,30); local IC = Instance.new("UICorner", IndBg); IC.CornerRadius = UDim.new(1,0); local Dot = Instance.new("Frame", IndBg); Dot.Size = UDim2.new(0, 14, 0, 14); Dot.Position = getgenv()[Var] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7); Dot.BackgroundColor3 = getgenv()[Var] and Color3.new(1,1,1) or Color3.fromRGB(100,100,100); local DC = Instance.new("UICorner", Dot); DC.CornerRadius = UDim.new(1,0); IndBg.BackgroundColor3 = getgenv()[Var] and Theme.Purple or Color3.fromRGB(30,30,30); Btn.MouseButton1Click:Connect(function() getgenv()[Var] = not getgenv()[Var]; if getgenv()[Var] then Dot:TweenPosition(UDim2.new(1, -16, 0.5, -7), "Out", "Quad", 0.2, true); Dot.BackgroundColor3 = Color3.new(1,1,1); IndBg.BackgroundColor3 = Theme.Purple else Dot:TweenPosition(UDim2.new(0, 2, 0.5, -7), "Out", "Quad", 0.2, true); Dot.BackgroundColor3 = Color3.fromRGB(100,100,100); IndBg.BackgroundColor3 = Color3.fromRGB(30,30,30) end end) end
function CreateTextBox(Parent, Text, Default, Var) local Frame = Instance.new("Frame", Parent); Frame.BackgroundColor3 = Theme.Item; Frame.Size = UDim2.new(1, -10, 0, 35); local C = Instance.new("UICorner", Frame); C.CornerRadius = UDim.new(0, 6); local Label = Instance.new("TextLabel", Frame); Label.Text = Text; Label.TextColor3 = Theme.Text; Label.BackgroundTransparency = 1; Label.Size = UDim2.new(0.5, 0, 1, 0); Label.Position = UDim2.new(0, 10, 0, 0); Label.Font = Enum.Font.GothamSemibold; Label.TextSize = 12; Label.TextXAlignment = Enum.TextXAlignment.Left; local InputBox = Instance.new("TextBox", Frame); InputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30); InputBox.Position = UDim2.new(0.6, 0, 0.15, 0); InputBox.Size = UDim2.new(0.35, 0, 0.7, 0); InputBox.Font = Enum.Font.GothamSemibold; InputBox.TextSize = 12; InputBox.TextColor3 = Theme.Text; InputBox.Text = tostring(Default); local IC = Instance.new("UICorner", InputBox); IC.CornerRadius = UDim.new(0, 4); InputBox.FocusLost:Connect(function() local val = tonumber(InputBox.Text); if val then getgenv()[Var] = val else InputBox.Text = tostring(getgenv()[Var]) end end); return InputBox end
function CreateButton(Parent, Text, Callback) local Btn = Instance.new("TextButton", Parent); Btn.BackgroundColor3 = Theme.Purple; Btn.Size = UDim2.new(1, -10, 0, 35); Btn.Text = Text; Btn.TextColor3 = Color3.new(1,1,1); Btn.Font = Enum.Font.GothamBold; Btn.TextSize = 12; local C = Instance.new("UICorner", Btn); C.CornerRadius = UDim.new(0, 6); Btn.MouseButton1Click:Connect(Callback) end
function CreateDropdown(Parent, Text, DefaultOptions, Var) local Frame = Instance.new("Frame", Parent); Frame.BackgroundColor3 = Theme.Item; Frame.Size = UDim2.new(1, -10, 0, 35); Frame.ClipsDescendants = true; local C = Instance.new("UICorner", Frame); C.CornerRadius = UDim.new(0, 6); local TopBtn = Instance.new("TextButton", Frame); TopBtn.Size = UDim2.new(1, 0, 0, 35); TopBtn.BackgroundTransparency = 1; TopBtn.Text = ""; local Label = Instance.new("TextLabel", TopBtn); Label.Text = Text .. ": Not Selected"; Label.TextColor3 = Theme.Text; Label.Font = Enum.Font.GothamSemibold; Label.TextSize = 11; Label.Size = UDim2.new(1, -20, 1, 0); Label.Position = UDim2.new(0, 10, 0, 0); Label.BackgroundTransparency = 1; Label.TextXAlignment = Enum.TextXAlignment.Left; local Icon = Instance.new("TextLabel", TopBtn); Icon.Text = "v"; Icon.TextColor3 = Theme.Purple; Icon.Font = Enum.Font.GothamBold; Icon.TextSize = 12; Icon.Size = UDim2.new(0, 20, 1, 0); Icon.Position = UDim2.new(1, -25, 0, 0); Icon.BackgroundTransparency = 1; local Scroll = Instance.new("ScrollingFrame", Frame); Scroll.Position = UDim2.new(0,0,0,35); Scroll.Size = UDim2.new(1,0,1,-35); Scroll.BackgroundTransparency = 1; Scroll.BorderSizePixel = 0; Scroll.ScrollBarThickness = 2; Scroll.ScrollBarImageColor3 = Theme.Purple; local List = Instance.new("UIListLayout", Scroll); local isOpen = false; TopBtn.MouseButton1Click:Connect(function() isOpen = not isOpen; if isOpen then Frame:TweenSize(UDim2.new(1, -10, 0, 110), "Out", "Quad", 0.2, true); Icon.Text = "^" else Frame:TweenSize(UDim2.new(1, -10, 0, 35), "Out", "Quad", 0.2, true); Icon.Text = "v" end end); local function RefreshOptions(Options) for _, child in ipairs(Scroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end; for _, opt in ipairs(Options) do local OptBtn = Instance.new("TextButton", Scroll); OptBtn.Size = UDim2.new(1, 0, 0, 25); OptBtn.BackgroundColor3 = Color3.fromRGB(35,35,35); OptBtn.TextColor3 = Theme.Text; OptBtn.Text = tostring(opt); OptBtn.Font = Enum.Font.Gotham; OptBtn.TextSize = 11; OptBtn.MouseButton1Click:Connect(function() getgenv()[Var] = opt; Label.Text = Text .. ": " .. tostring(opt); isOpen = false; Frame:TweenSize(UDim2.new(1, -10, 0, 35), "Out", "Quad", 0.2, true); Icon.Text = "v" end) end; Scroll.CanvasSize = UDim2.new(0, 0, 0, #Options * 25) end; RefreshOptions(DefaultOptions); return RefreshOptions end

-- [[ INJECT MENU ]] --
local RefreshSeedDropdown = CreateDropdown(TargetPage, "Pilih Seed", ScanAvailableItems(), "SelectedSeed")
local RefreshBlockDropdown = CreateDropdown(TargetPage, "Pilih Block", ScanAvailableItems(), "SelectedBlock")
CreateButton(TargetPage, "🔄 Refresh Tas", function() local newItems = ScanAvailableItems(); RefreshSeedDropdown(newItems); RefreshBlockDropdown(newItems) end)

CreateToggle(TargetPage, "START BALANCED PABRIK", "EnablePabrik")

CreateTextBox(TargetPage, "Hit Count", getgenv().HitCount, "HitCount")
CreateTextBox(TargetPage, "Break Delay (Detik)", getgenv().BreakDelay, "BreakDelay") 
CreateTextBox(TargetPage, "Start X", getgenv().PabrikStartX, "PabrikStartX")
CreateTextBox(TargetPage, "End X", getgenv().PabrikEndX, "PabrikEndX")
CreateTextBox(TargetPage, "Y Pos", getgenv().PabrikYPos, "PabrikYPos")

CreateTextBox(TargetPage, "Waktu Tumbuh (Detik)", getgenv().GrowthTime, "GrowthTime")
CreateTextBox(TargetPage, "Block Threshold", getgenv().BlockThreshold, "BlockThreshold")
CreateTextBox(TargetPage, "Keep Seed Amt", getgenv().KeepSeedAmt, "KeepSeedAmt")

-- SISTEM AUTO-UPDATE POSISI DI UI
local BreakXBox = CreateTextBox(TargetPage, "Break Pos X", getgenv().BreakPosX, "BreakPosX")
local BreakYBox = CreateTextBox(TargetPage, "Break Pos Y", getgenv().BreakPosY, "BreakPosY")
CreateButton(TargetPage, "📍 Set Break Pos (Di Sini)", function() 
    local H = workspace.Hitbox:FindFirstChild(LP.Name) 
    if H then 
        local bx = math.floor(H.Position.X/4.5+0.5)
        local by = math.floor(H.Position.Y/4.5+0.5)
        getgenv().BreakPosX = bx; getgenv().BreakPosY = by
        BreakXBox.Text = tostring(bx); BreakYBox.Text = tostring(by)
    end 
end)

local DropXBox = CreateTextBox(TargetPage, "Drop Pos X", getgenv().DropPosX, "DropPosX")
local DropYBox = CreateTextBox(TargetPage, "Drop Pos Y", getgenv().DropPosY, "DropPosY")
CreateButton(TargetPage, "📍 Set Drop Pos (Di Sini)", function() 
    local H = workspace.Hitbox:FindFirstChild(LP.Name) 
    if H then 
        local dx = math.floor(H.Position.X/4.5+0.5)
        local dy = math.floor(H.Position.Y/4.5+0.5)
        getgenv().DropPosX = dx; getgenv().DropPosY = dy
        DropXBox.Text = tostring(dx); DropYBox.Text = tostring(dy)
    end 
end)

-- [[ LOGIC BALANCED PABRIK ]] --
local RemotePlace = RS:WaitForChild("Remotes"):WaitForChild("PlayerPlaceItem")
local RemoteBreak = RS:WaitForChild("Remotes"):WaitForChild("PlayerFist")

task.spawn(function()
    while true do
        if getgenv().EnablePabrik then
            if getgenv().SelectedSeed == "" or getgenv().SelectedBlock == "" then task.wait(2); continue end

            -- FASE 1: PLANTING
            WalkToGrid(getgenv().PabrikStartX, getgenv().PabrikYPos, true); task.wait(0.5)
            for x = getgenv().PabrikStartX, getgenv().PabrikEndX do
                if not getgenv().EnablePabrik then break end
                local seedSlot = GetSlotByItemID(getgenv().SelectedSeed)
                if not seedSlot then break end
                
                WalkToGrid(x, getgenv().PabrikYPos, true); task.wait(0.1) 
                RemotePlace:FireServer(Vector2.new(x, getgenv().PabrikYPos), seedSlot); task.wait(getgenv().PlaceDelay)
            end

            -- FASE 2: WAITING
            if getgenv().EnablePabrik then 
                for w = 1, getgenv().GrowthTime do if not getgenv().EnablePabrik then break end; task.wait(1) end 
            end

            -- FASE 3: HARVESTING 
            if getgenv().EnablePabrik then
                WalkToGrid(getgenv().PabrikStartX, getgenv().PabrikYPos, true); task.wait(0.5)
                for x = getgenv().PabrikStartX, getgenv().PabrikEndX do
                    if not getgenv().EnablePabrik then break end
                    WalkToGrid(x, getgenv().PabrikYPos, true); task.wait(0.1) 
                    local TGrid = Vector2.new(x, getgenv().PabrikYPos)
                    
                    for hit = 1, getgenv().HitCount do 
                        if not getgenv().EnablePabrik then break end
                        RemoteBreak:FireServer(TGrid) 
                        task.wait(getgenv().BreakDelay)
                    end
                end
                
                -- Sweep pungut manual 
                if getgenv().EnablePabrik then
                    local moveDir = (getgenv().PabrikEndX >= getgenv().PabrikStartX) and 1 or -1
                    local sweepTargetX = getgenv().PabrikEndX + moveDir
                    local sweepReturnX = getgenv().PabrikStartX - moveDir

                    WalkToGrid(sweepTargetX, getgenv().PabrikYPos, true)
                    task.wait(0.3)
                    WalkToGrid(sweepReturnX, getgenv().PabrikYPos, true)
                    task.wait(0.2)
                end
            end

            -- FASE 4: AUTO FARM BLOCK
            if getgenv().EnablePabrik then
                WalkToGrid(getgenv().BreakPosX, getgenv().BreakPosY, true); task.wait(0.5)
                local BreakTarget = Vector2.new(getgenv().BreakPosX - 1, getgenv().BreakPosY)

                while getgenv().EnablePabrik do
                    local currentAmt = GetItemAmountByID(getgenv().SelectedBlock)
                    if currentAmt <= getgenv().BlockThreshold then break end
                    
                    local blockSlot = GetSlotByItemID(getgenv().SelectedBlock)
                    if not blockSlot then break end
                    
                    -- 1. PLACE
                    RemotePlace:FireServer(BreakTarget, blockSlot)
                    task.wait(0.15) 
                    
                    -- 2. BREAK 
                    for hit = 1, getgenv().HitCount do
                        if not getgenv().EnablePabrik then break end
                        RemoteBreak:FireServer(BreakTarget)
                        task.wait(getgenv().BreakDelay)
                    end
                    
                    -- 3. SMART COLLECT (UDAH PERMANEN ONLY SAPLING!)
                    if CheckDropsAtGrid(BreakTarget.X, BreakTarget.Y) then
                        local char = LP.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        local HitboxFolder = workspace:FindFirstChild("Hitbox")
                        local MyHitbox = HitboxFolder and HitboxFolder:FindFirstChild(LP.Name)
                        
                        local ExactHrpCF = hrp and hrp.CFrame
                        local ExactHitboxCF = MyHitbox and MyHitbox.CFrame
                        local ExactPMPos = nil
                        if PlayerMovement then pcall(function() ExactPMPos = PlayerMovement.Position end) end
                        
                        if hrp then getgenv().HoldCFrame = ExactHrpCF; hrp.Anchored = true; getgenv().IsGhosting = true end
                        if hum then
                            local animator = hum:FindFirstChildOfClass("Animator")
                            local tracks = animator and animator:GetPlayingAnimationTracks() or hum:GetPlayingAnimationTracks()
                            for _, track in ipairs(tracks) do track:Stop(0) end
                        end
                        
                        WalkToGrid(BreakTarget.X, BreakTarget.Y, true)
                        local waitTimeout = 0
                        while CheckDropsAtGrid(BreakTarget.X, BreakTarget.Y) and waitTimeout < 15 and getgenv().EnablePabrik do
                            task.wait(0.1); waitTimeout = waitTimeout + 1
                        end
                        
                        task.wait(0.1)
                        WalkToGrid(getgenv().BreakPosX, getgenv().BreakPosY, true)
                        
                        if hrp and ExactHrpCF then 
                            hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
                            if MyHitbox and ExactHitboxCF then MyHitbox.CFrame = ExactHitboxCF; MyHitbox.AssemblyLinearVelocity = Vector3.zero end
                            hrp.CFrame = ExactHrpCF
                            if PlayerMovement and ExactPMPos then pcall(function() PlayerMovement.Position = ExactPMPos; PlayerMovement.OldPosition = ExactPMPos; PlayerMovement.VelocityX = 0; PlayerMovement.VelocityY = 0; PlayerMovement.VelocityZ = 0; PlayerMovement.Grounded = true end) end
                            RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait()
                            hrp.Anchored = false 
                            for _ = 1, 2 do if PlayerMovement and ExactPMPos then pcall(function() PlayerMovement.Position = ExactPMPos; PlayerMovement.OldPosition = ExactPMPos; PlayerMovement.VelocityY = 0; PlayerMovement.Grounded = true end) end; RunService.Heartbeat:Wait() end
                        end
                        getgenv().IsGhosting = false 
                    end
                end
                task.wait(0.5)
            end

            -- FASE 5: AUTO DROP & REFILL
            if getgenv().EnablePabrik then 
                local currentSeedAmt = GetItemAmountByID(getgenv().SelectedSeed)
                
                if currentSeedAmt ~= getgenv().KeepSeedAmt then
                    WalkToGrid(getgenv().DropPosX, getgenv().DropPosY, true)
                    task.wait(1.5) 
                    
                    while getgenv().EnablePabrik do
                        local current = GetItemAmountByID(getgenv().SelectedSeed)
                        local toDrop = current - getgenv().KeepSeedAmt
                        
                        if toDrop <= 0 then break end
                        
                        local dropNow = math.min(toDrop, 200)
                        local success = DropItemLogic(getgenv().SelectedSeed, dropNow)
                        
                        if success then
                            task.wait(getgenv().DropDelay + 0.3) 
                        else
                            break 
                        end
                    end
                    
                    ForceRestoreUI()
                end
            end
        end
        task.wait(1)
    end
end)
