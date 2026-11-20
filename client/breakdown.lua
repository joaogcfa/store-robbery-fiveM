-- Flow 
--   idle      -> nothing happening
--   armed     -> robbery finished, waiting for the player to get into a car as the driver
--   driving   -> getaway car picked and it WILL break; counting metres driven
--   breaking  -> sputter sequence playing (a few seconds)
--   limp      -> smoking, speed capped, stalls every 20-30 s 

local BD = Config.breakdown   


math.randomseed(GetGameTimer())

local MPH_TO_MS = 0.44704     

local state = 'idle'
local getaway = nil       
local traveled = 0.0     
local breakAt = 0.0       
local lastPos = nil       

local stalled = false     
local stallTimer = 0.0    
local restartHeld = 0.0   
local smokeFx = nil       


local function debugPrint(msg)
    if BD.debug then
        print('[breakdown] ' .. msg)
    end
end

-- Small notification above the minimap
local function notify(text)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, true)
end


local function showHelp(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function randomFloat(min, max)
    return min + math.random() * (max - min)
end


local function isDriverOf(veh)
    local ped = PlayerPedId()
    return IsPedInVehicle(ped, veh, false) and GetPedInVehicleSeat(veh, -1) == ped
end


local function isLandVehicle(veh)
    local model = GetEntityModel(veh)
    return not (IsThisModelAHeli(model) or IsThisModelAPlane(model)
        or IsThisModelABoat(model) or IsThisModelABicycle(model))
end


local function startSmoke(veh)
    if smokeFx then return end

    RequestNamedPtfxAsset(BD.smokeAsset)
    local timeout = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(BD.smokeAsset) do
        if GetGameTimer() > timeout then
            debugPrint('Smoke effect asset failed to load: ' .. BD.smokeAsset)
            return
        end
        Wait(0)
    end

    UseParticleFxAssetNextCall(BD.smokeAsset)
    local bone = GetEntityBoneIndexByName(veh, 'engine')
    if bone ~= -1 then
        smokeFx = StartParticleFxLoopedOnEntityBone(BD.smokeEffect, veh,
            0.0, 0.0, 0.2, 0.0, 0.0, 0.0, bone, BD.smokeScale, false, false, false)
    else
        -- No engine bone on this model: put it at the front of the car instead
        smokeFx = StartParticleFxLoopedOnEntity(BD.smokeEffect, veh,
            0.0, 2.0, 0.4, 0.0, 0.0, 0.0, BD.smokeScale, false, false, false)
    end

    if not smokeFx or smokeFx == 0 then
        debugPrint('Smoke effect did not start: ' .. BD.smokeEffect)
        smokeFx = nil
    end
end

local function stopSmoke()
    if smokeFx then
        StopParticleFxLooped(smokeFx, false)
        smokeFx = nil
    end
end

local function resetBreakdown(reason)
    debugPrint('Reset: ' .. reason)
    stopSmoke()
    state = 'idle'
    getaway = nil
    stalled = false
end


local function checkForGetawayCar()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)   -- 0 if on foot

    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped or not isLandVehicle(veh) then
        return
    end

    getaway = veh

    -- Roll the dice once for this robbery
    local roll = math.random(1, 100)
    if roll > BD.chance then
        debugPrint(('Rolled %d (needed %d or less): clean getaway'):format(roll, BD.chance))
        resetBreakdown('roll failed, car is fine')
        return
    end

    breakAt = randomFloat(BD.breakDistanceMin, BD.breakDistanceMax)
    traveled = 0.0
    lastPos = GetEntityCoords(veh)
    state = 'driving'
    debugPrint(('Rolled %d: this car WILL break after %.0f m'):format(roll, breakAt))
end


local startBreakdown   -- defined below, declared here so trackDistance can call it

