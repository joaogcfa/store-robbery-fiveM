local missionStarted = false
local askedByCommand = false
local gunVanBlip = nil
local storeBlip = nil
local targetStoreId = nil
local gunBought = false
local objective = nil
local waitingEscape = false
local robbedStoreId = nil
local respawnStoreId = nil

local function SetObjective(text)
    objective = text
    print("new objective", text)
end

local function SendMissionTexts()
    RequestStreamedTextureDict(Config.mission.picture, false)
    local attempts = 0
    while not HasStreamedTextureDictLoaded(Config.mission.picture) do
        Wait(10)
        attempts = attempts + 1
        if attempts > 100 then
            print("contact picture failed to load", Config.mission.picture)
            break
        end
    end
    print("contact picture loaded", Config.mission.picture, HasStreamedTextureDictLoaded(Config.mission.picture))

    for i = 1, #Config.mission.messages do
        PlaySoundFrontend(-1, "Text_Arrive_Tone", "Phone_SoundSet_Default", true)
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(Config.mission.messages[i])
        EndTextCommandThefeedPostMessagetext(Config.mission.picture, Config.mission.picture, false, 1,
            Config.mission.senderName, Config.mission.subject)
        print("mission text sent", i)
        Wait(4000)
    end
end

local function FindMissionStore(storeId)
    for i = 1, #Config.stores do
        if Config.stores[i].id == storeId then
            return Config.stores[i]
        end
    end
    return nil
end

local function AddStoreBlip(store)
    if storeBlip then
        RemoveBlip(storeBlip)
    end

    storeBlip = AddBlipForCoord(store.x, store.y, store.z)
    SetBlipSprite(storeBlip, 52)
    SetBlipColour(storeBlip, 5)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Rival Store")
    EndTextCommandSetBlipName(storeBlip)
    print("store blip added", storeBlip, store.name)
end

local function AddMissionBlips()
    if gunVanBlip then
        RemoveBlip(gunVanBlip)
    end

    local van = Config.weaponShop.position
    gunVanBlip = AddBlipForCoord(van.x, van.y, van.z)
    SetBlipSprite(gunVanBlip, 110)
    SetBlipColour(gunVanBlip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName("Gun Van")
    EndTextCommandSetBlipName(gunVanBlip)

    print("gun van blip added", gunVanBlip)

    AddStoreBlip(FindMissionStore(targetStoreId))
end

RegisterCommand('startmission', function()
    print("startmission command")
    askedByCommand = true
    TriggerServerEvent("store-robbery:server:startMission")
end, false)

AddEventHandler("playerSpawned", function()
    if respawnStoreId then
        local store = FindMissionStore(respawnStoreId)
        respawnStoreId = nil
        SetEntityCoords(PlayerPedId(), store.respawn.x, store.respawn.y, store.respawn.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), store.respawn.r)
        print("respawned outside store", store.id)
    end

    if missionStarted then
        print("player spawned, mission already started")
        return
    end
    print("player spawned, starting mission")
    askedByCommand = false
    TriggerServerEvent("store-robbery:server:startMission")
end)

RegisterNetEvent("store-robbery:client:missionResult")
AddEventHandler("store-robbery:client:missionResult", function(result)
    print("mission result from server", result, "by command", askedByCommand)
    missionStarted = true

    if result == "started" then
        RemoveAllPedWeapons(PlayerPedId(), true)
        print("removed all weapons")
        targetStoreId = Config.mission.firstStoreId
        gunBought = false
        AddMissionBlips()
        SetObjective("Buy a gun at the ~r~Gun Van~s~")
        CreateThread(function()
            SendMissionTexts()
        end)
    elseif askedByCommand then
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName("You already have a job from " .. Config.mission.senderName .. ".")
        EndTextCommandThefeedPostTicker(false, true)
    end
end)

RegisterNetEvent("store-robbery:client:weaponPurchase")
AddEventHandler("store-robbery:client:weaponPurchase", function(ok, name, message)
    if ok and targetStoreId == Config.mission.firstStoreId and not gunBought then
        gunBought = true
        SetObjective("Go rob the ~y~rival store~s~")
    end
end)

RegisterNetEvent("store-robbery:client:storeRobbed")
AddEventHandler("store-robbery:client:storeRobbed", function(storeId)
    print("store robbed", storeId, "current target", targetStoreId)
    if storeId ~= targetStoreId or waitingEscape then
        return
    end

    waitingEscape = true
    robbedStoreId = storeId
    targetStoreId = nil
    if storeBlip then
        RemoveBlip(storeBlip)
        storeBlip = nil
    end

    if FindMissionStore(storeId).safe then
        SetObjective("~y~Crack the safe in the back of the store ~s~ or ~r~lose the cops~s~")
    else
        SetObjective("~r~Lose the cops~s~")
    end
end)

RegisterNetEvent("store-robbery:client:escapeFailed")
AddEventHandler("store-robbery:client:escapeFailed", function(failedStoreId, lostMoney, storeIds)
    print("escape failed, back to store", failedStoreId, "lost", lostMoney)
    respawnStoreId = failedStoreId

    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName("~r~You died while escaping.~s~ You lost $" .. lostMoney .. ".")
    EndTextCommandThefeedPostTicker(false, true)

    if waitingEscape then
        waitingEscape = false
        targetStoreId = robbedStoreId
        AddStoreBlip(FindMissionStore(targetStoreId))
        SetObjective("Go back to the ~y~rival store~s~")
    end
end)

RegisterNetEvent("store-robbery:client:escaped")
AddEventHandler("store-robbery:client:escaped", function(money)
    print("escaped, money is safe", money, "waiting escape", waitingEscape)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName("~g~You got away!~s~ The $" .. money .. " is yours.")
    EndTextCommandThefeedPostTicker(false, true)

    if not waitingEscape then
        return
    end
    waitingEscape = false

    local nextStore = FindMissionStore(robbedStoreId + 1)

    if nextStore then
        targetStoreId = nextStore.id
        AddStoreBlip(nextStore)
        if FindMissionStore(targetStoreId + 1) then
            SetObjective("Go rob the next ~y~rival store~s~")
        else
            SetObjective("Go rob the last ~y~rival store~s~")
        end
    else
        targetStoreId = nil
        SetObjective("Job done")
        CreateThread(function()
            Wait(8000)
            if targetStoreId == nil and not waitingEscape then
                objective = nil
            end
        end)
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        if objective then
            BeginTextCommandPrint("STRING")
            AddTextComponentSubstringPlayerName(objective)
            EndTextCommandPrint(1100, true)
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if gunVanBlip then
        RemoveBlip(gunVanBlip)
    end
    if storeBlip then
        RemoveBlip(storeBlip)
    end
    print("mission blips removed")
end)
