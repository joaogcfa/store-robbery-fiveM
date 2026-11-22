local shopVan
local shopDealer
local displayWeapons = {}

local shopLocation = {
    x = 110.0450,
    y = -1949.8994,
    z = 20.6405,
    heading = 309.6418
}

CreateThread(function()
    local model = GetHashKey("speedo")

    RequestModel(model)

    local timeout = GetGameTimer() + 10000

    while not HasModelLoaded(model) do
        Wait(50)

        if GetGameTimer() > timeout then
            print("[Weapon Shop] Van model didn't load.")
            return
        end
    end

    while #(GetEntityCoords(PlayerPedId()) - vector3(
        shopLocation.x,
        shopLocation.y,
        shopLocation.z
    )) > 80.0 do
        Wait(1000)
    end

    RequestCollisionAtCoord(
        shopLocation.x,
        shopLocation.y,
        shopLocation.z
    )

    shopVan = CreateVehicle(
        model,
        shopLocation.x,
        shopLocation.y,
        shopLocation.z,
        shopLocation.heading,
        false,
        false
    )

    if not DoesEntityExist(shopVan) then
        SetModelAsNoLongerNeeded(model)
        print("[Weapon Shop] Van couldn't be created.")
        return
    end

    SetEntityAsMissionEntity(shopVan, true, true)

    local collisionTimeout = GetGameTimer() + 5000

    while not HasCollisionLoadedAroundEntity(shopVan)
        and GetGameTimer() < collisionTimeout do
        Wait(50)
    end

    SetVehicleOnGroundProperly(shopVan, 5.0)
    SetVehicleColours(shopVan, 0, 0)
    SetVehicleDirtLevel(shopVan, 0.0)
    SetVehicleNumberPlateText(shopVan, "GUNSHOP")

    SetVehicleEngineOn(shopVan, false, true, true)
    SetVehicleDoorsLocked(shopVan, 2)
    SetEntityInvincible(shopVan, true)

    SetVehicleDoorOpen(shopVan, 2, false, true)
    SetVehicleDoorOpen(shopVan, 3, false, true)

    FreezeEntityPosition(shopVan, true)
    SetModelAsNoLongerNeeded(model)

    print("[Weapon Shop] Van spawned.")

    local dealerModel = GetHashKey("g_m_y_famdnf_01")

    RequestModel(dealerModel)

    local dealerTimeout = GetGameTimer() + 10000

    while not HasModelLoaded(dealerModel) do
        Wait(50)

        if GetGameTimer() > dealerTimeout then
            print("[Weapon Shop] Failed to load dealer model.")
            return
        end
    end

    local dealerPosition = GetOffsetFromEntityInWorldCoords(
        shopVan,
        -1.8,
        -3.0,
        0.0
    )

    local groundFound, groundZ = GetGroundZFor_3dCoord(
        dealerPosition.x,
        dealerPosition.y,
        dealerPosition.z + 3.0,
        false
    )

    if not groundFound then
        SetModelAsNoLongerNeeded(dealerModel)
        print("[Weapon Shop] Could not find ground for dealer.")
        return
    end

    shopDealer = CreatePed(
        4,
        dealerModel,
        dealerPosition.x,
        dealerPosition.y,
        groundZ,
        (GetEntityHeading(shopVan) + 180.0) % 360.0,
        false,
        false
    )

    SetModelAsNoLongerNeeded(dealerModel)

    if not DoesEntityExist(shopDealer) then
        print("[Weapon Shop] Failed to spawn dealer.")
        return
    end

    SetEntityAsMissionEntity(shopDealer, true, true)
    SetEntityInvincible(shopDealer, true)
    SetBlockingOfNonTemporaryEvents(shopDealer, true)
    SetPedCanRagdoll(shopDealer, false)
    FreezeEntityPosition(shopDealer, true)

    TaskStartScenarioInPlace(
        shopDealer,
        "WORLD_HUMAN_GUARD_STAND",
        0,
        true
    )

    print("[Weapon Shop] Dealer spawned.")

    local weaponDisplays = {
    {
        name = "Pistol",
        model = "w_pi_pistol",
        x = -0.50,
        y = -2.28,
        z = -0.12
    },
    {
        name = "Micro SMG",
        model = "w_sb_microsmg",
        x = -0.10,
        y = -2.28,
        z = -0.12
    },
    {
        name = "Pump Shotgun",
        model = "w_sg_pumpshotgun",
        x = 0.45,
        y = -2.28,
        z = -0.12
    }
    }



    for _, item in ipairs(weaponDisplays) do
        local objectModel = GetHashKey(item.model)

        RequestModel(objectModel)

        local modelTimeout = GetGameTimer() + 10000

        while not HasModelLoaded(objectModel)
            and GetGameTimer() < modelTimeout do
            Wait(50)
        end

        if HasModelLoaded(objectModel) then
            local position = GetOffsetFromEntityInWorldCoords(
                shopVan,
                item.x,
                item.y,
                item.z
            )

            local object = CreateObjectNoOffset(
                objectModel,
                position.x,
                position.y,
                position.z,
                false,
                false,
                false
            )

            if DoesEntityExist(object) then
                SetEntityAsMissionEntity(object, true, true)
                SetEntityCollision(object, false, false)

                AttachEntityToEntity(
                    object,
                    shopVan,
                    0,
                    item.x,
                    item.y,
                    item.z,
                    90.0,
                    0.0,
                    135.0,
                    false,
                    false,
                    false,
                    false,
                    2,
                    true
                )

                displayWeapons[#displayWeapons + 1] = {
                    entity = object,
                    name = item.name
                }

                print("[Weapon Shop] Display spawned: " .. item.name)
            else
                print("[Weapon Shop] Failed to create display: " .. item.name)
            end
        else
            print("[Weapon Shop] Failed to load display moddel: " .. item.model)
        end

        SetModelAsNoLongerNeeded(objectModel)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

        
    for _, item in ipairs(displayWeapons) do
        if DoesEntityExist(item.entity) then
            DeleteEntity(item.entity)
        end
    end

    if shopDealer and DoesEntityExist(shopDealer) then
        DeleteEntity(shopDealer)
    end

    if shopVan and DoesEntityExist(shopVan) then
        DeleteEntity(shopVan)
    end
