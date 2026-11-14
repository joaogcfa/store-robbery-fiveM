local casheer
local isRobberyStarted = false
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

local function DoRobbery()
    isRobberyStarted = true
    print("player is aiming at casheer, robbery started")

    TaskHandsUp(casheer --[[ Ped ]] , Config.handsUpDuration --[[ duration ]] , -1 --[[ facingPed, none: frozen ped can't turn ]] , -1,
        false)
    TriggerServerEvent("store-robbery:server:robberyStarted")

    Wait(Config.handsUpDuration)
    ClearPedTasks(casheer)

    Wait(Config.robberyCooldown)
    isRobberyStarted = false
end

local function StartRobberyWatch()
    if watchStarted then return end
    watchStarted = true

    CreateThread(function()
        while true do
            Wait(500)
            if not isRobberyStarted and DoesEntityExist(casheer) then
                if IsPedArmed(PlayerPedId() --[[ Ped ]] , 4 --[[ integer ]] ) and
                    IsPlayerFreeAimingAtEntity(PlayerId() --[[ Player ]] , casheer --[[ Entity ]] ) then
                    DoRobbery()
                end
            end
        end
    end)
end

RegisterCommand('spawncasheer', function()
    local modelHash = GetHashKey(store_data.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(0)
    end

    casheer = CreatePed(1, modelHash --[[ Hash ]] , store_data.x --[[ number ]] , store_data.y --[[ number ]] ,
        store_data.z --[[ number ]] , store_data.r --[[ number ]] , false --[[ boolean ]] , false --[[ boolean ]] )

    SetModelAsNoLongerNeeded(modelHash)
    SetEntityInvincible(casheer --[[ Entity ]] , true --[[ boolean ]] )
    SetBlockingOfNonTemporaryEvents(casheer --[[ Ped ]] , true --[[ boolean ]] )
    SetEntityAsMissionEntity(casheer --[[ Entity ]] , true --[[ boolean ]] , true --[[ boolean ]] )

    StartRobberyWatch()
end, false)

RegisterCommand('balance', function()
    TriggerServerEvent("store-robbery:server:getBalance")
end, false)

RegisterCommand('buy', function(source, args)
    local item = args[1]
    print("trying to buy", item)
    TriggerServerEvent("store-robbery:server:buyItem", item)
end, false)

RegisterCommand('startRobbery', function()
    TriggerServerEvent("store-robbery:server:robberyStarted")
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