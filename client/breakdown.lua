local BD = Config.breakdown  


local function debugPrint(msg)
    if BD.debug then
        print('[breakdown] ' .. msg)
    end
end

-- notification above the minimap
local function notify(text)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, true)
end


-- Hook: fired from DoRobbery() in client/main.lua when the clerk lowers their hands


AddEventHandler('store-robbery:client:robberyFinished', function()
    debugPrint('Robbery finished: breakdown system armed')
    notify('~r~Robbery complete!~s~ Get to a car and get out of here.')
end)


-- Debug commands 


-- bd_test: pretend a robbery just finished, so you don't have to rob the store every time
RegisterCommand('bd_test', function()
    if not BD.debug then return end
    TriggerEvent('store-robbery:client:robberyFinished')
end, false)

-- bd_gun: give yourself a pistol so you can test a real robbery
RegisterCommand('bd_gun', function()
    if not BD.debug then return end
    GiveWeaponToPed(PlayerPedId(), GetHashKey('WEAPON_PISTOL'), 100, false, true)
    debugPrint('Pistol given')
end, false)