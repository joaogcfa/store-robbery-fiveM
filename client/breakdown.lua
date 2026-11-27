-- Flow (the "state" variable):
--   idle      -> nothing happening
--   armed     -> robbery finished, waiting for the player to get into a car as the driver
--   driving   -> getaway car picked and it WILL break; counting metres driven
--   breaking  -> sputter sequence playing (a few seconds)
--   limp      -> smoking, speed capped, stalls every 20-30 s; can be repaired at the bonnet
--   repairing -> skill check in progress
--   escaping  -> repaired, player has wanted stars; ends when the stars are gone


local DEFAULTS = {
    debug = false,

    chance = 65, breakDistanceMin = 150.0, breakDistanceMax = 400.0,
    sputterCount = 4,

    limpSpeedMph = 25.0, limpEngineHealth = 120.0, limpPowerMultiplier = 0.5,
    stallIntervalMin = 20, stallIntervalMax = 30, restartHoldTime = 2.0,
    restartControl = 73, restartControlName = 'INPUT_VEH_DUCK',

    smokeAsset = 'core', smokeEffect = 'ent_amb_smoke_general', smokeScale = 1.5,

    repairDistance = 1.8, skillHits = 3, skillZoneSizes = { 0.22, 0.15, 0.09 },
    skillSpeed = 1.1, skillSpeedUp = 0.25, failCooldown = 3.0,

    wantedLevel = 5,

    ditchDistance = 50.0, ditchWarnDistance = 30.0,
}

Config.breakdown = Config.breakdown or {}
local BD = Config.breakdown   

for key, value in pairs(DEFAULTS) do
    if BD[key] == nil then
        BD[key] = value
        print(('^3[breakdown] Config.breakdown.%s is missing from config.lua, using default: %s^7')
            :format(key, tostring(value)))
    end
end


math.randomseed(GetGameTimer())

local MPH_TO_MS = 0.44704     


-- State


local state = 'idle'
local getaway = nil      
local traveled = 0.0      
local breakAt = 0.0       
local lastPos = nil       

local stalled = false     
local stallTimer = 0.0    
local restartHeld = 0.0   
local smokeFx = nil       
local repairCooldownUntil = 0   
local ditchWarned = false       

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

-- Is the player sitting in the driver's seat of this vehicle?
local function isDriverOf(veh)
    local ped = PlayerPedId()
    return IsPedInVehicle(ped, veh, false) and GetPedInVehicleSeat(veh, -1) == ped
end

-- Only things with an engine on the ground can be getaway cars
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
    ditchWarned = false
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
    SetVehicleEngineHealth(veh, BD.limpEngineHealth)      
    SetEntityMaxSpeed(veh, BD.limpSpeedMph * MPH_TO_MS)     
    CreateThread(function() startSmoke(veh) end)            

    stalled = false
    restartHeld = 0.0
    stallTimer = randomFloat(BD.stallIntervalMin, BD.stallIntervalMax)
    state = 'limp'

    notify('~r~Engine failing!~s~ Pull over and fix it at the bonnet.')
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



local CONTROL_E = 38          -- INPUT_CONTEXT (E)
local CONTROL_CANCEL = 177    -- INPUT_CELLPHONE_CANCEL (Backspace)
local BONNET_DOOR = 4         -- door index 4 = bonnet

local REPAIR_DICT, REPAIR_ANIM = 'mini@repair', 'fixing_a_player'

-- A point just in front of the car's nose
local function getBonnetPos(veh)
    local _, max = GetModelDimensions(GetEntityModel(veh))
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, max.y + 0.4, 0.0)
end

local function isNearBonnet(veh)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return false end
    return #(GetEntityCoords(ped) - getBonnetPos(veh)) <= BD.repairDistance
end

local function playRepairAnim(ped)
    RequestAnimDict(REPAIR_DICT)
    local timeout = GetGameTimer() + 2000
    while not HasAnimDictLoaded(REPAIR_DICT) and GetGameTimer() < timeout do
        Wait(0)
    end
    if HasAnimDictLoaded(REPAIR_DICT) then
        TaskPlayAnim(ped, REPAIR_DICT, REPAIR_ANIM, 8.0, -8.0, -1, 1, 0, false, false, false)   -- 1 = loop
    end
end

