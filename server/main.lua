RegisterNetEvent("store-robbery:server:robberyStarted")
AddEventHandler("store-robbery:server:robberyStarted", function()
    local src = source
    print("robbery started", src)
end)