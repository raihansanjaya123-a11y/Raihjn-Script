--[[
	Pabrik v0.74-SaplingOnly - FIXED VERSION
	Dikembangkan oleh Kzoyz (Replika) - Diperbaiki oleh Assistant
	Fitur: GUI Modern, Auto Plant, Harvest, Block Farm, Auto Drop Seed
]]

-- Cek environment
if not getgenv then
	warn("Script ini membutuhkan executor yang mendukung getgenv!")
	return
end

-- Variabel global (default)
getgenv().ScriptVersion = "Pabrik v0.74-Fixed"
getgenv().PlaceDelay = 0.05
getgenv().DropDelay = 0.5
getgenv().StepDelay = 0.1
getgenv().BreakDelay = 0.15
getgenv().GridSize = 4.5
getgenv().HitCount = 3
getgenv().EnablePabrik = false
getgenv().PabrikStartX = 0
getgenv().PabrikEndX = 10
getgenv().PabrikYPos = 37
getgenv().GrowthTime = 30
getgenv().BreakPosX = 0
getgenv().BreakPosY = 0
getgenv().DropPosX = 0
getgenv().DropPosY = 0
getgenv().BlockThreshold = 20
getgenv().KeepSeedAmt = 20
getgenv().SelectedSeed = ""
getgenv().SelectedBlock = ""
getgenv().IsGhosting = false
getgenv().HoldCFrame = nil

-- Layanan
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Anti-Afk
LP.Idled:Connect(function()
	VirtualUser:CaptureController()
	VirtualUser:ClickButton2(Vector2.new())
end)

-- Load modul game (dengan pcall)
local PlayerMovement, InventoryMod, UIManager
pcall(function() PlayerMovement = require(LP.PlayerScripts:WaitForChild("PlayerMovement")) end)
pcall(function() InventoryMod = require(RS:WaitForChild("Modules"):WaitForChild("Inventory")) end)
pcall(function() UIManager = require(RS:WaitForChild("Managers"):WaitForChild("UIManager")) end)

-- Remote events
local RemotePlace = RS:WaitForChild("Remotes"):WaitForChild("PlayerPlaceItem")
local RemoteBreak = RS:WaitForChild("Remotes"):WaitForChild("PlayerFist")

-- Heartbeat ghosting
if getgenv().KzoyzHeartbeatPabrik then
	getgenv().KzoyzHeartbeatPabrik:Disconnect()
	getgenv().KzoyzHeartbeatPabrik = nil
end
getgenv().KzoyzHeartbeatPabrik = RunService.Heartbeat:Connect(function()
	if getgenv().IsGhosting then
		if getgenv().HoldCFrame then
			local char = LP.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				char.HumanoidRootPart.CFrame = getgenv().HoldCFrame
			end
		end
		if PlayerMovement then
			pcall(function()
				PlayerMovement.VelocityY = 0
				PlayerMovement.VelocityX = 0
				PlayerMovement.VelocityZ = 0
				PlayerMovement.Grounded = true
				PlayerMovement.Jumping = false
			end)
		end
	end
end)

-- ==========================================
-- FUNGSI BANTU (HELPER)
-- ==========================================

-- Mendapatkan slot item berdasarkan ID
local function GetSlotByItemID(targetID)
	if not InventoryMod or not InventoryMod.Stacks then return nil end
	for slotIndex, data in pairs(InventoryMod.Stacks) do
		if type(data) == "table" and data.Id and tostring(data.Id) == tostring(targetID) then
			if not data.Amount or data.Amount > 0 then return slotIndex end
		end
	end
	return nil
end

-- Mendapatkan jumlah item berdasarkan ID
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

-- Memindai item yang tersedia di inventory
local function ScanAvailableItems()
	local items = {}
	local dict = {}
	pcall(function()
		if InventoryMod and InventoryMod.Stacks then
			for _, data in pairs(InventoryMod.Stacks) do
				if type(data) == "table" and data.Id then
					local itemID = tostring(data.Id)
					if not dict[itemID] then
						dict[itemID] = true
						table.insert(items, itemID)
					end
				end
			end
		end
	end)
	if #items == 0 then items = {"Kosong"} end
	return items