-- Text drawn straight onto the screen (x, y from 0.0 to 1.0)
local function drawText(text, x, y, scale)
    SetTextFont(4)
    SetTextScale(0.0, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- The skill check bar. All positions are fractions of the screen.
local BAR_X, BAR_Y, BAR_W, BAR_H = 0.5, 0.80, 0.30, 0.025

local function drawSkillBar(marker, zoneCenter, zoneSize, hits)
    local left = BAR_X - BAR_W / 2
    DrawRect(BAR_X, BAR_Y, BAR_W + 0.006, BAR_H + 0.012, 0, 0, 0, 190)                        -- background
    DrawRect(left + zoneCenter * BAR_W, BAR_Y, zoneSize * BAR_W, BAR_H, 80, 200, 90, 230)       -- green zone
    DrawRect(left + marker * BAR_W, BAR_Y, 0.003, BAR_H + 0.014, 255, 255, 255, 255)            -- marker
    drawText(('Fix the engine: press ~g~E~s~ in the green zone  (%d/%d)'):format(hits, BD.skillHits),
        BAR_X, BAR_Y - 0.06, 0.45)
    drawText('~c~Backspace to stop', BAR_X, BAR_Y + 0.022, 0.32)
end

-- Random centre for a green zone of this size, kept away from the edges
local function newZone(size)
    local margin = size / 2 + 0.03
    return margin + math.random() * (1.0 - 2 * margin)
end

-- Missed: bang, extra smoke, short cooldown before trying again
local function failRepair(veh)
    PlaySoundFrontend(-1, 'Hack_Failed', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.3)
    SetVehicleEngineHealth(veh, 60.0)          -- puff of thick smoke
    repairCooldownUntil = GetGameTimer() + BD.failCooldown * 1000
    notify('~r~Bang!~s~ You messed it up. Let it cool off and try again.')
    debugPrint('Repair failed')

    -- Smoke settles back to normal limp level after the cooldown
    CreateThread(function()
        Wait(math.floor(BD.failCooldown * 1000))
        if state == 'limp' and DoesEntityExist(veh) then
            SetVehicleEngineHealth(veh, BD.limpEngineHealth)
        end
    end)
end

-- Success: car fully working again, then the police turn up
local function finishRepair(veh)
    stopSmoke()
    RemoveParticleFxFromEntity(veh)
    SetVehicleDoorShut(veh, BONNET_DOOR, false)
    SetVehicleEngineCanDegrade(veh, true)
    SetVehicleEngineHealth(veh, 1000.0)
    SetEntityMaxSpeed(veh, 999.0)                -- effectively removes the cap
    SetVehicleEngineOn(veh, true, false, false)
    stalled = false
    PlaySoundFrontend(-1, 'Hack_Success', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)

    state = 'escaping'
    local player = PlayerId()
    SetPlayerWantedLevel(player, BD.wantedLevel, false)
    SetPlayerWantedLevelNow(player, false)

    notify(('~g~Engine fixed!~s~ But someone saw you... ~r~%d stars!'):format(BD.wantedLevel))
    debugPrint('Repaired, wanted level set to ' .. BD.wantedLevel)
end

-- The skill check itself. Runs in its own thread, every frame, until it ends.
local function runSkillCheck(veh)
    state = 'repairing'
    local ped = PlayerPedId()

    -- Face the car, pop the bonnet, start the repair animation, stop the player walking off
    TaskTurnPedToFaceEntity(ped, veh, 1000)
    Wait(800)
    SetVehicleDoorOpen(veh, BONNET_DOOR, false, true)   -- last true = open instantly, all the way
    playRepairAnim(ped)
    FreezeEntityPosition(ped, true)

    local hits = 0
    local marker, direction = 0.0, 1
    local speed = BD.skillSpeed
    local size = BD.skillZoneSizes[1]
    local zone = newZone(size)
    local result = nil   -- 'success', 'fail' or 'cancel'

    while not result do
        -- Stop if something else ended the breakdown (car destroyed, player died, bd_reset)
        if state ~= 'repairing' or not DoesEntityExist(veh) or IsEntityDead(ped) then
            result = 'cancel'
            break
        end

        -- Move the marker, bouncing off both ends of the bar
        marker = marker + direction * speed * GetFrameTime()
        if marker >= 1.0 then
            marker, direction = 1.0, -1
        elseif marker <= 0.0 then
            marker, direction = 0.0, 1
        end

        -- Use E and Backspace only for the skill check while it's on screen
        DisableControlAction(0, CONTROL_E, true)
        DisableControlAction(0, CONTROL_CANCEL, true)

        -- Keep the bonnet fully open (GTA can let it drift back down)
        if GetVehicleDoorAngleRatio(veh, BONNET_DOOR) < 0.95 then
            SetVehicleDoorOpen(veh, BONNET_DOOR, false, true)
        end
        drawSkillBar(marker, zone, size, hits)

        if IsDisabledControlJustPressed(0, CONTROL_E) then
            if math.abs(marker - zone) <= size / 2 then
                hits = hits + 1
                if hits >= BD.skillHits then
                    result = 'success'
                else
                    -- Next hit: smaller zone, somewhere else, faster marker
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    size = BD.skillZoneSizes[hits + 1] or size
                    zone = newZone(size)
                    speed = speed + BD.skillSpeedUp
                end
            else
                result = 'fail'
            end
        elseif IsDisabledControlJustPressed(0, CONTROL_CANCEL) then
            result = 'cancel'
        end

        Wait(0)
    end

    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)

    if result == 'success' then
        finishRepair(veh)
        return
    end

    if DoesEntityExist(veh) then
        SetVehicleDoorShut(veh, BONNET_DOOR, false)
        if result == 'fail' then
            failRepair(veh)
        end
    end
    if state == 'repairing' then
        state = 'limp'
    end
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

    -- Keep it slow: re-apply the speed cap and weaker engine every frame
    -- (power multipliers only last one frame, and GTA can reset the cap)
    SetEntityMaxSpeed(veh, BD.limpSpeedMph * MPH_TO_MS)
    SetVehicleCheatPowerIncrease(veh, BD.limpPowerMultiplier)

    -- On foot next to the bonnet: offer the repair
    if isNearBonnet(veh) then
        local wait = repairCooldownUntil - GetGameTimer()
        if wait > 0 then
            showHelp(('The engine is too hot. Try again in %d s'):format(math.ceil(wait / 1000)))
        else
            showHelp('Press ~INPUT_CONTEXT~ to fix the engine')
            if IsControlJustPressed(0, CONTROL_E) then
                state = 'repairing'   -- set straight away so it can't start twice
                CreateThread(function() runSkillCheck(veh) end)
            end
        end
        return
    end

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


