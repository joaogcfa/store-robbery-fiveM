Config = {
    stores = {
        {
            id = 1,
            name = "LTD Little Seoul",
            model = "s_m_m_autoshop_01",
            x = -705.4786,
            y = -913.8461,
            z = 18.2156,
            r = 75.8789
        },
        {
            id = 2,
            name = "Liquor Shop",
            model = "s_m_m_autoshop_01",
            x = 1133.9285,
            y = -982.3583,
            z = 46.4158,
            r = 268.9130,
            safe = {
                x = 1126.85,
                y = -980.19,
                z = 45.42,
                marker = {
                    x = 1126.82,
                    y = -980.15,
                    z = 44.44
                }
            }
        },
        {
            id = 3,
            name = "Market",
            model = "s_m_m_autoshop_01",
            x = 372.3670,
            y = 326.4533,
            z = 103.5664,
            r = 258.8167,
            safe = {
                x = 378.07,
                y = 333.31,
                z = 103.57,
                marker = {
                    x = 378.08,
                    y = 333.20,
                    z = 102.59
                }
            }
        }
    },
    robberyPayout = 500,
    handsUpDuration = 8000,
    robberyCooldown = 60000,
    safePayout = 2000,
    items = {
        water = 200,
        burger = 400
    }
}

--Car Breakdown (Veer)
Config.breakdown = {
    debug = false,              

    -- Trigger
    chance = 65,                
    breakDistanceMin = 150.0,    
    breakDistanceMax = 400.0,

    -- Breakdown
    sputterCount = 4,            

    -- Limp mode
    limpSpeedMph = 25.0,         
    limpPowerMultiplier = 0.5,   
    limpEngineHealth = 120.0,    
    stallIntervalMin = 20,       
    stallIntervalMax = 30,
    restartHoldTime = 2.0,       
    restartControl = 73,        
    restartControlName = 'INPUT_VEH_DUCK',   

    -- Extra engine smoke
    smokeAsset = 'core',
    smokeEffect = 'ent_amb_smoke_general',
    smokeScale = 1.5,            

    
    repairDistance = 1.8,                   
    skillHits = 3,                          
    skillZoneSizes = { 0.22, 0.15, 0.09 },   
    skillSpeed = 1.1,                        
    skillSpeedUp = 0.25,                    
    failCooldown = 3.0,                      
   
    wantedLevel = 5,                        

    
    ditchDistance = 50.0,                  
    ditchWarnDistance = 30.0,              
}

-- Weapon shop (Joao)
Config.weaponShop = {
    position = vector3(110.0450, -1949.8994, 20.6405),
    weapons = {
        ["Pistol"] = {
            weapon = "WEAPON_PISTOL",
            price = 500,
            ammo = 72
        },
        ["Micro SMG"] = {
            weapon = "WEAPON_MICROSMG",
            price = 1000,
            ammo = 180
        },
        ["Pump Shotgun"] = {
            weapon = "WEAPON_PUMPSHOTGUN",
            price = 1500,
            ammo = 48
        }
    }
}