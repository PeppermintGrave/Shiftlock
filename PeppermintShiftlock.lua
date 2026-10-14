-- PeppermintGrave | Forest ShiftLock v3.0
-- Compact, draggable, mobile-friendly ShiftLock
-- Repository: https://github.com/PeppermintGrave/Shiftlock
-- Image: bg_icon.png
-- Intended for client-side execution in a compatible environment

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
if not Player then
    return
end

local PlayerGui = Player:WaitForChild("PlayerGui")

local CONFIG = {
    GUI_NAME = "PeppermintForestShiftLock",
    ICON_URL = "https://raw.githubusercontent.com/PeppermintGrave/Shiftlock/main/bg_icon.png",

    PANEL_SIZE = 66,
    ICON_SIZE = 36,
    CORNER_RADIUS = 18,

    ROTATION_SPEED = 12,
    CAMERA_OFFSET = Vector3.new(1.7, 0, 0),

    START_ENABLED = false,
}

local COLORS = {
    Background = Color3.fromRGB(17, 24, 20),
    Panel = Color3.fromRGB(27, 37, 30),
    Border = Color3.fromRGB(94, 120, 87),

    Gold = Color3.fromRGB(230, 184, 85),
    GoldDark = Color3.fromRGB(132, 96, 42),

    Silver = Color3.fromRGB(207, 218, 220),
    SilverDark = Color3.fromRGB(102, 119, 122),

    White = Color3.fromRGB(245, 248, 241),
}

-- Remove an older copy of the GUI.
local ExistingGui = PlayerGui:FindFirstChild(CONFIG.GUI_NAME)
if ExistingGui then
    ExistingGui:Destroy()
end

local Enabled = false
local Dragging = false
local DragStart = nil
local StartPosition = nil
local DragMoved = false
local ActiveHumanoid = nil
local OriginalAutoRotate = nil
local OriginalCameraOffset = nil
local RenderConnection = nil
local CharacterConnection = nil

local function GetCharacter()
    return Player.Character
end

local function GetHumanoid()
    local Character = GetCharacter()
    return Character and Character:FindFirstChildOfClass("Humanoid")
end

local function RestoreHumanoid()
    if ActiveHumanoid and ActiveHumanoid.Parent then
        if OriginalAutoRotate ~= nil then
            ActiveHumanoid.AutoRotate = OriginalAutoRotate
        end

        if OriginalCameraOffset ~= nil then
            ActiveHumanoid.CameraOffset = OriginalCameraOffset
        end
    end

    ActiveHumanoid = nil
    OriginalAutoRotate = nil
    OriginalCameraOffset = nil
end

local function ApplyToHumanoid(Humanoid)
    if not Humanoid or Humanoid == ActiveHumanoid then
        return
    end

    RestoreHumanoid()

    ActiveHumanoid = Humanoid
    OriginalAutoRotate = Humanoid.AutoRotate
    OriginalCameraOffset = Humanoid.CameraOffset

    if Enabled then
        Humanoid.AutoRotate = false
        Humanoid.CameraOffset = CONFIG.CAMERA_OFFSET
    end
end

-- Main GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = CONFIG.GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Compact square panel
local Panel = Instance.new("Frame")
Panel.Name = "ForestPanel"
Panel.Size = UDim2.fromOffset(CONFIG.PANEL_SIZE, CONFIG.PANEL_SIZE)
Panel.Position = UDim2.new(0.82, 0, 0.68, 0)
Panel.BackgroundColor3 = COLORS.Background
Panel.BackgroundTransparency = 0.08
Panel.BorderSizePixel = 0
Panel.Active = true
Panel.Parent = ScreenGui

local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
PanelCorner.Parent = Panel

local PanelStroke = Instance.new("UIStroke")
PanelStroke.Name = "ForestBorder"
PanelStroke.Thickness = 1.5
PanelStroke.Color = COLORS.Gold
PanelStroke.Transparency = 0.15
PanelStroke.Parent = Panel

