local playerMoney = {}
local lastRobbery = {}
local cashMachineRobbed = {}
local safeOpened = {}

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
    cashMachineRobbed[key] = true
    TriggerClientEvent("store-robbery:client:storeRobbed", src, storeId)
    TriggerClientEvent("store-robbery:client:balance", src, getBalance(src))
    print("new balance", src, getBalance(src))
end)

RegisterNetEvent("store-robbery:server:safeCracked")
AddEventHandler("store-robbery:server:safeCracked", function(storeId)
    local src = source
    print("safe cracked event from", src, "store", storeId)

    local store = findStore(storeId)
    if store == nil or store.safe == nil then
        print("safe refused, bad store id or no safe", src, storeId)
        TriggerClientEvent("store-robbery:client:safeResult", src, false, storeId, "bad store")
        return
    end

    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local distance = #(playerCoords - vector3(store.safe.x, store.safe.y, store.safe.z))
    print("distance to safe", distance)
    if distance > 3.0 then
        print("safe refused, too far from safe", src, storeId)
        TriggerClientEvent("store-robbery:client:safeResult", src, false, storeId, "too far")
        return
    end

    local key = src .. "_" .. storeId
    if not cashMachineRobbed[key] then
        print("safe refused, cash machine not robbed", key)
        TriggerClientEvent("store-robbery:client:safeResult", src, false, storeId, "rob the cash machine first")
        return
    end

    if safeOpened[key] then
        print("safe refused, already opened by this player", key)
        TriggerClientEvent("store-robbery:client:safeResult", src, false, storeId, "already open")
        return
    end

    addMoney(src, Config.safePayout)
    safeOpened[key] = true
    print("safe paid", src, storeId, "new balance", getBalance(src))
    TriggerClientEvent("store-robbery:client:balance", src, getBalance(src))
    TriggerClientEvent("store-robbery:client:safeResult", src, true, storeId, "safe opened")
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

<<<<<<< HEAD
-- Car breakdown (Suryaveer): the player ditched their getaway car, so they lose the robbery cash
RegisterNetEvent("store-robbery:server:loseRobberyCash")
AddEventHandler("store-robbery:server:loseRobberyCash", function()
    local src = source
    -- Take back up to one robbery's payout (less if they've already spent some)
    local amount = math.min(Config.robberyPayout, getBalance(src))
    if amount > 0 then
        takeMoney(src, amount)
    end
    TriggerClientEvent("store-robbery:client:balance", src, getBalance(src))
    print("ditched getaway car, lost cash", src, amount, getBalance(src))
end)
=======

local lastWeaponPurchase = {}

RegisterNetEvent("store-robbery:server:buyWeapon", function(name)
    local src = source

    if type(name) ~= "string" then return end

    local item = Config.weaponShop.weapons[name]
    if not item then return end

    -- Limit repeated purchase requests.
    local now = GetGameTimer()

    if lastWeaponPurchase[src]
        and now - lastWeaponPurchase[src] < 1000 then
        return
    end

    lastWeaponPurchase[src] = now

    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return end

    -- Validate the player's position on the server.
    local position = GetEntityCoords(ped)

    if #(position - Config.weaponShop.position) > 7.0 then
        TriggerClientEvent(
            "store-robbery:client:weaponPurchase",
            src, false, name, "You are too far from the dealer."
        )
        return
    end

    -- Read the price from server configuration.
    if not takeMoney(src, item.price) then
        TriggerClientEvent(
            "store-robbery:client:weaponPurchase",
            src, false, name, "Not enough cash."
        )
        return
    end

    TriggerClientEvent(
        "store-robbery:client:balance",
        src, getBalance(src)
    )

    TriggerClientEvent(
        "store-robbery:client:weaponPurchase",
        src, true, name, "Purchased " .. name .. "."
    )

    print(("[Weapon Shop] Player %d purchased %s for $%d.")
        :format(src, name, item.price))
end)

AddEventHandler("playerDropped", function()
    lastWeaponPurchase[source] = nil
end)

local missionStarted = {}

RegisterNetEvent("store-robbery:server:startMission")
AddEventHandler("store-robbery:server:startMission", function()
    local src = source
    print("start mission event from", src)

    if missionStarted[src] then
        print("mission already started", src)
        TriggerClientEvent("store-robbery:client:missionResult", src, "already started")
        return
    end

    addMoney(src, Config.mission.startMoney)
    missionStarted[src] = true
    TriggerClientEvent("store-robbery:client:balance", src, getBalance(src))
    TriggerClientEvent("store-robbery:client:missionResult", src, "started")
    print("mission started", src, "new balance", getBalance(src))
end)

AddEventHandler("playerDropped", function()
    missionStarted[source] = nil
    print("player dropped, mission cleared", source)
end)