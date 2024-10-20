-- Получаем необходимые сервисы
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = game.Workspace.CurrentCamera

local currentTarget = nil -- Переменная для хранения текущей цели (игрока)
local connection = nil -- Переменная для хранения соединения
local isTracking = false -- Флаг для отслеживания, активировано ли слежение за целью
local isScriptEnabled = true -- Флаг для полного отключения скрипта
local highlightObjects = {} -- Таблица для хранения Highlight объектов

local cameraMode = 1 -- Переменная для отслеживания режима камеры (1 - горизонтальное слежение, 2 - обычное слежение)

-- Функция для создания неоновой подсветки (Highlight)
local function applyNeonOutline(targetPlayer)
    if targetPlayer and targetPlayer.Character then
        local highlight = Instance.new("Highlight")
        highlight.Parent = targetPlayer.Character
        highlight.FillTransparency = 1 -- Только контур
        highlight.OutlineTransparency = 0 -- Контур видимый
        highlight.OutlineColor = Color3.new(1, 0, 0) -- Красный контур
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Всегда на виду
        highlightObjects[targetPlayer] = highlight -- Сохраняем Highlight для удаления позже
    end
end

-- Функция для удаления неоновой подсветки
local function removeNeonOutline(targetPlayer)
    if highlightObjects[targetPlayer] then
        highlightObjects[targetPlayer]:Destroy() -- Удаляем Highlight
        highlightObjects[targetPlayer] = nil -- Очищаем из таблицы
    end
end

-- Функция для определения ближайшего игрока
local function getNearestPlayer()
    local closestPlayer = nil
    local closestDistance = math.huge
    local localCharacter = LocalPlayer.Character
    local localPosition = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart").Position

    if localPosition then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local playerPosition = player.Character.HumanoidRootPart.Position
                local distance = (localPosition - playerPosition).Magnitude
                if distance < closestDistance then
                    closestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end

    return closestPlayer
end

-- Функция для вызова уведомления с ником игрока (username и displayName)
local function notifyNearestPlayer(nearestPlayer)
    if nearestPlayer then
        local message = "Ближайший игрок: " .. nearestPlayer.DisplayName .. " (@" .. nearestPlayer.Name .. ")"
        game.StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = message;
            Color = Color3.new(1, 1, 0);
        })
    end
end

-- Функция для обновления камеры на игрока
local function updateCameraToTarget()
    if currentTarget and currentTarget.Character and currentTarget.Character:FindFirstChild("HumanoidRootPart") then
        local targetPosition = currentTarget.Character.HumanoidRootPart.Position
        local cameraPosition = Camera.CFrame.Position

        if cameraMode == 1 then
            -- Рассчитываем направление на цель (только горизонтально)
            local directionToTarget = (targetPosition - cameraPosition).unit
            local horizontalDirection = Vector3.new(directionToTarget.X, 0, directionToTarget.Z).unit

            -- Получаем текущий вертикальный угол обзора
            local verticalAngle = math.asin(Camera.CFrame.LookVector.Y)
            
            -- Обновляем камеру: горизонтально наводим на цель, вертикальный угол сохраняем
            Camera.CFrame = CFrame.new(cameraPosition, cameraPosition + horizontalDirection) * CFrame.Angles(verticalAngle, 0, 0)

        elseif cameraMode == 2 then
            -- Рассчитываем направление на цель
            local directionToTarget = (targetPosition - cameraPosition).unit

            -- Максимальная скорость поворота, без плавности
            Camera.CFrame = CFrame.new(cameraPosition, cameraPosition + directionToTarget)
        end
    end
end

-- Логика для работы при нажатии клавиши L (активация слежения за ближайшим игроком)
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.L and isScriptEnabled then
        local nearestPlayer = getNearestPlayer()

        if nearestPlayer and nearestPlayer ~= currentTarget and nearestPlayer.Character and nearestPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if currentTarget then
                removeNeonOutline(currentTarget)
            end

            currentTarget = nearestPlayer -- Обновляем текущую цель
            applyNeonOutline(currentTarget) -- Применяем подсветку

            isTracking = true -- Активируем слежение
            notifyNearestPlayer(nearestPlayer)

            if connection then
                connection:Disconnect()
            end

            connection = RunService.RenderStepped:Connect(function()
                if isTracking then
                    updateCameraToTarget()
                end
            end)
        end
    end
    
    -- Сброс цели по клавише R
    if input.KeyCode == Enum.KeyCode.R and isScriptEnabled then
        if currentTarget then
            removeNeonOutline(currentTarget) -- Снимаем подсветку с текущей цели
        end

        currentTarget = nil
        isTracking = false -- Отключаем слежение
        if connection then
            connection:Disconnect() -- Отключаем текущее слежение за игроком
        end
        game.StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = "Цель сброшена.";
            Color = Color3.new(1, 0, 0);
        })
    end
    
    -- Полное отключение/включение скрипта по клавише J
    if input.KeyCode == Enum.KeyCode.J then
        isScriptEnabled = not isScriptEnabled
        if not isScriptEnabled and connection then
            connection:Disconnect() -- Отключаем слежение, если скрипт выключен
        end
        local statusMessage = isScriptEnabled and "Скрипт включен." or "Скрипт отключен."
        game.StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = statusMessage;
            Color = isScriptEnabled and Color3.new(0, 1, 0) or Color3.new(1, 0, 0);
        })
    end

    -- Переключение режимов камеры по нажатию клавиши P
    if input.KeyCode == Enum.KeyCode.P then
        cameraMode = cameraMode == 1 and 2 or 1 -- Переключаем режим (1 <-> 2)
        local modeMessage = cameraMode == 1 and "Режим 1 активирован (горизонтальное слежение)." or "Режим 2 активирован (обычное слежение)."
        game.StarterGui:SetCore("ChatMakeSystemMessage", {
            Text = modeMessage;
            Color = Color3.new(0, 0, 1);
        })
    end
end)

-- Свободное управление камерой вверх/вниз с помощью мыши, даже при слежении за целью
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and isScriptEnabled then
        local xDelta = math.rad(-input.Delta.X * 3) -- Максимальная скорость поворота
        local yDelta = math.rad(-input.Delta.Y * 3)

        if not currentTarget or not isTracking then
            local newCameraCFrame = Camera.CFrame * CFrame.Angles(yDelta, xDelta, 0)
            Camera.CFrame = newCameraCFrame
        else
            local newCameraCFrame = Camera.CFrame * CFrame.Angles(yDelta, 0, 0)
            Camera.CFrame = newCameraCFrame
        end
    end
end)
