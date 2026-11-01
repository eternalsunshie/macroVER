-- Cameraman TD Macro | Draggable & Minimizable UI | Fixed Playback
local DrawingLib = Drawing or (getgenv and getgenv().Drawing)
if not DrawingLib then return warn("No Drawing Lib") end

local UIS     = game:GetService("UserInputService")
local VIM     = game:GetService("VirtualInputManager")
local HTTP    = game:GetService("HttpService")
local Players = game:GetService("Players")
local LP      = Players.LocalPlayer

-- KeyCode Lookup
local KC = {}
for _, v in ipairs(Enum.KeyCode:GetEnumItems()) do KC[v.Value] = v end

-- State
local data, slot = {}, 1
local rec, play = false, false
local t0, count = 0, 0

-- UI State
local hudX, hudY = 40, 140
local isMinimized = false
local isDragging = false
local dragStart = Vector2.new(0,0)
local hudStart = Vector2.new(0,0)

-- Drawing Helper
local function D(class)
    local ok, o = pcall(function() return DrawingLib.new(class) end)
    if ok and o then o.Visible = false; return o end
    return nil
end

-- Palette
local colBg   = Color3.fromRGB(20,22,28)
local colBord = Color3.fromRGB(60,65,80)
local colAcc  = Color3.fromRGB(0,170,255)
local colTxt  = Color3.fromRGB(255,255,255)
local colSub  = Color3.fromRGB(170,175,190)
local colRed  = Color3.fromRGB(220,60,60)
local colGrn  = Color3.fromRGB(60,200,90)
local colBlu  = Color3.fromRGB(60,110,220)

-- Elements registry
local ui = {}
local function make(class, props)
    local obj = D(class)
    if not obj then return nil end
    for k, v in pairs(props) do obj[k] = v end
    obj.Visible = true
    table.insert(ui, obj)
    return obj
end

-- Background
ui.bg = make("Square", {Size=Vector2.new(260, 160), Position=Vector2.new(hudX, hudY), Color=colBg, Filled=true, Transparency=0.05})
ui.border = make("Square", {Size=Vector2.new(260, 160), Position=Vector2.new(hudX, hudY), Color=colBord, Filled=false, Thickness=2, Transparency=0})
ui.accent = make("Square", {Size=Vector2.new(260, 25), Position=Vector2.new(hudX, hudY), Color=colAcc, Filled=true, Transparency=0.1})

-- Header Text & Minimize Button
ui.title = make("Text", {Text="Cameraman TD Macro", Position=Vector2.new(hudX+10, hudY+5), Size=14, Color=colTxt})
ui.minBtn = make("Text", {Text="[-]", Position=Vector2.new(hudX+230, hudY+4), Size=14, Color=colTxt})

-- Body Elements
ui.status = make("Text", {Text="Ready", Position=Vector2.new(hudX+10, hudY+35), Size=14, Color=colTxt})
ui.detail = make("Text", {Text="0 actions", Position=Vector2.new(hudX+10, hudY+55), Size=12, Color=colSub})
ui.slotTxt = make("Text", {Text="Slot: 1", Position=Vector2.new(hudX+10, hudY+75), Size=12, Color=colAcc})

-- Buttons (Rec, Play, Slot)
local btnY = hudY + 110
ui.bgRec = make("Square", {Size=Vector2.new(72, 30), Position=Vector2.new(hudX+10, btnY), Color=colRed, Filled=true, Transparency=0.2})
ui.txtRec = make("Text", {Text="REC", Center=true, Position=Vector2.new(hudX+10+36, btnY+8), Size=14, Color=colTxt})

ui.bgPlay = make("Square", {Size=Vector2.new(72, 30), Position=Vector2.new(hudX+94, btnY), Color=colGrn, Filled=true, Transparency=0.2})
ui.txtPlay = make("Text", {Text="PLAY", Center=true, Position=Vector2.new(hudX+94+36, btnY+8), Size=14, Color=colTxt})

