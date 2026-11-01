-- Cameraman TD Macro — Functional Replay Build
local DrawingLib = Drawing or (getgenv and getgenv().Drawing)
if not DrawingLib then warn("[CTD] No Drawing"); return end

local UIS    = game:GetService("UserInputService")
local VIM    = game:GetService("VirtualInputManager")
local HTTP   = game:GetService("HttpService")
local Players= game:GetService("Players")
local LP     = Players.LocalPlayer

-- ============================================================
-- Robust VIM senders — try LocalPlayer first (Delta/Arceus),
-- fall back to game (Synapse). Report success/failure.
-- ============================================================
local function sendKey(down, kc)
    -- Try LocalPlayer target
    local ok = pcall(function()
        VIM:SendKeyEvent(down, kc, false, LP)
    end)
    if ok then return true end
    -- Try game target
    ok = pcall(function()
        VIM:SendKeyEvent(down, kc, false, game)
    end)
    return ok
end

local function sendClick(down, x, y)
    local ok = pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, down, LP, 1)
    end)
    if ok then return true end
    ok = pcall(function()
        VIM:SendMouseButtonEvent(x, y, 0, down, game, 1)
    end)
    return ok
end

-- ============================================================
-- Reverse KeyCode lookup
-- ============================================================
local KC = {}
for _, v in ipairs(Enum.KeyCode:GetEnumItems()) do KC[v.Value] = v end

-- ============================================================
-- State
-- ============================================================
local data, slot = {}, 1
local rec, play = false, false
local t0, count = 0, 0
local hudOn = true

-- ============================================================
-- Drawing helper
-- ============================================================
local function D(class)
    local ok, o = pcall(function() return DrawingLib.new(class) end)
    if ok and o then o.Visible = false; return o end
    return nil
end

-- ============================================================
-- HUD
-- ============================================================
local X, Y, W, H = 40, 140, 280, 165
local colBg   = Color3.fromRGB(22,24,30)
local colBord = Color3.fromRGB(55,60,75)
local colAcc  = Color3.fromRGB(0,170,255)
local colTxt  = Color3.fromRGB(235,235,240)
local colSub  = Color3.fromRGB(160,165,180)
local colRed  = Color3.fromRGB(210,60,60)
local colGrn  = Color3.fromRGB(60,200,90)
local colBlu  = Color3.fromRGB(60,110,220)
local colGry  = Color3.fromRGB(120,125,140)

local w = {}
w.border = D("Square")
if w.border then
    w.border.Size=Vector2.new(W+4,H+4); w.border.Position=Vector2.new(X-2,Y-2)
    w.border.Color=colBord; w.border.Filled=true; w.border.Transparency=0.2
end
w.bg = D("Square")
if w.bg then
    w.bg.Size=Vector2.new(W,H); w.bg.Position=Vector2.new(X,Y)
    w.bg.Color=colBg; w.bg.Filled=true; w.bg.Transparency=0.15
end
w.accent = D("Square")
if w.accent then
    w.accent.Size=Vector2.new(W,3); w.accent.Position=Vector2.new(X,Y)
    w.accent.Color=colAcc; w.accent.Filled=true
end
w.title = D("Text")
if w.title then
    w.title.Text="CTD MACRO · SLOT 1"
    w.title.Position=Vector2.new(X+14,Y+10)
    w.title.Size=14; w.title.Color=colAcc
end
w.dot = D("Circle")
if w.dot then
    w.dot.Radius=5; w.dot.Thickness=1; w.dot.NumSides=32
    w.dot.Filled=true; w.dot.Position=Vector2.new(X+18,Y+44)
    w.dot.Color=colGry
end
w.status = D("Text")
if w.status then
    w.status.Text="Ready"
    w.status.Position=Vector2.new(X+32,Y+36)
    w.status.Size=13; w.status.Color=colTxt
end
w.detail = D("Text")
if w.detail then
    w.detail.Text="0 actions"
    w.detail.Position=Vector2.new(X+32,Y+54)
    w.detail.Size=12; w.detail.Color=colSub
end
w.hint = D("Text")
if w.hint then
    w.hint.Text="F1 Rec · F2 Play · F3 Slot · F4 Hide"
    w.hint.Position=Vector2.new(X+14,Y+H-84)
    w.hint.Size=11; w.hint.Color=colSub
end

-- Buttons
local btnY = Y + H - 42
local btnW, btnH = 76, 26
local btns = {}

local function makeBtn(name, label, bx, col)
    local b = {name=name, label=label, x=bx, y=btnY, w=btnW, h=btnH, baseColor=col}
    b.quad = D("Square")
    if b.quad then
        b.quad.Size=Vector2.new(btnW,btnH); b.quad.Position=Vector2.new(bx,btnY)
        b.quad.Color=col; b.quad.Filled=true; b.quad.Transparency=0.3
    end
    b.txt = D("Text")
    if b.txt then
        b.txt.Text=label; b.txt.Size=13; b.txt.Color=Color3.fromRGB(255,255,255)
        b.txt.Center=true
        b.txt.Position=Vector2.new(bx+btnW/2, btnY+5)
    end
    btns[name]=b
    return b
end

