-- Fixed Cameraman TD Hotkey Macro (Captures UI & Mobile Touch Events)
local DrawingLib = Drawing or (getgenv and getgenv().Drawing)
if not DrawingLib then
    warn("[CTD Macro] Drawing library not available in this executor.")
    return
end

local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local MacroData = {}
local SelectedSlot = 1
local IsRecording = false
local IsPlaying = false
local StartTime = 0

-- Build a KeyCode lookup (Value -> Enum.KeyCode) so playback sends real enums
local KeyCodeLookup = {}
for _, kc in ipairs(Enum.KeyCode:GetEnumItems()) do
    KeyCodeLookup[kc.Value] = kc
end

-- Safe drawing factory
local function newDraw(class)
    local ok, obj = pcall(function() return DrawingLib.new(class) end)
    if ok and obj then
        obj.Visible = false
        return obj
    end
    return nil
end

-- On-Screen Status HUD
local StatusBox = newDraw("Square")
if StatusBox then
    StatusBox.Visible = true
    StatusBox.Size = Vector2.new(240, 120)
    StatusBox.Position = Vector2.new(40, 140)
    StatusBox.Color = Color3.fromRGB(20, 20, 20)
    StatusBox.Filled = true
    StatusBox.Transparency = 0.5
end

local Title = newDraw("Text")
if Title then
    Title.Visible = true
    Title.Text = "CTD Hotkey Macro (Slot 1)"
    Title.Position = Vector2.new(50, 150)
    Title.Size = 14
    Title.Color = Color3.fromRGB(0, 170, 255)
end

local InfoText1 = newDraw("Text")
if InfoText1 then
    InfoText1.Visible = true
    InfoText1.Text = "[F1] Rec | [F2] Play | [F3] Slot | Tap HUD buttons"
    InfoText1.Position = Vector2.new(50, 170)
    InfoText1.Size = 13
    InfoText1.Color = Color3.fromRGB(255, 255, 255)
end

local StatusText = newDraw("Text")
if StatusText then
    StatusText.Visible = true
    StatusText.Text = "Status: Ready (Slot 1)"
    StatusText.Position = Vector2.new(50, 190)
    StatusText.Size = 13
    StatusText.Color = Color3.fromRGB(200, 200, 200)
end

-- Mobile / mouse-clickable buttons (drawn as Quads + Text labels)
local buttonDefs = {
    { id = "Record", label = "REC",  x = 50,  y = 215, w = 60, h = 22, color = Color3.fromRGB(180, 40, 40) },
    { id = "Play",   label = "PLAY", x = 120, y = 215, w = 60, h = 22, color = Color3.fromRGB(40, 140, 40) },
    { id = "Slot",   label = "SLOT", x = 190, y = 215, w = 60, h = 22, color = Color3.fromRGB(40, 80, 180) },
}
local Buttons = {}
for _, b in ipairs(buttonDefs) do
    local quad = newDraw("Square")
    if quad then
        quad.Visible = true
        quad.Size = Vector2.new(b.w, b.h)
        quad.Position = Vector2.new(b.x, b.y)
        quad.Color = b.color
        quad.Filled = true
        quad.Transparency = 0.3
    end
    local txt = newDraw("Text")
    if txt then
        txt.Visible = true
        txt.Text = b.label
        txt.Position = Vector2.new(b.x + 8, b.y + 3)
        txt.Size = 13
        txt.Color = Color3.fromRGB(255, 255, 255)
    end
    Buttons[b.id] = { def = b, quad = quad, txt = txt }
end

local function setStatus(text, color)
    if StatusText then
        StatusText.Text = text
        if color then StatusText.Color = color end
    end
end

-- File Storage Helpers
local function saveMacro()
    if not writefile then return end
    pcall(function()
        writefile("CTD_Slot_" .. SelectedSlot .. ".json", HttpService:JSONEncode(MacroData))
    end)
end

