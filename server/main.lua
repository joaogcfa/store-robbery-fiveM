local playerMoney = {}
local lastRobbery = {}

local function addMoney(src, amount)
    if type(amount) ~= "number" or amount <= 0 then
        print("addMoney bad amount", src, amount)
        return false
    end
    playerMoney[src] = (playerMoney[src] or 0) + amount
    return true
end

local function getBalance(src)
    return playerMoney[src] or 0
end

local function takeMoney(src, amount)
    if type(amount) ~= "number" or amount <= 0 then
        print("takeMoney bad amount", src, amount)
        return false
    end
    if getBalance(src) >= amount then
        playerMoney[src] = getBalance(src) - amount
        return true
    end
    return false
end

local function findStore(storeId)
    for i = 1, #Config.stores do
        if Config.stores[i].id == storeId then
            return Config.stores[i]
        end
    end
    return nil
end

RegisterNetEvent("store-robbery:server:robberyStarted")
AddEventHandler("store-robbery:server:robberyStarted", function(storeId)
    local src = source
    local now = GetGameTimer()
    print("robbery event from", src, "store", storeId)

    local store = findStore(storeId)
    if store == nil then
        print("robbery refused, bad store id", src, storeId)
        return
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local distance = #(playerCoords - vector3(store.x, store.y, store.z))
    print("player coords", playerCoords, "distance to store", distance)
    if distance > 10.0 then
        print("robbery refused, too far from store", src, storeId)
        return
    end

    local key = src .. "_" .. storeId

    if lastRobbery[key] and now - lastRobbery[key] < Config.robberyCooldown then
        print("robbery refused, still on cooldown", key)
        return
    end

    addMoney(src, Config.robberyPayout)
    lastRobbery[key] = now
    TriggerClientEvent("store-robbery:client:balance", src, getBalance(src))
    print("new balance", src, getBalance(src))
end)

RegisterNetEvent("store-robbery:server:getBalance")
AddEventHandler("store-robbery:server:getBalance", function()
    local src = source
    local balance = getBalance(src)
    print("balance asked", src, balance)
    TriggerClientEvent("store-robbery:client:balance", src, balance)
end)

RegisterNetEvent("store-robbery:server:buyItem")
AddEventHandler("store-robbery:server:buyItem", function(item)
    local src = source
    local price = Config.items[item]
    if price == nil then
        print("unknown item", src, item)
        TriggerClientEvent("store-robbery:client:unknownItem", src, item)
        return
    end

    local ok = takeMoney(src, price)
    print("buy", src, item, price, ok, getBalance(src))
    TriggerClientEvent("store-robbery:client:buyResult", src, ok, item, getBalance(src))
end)
