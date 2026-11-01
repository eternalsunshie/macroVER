-- Cameraman TD Hotkey Macro — Fixed & Upgraded HUD
-- Works with executors that expose `Drawing`

local DrawingLib = Drawing or (getgenv and getgenv().Drawing)
if not DrawingLib then
    warn("[CTD Macro] This executor has no Drawing library.")
    return
end

local UserInputService      = game:GetService("UserInputService")
local VirtualInputManager   = game:GetService("VirtualInputManager")
local HttpService           = game:GetService("HttpService")

-- ------------------------------------------------------------------
-- State
-- ------------------------------------------------------------------
local MacroData    = {}
local SelectedSlot = 1
local IsRecording  = false
local IsPlaying    = false
local HudVisible   = true
local RecStart     = 0
local RecCount     = 0

-- KeyCode value -> Enum.KeyCode (for playback)
local KeyCodeLookup = {}
for _, kc in ipairs(Enum.KeyCode:GetEnumItems()) do
    KeyCodeLookup[kc.Value] = kc
end

-- ------------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------------
local function newDraw(class)
    local ok, obj = pcall(function() return DrawingLib.new(class) end)
    if ok and obj then
        obj.Visible = false
        return obj
    end
    return nil
end

local function isfileSafe(f)
    return isfile and isfile(f) or false
end

local function setVisible(obj, v)
    if obj then obj.Visible = v end
end

-- ------------------------------------------------------------------
-- Palette
-- ------------------------------------------------------------------
local C = {
    bg      = Color3.fromRGB(22, 24, 30),
    border  = Color3.fromRGB(55, 60, 75),
    accent  = Color3.fromRGB(0, 170, 255),
    text    = Color3.fromRGB(235, 235, 240),
    subtext = Color3.fromRGB(160, 165, 180),
    red     = Color3.fromRGB(210, 60, 60),
    green   = Color3.fromRGB(60, 200, 90),
    blue    = Color3.fromRGB(60, 110, 220),
    grey    = Color3.fromRGB(120, 125, 140),
    white   = Color3.fromRGB(255, 255, 255),
}

-- ------------------------------------------------------------------
-- Layout constants
-- ------------------------------------------------------------------
local HUD_X, HUD_Y   = 40, 140
local HUD_W, HUD_H   = 270, 150
local BTN_W, BTN_H   = 72, 26
local BTN_Y          = HUD_Y + HUD_H - 40
local BTN_GAP        = 6
local BTN_X0         = HUD_X + 16

-- ------------------------------------------------------------------
-- Widgets
-- ------------------------------------------------------------------
local Widgets = {}

-- Border (slightly larger, darker)
Widgets.Border = newDraw("Square")
if Widgets.Border then
    Widgets.Border.Size        = Vector2.new(HUD_W + 4, HUD_H + 4)
    Widgets.Border.Position    = Vector2.new(HUD_X - 2, HUD_Y - 2)
    Widgets.Border.Color       = C.border
    Widgets.Border.Filled      = true
    Widgets.Border.Transparency= 0.2
    Widgets.Border.Visible     = true
end

-- Background
Widgets.Bg = newDraw("Square")
if Widgets.Bg then
    Widgets.Bg.Size        = Vector2.new(HUD_W, HUD_H)
    Widgets.Bg.Position    = Vector2.new(HUD_X, HUD_Y)
    Widgets.Bg.Color       = C.bg
    Widgets.Bg.Filled      = true
    Widgets.Bg.Transparency= 0.15
    Widgets.Bg.Visible     = true
end

-- Accent bar (top strip)
Widgets.Accent = newDraw("Square")
if Widgets.Accent then
    Widgets.Accent.Size        = Vector2.new(HUD_W, 3)
    Widgets.Accent.Position    = Vector2.new(HUD_X, HUD_Y)
    Widgets.Accent.Color       = C.accent
    Widgets.Accent.Filled      = true
    Widgets.Accent.Transparency= 0
    Widgets.Accent.Visible     = true
end

-- Title
Widgets.Title = newDraw("Text")
if Widgets.Title then
    Widgets.Title.Text      = "CTD MACRO  ·  SLOT 1"
    Widgets.Title.Position  = Vector2.new(HUD_X + 14, HUD_Y + 10)
    Widgets.Title.Size      = 14
    Widgets.Title.Color     = C.accent
    Widgets.Title.Visible   = true
end

-- Status dot
Widgets.Dot = newDraw("Circle")
if Widgets.Dot then
    Widgets.Dot.Radius      = 5
    Widgets.Dot.Thickness   = 1
    Widgets.Dot.NumSides    = 32
    Widgets.Dot.Filled      = true
    Widgets.Dot.Position    = Vector2.new(HUD_X + 16, HUD_Y + 42)
    Widgets.Dot.Color       = C.grey
    Widgets.Dot.Visible     = true
