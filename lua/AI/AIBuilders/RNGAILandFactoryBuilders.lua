local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

local LandMode = function(self, aiBrain, builderManager, builderData)
    --RNGLOG('Setting T1 Queue to Eng')
    if builderData.TechLevel == 1 then
        return 745
    elseif builderData.TechLevel == 2 then
        return 750
    elseif builderData.TechLevel == 3 then
        return 755
    end
    return 0
end

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T1',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Scout',
        PlatoonTemplate = 'T1LandScout',
        Priority = 755,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'scout'} },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Tank',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 748,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land', true}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'tank'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Artillery',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 747,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land', true}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'arty'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 AA',
        PlatoonTemplate = 'T1LandAA',
        Priority = 742,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'aa'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T2',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T2 Tank',
        PlatoonTemplate = 'T2LandDFTank',
        Priority = 750,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'tank'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Bot',
        PlatoonTemplate = 'RNGAIT2AttackBot',
        Priority = 749,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'bot'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 AA',
        PlatoonTemplate = 'T2LandAA',
        Priority = 746,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'aa'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Shield',
        PlatoonTemplate = 'T2MobileShields',
        Priority = 747,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'shield'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 MML',
        PlatoonTemplate = 'T2LandArtillery',
        Priority = 748,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'mml'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
    Builder {
        BuilderName = 'RNGAI T2 Mobile Stealth',
        PlatoonTemplate = 'RNGAIT2MobileStealth',
        Priority = 746,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T2', 'stealth'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 2
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T3',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T3 Tank',
        PlatoonTemplate = 'T3LandBot',
        Priority = 755,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'tank'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Armoured',
        PlatoonTemplate = 'T3ArmoredAssault',
        Priority = 755,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'armoured'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 AA',
        PlatoonTemplate = 'T3LandAA',
        Priority = 752,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'aa'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Artillery',
        PlatoonTemplate = 'T3LandArtillery',
        Priority = 753,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'arty'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Shields',
        PlatoonTemplate = 'T3MobileShields',
        Priority = 751,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'shield'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Sniper',
        PlatoonTemplate = 'T3SniperBots',
        Priority = 754,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'sniper'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
    Builder {
        BuilderName = 'RNGAI T3 Mobile Missile',
        PlatoonTemplate = 'T3MobileMissile',
        Priority = 754,
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T3', 'mml'} },

            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 3
        },
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI LandBuilder T1 Islands',
    BuildersType = 'FactoryBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Scout Islands',
        PlatoonTemplate = 'T1LandScout',
        Priority = 744,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'scout'} },
        },
        BuilderType = 'Land',
    },
    Builder {
        BuilderName = 'RNGAI T1 Tank Islands',
        PlatoonTemplate = 'T1LandDFTank',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 2 }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.20}},
            --{ UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'tank'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
    Builder {
        BuilderName = 'RNGAI T1 Artillery Islands',
        PlatoonTemplate = 'T1LandArtillery',
        Priority = 500,
        BuilderConditions = {
            { MIBC, 'FactionIndex', { 4 }},
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', false } },
            { EBC, 'FactorySpendRatioRNG', {'Land'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.20}},
            --{ UCBC, 'ArmyManagerBuild', { 'Land', 'T1', 'arty'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Land',
        BuilderData = {
            TechLevel = 1
        },
    },
}