end

-- Deteksi apakah ada drop sapling di grid tertentu
local function CheckDropsAtGrid(TargetGridX, TargetGridY)
	local TargetFolders = { workspace:FindFirstChild("Drops"), workspace:FindFirstChild("Gems") }
	for _, folder in ipairs(TargetFolders) do
		if folder then
			for _, obj in pairs(folder:GetChildren()) do
				local pos = nil
				if obj:IsA("BasePart") then
					pos = obj.Position
				elseif obj:IsA("Model") and obj.PrimaryPart then
					pos = obj.PrimaryPart.Position
				elseif obj:IsA("Model") then
					local firstPart = obj:FindFirstChildWhichIsA("BasePart")
					if firstPart then pos = firstPart.Position end
				end
				if pos then
					local dX = math.floor(pos.X / getgenv().GridSize + 0.5)
					local dY = math.floor(pos.Y / getgenv().GridSize + 0.5)
					if dX == TargetGridX and dY == TargetGridY then
						-- Deteksi sapling (dari nama atau atribut)
						local isSapling = false
						-- Cek atribut objek
						for _, attrValue in pairs(obj:GetAttributes()) do
							if type(attrValue) == "string" and string.find(string.lower(attrValue), "sapling") then
								isSapling = true
								break
							end
						end
						-- Cek descendant
						if not isSapling then
							for _, child in ipairs(obj:GetDescendants()) do
								if child:IsA("StringValue") and string.find(string.lower(child.Value), "sapling") then
									isSapling = true
									break
								end
								for _, attrValue in pairs(child:GetAttributes()) do
									if type(attrValue) == "string" and string.find(string.lower(attrValue), "sapling") then
										isSapling = true
										break
									end
								end
								if isSapling then break end
							end
						end
						if isSapling then return true end
					end
				end
			end
		end
	end
	return false
end

-- Logika drop item (menggunakan remote)
local function DropItemLogic(targetID, dropAmount)
	local slot = GetSlotByItemID(targetID)
	if not slot then
		warn("Slot tidak ditemukan untuk", targetID)
		return false
	end
	local dropRemote = RS:WaitForChild("Remotes"):FindFirstChild("PlayerDrop") or RS:WaitForChild("Remotes"):FindFirstChild("PlayerDropItem")
	local promptRemote = RS:WaitForChild("Managers"):WaitForChild("UIManager"):FindFirstChild("UIPromptEvent")
	if dropRemote and promptRemote then
		pcall(function() dropRemote:FireServer(slot) end)
		task.wait(0.2)
		pcall(function() promptRemote:FireServer({ ButtonAction = "drp", Inputs = { amt = tostring(dropAmount) } }) end)
		task.wait(0.1)
		-- Tutup prompt yang mungkin muncul
		pcall(function()
			for _, gui in pairs(LP.PlayerGui:GetDescendants()) do
				if gui:IsA("Frame") and string.find(string.lower(gui.Name), "prompt") then
					gui.Visible = false
				end
			end
		end)
		return true
	else
		warn("Remote drop tidak ditemukan")
		return false
	end
end

