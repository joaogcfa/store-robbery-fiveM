local casheer
local isRobberyStarted = false
local watchStarted = false

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
