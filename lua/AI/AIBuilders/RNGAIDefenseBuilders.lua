--[[
    File    :   /lua/AI/AIBuilders/RNGAIDefenceBuilders.lua
    Author  :   relentless
    Summary :
        Defence Builders, for thos pesky units that slip past. Like bombers.
]]
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()

local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local TBC = '/lua/editor/ThreatBuildConditions.lua'
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

local ActiveExpansion = function(self, aiBrain, builderManager)
    local activeExpansion = aiBrain.BrainIntel.ActiveExpansion
    --LOG('LocationType is '..builderManager.LocationType)
    if aiBrain.BrainIntel.ActiveExpansion == builderManager.LocationType then
        --LOG('Active Expansion is set'..builderManager.LocationType)
        --LOG('Active Expansion builders are set to 900')
        return 900
    else
        --LOG('Disable Air Intie Pool Builder')
        --LOG('My Air Threat '..myAirThreat..'Enemy Air Threat '..enemyAirThreat)
        return 0
    end
end



BuilderGroup {
    BuilderGroupName = 'RNGAI Base Defenses',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Engineer Restricted Breach Land',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.DEFENSE * categories.TECH1 * categories.DIRECTFIRE}},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/RNGAIT1PDTemplate.lua',
                BaseTemplate = 'T1PDTemplate',
                BuildClose = true,
                OrderedTemplate = true,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.DEFENSE * categories.TECH1 * categories.ANTIAIR}},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Land',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, categories.DEFENSE * categories.TECH2 * categories.DIRECTFIRE}},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * (categories.LAND + categories.NAVAL) - categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD),
            AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
            maxUnits = 1,
            maxRadius = 5,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, categories.DEFENSE * categories.TECH2 * categories.ANTIAIR}},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD),
            AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
            maxUnits = 1,
            maxRadius = 5,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T2AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer ACUClose Artillery',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 800,
        InstanceCount = 1,
        BuilderType = 'Any',
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { TBC, 'EnemyACUCloseToBase', {}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, categories.TECH2 * categories.ARTILLERY}},
        },
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD),
                AvoidCategory = categories.STRUCTURE * categories.ARTILLERY * categories.TECH2,
                maxUnits = 1,
                maxRadius = 35,
                BuildStructures = {
                    'T2Artillery',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T3 Defence Engineer Restricted Breach Air',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, categories.DEFENSE * categories.TECH3 * categories.ANTIAIR}},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD),
            AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
            maxUnits = 1,
            maxRadius = 5,
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T3AADefense',
                },
                AdjacencyCategory = categories.STRUCTURE * (categories.SHIELD + categories.FACTORY),
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer TMD',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 825,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 7, categories.DEFENSE * categories.TECH2 * categories.ANTIMISSILE}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 0.8}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = (categories.ENERGYPRODUCTION * categories.TECH3 + categories.TECH2) + (categories.STRUCTURE * categories.FACTORY),
                AvoidCategory = categories.STRUCTURE * categories.ANTIMISSILE * categories.TECH2 * categories.DEFENSE,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2TMLEngineer',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 825,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 600 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.TACTICALMISSILEPLATFORM}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 0.8}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.80}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                AdjacencyCategory = (categories.ENERGYPRODUCTION * categories.TECH3 + categories.TECH2),
                AvoidCategory = categories.STRUCTURE * categories.FACTORY,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T2StrategicMissile',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2TMLEngineer 3rd',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 625,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 720 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 5, categories.TACTICALMISSILEPLATFORM}},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, categories.TACTICALMISSILEPLATFORM } },
            { EBC, 'GreaterThanEconEfficiency', { 0.8, 0.8}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.60}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                AdjacencyCategory = (categories.ENERGYPRODUCTION * categories.TECH3 + categories.TECH2),
                AvoidCategory = categories.STRUCTURE * categories.FACTORY,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T2StrategicMissile',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2TMLEngineer Close Enemy',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 825,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'TMLEnemyStartRangeCheck', {} },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, categories.TACTICALMISSILEPLATFORM}},
            { EBC, 'GreaterThanEconEfficiency', { 0.7, 1.0}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.70}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                AdjacencyCategory = (categories.ENERGYPRODUCTION * categories.TECH3 + categories.TECH2),
                AvoidCategory = categories.STRUCTURE * categories.FACTORY,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T2StrategicMissile',
                },
                Location = 'LocationType',
            }
        }
    },
    
    Builder {
        BuilderName = 'RNGAI T3 Base D Engineer AA',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 12, categories.DEFENSE * categories.TECH3 * categories.ANTIAIR}},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH3 } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.1 }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80}},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 1,
            Construction = {
                BuildClose = true,
                maxUnits = 1,
                AdjacencyCategory = categories.STRUCTURE * (categories.SHIELD + categories.FACTORY),
                BuildStructures = {
                    'T3AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Reclaim Enemy Walls',
        PlatoonTemplate = 'EngineerBuilderRNG',
        PlatoonAIPlan = 'ReclaimUnitsAIRNG',
        Priority = 400,
        BuilderConditions = {
            { UCBC, 'HaveUnitsWithCategoryAndAlliance', { true, 10, categories.WALL, 'Enemy'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Radius = 1000,
            Categories = {categories.WALL},
            ThreatMin = -10,
            ThreatMax = 10000,
            ThreatRings = 1,
        },
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI Base Defenses Expansion',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Land Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.DEFENSE * categories.TECH1 * categories.DIRECTFIRE}},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.9 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 2,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/RNGAIT1PDTemplate.lua',
                BaseTemplate = 'T1PDTemplate',
                BuildClose = false,
                OrderedTemplate = true,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                    'Wall',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Air Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.DEFENSE * categories.TECH1 * categories.ANTIAIR}},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.AIR - categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                BuildStructures = {
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Sea Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.DEFENSE * categories.TECH1 * categories.NAVAL}},
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.NAVAL - categories.SCOUT }},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                AdjacencyCategory = categories.STRUCTURE * categories.FACTORY * categories.NAVAL,
                AvoidCategory = categories.STRUCTURE * categories.NAVAL * categories.DEFENSE,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Land Expansion',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * (categories.LAND + categories.NAVAL) - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, categories.DEFENSE * categories.TECH2 * categories.DIRECTFIRE}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD),
            AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
            maxUnits = 1,
            maxRadius = 5,
            Construction = {
                BuildClose = false,
                BuildStructures = {
                    'T2GroundDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer Restricted Breach Air Expansion',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 4, categories.DEFENSE * categories.TECH2 * categories.ANTIAIR}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD),
            AvoidCategory = categories.STRUCTURE * categories.FACTORY * categories.TECH2,
            maxUnits = 1,
            maxRadius = 5,
            Construction = {
                BuildClose = false,
                BuildStructures = {
                    'T2AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Expansion TML',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T2TMLEngineer Expansion',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 825,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 720 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 2, categories.TACTICALMISSILEPLATFORM}},
            { EBC, 'GreaterThanEconEfficiency', { 1.0, 1.0}},
            { UCBC, 'CheckUnitRange', { 'LocationType', 'T2StrategicMissile', categories.STRUCTURE + (categories.LAND * (categories.TECH2 + categories.TECH3)) } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BuildStructures = {
                    'T2StrategicMissile',
                },
                Location = 'LocationType',
            }
        }
    },
}