-- Background detail
local InnerPanel = Instance.new("Frame")
InnerPanel.Name = "InnerPanel"
InnerPanel.AnchorPoint = Vector2.new(0.5, 0.5)
InnerPanel.Position = UDim2.fromScale(0.5, 0.5)
InnerPanel.Size = UDim2.new(1, -8, 1, -8)
InnerPanel.BackgroundColor3 = COLORS.Panel
InnerPanel.BackgroundTransparency = 0.12
InnerPanel.BorderSizePixel = 0
InnerPanel.ZIndex = 1
InnerPanel.Parent = Panel

local InnerCorner = Instance.new("UICorner")
InnerCorner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS - 4)
InnerCorner.Parent = InnerPanel

-- Toggle button
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ShiftLockToggle"
ToggleButton.Size = UDim2.fromScale(1, 1)
ToggleButton.BackgroundTransparency = 1
ToggleButton.Text = ""
ToggleButton.AutoButtonColor = false
ToggleButton.Active = true
ToggleButton.ZIndex = 5
ToggleButton.Parent = Panel

-- Small square icon
local LeafIcon = Instance.new("ImageLabel")
LeafIcon.Name = "LeafIcon"
LeafIcon.AnchorPoint = Vector2.new(0.5, 0.5)
LeafIcon.Position = UDim2.new(0.5, 0, 0.43, 0)
LeafIcon.Size = UDim2.fromOffset(CONFIG.ICON_SIZE, CONFIG.ICON_SIZE)
LeafIcon.BackgroundTransparency = 1
LeafIcon.BorderSizePixel = 0
LeafIcon.ScaleType = Enum.ScaleType.Fit
LeafIcon.Image = ""
LeafIcon.ZIndex = 6
LeafIcon.Parent = Panel

-- ImageLabel cannot load a raw GitHub URL by itself.
-- This URL is retained for compatible environments that can fetch/render it.
local function LoadRepositoryIcon()
    local Fetch = nil

    pcall(function()
        if type(game.HttpGet) == "function" then
            Fetch = function(url)
                return game:HttpGet(url)
            end
        end
    end)

    if not Fetch then
        return false
    end

    local Success, Result = pcall(Fetch, CONFIG.ICON_URL)
    if not Success or type(Result) ~= "string" then
        return false
    end

    -- Standard Roblox ImageLabel requires a Roblox image asset ID.
    -- Fetching bytes alone does not make those bytes displayable in ImageLabel.
    -- Leave the built-in fallback visible when no compatible image renderer exists.
    return false
end

-- Fallback leaf symbol, visible when the repository image cannot be rendered.
local FallbackIcon = Instance.new("TextLabel")
FallbackIcon.Name = "FallbackLeaf"
FallbackIcon.AnchorPoint = Vector2.new(0.5, 0.5)
FallbackIcon.Position = LeafIcon.Position
FallbackIcon.Size = LeafIcon.Size
FallbackIcon.BackgroundTransparency = 1
FallbackIcon.Text = "❧"
FallbackIcon.TextColor3 = COLORS.Gold
FallbackIcon.TextScaled = true
FallbackIcon.Font = Enum.Font.Garamond
FallbackIcon.ZIndex = 7
FallbackIcon.Parent = Panel

pcall(LoadRepositoryIcon)

-- Small status indicator
local StatusDot = Instance.new("Frame")
StatusDot.Name = "StatusDot"
StatusDot.AnchorPoint = Vector2.new(0.5, 0.5)
StatusDot.Position = UDim2.new(0.5, 0, 0.86, 0)
StatusDot.Size = UDim2.fromOffset(7, 7)
StatusDot.BackgroundColor3 = COLORS.Gold
StatusDot.BorderSizePixel = 0
StatusDot.ZIndex = 8
StatusDot.Parent = Panel

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

local function Tween(object, duration, properties)
    local Success, Result = pcall(function()
        return TweenService:Create(
            object,
            TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            properties
        )
    end)

    if Success and Result then
        Result:Play()
    end
end

local function UpdateAppearance()
    local BorderColor = Enabled and COLORS.Silver or COLORS.Gold
    local IconColor = Enabled and COLORS.Silver or COLORS.Gold

    Tween(PanelStroke, 0.18, {
        Color = BorderColor,
        Transparency = Enabled and 0 or 0.15,
    })

    Tween(StatusDot, 0.18, {
        BackgroundColor3 = Enabled and COLORS.Silver or COLORS.Gold,
    })

    Tween(Panel, 0.18, {
        BackgroundColor3 = Enabled
            and Color3.fromRGB(28, 34, 36)
            or COLORS.Background,
    })

    FallbackIcon.TextColor3 = IconColor