local function trackDistance()
    local pos = GetEntityCoords(getaway)

    -- Only count distance the player actually drives
    if isDriverOf(getaway) then
        traveled = traveled + #(pos - lastPos)
    end
    lastPos = pos

    if traveled >= breakAt then
        startBreakdown()
    end
end


local function enterLimpMode(veh)
    SetVehicleEngineHealth(veh, BD.limpEngineHealth)        -- lower = thicker smoke (below 0 = fire)
    SetEntityMaxSpeed(veh, BD.limpSpeedMph * MPH_TO_MS)     -- cap top speed
    CreateThread(function() startSmoke(veh) end)            -- loading the effect can take a few frames

    stalled = false
    restartHeld = 0.0
    stallTimer = randomFloat(BD.stallIntervalMin, BD.stallIntervalMax)
    state = 'limp'

    notify('~r~Engine failing!~s~ The car is barely holding together.')
    debugPrint(('Limp mode: %.0f mph cap, first stall in %.0f s'):format(BD.limpSpeedMph, stallTimer))
end

startBreakdown = function()
    state = 'breaking'
    local veh = getaway
    debugPrint(('Breaking down after %.0f m'):format(traveled))
    notify('~o~The engine is making a horrible noise...')

    -- Stop GTA's own damage system from changing engine health while we control it
    SetVehicleEngineCanDegrade(veh, false)

    CreateThread(function()
        local startHealth = 700.0
        local step = (startHealth - BD.limpEngineHealth) / BD.sputterCount

        for i = 1, BD.sputterCount do
            if not DoesEntityExist(veh) then return end

            -- Cut the engine for a moment: the car jerks and loses power
            SetVehicleEngineOn(veh, false, true, true)
            Wait(250)
            SetVehicleEngineOn(veh, true, true, false)

            -- Each sputter damages the engine a bit more, so the smoke builds up
            SetVehicleEngineHealth(veh, startHealth - step * i)
            Wait(math.random(400, 900))
        end

        if DoesEntityExist(veh) and state == 'breaking' then
            enterLimpMode(veh)
        end
    end)
end

local function updateLimp()
    local veh = getaway

    -- Keep the engine smoking: never healthier than limp level, never low enough to catch fire
    local hp = GetVehicleEngineHealth(veh)
    if hp > BD.limpEngineHealth then
        SetVehicleEngineHealth(veh, BD.limpEngineHealth)
    elseif hp < 50.0 then
        SetVehicleEngineHealth(veh, 50.0)
    end


    SetEntityMaxSpeed(veh, BD.limpSpeedMph * MPH_TO_MS)
    SetVehicleCheatPowerIncrease(veh, BD.limpPowerMultiplier)

    -- The stall timer only runs while the player is driving
    if not isDriverOf(veh) then return end

    local dt = GetFrameTime()   -- seconds since last frame

    if stalled then
        -- Make sure GTA doesn't restart the engine by itself
        if GetIsVehicleEngineRunning(veh) then
            SetVehicleEngineOn(veh, false, true, true)
        end

        showHelp(('Engine stalled! Hold ~%s~ to restart'):format(BD.restartControlName))

        -- Stop the key doing its normal job (X = duck) while we use it for restarting
        DisableControlAction(0, BD.restartControl, true)

        if IsDisabledControlPressed(0, BD.restartControl) then
            restartHeld = restartHeld + dt
        else
            restartHeld = 0.0
        end

        if restartHeld >= BD.restartHoldTime then
            SetVehicleEngineOn(veh, true, false, false)   -- false = play the normal start-up
            stalled = false
            restartHeld = 0.0
            stallTimer = randomFloat(BD.stallIntervalMin, BD.stallIntervalMax)
            debugPrint(('Restarted. Next stall in %.0f s'):format(stallTimer))
        end
    else
        stallTimer = stallTimer - dt
        if stallTimer <= 0 then
            stalled = true
            restartHeld = 0.0
            SetVehicleEngineOn(veh, false, true, true)
            debugPrint('Stalled')
        end
    end
