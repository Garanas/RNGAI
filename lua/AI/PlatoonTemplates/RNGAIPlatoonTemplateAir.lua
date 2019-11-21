

-- Former Templates --

PlatoonTemplate {
    Name = 'RNGAI AntiAirHunt',
    Plan = 'AirHuntAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.ANTIAIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 3, 100, 'attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI T1AirScoutForm',
    Plan = 'ScoutingAIRNG',
    GlobalSquads = {
        { categories.AIR * categories.SCOUT * categories.TECH1, 1, 1, 'scout', 'None' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI AntiAir BaseGuard',
    Plan = 'GuardBase',
    GlobalSquads = {
        { categories.AIR * categories.MOBILE * categories.ANTIAIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 3, 50, 'attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI Bomber BaseGuard',
    Plan = 'GuardBase',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) - categories.BOMBER - categories.TRANSPORTFOCUS - categories.EXPERIMENTAL, 3, 50, 'attack', 'none' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI BomberAttack',
    Plan = 'StrikeForceAI',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER - categories.EXPERIMENTAL - categories.ANTINAVY, 1, 100, 'Attack', 'GrowthFormation' },
        #{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI GunShipAttack',
    Plan = 'StrikeForceAI',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.GROUNDATTACK - categories.EXPERIMENTAL - categories.ANTINAVY, 1, 100, 'Attack', 'GrowthFormation' },
        #{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Attack', 'GrowthFormation' },
    }
}

PlatoonTemplate {
    Name = 'RNGAI BomberEnergyAttack',
    Plan = 'StrikeForceAI',
    GlobalSquads = {
        { categories.MOBILE * categories.AIR * categories.BOMBER - categories.EXPERIMENTAL - categories.ANTINAVY, 1, 5, 'Attack', 'GrowthFormation' },
        #{ categories.MOBILE * categories.AIR * categories.ANTIAIR - categories.EXPERIMENTAL - categories.BOMBER - categories.TRANSPORTFOCUS, 0, 10, 'Attack', 'GrowthFormation' },
    }
}