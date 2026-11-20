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