-- Defenses surrounding the base in patrol points

BuilderGroup {
    BuilderGroupName = 'RNGAI Perimeter Defenses Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Land - Perimeter',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.DEFENSE * categories.TECH1}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 40,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Sea - Perimeter',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.DEFENSE * categories.TECH1 * categories.NAVAL}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                BaseTemplate = 'ExpansionBaseTemplates',
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                LocationRadius = 250,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                ExpansionRadius = 120,
                BuildStructures = {
                    'T1AADefense',
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer - Perimeter',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 12, categories.DEFENSE * categories.TECH2}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, categories.DEFENSE * categories.TECH2 } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 45,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = true,
                BuildStructures = {
                    'T2AADefense',
                    'T2GroundDefense',
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Perimeter Defenses Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Land - Perimeter Large',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.DEFENSE * categories.TECH1}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 40,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer - Perimeter Large',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 12, categories.DEFENSE * categories.TECH2}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, categories.DEFENSE * categories.TECH2 } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 45,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                BuildStructures = {
                    'T2AADefense',
                    'T2GroundDefense',
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Perimeter Defenses Expansions',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Land - Perimeter Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.DEFENSE * categories.TECH1}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.07, 0.70}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 18,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                NearBasePatrolPoints = false,
                BuildStructures = {
                    'T1GroundDefense',
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Sea - Perimeter Expansion',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 650,
        InstanceCount = 2,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.DEFENSE * categories.TECH1 * categories.NAVAL}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                BaseTemplate = 'ExpansionBaseTemplates',
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                LocationRadius = 250,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                ExpansionRadius = 120,
                BuildStructures = {
                    'T1AADefense',
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Engineer - Perimeter Expansion',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 0,
        PriorityFunction = ActiveExpansion,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 12, categories.DEFENSE * categories.TECH2}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80}},
            { MIBC, 'GreaterThanGameTimeRNG', { 480 } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.8, 1.0 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, categories.DEFENSE * categories.TECH2 } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                NearPerimeterPoints = true,
                Radius = 14,
                BasePerimeterOrientation = 'FRONT',
                BasePerimeterSelection = true,
                BuildClose = false,
                BuildStructures = {
                    'T2AADefense',
                    'T2GroundDefense',
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI T12 Perimeter Defenses Naval',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Defence Sea - Perimeter Naval',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.DEFENSE * categories.TECH1 * categories.NAVAL}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.15, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                BaseTemplate = 'ExpansionBaseTemplates',
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                LocationRadius = 250,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                ExpansionRadius = 80,
                BuildStructures = {
                    'T1AADefense',
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Sea - Perimeter Naval',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 360 } },
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 3, categories.DEFENSE * categories.TECH1 * categories.NAVAL}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.20, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 1.0, 1.0 }},
            { UCBC, 'UnitCapCheckLess', { .6 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            NumAssistees = 2,
            Construction = {
                BuildClose = false,
                BaseTemplate = 'ExpansionBaseTemplates',
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                LocationRadius = 250,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                ExpansionRadius = 60,
                BuildStructures = {
                    'T2AADefense',
                    'T2NavalDefense',
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence Restricted Breach Sea',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.NAVAL - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, categories.DEFENSE * categories.TECH1 * categories.NAVAL}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.STRUCTURE * categories.FACTORY * categories.NAVAL,
                AvoidCategory = categories.STRUCTURE * categories.NAVAL * categories.DEFENSE,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T1NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Restricted Breach Sea',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.NAVAL - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, categories.DEFENSE * categories.TECH2 * categories.NAVAL}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = true,
                AdjacencyCategory = categories.STRUCTURE * categories.FACTORY * categories.NAVAL,
                AvoidCategory = categories.STRUCTURE * categories.NAVAL * categories.DEFENSE,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T2NavalDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T2 Defence Restricted Breach Cruisers',
        PlatoonTemplate = 'T23EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { UCBC, 'EnemyUnitsGreaterAtLocationRadius', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.NAVAL * categories.CRUISER * (categories.UEF + categories.SERAPHIM) - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocation', { 'LocationType', 6, categories.DEFENSE * categories.TECH2 * categories.ANTIMISSILE}},
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 5,
            Construction = {
                BuildClose = false,
                AdjacencyCategory = categories.STRUCTURE * categories.FACTORY * categories.NAVAL,
                AvoidCategory = categories.STRUCTURE * categories.NAVAL * categories.DEFENSE,
                maxUnits = 1,
                maxRadius = 5,
                BuildStructures = {
                    'T2MissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}
BuilderGroup {
    BuilderGroupName = 'RNGAI T2 Defense FormBuilders',
    BuildersType = 'PlatoonFormBuilder',
    Builder {
        BuilderName = 'RNGAI T2 TML Silo',
        PlatoonTemplate = 'AddToTMLPlatoonRNG',
        Priority = 1,
        InstanceCount = 1000,
        FormRadius = 100,
        BuilderConditions = {
            -- Have we the eco to build it ?
            -- When do we want to build this ?
            { UCBC, 'HaveGreaterThanArmyPoolWithCategory', { 0, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM * categories.TECH2 } },
        },
        BuilderData = {
            PlatoonPlan = 'TMLAIRNG',
            Location = 'LocationType'
        },
        BuilderType = 'Any',
    },
    --[[
    Builder {
        BuilderName = 'RNGAI T2 TML Silo',
        PlatoonTemplate = 'RNGAI T2 TML',
        Priority = 1,
        InstanceCount = 1000,
        FormRadius = 10000,
        BuilderType = 'Any',
    },]]
    
    Builder {
        BuilderName = 'RNGAI T2 Artillery',
        PlatoonTemplate = 'T2ArtilleryStructure',
        Priority = 1,
        InstanceCount = 1000,
        FormRadius = 10000,
        BuilderType = 'Any',
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI SMD Builders',                               
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI SMD 1st Main',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 800,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.ENERGYPRODUCTION * categories.TECH3 }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3 } },
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { EBC, 'GreaterThanEconTrendRNG', { 0.0, 0.0 } },                      -- relative income
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.10, 0.50 } },             -- Ratio from 0 to 1. (1=100%)
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                DesiresAssist = true,
                NumAssistees = 5,
                BuildClose = false,
                AdjacencyCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
                AdjacencyDistance = 80,
                AvoidCategory = categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3,
                maxUnits = 1,
                maxRadius = 20,
                BuildStructures = {
                    'T3StrategicMissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI SMD Response',
        PlatoonTemplate = 'T3EngineerBuilderRNG',
        Priority = 950,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'BuildOnlyOnLocation', { 'LocationType', 'MAIN' } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 4, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3 } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.7, 0.8 }},
            { UCBC, 'UnitsGreaterAtEnemy', { 2 , categories.STRUCTURE * categories.NUKE * categories.SILO } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                DesiresAssist = true,
                NumAssistees = 10,
                BuildClose = false,
                AdjacencyCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
                AdjacencyDistance = 80,
                AvoidCategory = categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3,
                maxUnits = 1,
                maxRadius = 20,
                BuildStructures = {
                    'T3StrategicMissileDefense',
                },
                Location = 'LocationType',
            }
        }
    },
}