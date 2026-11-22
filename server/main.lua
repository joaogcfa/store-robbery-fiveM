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

RegisterNetEvent("store-robbery:server:robberyStarted")
AddEventHandler("store-robbery:server:robberyStarted", function()
    local src = source
    local now = GetGameTimer()

    if lastRobbery[src] and now - lastRobbery[src] < Config.robberyCooldown then
        print("robbery refused, still on cooldown", src)
        return
    end

    addMoney(src, Config.robberyPayout)
    lastRobbery[src] = now
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