ui.bgSlot = make("Square", {Size=Vector2.new(72, 30), Position=Vector2.new(hudX+178, btnY), Color=colBlu, Filled=true, Transparency=0.2})
ui.txtSlot = make("Text", {Text="SLOT", Center=true, Position=Vector2.new(hudX+178+36, btnY+8), Size=14, Color=colTxt})

-- Apply Positions dynamically based on hudX/hudY
local function updatePositions()
    ui.bg.Position = Vector2.new(hudX, hudY)
    ui.border.Position = Vector2.new(hudX, hudY)
    ui.accent.Position = Vector2.new(hudX, hudY)
    
    if isMinimized then
        ui.bg.Size = Vector2.new(260, 25)
        ui.border.Size = Vector2.new(260, 25)
        ui.accent.Visible = false
        
        ui.status.Visible = false; ui.detail.Visible = false; ui.slotTxt.Visible = false
        ui.bgRec.Visible = false; ui.txtRec.Visible = false
        ui.bgPlay.Visible = false; ui.txtPlay.Visible = false
        ui.bgSlot.Visible = false; ui.txtSlot.Visible = false
        
        ui.minBtn.Text = "[+]"
    else
        ui.bg.Size = Vector2.new(260, 160)
        ui.border.Size = Vector2.new(260, 160)
        ui.accent.Visible = true
        
        ui.status.Visible = true; ui.detail.Visible = true; ui.slotTxt.Visible = true
        ui.bgRec.Visible = true; ui.txtRec.Visible = true
        ui.bgPlay.Visible = true; ui.txtPlay.Visible = true
        ui.bgSlot.Visible = true; ui.txtSlot.Visible = true
        
        ui.minBtn.Text = "[-]"
    end
    
    ui.title.Position = Vector2.new(hudX+10, hudY+5)
    ui.minBtn.Position = Vector2.new(hudX+230, hudY+4)
    ui.status.Position = Vector2.new(hudX+10, hudY+35)
    ui.detail.Position = Vector2.new(hudX+10, hudY+55)
    ui.slotTxt.Position = Vector2.new(hudX+10, hudY+75)
    
    local bY = hudY + 110
    ui.bgRec.Position = Vector2.new(hudX+10, bY);  ui.txtRec.Position = Vector2.new(hudX+10+36, bY+8)
    ui.bgPlay.Position = Vector2.new(hudX+94, bY); ui.txtPlay.Position = Vector2.new(hudX+94+36, bY+8)
    ui.bgSlot.Position = Vector2.new(hudX+178, bY);ui.txtSlot.Position = Vector2.new(hudX+178+36, bY+8)
end

-- Hitbox check
local function inRect(px, py, x, y, w, h)
    return px >= x and px <= x+w and py >= y and py <= y+h
end

-- ==================== MACRO LOGIC ====================

-- Improved Input Sender (uses executor native functions if available)
local function sendKey(down, kc)
    if down then
        if keypress then pcall(keypress, kc) return end
    else
        if keyrelease then pcall(keyrelease, kc) return end
    end
    -- Fallback to VIM
    pcall(function() VIM:SendKeyEvent(down, kc, false, LP) end)
end

local function sendClick(down, x, y)
    if down then
        -- Force mouse to move to the exact X/Y first (Crucial for TD games)
        pcall(function() VIM:SendMouseMoveEvent(x, y, LP) end)
        task.wait(0.01)
        
        if mouse1click then pcall(mouse1click) return end
    else
        if mouse1release then pcall(mouse1release) return end
    end
    -- Fallback to VIM
    pcall(function() VIM:SendMouseButtonEvent(x, y, 0, down, LP, 1) end)
end

local function save()
    if writefile then
        pcall(function() writefile("CTD_Slot_"..slot..".json", HTTP:JSONEncode(data)) end)
    end
end

local function load()
    if readfile and isfile then
        local f = "CTD_Slot_"..slot..".json"
        if isfile(f) then
            local ok, r = pcall(function() return HTTP:JSONDecode(readfile(f)) end)
            if ok and r then data = r end
        else
            data = {}
        end
    end
    ui.detail.Text = #data .. " actions loaded"