-- States in which the player is committed to the getaway car
local RULE_STATES = { driving = true, breaking = true, limp = true, repairing = true, escaping = true }

local function ditch(reason)
    debugPrint('Ditched the getaway car: ' .. reason)
    -- The server takes the robbery cash back and sends the new balance (the HUD shows -$500)
    TriggerServerEvent('store-robbery:server:loseRobberyCash')
    notify('~r~You ditched the getaway car!~s~ The cash is gone.')
    resetBreakdown('ditched (' .. reason .. ')')
end

-- Returns true if the player broke the rule (and has been punished)
local function checkDitching()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)   -- 0 when on foot

    -- Sitting in any other vehicle (driver or passenger) counts as switching cars
    if veh ~= 0 and veh ~= getaway then
        ditch('got into another vehicle')
        return true
    end

    -- On foot: how far from the getaway car?
    if veh == 0 then
        local dist = #(GetEntityCoords(ped) - GetEntityCoords(getaway))

        if dist > BD.ditchDistance then
            ditch(('walked %.0f m away'):format(dist))
            return true
        end

        -- Warn once when they start wandering off; reset when they come back
        if dist > BD.ditchWarnDistance then
            if not ditchWarned then
                ditchWarned = true
                notify(('~o~Don\'t leave the getaway car!~s~ Go more than %.0f m and you lose the cash.')
                    :format(BD.ditchDistance))
            end
        else
            ditchWarned = false
        end
    end

    return false
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

        -- The no-switching rule runs before everything else; if it fires, state is back to idle
        if RULE_STATES[state] and getaway then
            checkDitching()
        end

        if state == 'armed' then
            sleep = 250
            checkForGetawayCar()
        elseif state == 'driving' then
            sleep = 250
            trackDistance()
        elseif state == 'limp' then
            sleep = 0              -- every frame: help text and key checks need it
            updateLimp()
        elseif state == 'escaping' then
            sleep = 1000
            if GetPlayerWantedLevel(PlayerId()) == 0 then
                notify('~g~You lost the cops.~s~ Clean getaway!')
                resetBreakdown('escaped the police')
            end
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
    info = info .. (' | wanted %d'):format(GetPlayerWantedLevel(PlayerId()))
    if getaway and DoesEntityExist(getaway) then
        info = info .. (' | speed %.0f mph | engine %.0f')
            :format(GetEntitySpeed(getaway) / MPH_TO_MS, GetVehicleEngineHealth(getaway))
        info = info .. (' | bonnet %.1f m'):format(#(GetEntityCoords(PlayerPedId()) - getBonnetPos(getaway)))
        info = info .. (' | car %.0f m away'):format(#(GetEntityCoords(PlayerPedId()) - GetEntityCoords(getaway)))
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

-- bd_nowanted: clear your wanted stars (to test the 'escaping' state ending)
RegisterCommand('bd_nowanted', function()
    if not BD.debug then return end
    ClearPlayerWantedLevel(PlayerId())
    debugPrint('Wanted level cleared')
end, false)

-- bd_gun: give yourself a pistol so you can test a real robbery
RegisterCommand('bd_gun', function()
    if not BD.debug then return end
    GiveWeaponToPed(PlayerPedId(), GetHashKey('WEAPON_PISTOL'), 100, false, true)
    debugPrint('Pistol given')
end, false)