end

-- Status text
Widgets.Status = newDraw("Text")
if Widgets.Status then
    Widgets.Status.Text     = "Ready"
    Widgets.Status.Position = Vector2.new(HUD_X + 30, HUD_Y + 34)
    Widgets.Status.Size     = 13
    Widgets.Status.Color    = C.text
    Widgets.Status.Visible  = true
end

-- Detail text (count / timer)
Widgets.Detail = newDraw("Text")
if Widgets.Detail then
    Widgets.Detail.Text     = "0 actions"
    Widgets.Detail.Position = Vector2.new(HUD_X + 30, HUD_Y + 52)
    Widgets.Detail.Size     = 12
    Widgets.Detail.Color    = C.subtext
    Widgets.Detail.Visible  = true
end

-- HUD buttons: REC / PLAY / SLOT
local function makeButton(label, x, color)
    local btn = {
        x = x, y = BTN_Y, w = BTN_W, h = BTN_H,
        quad = newDraw("Square"),
        txt  = newDraw("Text"),
        label = label,
        color = color,
    }
    if btn.quad then
        btn.quad.Size         = Vector2.new(BTN_W, BTN_H)
        btn.quad.Position     = Vector2.new(x, BTN_Y)
        btn.quad.Color        = color
        btn.quad.Filled       = true
        btn.quad.Transparency = 0.35
        btn.quad.Visible      = true
    end
    if btn.txt then
        btn.txt.Text      = label
        btn.txt.Size      = 13
        btn.txt.Color     = C.white
        btn.txt.Center    = true
        btn.txt.Position  = Vector2.new(x + BTN_W / 2, BTN_Y + 5)
        btn.txt.Visible   = true
    end
    return btn
end

Widgets.BtnRec  = makeButton("REC",  BTN_X0 + (BTN_W + BTN_GAP) * 0, C.red)
Widgets.BtnPlay = makeButton("PLAY", BTN_X0 + (BTN_W + BTN_GAP) * 1, C.green)
Widgets.BtnSlot = makeButton("SLOT", BTN_X0 + (BTN_W + BTN_GAP) * 2, C.blue)

-- Footer hint
Widgets.Footer = newDraw("Text")
if Widgets.Footer then
    Widgets.Footer.Text     = "F1 Rec · F2 Play · F3 Slot · F4 Hide"
    Widgets.Footer.Position = Vector2.new(HUD_X + 14, HUD_Y + HUD_H - 72)
    Widgets.Footer.Size     = 11
    Widgets.Footer.Color    = C.subtext
    Widgets.Footer.Visible  = true
end

-- ------------------------------------------------------------------
-- Update helpers
-- ------------------------------------------------------------------
local function setStatus(text, color)
    if Widgets.Status then Widgets.Status.Text = text end
    if Widgets.Dot and color then Widgets.Dot.Color = color end
end

local function setDetail(text)
    if Widgets.Detail then Widgets.Detail.Text = text end
end

local function setTitle(text)
    if Widgets.Title then Widgets.Title.Text = text end
end

local function showHUD(v)
    HudVisible = v
    for _, w in pairs(Widgets) do
        if typeof(w) == "table" then
            if w.quad then w.quad.Visible = v end
            if w.txt  then w.txt.Visible  = v end
        else
            setVisible(w, v)
        end
    end
end

-- ------------------------------------------------------------------
-- File storage
-- ------------------------------------------------------------------
local function saveMacro()
    if not writefile then return end
    pcall(function()
        writefile("CTD_Slot_" .. SelectedSlot .. ".json",
                   HttpService:JSONEncode(MacroData))
    end)
end