end)

local shopCargo = {}

CreateThread(function()

    while not shopVan or not DoesEntityExist(shopVan) do
        Wait(250)
    end

    Wait(1000)

    local cargoItems = {
        {
            model = "prop_box_ammo03a",
            x = -0.22,
            y = -0.65,
            lift = 0.0,
            heading = 0.0
        },
        {
            model = "prop_box_ammo03a",
            x = -0.22,
            y = -0.65,
            lift = 0.0,
            heading = 0.0,
            level = 1
        },
        {
            model = "prop_box_ammo03a",
            x = -0.22,
            y = -0.10,
            lift = 0.0,
            heading = 0.0
        },
        {
            model = "prop_box_guncase_01a",
            x = 0.22,
            y = -0.35,
            lift = 0.0,
            heading = 90.0
        }
    }

    local floorHeight = -0.15

    for _, item in ipairs(cargoItems) do
        local model = GetHashKey(item.model)

        RequestModel(model)

        local deadline = GetGameTimer() + 10000

        while not HasModelLoaded(model)
            and GetGameTimer() < deadline do
            Wait(50)
        end

        if HasModelLoaded(model) then
            local minimum, maximum = GetModelDimensions(model)
            local boxHeight = maximum.z - minimum.z

            local stackHeight = boxHeight * (item.level or 0)
            local height = floorHeight - minimum.z + item.lift + stackHeight
            local position = GetEntityCoords(shopVan)

            local object = CreateObjectNoOffset(
                model,
                position.x,
                position.y,
                position.z,
                false,
                false,
                false
            )

            if DoesEntityExist(object) then
                SetEntityAsMissionEntity(object, true, true)
                SetEntityCollision(object, false, false)

                AttachEntityToEntity(
                    object, shopVan, 0,
                    item.x, item.y, height,
                    0.0, 0.0, item.heading,
                    false, false, false, false, 2, true
                )

                shopCargo[#shopCargo + 1] = object
                print("[Weapon Shop] Cargo spawned: " .. item.model)
            else
                print("[Weapon Shop] Failled to create cargo: " .. item.model)
            end
        else
            print("[Weapon Shop] Failled to load cargo model: " .. item.model)
        end

        SetModelAsNoLongerNeeded(model)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, object in ipairs(shopCargo) do
        if DoesEntityExist(object) then
            DeleteEntity(object)
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 500

        if shopVan and DoesEntityExist(shopVan) then
            local vanPosition = GetEntityCoords(shopVan)
            local playerPosition = GetEntityCoords(PlayerPedId())

            if #(playerPosition - vanPosition) < 25.0 then
                sleep = 0

                local lightPosition = GetOffsetFromEntityInWorldCoords(
                    shopVan,
                    0.0,
                    -1.35,
                    0.55
                )

                DrawLightWithRange(
                    lightPosition.x,
                    lightPosition.y,
                    lightPosition.z,
                    255,
                    230,
                    190,
                    3.0,
                    2.0
                )
            end
        end

        Wait(sleep)
    end
end)

local shopLamp

CreateThread(function()
    while not shopVan or not DoesEntityExist(shopVan) do
        Wait(250)
    end

    Wait(1000)

    local model = GetHashKey("prop_barebulb_01")

    RequestModel(model)

    local deadline = GetGameTimer() + 10000

    while not HasModelLoaded(model)
        and GetGameTimer() < deadline do
        Wait(50)
    end

    if not HasModelLoaded(model) then
        print("[Weapon Shop] Failed to load lamp model.")
        return
    end

    local position = GetEntityCoords(shopVan)

    shopLamp = CreateObjectNoOffset(
        model,
        position.x,
        position.y,
        position.z,
        false,
        false,
        false
    )

    SetModelAsNoLongerNeeded(model)

    if not DoesEntityExist(shopLamp) then
        print("[Weapon Shop] Failed to create lamp.")
        return
    end

    SetEntityAsMissionEntity(shopLamp, true, true)
    SetEntityCollision(shopLamp, false, false)
    
    AttachEntityToEntity(
        shopLamp,
        shopVan,
        0,
        0.0, -1.85, 0.40,
        0.0, 0.0, 0.0,
        false, false, false, false, 2, true
    )

    print("[Weapon Shop] Ceiling lamp mounted.")
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if shopLamp and DoesEntityExist(shopLamp) then
        DeleteEntity(shopLamp)
    end
end)

local function DrawShopsPanel(name, price, owned)

    DrawRect(0.5, 0.87, 0.26, 0.13, 10, 10, 10, 210)
    DrawRect(0.5, 0.805, 0.26, 0.003, 240, 190, 65, 255)

    SetTextFont(4)
    SetTextScale(0.0, 0.48)
    SetTextColour(240, 190, 65, 255)
    SetTextCentre(true)
    SetTextOutline()

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandDisplayText(0.5, 0.815)

    SetTextFont(7)
    SetTextScale(0.0, 0.48)
    SetTextColour(114, 204, 114, 255)
    SetTextCentre(true)
    SetTextOutline()

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName("$" .. tostring(price))
    EndTextCommandDisplayText(0.5, 0.852)

    SetTextFont(4)
    SetTextScale(0.0, 0.32)
    SetTextColour(235, 235, 235, 255)
    SetTextCentre(true)
    SetTextOutline()

    BeginTextCommandDisplayText("STRING")

    if owned then
        AddTextComponentSubstringPlayerName("ALREADY OWNED")
    else
        AddTextComponentSubstringPlayerName("~y~E~s~  BUY")
    end

    EndTextCommandDisplayText(0.5, 0.895)
end

local nextBuying = 0

local function NotiffyPlayer(message)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

RegisterNetEvent("store-robbery:client:weaponPurchase", function(ok, name, message)

    if source ~= 65535 then return end

    if ok then
        local item = Config.weaponShop.weapons[name]
        if not item then return end

        GiveWeaponToPed(
            PlayerPedId(),
            GetHashKey(item.weapon),
            item.ammo,
            false,
            false
        )
    end

    NotiffyPlayer(message)
end)

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()

        if shopVan and DoesEntityExist(shopVan)
            and not IsEntityDead(ped)
            and not IsPedInAnyVehicle(ped, false)
            and not IsPauseMenuActive() then

            local playerPosition = GetEntityCoords(ped)
            local rearPosition = GetOffsetFromEntityInWorldCoords(
                shopVan, 0.0, -2.8, 0.0
            )

            if #(playerPosition - rearPosition) < 3.0 then
                sleep = 0

                local selected
                local closest = 0.09
                local aspect = GetAspectRatio(false)

                for _, display in ipairs(displayWeapons) do
                    if DoesEntityExist(display.entity) then
                        local position = GetEntityCoords(display.entity)

                        local visible, screenX, screenY =
                            GetScreenCoordFromWorldCoord(
                                position.x, position.y, position.z
                            )

                        if visible
                            and #(playerPosition - position) < 3.5
                            and HasEntityClearLosToEntity(
                                ped, display.entity, 17
                            ) then

                            local dx = (screenX - 0.5) * aspect
                            local dy = screenY - 0.5
                            local distance = math.sqrt(dx * dx + dy * dy)

                            if distance < closest then
                                closest = distance
                                selected = display
                            end
                        end
                    end
                end

                DrawRect(0.5, 0.5, 0.002, 0.0035, 255, 255, 255, 200)

                if selected then
                    local item = Config.weaponShop.weapons[selected.name]

                    if item then
                        local owned = HasPedGotWeapon(
                            ped,
                            GetHashKey(item.weapon),
                            false
                        )

                        DrawShopsPanel(selected.name, item.price, owned)

                        if IsControlJustReleased(0, 38)
                            and GetGameTimer() >= nextBuying then

                            nextBuying = GetGameTimer() + 1500

                            if HasPedGotWeapon(
                                ped, GetHashKey(item.weapon), false
                            ) then
                                NotiffyPlayer("You already own this weapon.")
                            else
                                TriggerServerEvent(
                                    "store-robbery:server:buyWeapon",
                                    selected.name
                                )
                            end
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)