end

local function toggleRec()
    if play then return end
    rec = not rec
    if rec then
        data, count, t0 = {}, 0, os.clock()
        ui.status.Text = "RECORDING..."
        ui.status.Color = colRed
        ui.bgRec.Color = Color3.fromRGB(255,100,100)
    else
        ui.status.Text = "Saved"
        ui.status.Color = colGrn
        ui.bgRec.Color = colRed
        save()
    end
end

local function togglePlay()
    if rec or play then return end
    load()
    if #data == 0 then return ui.status.Text = "Slot Empty" end
    
    play = true
    ui.status.Text = "PLAYING..."
    ui.status.Color = colGrn
    
    task.spawn(function()
        local start = os.clock()
        for _, a in ipairs(data) do
            if not play then break end
            local target = start + a.Time
            while os.clock() < target do task.wait(0.001) end
            
            if a.Type == "Key" then
                sendKey(true, KC[a.Code])
                task.wait(0.03)
                sendKey(false, KC[a.Code])
            elseif a.Type == "Click" then
                sendClick(true, a.PosX, a.PosY)
                task.wait(0.05) -- Allow click to register
                sendClick(false, a.PosX, a.PosY)
            end
        end
        play = false
        ui.status.Text = "Finished"
        ui.status.Color = colTxt
    end)
end

local function cycleSlot()
    if rec or play then return end
    slot = slot + 1
    if slot > 3 then slot = 1 end
    ui.slotTxt.Text = "Slot: " .. slot
    load()
end

-- ==================== INPUT HANDLING ====================

UIS.InputBegan:Connect(function(input, processed)
    local px, py = input.Position.X, input.Position.Y
    
    -- 1. UI Interactions (Mouse & Touch)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        
        -- Minimize Button
        if inRect(px, py, hudX+225, hudY+2, 30, 20) then
            isMinimized = not isMinimized
            updatePositions()
            return
        end
        
        -- Dragging (Click Header area)
        if inRect(px, py, hudX, hudY, 260, 25) then
            isDragging = true
            dragStart = Vector2.new(px, py)
            hudStart = Vector2.new(hudX, hudY)
            return
        end
        
        -- Action Buttons (Only if not minimized)
        if not isMinimized then
            local bY = hudY + 110
            if inRect(px, py, hudX+10, bY, 72, 30) then toggleRec() return end
            if inRect(px, py, hudX+94, bY, 72, 30) then togglePlay() return end
            if inRect(px, py, hudX+178, bY, 72, 30) then cycleSlot() return end
        end
        
        -- Recording Clicks
        if rec then
            -- Ignore clicks on the HUD itself
            if inRect(px, py, hudX, hudY, 260, 160) then return end
            table.insert(data, {Type="Click", Time=os.clock()-t0, PosX=px, PosY=py})
            count = count + 1
        end
    end
    
    -- 2. Keyboard Hotkeys
    if input.UserInputType == Enum.UserInputType.Keyboard and not processed then
        if input.KeyCode == Enum.KeyCode.F1 then toggleRec() return end
        if input.KeyCode == Enum.KeyCode.F2 then togglePlay() return end
        if input.KeyCode == Enum.KeyCode.F3 then cycleSlot() return end
    end
    
    -- 3. Recording Keys
    if rec and input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.F1 or input.KeyCode == Enum.KeyCode.F2 or input.KeyCode == Enum.KeyCode.F3 then return end
        table.insert(data, {Type="Key", Time=os.clock()-t0, Code=input.KeyCode.Value})
        count = count + 1
    end
end)

UIS.InputChanged:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local dx = input.Position.X - dragStart.X
        local dy = input.Position.Y - dragStart.Y
        hudX = hudStart.X + dx
        hudY = hudStart.Y + dy
        updatePositions()
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = false
    end
end)

-- Live update timer
task.spawn(function()
    while true do
        task.wait(0.1)
        if rec then
            ui.detail.Text = string.format("%d actions · %.1fs", count, os.clock()-t0)
        end
    end
end)

-- Boot
updatePositions()
load()