local function loadMacro()
    if not (readfile and isfileSafe) then return end
    local name = "CTD_Slot_" .. SelectedSlot .. ".json"
    if isfile(name) then
        local ok, result = pcall(function() return HttpService:JSONDecode(readfile(name)) end)
        if ok and result then
            MacroData = result
            setDetail(#MacroData .. " actions loaded")
            setStatus("Slot " .. SelectedSlot .. " loaded", C.text)
        end
    else
        MacroData = {}
        setDetail("Slot " .. SelectedSlot .. " is empty")
    end
end

-- ------------------------------------------------------------------
-- Actions
-- ------------------------------------------------------------------
local function toggleRecord()
    if IsPlaying then return end
    IsRecording = not IsRecording
    if IsRecording then
        MacroData = {}
        RecCount  = 0
        RecStart  = os.clock()
        setStatus("RECORDING...", C.red)
        setDetail("0 actions")
        if Widgets.BtnRec then
            Widgets.BtnRec.quad.Color = Color3.fromRGB(255, 90, 90)
            Widgets.BtnRec.quad.Transparency = 0.1
        end
    else
        setStatus("Saved", C.green)
        setDetail(#MacroData .. " actions saved")
        if Widgets.BtnRec then
            Widgets.BtnRec.quad.Color = C.red
            Widgets.BtnRec.quad.Transparency = 0.35
        end
        saveMacro()
    end
end

local function startPlayback()
    if IsRecording or IsPlaying then return end
    loadMacro()
    if #MacroData == 0 then
        setStatus("Slot empty", C.grey)
        setDetail("Record something first")
        return
    end

    IsPlaying = true
    setStatus("PLAYING...", C.green)
    setDetail("Slot " .. SelectedSlot)

    task.spawn(function()
        local t0 = os.clock()
        for _, a in ipairs(MacroData) do
            if not IsPlaying then break end
            local target = t0 + a.Time
            while os.clock() < target do task.wait(0.001) end

            if a.Type == "Key" then
                local kc = KeyCodeLookup[a.Code]
                if kc then
                    VirtualInputManager:SendKeyEvent(true, kc, false, game)
                    task.wait(0.02)
                    VirtualInputManager:SendKeyEvent(false, kc, false, game)
                end
            elseif a.Type == "Click" then
                VirtualInputManager:SendMouseButtonEvent(a.PosX, a.PosY, 0, true, game, 1)
                task.wait(0.02)
                VirtualInputManager:SendMouseButtonEvent(a.PosX, a.PosY, 0, false, game, 1)
            end
        end
        IsPlaying = false
        setStatus("Finished", C.text)
        setDetail(#MacroData .. " actions played")
    end)
end

local function cycleSlot()
    if IsRecording or IsPlaying then return end
    SelectedSlot = SelectedSlot + 1
    if SelectedSlot > 3 then SelectedSlot = 1 end
    setTitle("CTD MACRO  ·  SLOT " .. SelectedSlot)
    setStatus("Ready", C.grey)
    loadMacro()
end

-- ------------------------------------------------------------------
-- Hit-testing for HUD buttons (works for mouse + touch)
-- ------------------------------------------------------------------
local function hitButton(px, py)
    local function inRect(b)
        return px >= b.x and px <= b.x + b.w
           and py >= b.y and py <= b.y + b.h
    end
    if inRect(Widgets.BtnRec)  then return "Rec"  end
    if inRect(Widgets.BtnPlay) then return "Play" end
    if inRect(Widgets.BtnSlot) then return "Slot" end
    return nil
end

-- ------------------------------------------------------------------
-- Live timer for recording
-- ------------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(0.1)
        if IsRecording then
            setDetail(RecCount .. " actions · " ..
                string.format("%.1fs", os.clock() - RecStart))
        end
    end
end)

-- ------------------------------------------------------------------
-- Input handler
-- ------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    -- F4 toggles HUD, always
    if input.UserInputType == Enum.UserInputType.Keyboard
       and input.KeyCode == Enum.KeyCode.F4 then
        showHUD(not HudVisible)
        return
    end

    -- Keyboard hotkeys (ignore if game UI is focused → prevents typing)
    if input.UserInputType == Enum.UserInputType.Keyboard and not processed then
        if input.KeyCode == Enum.KeyCode.F1 then toggleRecord();  return end
        if input.KeyCode == Enum.KeyCode.F2 then startPlayback(); return end
        if input.KeyCode == Enum.KeyCode.F3 then cycleSlot();     return end
    end

    -- HUD button taps (mouse or touch) — these are NOT `processed` by Roblox
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        local px, py = input.Position.X, input.Position.Y
        local hit = hitButton(px, py)
        if hit == "Rec"  then toggleRecord();  return end
        if hit == "Play" then startPlayback(); return end
        if hit == "Slot" then cycleSlot();     return end
    end

    -- Record real inputs (skip ones landing on the HUD)
    if not IsRecording then return end
    local offset = os.clock() - RecStart
    local px, py = input.Position.X, input.Position.Y

    if hitButton(px, py) then return end -- don't record our own buttons

    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.F1
        or input.KeyCode == Enum.KeyCode.F2
        or input.KeyCode == Enum.KeyCode.F3
        or input.KeyCode == Enum.KeyCode.F4 then return end
        table.insert(MacroData, { Type = "Key", Time = offset, Code = input.KeyCode.Value })
        RecCount = RecCount + 1

    elseif input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        table.insert(MacroData, {
            Type = "Click",
            Time = offset,
            PosX = px,
            PosY = py,
        })
        RecCount = RecCount + 1
    end
end)

-- ------------------------------------------------------------------
-- Boot
-- ------------------------------------------------------------------
loadMacro()
setStatus("Ready", C.grey)
setDetail("F1 Rec · F2 Play · F3 Slot")