-- Memulihkan UI setelah drop
local function ForceRestoreUI()
	pcall(function()
		if UIManager and type(UIManager.ClosePrompt) == "function" then UIManager:ClosePrompt() end
		for _, gui in pairs(LP.PlayerGui:GetDescendants()) do
			if gui:IsA("Frame") and string.find(string.lower(gui.Name), "prompt") then
				gui.Visible = false
			end
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

-- Berjalan menuju grid tertentu
local function WalkToGrid(tX, tY, isPabrik)
	local HitboxFolder = workspace:FindFirstChild("Hitbox")
	local MyHitbox = HitboxFolder and HitboxFolder:FindFirstChild(LP.Name)
	if not MyHitbox then
		warn("Hitbox tidak ditemukan")
		return
	end

	local startZ = MyHitbox.Position.Z
	local currentX = math.floor(MyHitbox.Position.X / getgenv().GridSize + 0.5)
	local currentY = math.floor(MyHitbox.Position.Y / getgenv().GridSize + 0.5)

	while (currentX ~= tX or currentY ~= tY) do
		if isPabrik and not getgenv().EnablePabrik then break end
		if currentX ~= tX then
			currentX = currentX + (tX > currentX and 1 or -1)
		elseif currentY ~= tY then
			currentY = currentY + (tY > currentY and 1 or -1)
		end

		local newWorldPos = Vector3.new(currentX * getgenv().GridSize, currentY * getgenv().GridSize, startZ)
		MyHitbox.CFrame = CFrame.new(newWorldPos)
		if PlayerMovement then
			pcall(function() PlayerMovement.Position = newWorldPos end)
		end
		task.wait(getgenv().StepDelay)
	end
end

-- ==========================================
-- GUI MODERN (LENGKAP)
-- ==========================================
local Tema = {
	BgUtama = Color3.fromRGB(30, 30, 40),
	BgItem = Color3.fromRGB(45, 45, 55),
	Teks = Color3.fromRGB(255, 255, 255),
	Aksen = Color3.fromRGB(140, 80, 255),
	BgInput = Color3.fromRGB(25, 25, 35),
	Shadow = Color3.fromRGB(0, 0, 0)
}

-- Buat ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PabrikGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

-- Frame utama
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 420, 0, 550)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -275)
MainFrame.BackgroundColor3 = Tema.BgUtama
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

-- Shadow
local Shadow = Instance.new("ImageLabel")
Shadow.Name = "Shadow"
Shadow.Size = UDim2.new(1, 20, 1, 20)
Shadow.Position = UDim2.new(0, -10, 0, -10)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6014261993" -- asset shadow
Shadow.ImageColor3 = Color3.new(0, 0, 0)
Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(10, 10, 10, 10)
Shadow.Parent = MainFrame

-- Sudut rounded
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Tema.Aksen
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
-- Biarkan TitleBar tanpa corner sendiri (mengikuti MainFrame)

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -40, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🌾 Pabrik Controller v0.74 (Fixed)"
Title.TextColor3 = Tema.Teks
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0.5, -15)
CloseBtn.BackgroundColor3 = Tema.BgItem
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Tema.Teks
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.AutoButtonColor = false
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn
CloseBtn.Parent = TitleBar
CloseBtn.MouseButton1Click:Connect(function()
	ScreenGui:Destroy()
end)

-- Drag functionality
local dragging = false
local dragInput, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)
TitleBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)
UIS.InputChanged:Connect(function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- Container (ScrollingFrame)
local Container = Instance.new("ScrollingFrame")
Container.Name = "Container"
Container.Size = UDim2.new(1, 0, 1, -40)
Container.Position = UDim2.new(0, 0, 0, 40)
Container.BackgroundColor3 = Tema.BgUtama
Container.BorderSizePixel = 0
Container.ScrollBarThickness = 4
Container.ScrollBarImageColor3 = Tema.Aksen
Container.CanvasSize = UDim2.new(0, 0, 0, 0)
Container.AutomaticCanvasSize = Enum.AutomaticSize.Y
Container.Parent = MainFrame

-- Layout container
local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 8)
ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = Container

local Padding = Instance.new("UIPadding")
Padding.PaddingLeft = UDim.new(0, 10)
Padding.PaddingRight = UDim.new(0, 10)
Padding.PaddingTop = UDim.new(0, 10)
Padding.PaddingBottom = UDim.new(0, 10)
Padding.Parent = Container

-- ==========================================
-- FUNGSI PEMBUAT KOMPONEN UI
-- ==========================================
local function CreateToggle(parent, text, var)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Tema.BgItem
	frame.Size = UDim2.new(1, 0, 0, 40)
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.7, -10, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Tema.Teks
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local toggleBg = Instance.new("Frame")
	toggleBg.Size = UDim2.new(0, 50, 0, 24)
	toggleBg.Position = UDim2.new(1, -60, 0.5, -12)
	toggleBg.BackgroundColor3 = getgenv()[var] and Tema.Aksen or Color3.fromRGB(60, 60, 70)
	toggleBg.BorderSizePixel = 0
	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(1, 0)
	toggleCorner.Parent = toggleBg
	toggleBg.Parent = frame

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 20, 0, 20)
	knob.Position = getgenv()[var] and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob
	knob.Parent = toggleBg

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = frame
	button.MouseButton1Click:Connect(function()
		getgenv()[var] = not getgenv()[var]
		local newPos = getgenv()[var] and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
		TweenService:Create(knob, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = newPos}):Play()
		TweenService:Create(toggleBg, TweenInfo.new(0.1), {BackgroundColor3 = getgenv()[var] and Tema.Aksen or Color3.fromRGB(60, 60, 70)}):Play()
	end)
