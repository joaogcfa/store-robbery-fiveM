local playerMoney = {}

RegisterNetEvent("store-robbery:server:robberyStarted")
AddEventHandler("store-robbery:server:robberyStarted", function()
    local src = source

    playerMoney[src] = (playerMoney[src] or 0) + Config.robberyPayout
    print(("player %d robbed the store, new balance: %d"):format(src, playerMoney[src]))
end)