makeBtn("Rec",  "REC",  X+14,            colRed)
makeBtn("Play", "PLAY", X+14+btnW+8,     colGrn)
makeBtn("Slot", "SLOT", X+14+(btnW+8)*2, colBlu)

-- Show/hide
local function showHUD(v)
    hudOn = v
    for k, o in pairs(w) do if o then o.Visible = v end end
    for _, b in pairs(btns) do
        if b.quad then b.quad.Visible = v end
        if b.txt  then b.txt.Visible  = v end
    end
end
showHUD(true)

local function setStatus(txt, col)
    if w.status then w.status.Text = txt end
    if w.dot and col then w.dot.Color = col end
end
local function setDetail(txt)
    if w.detail then w.detail.Text = txt end
end

-- ============================================================
-- Files
-- ============================================================
local function save()
    if not writefile then return end
    pcall(function()
        writefile("CTD_Slot_"..slot..".json", HTTP:JSONEncode(data))
    end)
end
local function load()
    if not (readfile and isfile) then return end
    local f = "CTD_Slot_"..slot..".json"
    if isfile(f) then
        local ok, r = pcall(function() return HTTP:JSONDecode(readfile(f)) end)
        if ok and r then data = r; setDetail(#data.." loaded") end
    else
        data = {}; setDetail("Slot "..slot.." empty")
    end
end

-- ============================================================
-- Actions
-- ============================================================
local function record()
    if play then return end
    rec = not rec
    if rec then
        data, count, t0 = {}, 0, os.clock()
        setStatus("RECORDING...", colRed)
        setDetail("0 actions")
        if btns.Rec.quad then
            btns.Rec.quad.Color = Color3.fromRGB(255,80,80)
            btns.Rec.quad.Transparency = 0.05
        end
    else
        setStatus("Saved", colGrn)
        setDetail(#data.." saved")
        if btns.Rec.quad then
            btns.Rec.quad.Color = btns.Rec.baseColor
            btns.Rec.quad.Transparency = 0.3
        end
        save()
    end
end

local function playback()
    if rec or play then return end
    load()
    if #data == 0 then
        setStatus("Slot empty", colGry); setDetail("Record first"); return
    end
    play = true
    setStatus("PLAYING...", colGrn)
    setDetail("Slot "..slot.." — "..#data.." actions")

    task.spawn(function()
        local start = os.clock()
        local okKeys, okClicks = 0, 0
        for _, a in ipairs(data) do
            if not play then break end
            local target = start + a.Time
            while os.clock() < target do task.wait(0.001) end

            if a.Type == "Key" then
                local kc = KC[a.Code]
                if kc then
                    if sendKey(true, kc) then okKeys = okKeys + 1 end
                    task.wait()   -- one frame between down & up
                    sendKey(false, kc)
                end
            elseif a.Type == "Click" then
                if sendClick(true, a.PosX, a.PosY) then okClicks = okClicks + 1 end
                task.wait()   -- one frame — critical
                sendClick(false, a.PosX, a.PosY)
            end
        end
        play = false
        setStatus("Done", colTxt)
        setDetail(string.format("%d keys · %d clicks sent", okKeys, okClicks))
    end)
end

local function cycleSlot()
    if rec or play then return end
    slot = slot + 1
    if slot > 3 then slot = 1 end
    if w.title then w.title.Text = "CTD MACRO · SLOT "..slot end
    setStatus("Ready", colGry)
    load()
end

-- ============================================================
-- Hit test
-- ============================================================
local function hit(px, py)
    for name, b in pairs(btns) do
        if px >= b.x and px <= b.x + b.w
           and py >= b.y and py <= b.y + b.h then
            return name
        end
    end
end

-- ============================================================
-- Live recording detail
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.1)
        if rec then
            setDetail(string.format("%d actions · %.1fs", count, os.clock()-t0))
        end
    end
end)

-- ============================================================
-- Input
-- ============================================================
UIS.InputBegan:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.Keyboard
       and input.KeyCode == Enum.KeyCode.F4 then
        showHUD(not hudOn); return
    end

    if input.UserInputType == Enum.UserInputType.Keyboard and not processed then
        if input.KeyCode == Enum.KeyCode.F1 then record() return end
        if input.KeyCode == Enum.KeyCode.F2 then playback() return end
        if input.KeyCode == Enum.KeyCode.F3 then cycleSlot() return end
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        local px, py = input.Position.X, input.Position.Y
        local h = hit(px, py)
        if h == "Rec"  then record() return end
        if h == "Play" then playback() return end
        if h == "Slot" then cycleSlot() return end
    end

    if not rec then return end
    local px, py = input.Position.X, input.Position.Y
    if hit(px, py) then return end
    local off = os.clock() - t0

    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.F1 or input.KeyCode == Enum.KeyCode.F2
        or input.KeyCode == Enum.KeyCode.F3 or input.KeyCode == Enum.KeyCode.F4 then return end
        table.insert(data, {Type="Key", Time=off, Code=input.KeyCode.Value})
        count = count + 1

    elseif input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        table.insert(data, {Type="Click", Time=off, PosX=px, PosY=py})
        count = count + 1
    end
end)

-- ============================================================
-- Boot
-- ============================================================
load()
setStatus("Ready", colGry)
setDetail("Record on F1, play on F2")
