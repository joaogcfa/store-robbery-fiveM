local state = "setup"

local spriteX = 0.48
local spriteY = 0.30
local aspectRatio = 1.0

local lastKeyPress = 0
local debounceTime = 100

local safeDialRotation = 0.0
local currentDialRotationDirection = "idle"
local lastDialRotationDirection = "idle"

local safeCombination = {}
local currentLockNum = 1
local onTarget = false
local initPlayerHealth = 0

local function SetSafeDialRotation(value)
    safeDialRotation = value
    if safeDialRotation < 0 then
        safeDialRotation = safeDialRotation + 360
    elseif safeDialRotation >= 360 then
        safeDialRotation = safeDialRotation - 360
    end
end

local function LoadResources()
    RequestStreamedTextureDict("MPSafeCracking", false)

    local loadAttempt = 0
    while not HasStreamedTextureDictLoaded("MPSafeCracking") or not RequestScriptAudioBank("SAFE_CRACK", false) do
        Wait(10)
        loadAttempt = loadAttempt + 1
        if loadAttempt >= 100 then
            print("failed to load, texture:", HasStreamedTextureDictLoaded("MPSafeCracking"))
            break
        end
    end

    aspectRatio = GetAspectRatio(true)
    print("resources loaded, attempts", loadAttempt, "aspect ratio", aspectRatio)
end

local function SetSafeDialStartNumber()
    local dialStartNumber = math.random(0, 99)
    SetSafeDialRotation(3.6 * dialStartNumber)
    print("dial start number", dialStartNumber)
end

local function GetCurrentSafeDialNumber(currentDialAngle)
    local number = math.floor(100 * (currentDialAngle / 360) + 0.5)
    if number > 0 then
        number = 100 - number
    end
    return math.abs(number)
end

local function SetSafeCombination()
    safeCombination = {}
    for i = 1, 3 do
        safeCombination[i] = math.random(0, 99)
    end
    currentLockNum = 1
    onTarget = false
    print("combination (remove this print later)", safeCombination[1], safeCombination[2], safeCombination[3])
end

local function RelockSafe()
    currentLockNum = 1
    onTarget = false
    print("safe relocked, back to lock 1")
end

local function IsSafeUnlocked()
    return currentLockNum > #safeCombination
end

local function ReleaseCurrentPin()
    currentLockNum = currentLockNum + 1
    onTarget = false

    if IsSafeUnlocked() then
        PlaySoundFrontend(-1, "TUMBLER_PIN_FALL_FINAL", "SAFE_CRACK_SOUNDSET", true)
        print("last pin released, safe unlocked")
    else
        PlaySoundFrontend(-1, "TUMBLER_PIN_FALL", "SAFE_CRACK_SOUNDSET", true)
        print("pin released, now on lock", currentLockNum)
    end
end

local function RotateSafeDial(rotationDirection)
    local multiplier = -1
    if rotationDirection == "anticlockwise" then
        multiplier = 1
    end

    SetSafeDialRotation(safeDialRotation + multiplier * 3.6)
    PlaySoundFrontend(-1, "TUMBLER_TURN", "SAFE_CRACK_SOUNDSET", true)

    currentDialRotationDirection = rotationDirection
    lastDialRotationDirection = rotationDirection
    local number = GetCurrentSafeDialNumber(safeDialRotation)

    if number == safeCombination[currentLockNum] then
        if not onTarget then
            onTarget = true
            PlaySoundFrontend(-1, "TUMBLER_PIN_FALL", "SAFE_CRACK_SOUNDSET", true)
            print("landed on target", number)
        end
    else
        onTarget = false
    end
end

local function HandleSafeDialMovement()
    local now = GetGameTimer()

    if IsDisabledControlJustPressed(0, 38) then
        debounceTime = 100
        lastKeyPress = now
        RotateSafeDial("anticlockwise")
    elseif IsDisabledControlJustPressed(0, 23) then
        debounceTime = 100
        lastKeyPress = now
        RotateSafeDial("clockwise")
    elseif IsDisabledControlPressed(0, 38) then
        if lastKeyPress >= now - debounceTime then return end
        debounceTime = 50
        lastKeyPress = now
        RotateSafeDial("anticlockwise")
    elseif IsDisabledControlPressed(0, 23) then
        if lastKeyPress >= now - debounceTime then return end
        debounceTime = 50
        lastKeyPress = now
        RotateSafeDial("clockwise")
    else
        currentDialRotationDirection = "idle"
    end