end

local function CreateTextBox(parent, text, default, var)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Tema.BgItem
	frame.Size = UDim2.new(1, 0, 0, 40)
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.4, -10, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Tema.Teks
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.55, 0, 0, 30)
	box.Position = UDim2.new(0.45, -5, 0.5, -15)
	box.BackgroundColor3 = Tema.BgInput
	box.TextColor3 = Tema.Teks
	box.Font = Enum.Font.Gotham
	box.TextSize = 14
	box.Text = tostring(default)
	box.ClearTextOnFocus = false
	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = box
	box.Parent = frame

	box.FocusLost:Connect(function()
		local val = tonumber(box.Text)
		if val then
			getgenv()[var] = val
		else
			box.Text = tostring(getgenv()[var])
		end
	end)

	return box
end

local function CreateButton(parent, text, callback)
	local btn = Instance.new("TextButton")
	btn.BackgroundColor3 = Tema.Aksen
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.Text = text
	btn.TextColor3 = Tema.Teks
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.AutoButtonColor = false
	btn.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	btn.MouseButton1Click:Connect(callback)
	-- Hover effect
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Tema.Aksen:Lerp(Color3.new(1,1,1), 0.2)}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Tema.Aksen}):Play()
	end)
end

local function CreateDropdown(parent, text, defaultOptions, var)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Tema.BgItem
	frame.Size = UDim2.new(1, 0, 0, 40)
	frame.ClipsDescendants = true
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local top = Instance.new("TextButton")
	top.Size = UDim2.new(1, 0, 0, 40)
	top.BackgroundTransparency = 1
	top.Text = ""
	top.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.7, -10, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text .. ": " .. (getgenv()[var] ~= "" and getgenv()[var] or "Not Selected")
	label.TextColor3 = Tema.Teks
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = top

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 30, 1, 0)
	icon.Position = UDim2.new(1, -30, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "▼"
	icon.TextColor3 = Tema.Aksen
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 16
	icon.Parent = top

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -40)
	scroll.Position = UDim2.new(0, 0, 0, 40)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 2
	scroll.ScrollBarImageColor3 = Tema.Aksen
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = frame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = scroll

	local isOpen = false
	top.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		frame:TweenSize(
			UDim2.new(1, 0, 0, isOpen and 200 or 40),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quad,
			0.2,
			true
		)
		icon.Text = isOpen and "▲" or "▼"
	end)

	local function RefreshOptions(options)
		scroll:ClearAllChildren()
		local newList = Instance.new("UIListLayout")
		newList.Padding = UDim.new(0, 2)
		newList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		newList.Parent = scroll

		for _, opt in ipairs(options) do
			local optBtn = Instance.new("TextButton")
			optBtn.Size = UDim2.new(1, -10, 0, 30)
			optBtn.BackgroundColor3 = Tema.BgInput
			optBtn.Text = tostring(opt)
			optBtn.TextColor3 = Tema.Teks
			optBtn.Font = Enum.Font.Gotham
			optBtn.TextSize = 13
			local optCorner = Instance.new("UICorner")
			optCorner.CornerRadius = UDim.new(0, 6)
			optCorner.Parent = optBtn
			optBtn.Parent = scroll
			optBtn.MouseButton1Click:Connect(function()
				getgenv()[var] = opt
				label.Text = text .. ": " .. tostring(opt)
				isOpen = false
				frame:TweenSize(UDim2.new(1, 0, 0, 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
				icon.Text = "▼"
			end)
		end
	end

	RefreshOptions(defaultOptions)
	return RefreshOptions
end

-- ==========================================
-- MEMBUAT KOMPONEN DI CONTAINER
-- ==========================================
local RefreshSeedDropdown = CreateDropdown(Container, "Pilih Seed", ScanAvailableItems(), "SelectedSeed")
local RefreshBlockDropdown = CreateDropdown(Container, "Pilih Block", ScanAvailableItems(), "SelectedBlock")

CreateButton(Container, "🔄 Refresh Inventory", function()
	local items = ScanAvailableItems()
	RefreshSeedDropdown(items)
	RefreshBlockDropdown(items)
end)

CreateToggle(Container, "START PABRIK (Balanced)", "EnablePabrik")

-- Baris Hit Count & Break Delay
local row1 = Instance.new("Frame")
row1.Size = UDim2.new(1, 0, 0, 40)
row1.BackgroundTransparency = 1
row1.Parent = Container
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.Padding = UDim.new(0, 10)
rowLayout.Parent = row1

local hitBox = CreateTextBox(row1, "Hit Count", getgenv().HitCount, "HitCount")
hitBox.Size = UDim2.new(0.45, 0, 0, 30)
hitBox.Position = UDim2.new(0, 0, 0.5, -15)
local breakDelayBox = CreateTextBox(row1, "Break Delay", getgenv().BreakDelay, "BreakDelay")
breakDelayBox.Size = UDim2.new(0.45, 0, 0, 30)
breakDelayBox.Position = UDim2.new(0, 0, 0.5, -15)

-- Baris Start X, End X, Y Pos
local row2 = Instance.new("Frame")
row2.Size = UDim2.new(1, 0, 0, 40)
row2.BackgroundTransparency = 1
row2.Parent = Container
local rowLayout2 = Instance.new("UIListLayout")
rowLayout2.FillDirection = Enum.FillDirection.Horizontal
rowLayout2.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout2.Padding = UDim.new(0, 5)
rowLayout2.Parent = row2

local startXBox = CreateTextBox(row2, "Start X", getgenv().PabrikStartX, "PabrikStartX")
startXBox.Size = UDim2.new(0.3, 0, 0, 30)
startXBox.Position = UDim2.new(0, 0, 0.5, -15)
local endXBox = CreateTextBox(row2, "End X", getgenv().PabrikEndX, "PabrikEndX")
endXBox.Size = UDim2.new(0.3, 0, 0, 30)
endXBox.Position = UDim2.new(0, 0, 0.5, -15)
local yPosBox = CreateTextBox(row2, "Y Pos", getgenv().PabrikYPos, "PabrikYPos")
yPosBox.Size = UDim2.new(0.3, 0, 0, 30)
yPosBox.Position = UDim2.new(0, 0, 0.5, -15)

CreateTextBox(Container, "Growth Time (s)", getgenv().GrowthTime, "GrowthTime")
CreateTextBox(Container, "Block Threshold", getgenv().BlockThreshold, "BlockThreshold")
CreateTextBox(Container, "Keep Seed Amt", getgenv().KeepSeedAmt, "KeepSeedAmt")

-- Section Break Pos
local breakSection = Instance.new("Frame")
breakSection.Size = UDim2.new(1, 0, 0, 40)
breakSection.BackgroundTransparency = 1
breakSection.Parent = Container
local breakLayout = Instance.new("UIListLayout")
breakLayout.FillDirection = Enum.FillDirection.Horizontal
breakLayout.Padding = UDim.new(0, 5)
breakLayout.Parent = breakSection

local breakXBox = CreateTextBox(breakSection, "Break X", getgenv().BreakPosX, "BreakPosX")
breakXBox.Size = UDim2.new(0.4, 0, 0, 30)
breakXBox.Position = UDim2.new(0, 0, 0.5, -15)
local breakYBox = CreateTextBox(breakSection, "Break Y", getgenv().BreakPosY, "BreakPosY")
breakYBox.Size = UDim2.new(0.4, 0, 0, 30)
breakYBox.Position = UDim2.new(0, 0, 0.5, -15)
CreateButton(breakSection, "📍 Set Break", function()
	local H = workspace:FindFirstChild("Hitbox") and workspace.Hitbox:FindFirstChild(LP.Name)
	if H then
		local bx = math.floor(H.Position.X / 4.5 + 0.5)
		local by = math.floor(H.Position.Y / 4.5 + 0.5)
		getgenv().BreakPosX = bx
		getgenv().BreakPosY = by
		breakXBox.Text = tostring(bx)
		breakYBox.Text = tostring(by)
		print("Break pos set to:", bx, by)
	end
end)

-- Section Drop Pos
local dropSection = Instance.new("Frame")
dropSection.Size = UDim2.new(1, 0, 0, 40)
dropSection.BackgroundTransparency = 1
dropSection.Parent = Container
local dropLayout = Instance.new("UIListLayout")
dropLayout.FillDirection = Enum.FillDirection.Horizontal
dropLayout.Padding = UDim.new(0, 5)
dropLayout.Parent = dropSection

local dropXBox = CreateTextBox(dropSection, "Drop X", getgenv().DropPosX, "DropPosX")
dropXBox.Size = UDim2.new(0.4, 0, 0, 30)
dropXBox.Position = UDim2.new(0, 0, 0.5, -15)
local dropYBox = CreateTextBox(dropSection, "Drop Y", getgenv().DropPosY, "DropPosY")
dropYBox.Size = UDim2.new(0.4, 0, 0, 30)
dropYBox.Position = UDim2.new(0, 0, 0.5, -15)
CreateButton(dropSection, "📍 Set Drop", function()
	local H = workspace:FindFirstChild("Hitbox") and workspace.Hitbox:FindFirstChild(LP.Name)
	if H then
		local dx = math.floor(H.Position.X / 4.5 + 0.5)
		local dy = math.floor(H.Position.Y / 4.5 + 0.5)
		getgenv().DropPosX = dx
		getgenv().DropPosY = dy
		dropXBox.Text = tostring(dx)
		dropYBox.Text = tostring(dy)
		print("Drop pos set to:", dx, dy)
	end
end)

-- Footer
local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, 0, 0, 30)
footer.BackgroundTransparency = 1
footer.Text = getgenv().ScriptVersion .. " | Fixed by Assistant"
footer.TextColor3 = Tema.Teks
footer.Font = Enum.Font.Gotham
footer.TextSize = 12
footer.TextTransparency = 0.5
footer.Parent = Container

-- ==========================================
-- LOGIKA UTAMA PABRIK (BALANCED)
-- ==========================================
task.spawn(function()
	while true do
		if getgenv().EnablePabrik then
			if getgenv().SelectedSeed == "" or getgenv().SelectedBlock == "" then
				warn("Seed atau Block belum dipilih!")
				task.wait(2)
				goto continue
			end

			-- FASE 1: PLANTING
			print("Fase 1: Menanam...")
			WalkToGrid(getgenv().PabrikStartX, getgenv().PabrikYPos, true)
			task.wait(0.5)
			for x = getgenv().PabrikStartX, getgenv().PabrikEndX do
				if not getgenv().EnablePabrik then break end
				local seedSlot = GetSlotByItemID(getgenv().SelectedSeed)
				if not seedSlot then
					warn("Benih habis, stop menanam")
					break
				end
				WalkToGrid(x, getgenv().PabrikYPos, true)
				task.wait(0.1)
				RemotePlace:FireServer(Vector2.new(x, getgenv().PabrikYPos), seedSlot)
				task.wait(getgenv().PlaceDelay)
			end

			-- FASE 2: WAITING
			if getgenv().EnablePabrik then
				print("Fase 2: Menunggu pertumbuhan...")
				for w = 1, getgenv().GrowthTime do
					if not getgenv().EnablePabrik then break end
					task.wait(1)
				end
			end

			-- FASE 3: HARVESTING
			if getgenv().EnablePabrik then
				print("Fase 3: Panen...")
				WalkToGrid(getgenv().PabrikStartX, getgenv().PabrikYPos, true)
				task.wait(0.5)
				for x = getgenv().PabrikStartX, getgenv().PabrikEndX do
					if not getgenv().EnablePabrik then break end
					WalkToGrid(x, getgenv().PabrikYPos, true)
					task.wait(0.1)
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
				print("Fase 4: Auto farm block...")
				WalkToGrid(getgenv().BreakPosX, getgenv().BreakPosY, true)
				task.wait(0.5)
				local BreakTarget = Vector2.new(getgenv().BreakPosX - 1, getgenv().BreakPosY)

				while getgenv().EnablePabrik do
					local currentAmt = GetItemAmountByID(getgenv().SelectedBlock)
					if currentAmt <= getgenv().BlockThreshold then
						print("Jumlah block di bawah threshold, berhenti")
						break
					end
					local blockSlot = GetSlotByItemID(getgenv().SelectedBlock)
					if not blockSlot then
						warn("Block tidak ditemukan di inventory")
						break
					end

					-- Place
					RemotePlace:FireServer(BreakTarget, blockSlot)
					task.wait(0.15)

					-- Break
					for hit = 1, getgenv().HitCount do
						if not getgenv().EnablePabrik then break end
						RemoteBreak:FireServer(BreakTarget)
						task.wait(getgenv().BreakDelay)
					end

					-- Smart collect (sapling only)
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
							task.wait(0.1)
							waitTimeout = waitTimeout + 1
						end

						task.wait(0.1)
						WalkToGrid(getgenv().BreakPosX, getgenv().BreakPosY, true)

						if hrp and ExactHrpCF then
							hrp.AssemblyLinearVelocity = Vector3.zero
							hrp.AssemblyAngularVelocity = Vector3.zero
							if MyHitbox and ExactHitboxCF then
								MyHitbox.CFrame = ExactHitboxCF
								MyHitbox.AssemblyLinearVelocity = Vector3.zero
							end
							hrp.CFrame = ExactHrpCF
							if PlayerMovement and ExactPMPos then
								pcall(function()
									PlayerMovement.Position = ExactPMPos
									PlayerMovement.OldPosition = ExactPMPos
									PlayerMovement.VelocityX = 0
									PlayerMovement.VelocityY = 0
									PlayerMovement.VelocityZ = 0
									PlayerMovement.Grounded = true
								end)
							end
							RunService.Heartbeat:Wait()
							RunService.Heartbeat:Wait()
							hrp.Anchored = false
							for _ = 1, 2 do
								if PlayerMovement and ExactPMPos then
									pcall(function()
										PlayerMovement.Position = ExactPMPos
										PlayerMovement.OldPosition = ExactPMPos
										PlayerMovement.VelocityY = 0
										PlayerMovement.Grounded = true
									end)
								end
								RunService.Heartbeat:Wait()
							end
						end
						getgenv().IsGhosting = false
					end
				end
				task.wait(0.5)
			end

			-- FASE 5: AUTO DROP & REFILL (PERBAIKAN)
			if getgenv().EnablePabrik then
				local currentSeedAmt = GetItemAmountByID(getgenv().SelectedSeed)
				if currentSeedAmt ~= getgenv().KeepSeedAmt then
					print("Fase 5: Auto drop seed. Current:", currentSeedAmt, "Keep:", getgenv().KeepSeedAmt)
					WalkToGrid(getgenv().DropPosX, getgenv().DropPosY, true)
					task.wait(1.5) -- Beri waktu sampai posisi

					while getgenv().EnablePabrik do
						local current = GetItemAmountByID(getgenv().SelectedSeed)
						local toDrop = current - getgenv().KeepSeedAmt
						if toDrop <= 0 then
							print("Jumlah seed sudah sesuai, stop drop")
							break
						end
						local dropNow = math.min(toDrop, 200)
						print("Mencoba drop", dropNow, "seed")
						local success = DropItemLogic(getgenv().SelectedSeed, dropNow)
						if success then
							print("Berhasil drop, menunggu...")
							task.wait(getgenv().DropDelay + 0.5) -- Tambah jeda
						else
							warn("Gagal drop, hentikan loop")
							break
						end
					end

					ForceRestoreUI()
				else
					print("Jumlah seed sudah pas, tidak perlu drop")
				end
			end
		end
		::continue::
		task.wait(1)
	end
end)

print("Script Pabrik Fixed telah dimuat! GUI muncul di tengah.")