local function loadMacro()
    if not (readfile and isfile) then return end
    local filename = "CTD_Slot_" .. SelectedSlot .. ".json"
    if isfile(filename) then
        local ok, result = pcall(function() return HttpService:JSONDecode(readfile(filename)) end)
        if ok and result then
            MacroData = result
            setStatus("Loaded Slot " .. SelectedSlot .. " (" .. #MacroData .. " actions)")
        end
    else
        setStatus("Slot " .. SelectedSlot .. " is empty")
    end
end

-- Core actions (used by both hotkeys and on-screen buttons)
local function toggleRecord()
    if IsPlaying then return end
    IsRecording = not IsRecording
    if IsRecording then
        MacroData = {}
        StartTime = tick()
        setStatus("RECORDING (Slot " .. SelectedSlot .. ")...", Color3.fromRGB(0, 255, 0))
    else
        setStatus("Saved " .. #MacroData .. " actions!", Color3.fromRGB(255, 255, 255))
        saveMacro()
    end
end

local function startPlayback()
    if IsRecording or IsPlaying then return end
    loadMacro()
    if #MacroData == 0 then
        setStatus("Slot " .. SelectedSlot .. " is empty!")
        return
    end
    IsPlaying = true
    setStatus("PLAYING Slot " .. SelectedSlot, Color3.fromRGB(80, 255, 80))

    task.spawn(function()
        local playbackStart = tick()
        for _, action in ipairs(MacroData) do
            if not IsPlaying then break end
            while (tick() - playbackStart) < action.Time do task.wait() end

            if action.Type == "Key" then
                local kc = KeyCodeLookup[action.Code]
                if kc then
                    VirtualInputManager:SendKeyEvent(true, kc, false, game)
                    task.wait(0.02)
                    VirtualInputManager:SendKeyEvent(false, kc, false, game)
                end
            elseif action.Type == "Click" then
                VirtualInputManager:SendMouseButtonEvent(action.PosX, action.PosY, 0, true, game, 1)
                task.wait(0.02)
                VirtualInputManager:SendMouseButtonEvent(action.PosX, action.PosY, 0, false, game, 1)
            end
        end
        IsPlaying = false
        setStatus("Playback Finished", Color3.fromRGB(200, 200, 200))
    end)
end

local function cycleSlot()
    if IsRecording or IsPlaying then return end
    SelectedSlot = SelectedSlot + 1
    if SelectedSlot > 3 then SelectedSlot = 1 end
    if Title then Title.Text = "CTD Hotkey Macro (Slot " .. SelectedSlot .. ")" end
    setStatus("Switched to Slot " .. SelectedSlot)
    loadMacro()
end

-- Hit-test for on-screen buttons
local function buttonAt(px, py)
    for id, btn in pairs(Buttons) do
        local d = btn.def
        if px >= d.x and px <= d.x + d.w and py >= d.y and py <= d.y + d.h then
            return id
        end
    end
    return nil
end

-- Unified Input Handler
UserInputService.InputBegan:Connect(function(input, processed)
    -- 1. Keyboard hotkeys
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.F1 then toggleRecord(); return end
        if input.KeyCode == Enum.KeyCode.F2 then startPlayback(); return end
        if input.KeyCode == Enum.KeyCode.F3 then cycleSlot(); return end
    end

    -- 2. On-screen HUD button taps (works on mobile)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        local hit = buttonAt(input.Position.X, input.Position.Y)
        if hit == "Record" then toggleRecord(); return end
        if hit == "Play"   then startPlayback(); return end
        if hit == "Slot"   then cycleSlot(); return end
    end

    -- 3. Record real inputs (skip ones that hit our own HUD)
    if not IsRecording then return end
    local timeOffset = tick() - StartTime

    if input.UserInputType == Enum.UserInputType.Keyboard then
        table.insert(MacroData, { Type = "Key", Time = timeOffset, Code = input.KeyCode.Value })
    elseif input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        if buttonAt(input.Position.X, input.Position.Y) then return end
        table.insert(MacroData, { Type = "Click", Time = timeOffset,
            PosX = input.Position.X, PosY = input.Position.Y })
    end
end)
