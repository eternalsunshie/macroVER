-- CTD Hotkey Macro System (Guaranteed Input Capture)
local DrawingLib = Drawing or (getgenv and getgenv().Drawing)
if not DrawingLib then return end

local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local MacroData = {}
local SelectedSlot = 1
local IsRecording = false
local IsPlaying = false
local StartTime = 0

-- On-Screen Status HUD (Drawing Library)
local StatusBox = DrawingLib.new("Square")
StatusBox.Visible = true
StatusBox.Size = Vector2.new(240, 90)
StatusBox.Position = Vector2.new(40, 140)
StatusBox.Color = Color3.fromRGB(20, 20, 20)
StatusBox.Filled = true
StatusBox.Transparency = 0.95

local Title = DrawingLib.new("Text")
Title.Visible = true
Title.Text = "CTD Hotkey Macro (Slot 1)"
Title.Position = Vector2.new(50, 150)
Title.Size = 14
Title.Color = Color3.fromRGB(0, 170, 255)

local InfoText1 = DrawingLib.new("Text")
InfoText1.Visible = true
InfoText1.Text = "[F1] Toggle Record | [F2] Play"
InfoText1.Position = Vector2.new(50, 180)
InfoText1.Size = 13
InfoText1.Color = Color3.fromRGB(255, 255, 255)

local StatusText = DrawingLib.new("Text")
StatusText.Visible = true
StatusText.Text = "Status: Ready (Slot 1)"
StatusText.Position = Vector2.new(50, 205)
StatusText.Size = 13
StatusText.Color = Color3.fromRGB(200, 200, 200)

-- File Save / Load Helpers
local function saveMacro()
    if not writefile then return end
    pcall(function()
        writefile("CTD_Slot_" .. SelectedSlot .. ".json", game:GetService("HttpService"):JSONEncode(MacroData))
    end)
end

local function loadMacro()
    if not readfile or not isfile then return end
    local filename = "CTD_Slot_" .. SelectedSlot .. ".json"
    if isfile(filename) then
        local success, result = pcall(function()
            return game:GetService("HttpService"):JSONDecode(readfile(filename))
        end)
        if success and result then
            MacroData = result
            StatusText.Text = "Loaded Slot " .. SelectedSlot .. " (" .. #MacroData .. " actions)"
        end
    else
        StatusText.Text = "Slot " .. SelectedSlot << " is empty"
    end
end

-- Hotkey Controls & Input Logger
UserInputService.InputBegan:Connect(function(input, processed)
    -- Handle Macro Hotkeys
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.F1 then
            -- F1: Toggle Record
            if IsPlaying then return end
            IsRecording = not IsRecording
            if IsRecording then
                MacroData = {}
                StartTime = tick()
                StatusText.Text = "RECORDING to Slot " .. SelectedSlot
                StatusText.Color = Color3.fromRGB(0, 255, 0)
            else
                StatusText.Text = "Recorded " .. #MacroData .. " actions. Saved!"
                StatusText.Color = Color3.fromRGB(255, 255, 255)
                saveMacro()
            end
            return
        elseif input.KeyCode == Enum.KeyCode.F2 then
            -- F2: Playback Macro
            if IsRecording or IsPlaying then return end
            loadMacro()
            if #MacroData == 0 then
                StatusText.Text = "Slot " .. SelectedSlot .. " is empty!"
                return
            end

            IsPlaying = true
            StatusText.Text = "PLAYING Slot " .. SelectedSlot
            StatusText.Color = Color3.fromRGB(80, 255, 80)

            task.spawn(function()
                local playbackStart = tick()
                for _, action in ipairs(MacroData) do
                    if not IsPlaying then break end
                    while (tick() - playbackStart) < action.Time do task.wait() end

                    if action.Type == "Key" then
                        VirtualInputManager:SendKeyEvent(true, action.Code, false, game)
                        task.wait(0.02)
                        VirtualInputManager:SendKeyEvent(false, action.Code, false, game)
                    elseif action.Type == "Click" then
                        VirtualInputManager:SendMouseButtonEvent(action.PosX, action.PosY, 0, true, game, 1)
                        task.wait(0.02)
                        VirtualInputManager:SendMouseButtonEvent(action.PosX, action.PosY, 0, false, game, 1)
                    end
                end
                IsPlaying = false
                StatusText.Text = "Playback Finished"
                StatusText.Color = Color3.fromRGB(200, 200, 200)
            end)
            return
        elseif input.KeyCode == Enum.KeyCode.F3 then
            -- F3: Switch Slots (1 -> 2 -> 3 -> 1)
            if IsRecording or IsPlaying then return end
            SelectedSlot = SelectedSlot + 1
            if SelectedSlot > 3 then SelectedSlot = 1 end
            Title.Text = "CTD Hotkey Macro (Slot " .. SelectedSlot .. ")"
            loadMacro()
            return
        end
    end

    -- Capture Game Actions while Recording
    if not IsRecording then return end
    local timeOffset = tick() - StartTime

    if input.UserInputType == Enum.UserInputType.Keyboard then
        table.insert(MacroData, { Type = "Key", Time = timeOffset, Code = input.KeyCode.Value })
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        table.insert(MacroData, { Type = "Click", Time = timeOffset, PosX = input.Position.X, PosY = input.Position.Y })
    end
end)