end



CreateThread(function()
    while true do
        local sleep = 500

        -- Safety: stop if the car is gone/destroyed or the player died
        if state ~= 'idle' and state ~= 'armed' then
            if not getaway or not DoesEntityExist(getaway) or IsEntityDead(getaway) then
                resetBreakdown('getaway car gone or destroyed')
            elseif IsEntityDead(PlayerPedId()) then
                resetBreakdown('player died')
            end
        end

        if state == 'armed' then
            sleep = 250
            checkForGetawayCar()
        elseif state == 'driving' then
            sleep = 250
            trackDistance()
        elseif state == 'limp' then
            sleep = 0              -- every frame: help text and the hold-W check need it
            updateLimp()
        end

        Wait(sleep)
    end
end)



AddEventHandler('store-robbery:client:robberyFinished', function()
    if state ~= 'idle' then
        debugPrint('Robbery finished, but a breakdown is already in progress: ignoring')
        return
    end

    state = 'armed'
    debugPrint('Robbery finished: armed, waiting for a getaway car')
    notify('~r~Robbery complete!~s~ Get to a car and get out of here.')
end)



-- bd_test: pretend a robbery just finished
RegisterCommand('bd_test', function()
    if not BD.debug then return end
    TriggerEvent('store-robbery:client:robberyFinished')
end, false)

-- bd_break: break the car you're driving right now (skips the roll and the distance)
RegisterCommand('bd_break', function()
    if not BD.debug then return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then
        print('[breakdown] Get in a car as the driver first')
        return
    end
    getaway = veh
    traveled = 0.0
    startBreakdown()
end, false)

-- bd_reset: cancel everything and fully repair the current getaway car
RegisterCommand('bd_reset', function()
    if not BD.debug then return end
    if getaway and DoesEntityExist(getaway) then
        SetVehicleEngineCanDegrade(getaway, true)
        SetVehicleEngineHealth(getaway, 1000.0)
        SetEntityMaxSpeed(getaway, 999.0)   -- effectively removes the cap
        RemoveParticleFxFromEntity(getaway)
        SetVehicleEngineOn(getaway, true, true, false)
    end
    resetBreakdown('bd_reset command')
end, false)

-- bd_state: print what the system is doing
RegisterCommand('bd_state', function()
    if not BD.debug then return end
    local info = ('state=%s'):format(state)
    if state == 'driving' then
        info = info .. (' | driven %.0f / %.0f m'):format(traveled, breakAt)
    elseif state == 'limp' then
        info = info .. (' | stalled=%s | next stall in %.0f s'):format(tostring(stalled), stallTimer)
    end
    if getaway and DoesEntityExist(getaway) then
        info = info .. (' | speed %.0f mph | engine %.0f')
            :format(GetEntitySpeed(getaway) / MPH_TO_MS, GetVehicleEngineHealth(getaway))
    end
    print('[breakdown] ' .. info)
end, false)

-- bd_car: spawn a car and put you in the driver's seat
RegisterCommand('bd_car', function(_, args)
    if not BD.debug then return end
    local model = GetHashKey(args[1] or 'sultan')
    if not IsModelInCdimage(model) then
        print('[breakdown] Unknown car model')
        return
    end

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    local ped = PlayerPedId()
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)   -- 4 m in front of you
    local veh = CreateVehicle(model, pos.x, pos.y, pos.z, GetEntityHeading(ped), true, false)
    SetModelAsNoLongerNeeded(model)
    TaskWarpPedIntoVehicle(ped, veh, -1)   -- -1 = driver's seat
end, false)

-- bd_gun: give yourself a pistol so you can test a real robbery
RegisterCommand('bd_gun', function()
    if not BD.debug then return end
    GiveWeaponToPed(PlayerPedId(), GetHashKey('WEAPON_PISTOL'), 100, false, true)
    debugPrint('Pistol given')
end, false)