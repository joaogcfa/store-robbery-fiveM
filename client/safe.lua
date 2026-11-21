local state = "setup"

local spriteX = 0.48
local spriteY = 0.30
local aspectRatio = 1.0

local lastKeyPress = 0
local debounceTime = 100

local safeDialRotation = 0.0
local currentDialRotationDirection = "idle"
local lastDialRotationDirection = "idle"

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

local function RotateSafeDial(rotationDirection)
    local multiplier = -1
    if rotationDirection == "anticlockwise" then
        multiplier = 1
    end

    SetSafeDialRotation(safeDialRotation + multiplier * 3.6)
    PlaySoundFrontend(-1, "TUMBLER_TURN", "SAFE_CRACK_SOUNDSET", true)

    currentDialRotationDirection = rotationDirection
    lastDialRotationDirection = rotationDirection
    print("rotate", rotationDirection, "number", GetCurrentSafeDialNumber(safeDialRotation))
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
    FreezeEntityPosition(PlayerPedId(), false)
    SetStreamedTextureDictAsNoLongerNeeded("MPSafeCracking")
    ReleaseNamedScriptAudioBank("SAFE_CRACK")
    state = "setup"
end

local function RunMiniGame()
    if state == "setup" then
        FreezeEntityPosition(PlayerPedId(), true)
        print("player frozen")
        state = "cracking"
    elseif state == "cracking" then
        DisableSafeControls()

        if IsDisabledControlJustPressed(0, 33) then
            print("S pressed (33), cancel")
            EndMiniGame(false)
            return -1
        end

        HandleSafeDialMovement()

        if IsDisabledControlJustPressed(0, 74) then
            print("H pressed (74), confirm on number", GetCurrentSafeDialNumber(safeDialRotation))
            PlaySoundFrontend(-1, "TUMBLER_PIN_FALL", "SAFE_CRACK_SOUNDSET", true)
        end

        DrawSprites()
    end
    return 0
end

RegisterCommand('crack', function()
    print("crack command")
    LoadResources()
    SetSafeDialStartNumber()

    local result = 0
    while result == 0 do
        Wait(0)
        result = RunMiniGame()
    end
    print("minigame result", result)
end, false)
