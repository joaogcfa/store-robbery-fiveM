store_data = {
    model = "s_m_m_autoshop_01",
    x = -705.4786,
    y = -913.8461,
    z = 18.2156,
    r = 75.8789
}

liquorShop_data = {
    model = "s_m_m_autoshop_01",
    x = 1133.9285,
    y = -982.3583,
    z = 46.4158,
    r = 268.9130
}

market_data = {
    model = "s_m_m_autoshop_01",
    x = 372.3670,
    y = 326.4533,
    z = 103.5664,
    r = 258.8167
}

Config = {
    robberyPayout = 500, -- money given to the player per robbery
    handsUpDuration = 8000, -- ms the clerk keeps hands up / register is "open"
    robberyCooldown = 60000, -- ms before the same clerk can be robbed again
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

    -- Repair (skill check at the bonnet)
    repairDistance = 1.8,                    
    skillHits = 3,                           
    skillZoneSizes = { 0.22, 0.15, 0.09 },   
    skillSpeed = 1.1,                        
    skillSpeedUp = 0.25,                    
    failCooldown = 3.0,                     

    -- After the repair
    wantedLevel = 5,                         

    -- No switching cars 
    ditchDistance = 50.0,                    
    ditchWarnDistance = 30.0,                
}