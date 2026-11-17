-- Brainrot Bay: Grab & Dash — client HUD.
-- Cash and income live at the top-right (clear of Roblox's top-left menu),
-- shop buttons at the bottom-right, and banners across the upper middle:
-- rare spawns, the tsunami countdown, and little "+$N" earnings popups.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notify = remotes:WaitForChild("Notify")

local BOLD = FontFace.new("rbxasset://fonts/families/Fredoka.json", Enum.FontWeight.Bold)

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotBayGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(name, size, position, anchor, textSize, color, parent)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = anchor
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.FontFace = BOLD
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.35
	label.Text = ""
	label.Parent = parent or gui
	return label
end

-- Cash + income, top-right.
local cashLabel = makeLabel("CashLabel", UDim2.fromOffset(340, 46), UDim2.new(1, -18, 0, 12),
	Vector2.new(1, 0), 36, Color3.fromRGB(120, 255, 140))
cashLabel.TextXAlignment = Enum.TextXAlignment.Right
cashLabel.Text = "$0"
local incomeLabel = makeLabel("IncomeLabel", UDim2.fromOffset(340, 30), UDim2.new(1, -18, 0, 58),
	Vector2.new(1, 0), 22, Color3.fromRGB(210, 255, 215))
incomeLabel.TextXAlignment = Enum.TextXAlignment.Right
incomeLabel.Text = "+$0/s"

-- What you are carrying, bottom-left.
local carryLabel = makeLabel("CarryLabel", UDim2.fromOffset(460, 32), UDim2.new(0, 16, 1, -58),
	Vector2.new(0, 1), 24, Color3.fromRGB(255, 240, 190))
carryLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Banners, upper middle.
local tsunamiBanner = makeLabel("TsunamiBanner", UDim2.fromOffset(760, 58), UDim2.new(0.5, 0, 0, 64),
	Vector2.new(0.5, 0), 40, Color3.fromRGB(255, 92, 76))
tsunamiBanner.Visible = false
local spawnBanner = makeLabel("SpawnBanner", UDim2.fromOffset(760, 44), UDim2.new(0.5, 0, 0, 128),
	Vector2.new(0.5, 0), 28, Color3.fromRGB(255, 214, 84))
spawnBanner.Visible = false
local toastLabel = makeLabel("ToastLabel", UDim2.fromOffset(700, 40), UDim2.new(0.5, 0, 1, -130),
	Vector2.new(0.5, 1), 26, Color3.fromRGB(255, 255, 255))
toastLabel.Visible = false

-- Shop buttons, bottom-right column.
local buttonFrame = Instance.new("Frame")
buttonFrame.Name = "ShopButtons"
buttonFrame.AnchorPoint = Vector2.new(1, 1)
buttonFrame.Position = UDim2.new(1, -16, 1, -16)
buttonFrame.Size = UDim2.fromOffset(216, 168)
buttonFrame.BackgroundTransparency = 1
buttonFrame.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 10)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.Parent = buttonFrame

local function makeButton(name, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(216, 48)
	button.BackgroundColor3 = color
	button.FontFace = BOLD
	button.TextSize = 21
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextStrokeTransparency = 0.5
	button.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	button.Parent = buttonFrame
	return button
end

local rebirthButton = makeButton("RebirthButton", "Rebirth", Color3.fromRGB(150, 84, 220))
local lockButton = makeButton("LockButton", "Lock Base (60s)", Color3.fromRGB(52, 140, 220))
local bootsButton = makeButton("BootsButton", "Boots", Color3.fromRGB(64, 170, 92))

rebirthButton.Activated:Connect(function()
	remotes.RebirthRequest:FireServer()
end)
lockButton.Activated:Connect(function()
	remotes.LockBaseRequest:FireServer()
end)
bootsButton.Activated:Connect(function()
	remotes.BuyBootsRequest:FireServer()
end)

----------------------------------------------------------------------
-- Live state
----------------------------------------------------------------------

local leaderstats = player:WaitForChild("leaderstats")
local cashValue = leaderstats:WaitForChild("Cash")
local rebirthsValue = leaderstats:WaitForChild("Rebirths")

local function refreshCash()
	cashLabel.Text = "$" .. cashValue.Value
end
local function refreshRebirthButton()
	local cost = 25000 * (rebirthsValue.Value + 1)
	rebirthButton.Text = "Rebirth ($" .. cost .. ")"
end
cashValue.Changed:Connect(refreshCash)
rebirthsValue.Changed:Connect(refreshRebirthButton)
refreshCash()
refreshRebirthButton()

player:GetAttributeChangedSignal("CarryingName"):Connect(function()
	local name = player:GetAttribute("CarryingName")
	if name and name ~= "" then
		carryLabel.Text = "Carrying: " .. name .. " — get it home!"
		carryLabel.TextColor3 = Color3.fromRGB(255, 214, 84)
	else
		carryLabel.Text = ""
		carryLabel.TextColor3 = Color3.fromRGB(255, 240, 190)
	end
end)

----------------------------------------------------------------------
-- Server notifications
----------------------------------------------------------------------

local popupCount = 0
local function showEarningsPopup(amount)
	if popupCount >= 6 then
		return
	end
	popupCount += 1
	local popup = makeLabel("EarningsPopup", UDim2.fromOffset(200, 34), UDim2.new(1, -30, 0, 96),
		Vector2.new(1, 0), 26, Color3.fromRGB(140, 255, 150))
	popup.TextXAlignment = Enum.TextXAlignment.Right
	popup.Text = "+$" .. math.floor(amount)
	local rise = TweenService:Create(popup, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = popup.Position - UDim2.fromOffset(0, 44), TextTransparency = 1 })
	rise:Play()
	rise.Completed:Connect(function()
		popup:Destroy()
		popupCount -= 1
	end)
end

local toastToken = 0
local function showToast(text)
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(3.2, function()
		if toastToken == myToken then
			toastLabel.Visible = false
		end
	end)
end

local spawnToken = 0
local function showSpawnBanner(text)
	spawnToken += 1
	local myToken = spawnToken
	spawnBanner.Text = text
	spawnBanner.Visible = true
	task.delay(3.5, function()
		if spawnToken == myToken then
			spawnBanner.Visible = false
		end
	end)
end

local tsunamiToken = 0
local function runTsunamiCountdown(seconds)
	tsunamiToken += 1
	local myToken = tsunamiToken
	tsunamiBanner.Visible = true
	for left = seconds, 1, -1 do
		if tsunamiToken ~= myToken then
			return
		end
		tsunamiBanner.Text = "TSUNAMI IN " .. left .. " — GET TO A BASE!"
		task.wait(1)
	end
	if tsunamiToken == myToken then
		tsunamiBanner.Text = "TSUNAMI!"
	end
end

notify.OnClientEvent:Connect(function(kind, a, b)
	if kind == "Earnings" then
		incomeLabel.Text = "+$" .. math.floor(b) .. "/s"
		showEarningsPopup(a)
	elseif kind == "RareSpawn" then
		showSpawnBanner(a)
	elseif kind == "TsunamiWarning" then
		task.spawn(runTsunamiCountdown, a or 10)
	elseif kind == "TsunamiOver" then
		tsunamiToken += 1
		tsunamiBanner.Visible = false
	elseif kind == "Message" then
		showToast(a)
	elseif kind == "Boots" then
		if b then
			bootsButton.Text = "Boots Lv" .. (a + 1) .. " ($" .. b .. ")"
		else
			bootsButton.Text = "Boots MAX"
		end
	end
end)