end

local function SetEnabled(State)
    Enabled = State == true

    local Humanoid = GetHumanoid()
    if Humanoid then
        if Enabled then
            ApplyToHumanoid(Humanoid)
            Humanoid.AutoRotate = false
            Humanoid.CameraOffset = CONFIG.CAMERA_OFFSET
        else
            RestoreHumanoid()
        end
    elseif not Enabled then
        RestoreHumanoid()
    end

    UpdateAppearance()
end

-- Drag support for mouse and touch.
local function BeginDrag(Input)
    if Input.UserInputType ~= Enum.UserInputType.MouseButton1
        and Input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    Dragging = true
    DragMoved = false
    DragStart = Input.Position
    StartPosition = Panel.Position
end

local function MoveDrag(Input)
    if not Dragging or not DragStart or not StartPosition then
        return
    end

    local Delta = Input.Position - DragStart

    if math.abs(Delta.X) > 5 or math.abs(Delta.Y) > 5 then
        DragMoved = true
    end

    Panel.Position = UDim2.new(
        StartPosition.X.Scale,
        StartPosition.X.Offset + Delta.X,
        StartPosition.Y.Scale,
        StartPosition.Y.Offset + Delta.Y
    )
end

local function EndDrag()
    Dragging = false
    DragStart = nil
    StartPosition = nil
end

Panel.InputBegan:Connect(BeginDrag)

UserInputService.InputChanged:Connect(function(Input)
    if not Dragging then
        return
    end

    if Input.UserInputType == Enum.UserInputType.MouseMovement
        or Input.UserInputType == Enum.UserInputType.Touch then
        MoveDrag(Input)
    end
end)

UserInputService.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1
        or Input.UserInputType == Enum.UserInputType.Touch then
        EndDrag()
    end
end)

ToggleButton.Activated:Connect(function()
    if DragMoved then
        DragMoved = false
        return
    end

    SetEnabled(not Enabled)
end)

-- Smoothly face the camera direction while ShiftLock is active.
RenderConnection = RunService.RenderStepped:Connect(function(DeltaTime)
    if not Enabled then
        return
    end

    local Character = GetCharacter()
    local Humanoid = GetHumanoid()
    local Root = Character and Character:FindFirstChild("HumanoidRootPart")
    local Camera = workspace.CurrentCamera

    if not Humanoid or not Root or not Camera then
        return
    end

    if Humanoid ~= ActiveHumanoid then
        ApplyToHumanoid(Humanoid)
    end

    Humanoid.AutoRotate = false
    Humanoid.CameraOffset = CONFIG.CAMERA_OFFSET

    local LookVector = Camera.CFrame.LookVector
    local FlatLook = Vector3.new(LookVector.X, 0, LookVector.Z)

    if FlatLook.Magnitude > 0.001 then
        local Target = CFrame.lookAt(
            Root.Position,
            Root.Position + FlatLook.Unit
        )

        local Alpha = 1 - math.exp(-CONFIG.ROTATION_SPEED * DeltaTime)
        Root.CFrame = Root.CFrame:Lerp(Target, Alpha)
    end
end)

CharacterConnection = Player.CharacterAdded:Connect(function(Character)
    RestoreHumanoid()

    local Humanoid = Character:WaitForChild("Humanoid", 10)
    if Humanoid and Enabled then
        ApplyToHumanoid(Humanoid)
        Humanoid.AutoRotate = false
        Humanoid.CameraOffset = CONFIG.CAMERA_OFFSET
    end
end)

-- Initial state
SetEnabled(CONFIG.START_ENABLED)

-- Cleanup if this GUI is removed.
ScreenGui.Destroying:Connect(function()
    if RenderConnection then
        RenderConnection:Disconnect()
        RenderConnection = nil
    end

    if CharacterConnection then
        CharacterConnection:Disconnect()
        CharacterConnection = nil
    end

    RestoreHumanoid()
end)
