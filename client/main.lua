local casheer
local isRobberyStarted

RegisterCommand('spawncasheer', function()
    local modelHash = GetHashKey(store_data.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(0)
    end

    casheer = CreatePed(1, modelHash --[[ Hash ]] , store_data.x --[[ number ]] , store_data.y --[[ number ]] ,
        store_data.z --[[ number ]] , store_data.r --[[ number ]] , false --[[ boolean ]] , false --[[ boolean ]] )

    SetModelAsNoLongerNeeded(modelHash)
    FreezeEntityPosition(casheer, true)
    SetEntityInvincible(casheer --[[ Entity ]] , true --[[ boolean ]] )
end, false)

CreateThread(function()
    while not isRobberyStarted do
        Wait(500)
        if DoesEntityExist(casheer) then
            print("clerk exists")
            if IsPedArmed(PlayerPedId() --[[ Ped ]] , 4 --[[ integer ]] ) then
                print("player is armed")
                if IsPlayerFreeAimingAtEntity(PlayerId() --[[ Player ]] , casheer --[[ Entity ]] ) and
                    not isRobberyStarted then
                    print("player is aiming at casheer")
                    isRobberyStarted = true
					TriggerServerEvent("store-robbery:server:robberyStarted")
                end
            end
        end
    end
end)
