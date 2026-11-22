cashMachineRobbed = {}

local casheer = {}
local isRobberyStarted = {}
local watchStarted = false
local currentBalance = 0
local balanceLoaded = false
local moneyChange = 0
local moneyChangeUntil = 0

local function UpdateBalance(balance)
    if type(balance) ~= "number" then return end

    if balanceLoaded then
        local difference = balance - currentBalance

        if difference ~= 0 then
            moneyChange = difference
            moneyChangeUntil = GetGameTimer() + 2500
        end
    end

    currentBalance = balance
    balanceLoaded = true
end

local function DoRobbery(storeId)
    isRobberyStarted[storeId] = true
    print("player is aiming at casheer, robbery started", storeId)

    TaskHandsUp(casheer[storeId] --[[ Ped ]] , Config.handsUpDuration --[[ duration ]] , -1 --[[ Ped ]] , -1,
        false)
    TriggerServerEvent("store-robbery:server:robberyStarted", storeId)
    cashMachineRobbed[storeId] = true
    print("cash machine robbed, safe can be cracked for store", storeId)

    Wait(Config.handsUpDuration)
    ClearPedTasks(casheer[storeId])

    Wait(Config.robberyCooldown)
    isRobberyStarted[storeId] = false
    print("cooldown over", storeId)
end

local function StartRobberyWatch()
    if watchStarted then return end
    watchStarted = true

    CreateThread(function()
        while true do
            Wait(500)
            for i = 1, #Config.stores do
                local id = Config.stores[i].id
                if not isRobberyStarted[id] and DoesEntityExist(casheer[id]) then
                    if IsPedArmed(PlayerPedId() --[[ Ped ]] , 4 --[[ integer ]] ) and
                        IsPlayerFreeAimingAtEntity(PlayerId() --[[ Player ]] , casheer[id] --[[ Entity ]] ) then
                        print("aiming at casheer", id)
                        isRobberyStarted[id] = true
                        CreateThread(function()
                            DoRobbery(id)
                        end)
                    end
                end
            end
        end
    end)
end

local function spawnCasheer(store)
    if casheer[store.id] and DoesEntityExist(casheer[store.id]) then
        print("deleting old casheer", store.id)
        DeleteEntity(casheer[store.id])
    end

    local modelHash = GetHashKey(store.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(0)
    end
    print("model loaded", store.id, store.model)

    local ped = CreatePed(1, modelHash --[[ Hash ]] , store.x --[[ number ]] , store.y --[[ number ]] ,
        store.z --[[ number ]] , store.r --[[ number ]] , false --[[ boolean ]] , false --[[ boolean ]] )

    SetModelAsNoLongerNeeded(modelHash)
    SetEntityInvincible(ped --[[ Entity ]] , true --[[ boolean ]] )
    SetBlockingOfNonTemporaryEvents(ped --[[ Ped ]] , true --[[ boolean ]] )
    SetEntityAsMissionEntity(ped --[[ Entity ]] , true --[[ boolean ]] , true --[[ boolean ]] )

    print("casheer spawned", store.id, store.name)
    return ped
end

local function spawnAllCasheers()
    for i = 1, #Config.stores do
        casheer[Config.stores[i].id] = spawnCasheer(Config.stores[i])
    end

    StartRobberyWatch()
end

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(250)
    end
    spawnAllCasheers()
end)

RegisterCommand('spawncasheer', function()
    spawnAllCasheers()
end, false)

RegisterCommand('balance', function()
    TriggerServerEvent("store-robbery:server:getBalance")
end, false)

RegisterCommand('buy', function(source, args)
    local item = args[1]
    print("trying to buy", item)
    TriggerServerEvent("store-robbery:server:buyItem", item)
end, false)

RegisterCommand('startRobbery', function(source, args)
    local storeId = tonumber(args[1])
    print("test robbery for store", storeId)
    TriggerServerEvent("store-robbery:server:robberyStarted", storeId)
end, false)

RegisterNetEvent("store-robbery:client:balance")
AddEventHandler("store-robbery:client:balance", function(balance)
    UpdateBalance(balance)
    print("my balance:", balance)
end)

RegisterNetEvent("store-robbery:client:unknownItem")
AddEventHandler("store-robbery:client:unknownItem", function(item)
    print("unknown item:", item)
end)

RegisterNetEvent("store-robbery:client:buyResult")
AddEventHandler("store-robbery:client:buyResult", function(ok, item, balance)
    UpdateBalance(balance)
    if ok then
        print("bought", item, "balance now:", balance)
    else
        print("cant buy", item, "balance still:", balance)
    end
end)


CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(250)
    end

    TriggerServerEvent("store-robbery:server:getBalance")
end)

CreateThread(function()
    while true do
        Wait(0)

        if balanceLoaded and not IsPauseMenuActive() then
            local margin = (1.0 - GetSafeZoneSize()) * 0.5
            local rightEdge = 0.985 - margin
            local topEdge = 0.045 + margin

            SetTextFont(7)
            SetTextScale(0.0, 0.65)
            SetTextColour(114, 204, 114, 255)
            SetTextOutline()
            SetTextRightJustify(true)
            SetTextWrap(0.0, rightEdge)

            BeginTextCommandDisplayText("STRING")
            AddTextComponentSubstringPlayerName(
                "$" .. tostring(currentBalance)
            )
            EndTextCommandDisplayText(rightEdge, topEdge)

            local remaining = moneyChangeUntil - GetGameTimer()

            if remaining > 0 then
                
                local alpha = math.floor(
                    255 * math.min(1.0, remaining / 500.0)
                )

                local text

                if moneyChange > 0 then
                    SetTextColour(114, 204, 114, alpha)
                    text = "+$" .. tostring(moneyChange)
                else
                    SetTextColour(224, 50, 50, alpha)
                    text = "-$" .. tostring(math.abs(moneyChange))
                end

                SetTextFont(7)
                SetTextScale(0.0, 0.5)
                SetTextOutline()
                SetTextRightJustify(true)
                SetTextWrap(0.0, rightEdge)

                BeginTextCommandDisplayText("STRING")
                AddTextComponentSubstringPlayerName(text)
                EndTextCommandDisplayText(
                    rightEdge,
                    topEdge + 0.045
                )
            end
        end
    end
end)

RegisterCommand('coords', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    print(("x = %.4f, y = %.4f, z = %.4f, r = %.4f")
        :format(coords.x, coords.y, coords.z, heading))
end, false)