end

local function DisableSafeControls()
    DisableControlAction(0, 38, true)
    DisableControlAction(0, 23, true)
    DisableControlAction(0, 74, true)
    DisableControlAction(0, 33, true)
    DisableControlAction(0, 30, true)
    DisableControlAction(0, 31, true)
    DisableControlAction(0, 24, true)
    DisableControlAction(0, 25, true)
end

local function DrawSprites()
    DrawSprite("MPSafeCracking", "Dial_BG", spriteX, spriteY, 0.3, aspectRatio * 0.3, 0.0, 255, 255, 255, 255)
    DrawSprite("MPSafeCracking", "Dial", spriteX, spriteY, 0.3 * 0.5, aspectRatio * 0.3 * 0.5, safeDialRotation,
        255, 255, 255, 255)
end

local function EndMiniGame(safeUnlocked)
    print("end minigame, unlocked:", safeUnlocked)
    if safeUnlocked then
        PlaySoundFrontend(-1, "SAFE_DOOR_OPEN", "SAFE_CRACK_SOUNDSET", true)
    end

    FreezeEntityPosition(PlayerPedId(), false)
    SetStreamedTextureDictAsNoLongerNeeded("MPSafeCracking")
    ReleaseNamedScriptAudioBank("SAFE_CRACK")
    state = "setup"
end

local function RunMiniGame()
    if state == "setup" then
        FreezeEntityPosition(PlayerPedId(), true)
        print("player frozen")
        initPlayerHealth = GetEntityHealth(PlayerPedId())
        state = "cracking"
    elseif state == "cracking" then
        DisableSafeControls()

        local currentHealth = GetEntityHealth(PlayerPedId())
        if currentHealth > initPlayerHealth then
            initPlayerHealth = currentHealth
        end
        if currentHealth < initPlayerHealth or IsEntityDead(PlayerPedId()) or IsPedRagdoll(PlayerPedId()) then
            print("player died")
            EndMiniGame(false)
            return -1
        end

        if IsDisabledControlJustPressed(0, 33) then
            print("S pressed (33), cancel")
            EndMiniGame(false)
            return -2
        end

        HandleSafeDialMovement()

        if IsDisabledControlJustPressed(0, 74) then
            local number = GetCurrentSafeDialNumber(safeDialRotation)
            print("H pressed (74), number", number, "target", safeCombination[currentLockNum])

            if number == safeCombination[currentLockNum] then
                ReleaseCurrentPin()
                if IsSafeUnlocked() then
                    EndMiniGame(true)
                    return 1
                end
            else
                PlaySoundFrontend(-1, "TUMBLER_RESET", "SAFE_CRACK_SOUNDSET", true)
                RelockSafe()
            end
        end

        DrawSprites()
    end
    return 0
end

local isCracking = false
local safeOpened = {}

local function CrackSafe(storeId)
    if isCracking then
        return 0
    end
    isCracking = true
    print("start cracking storeId", storeId)

    LoadResources()
    SetSafeDialStartNumber()
    SetSafeCombination()

    local result = 0
    while result == 0 do
        Wait(0)
        result = RunMiniGame()
    end
    print("minigame result", result)

    if result == 1 then
        safeOpened[storeId] = true
        print("safe opened storeId", storeId)
    end

    isCracking = false
    return result
end

RegisterCommand('crack', function()
    CrackSafe(0)
end, false)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() and isCracking then
        print("resource stopped while cracking, unfreezing")
        FreezeEntityPosition(PlayerPedId(), false)
    end
end)

local function ShowHelp(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

CreateThread(function()
    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())

        for i = 1, #Config.stores do
            local store = Config.stores[i]
            if store.safe and not isCracking then
                local distance = #(playerCoords - vector3(store.safe.x, store.safe.y, store.safe.z))

                if distance < 10.0 then
                    sleep = 0
                end

                if distance < 1.5 then
                    if not cashMachineRobbed[store.id] then
                        ShowHelp("Rob the cash machine first")
                    elseif safeOpened[store.id] then
                        ShowHelp("This safe is already open")
                    else
                        ShowHelp("Press ~INPUT_PICKUP~ to crack the safe")
                        if IsControlJustPressed(0, 38) then
                            print("E pressed at safe", store.id)
                            CrackSafe(store.id)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)
