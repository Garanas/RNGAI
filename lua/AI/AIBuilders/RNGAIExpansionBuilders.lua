--[[
    File    :   /lua/AI/AIBuilders/RNGAIExpansionBuilders.lua
    Author  :   relentless
    Summary :
        Expansion Base Templates
]]

local ExBaseTmpl = 'ExpansionBaseTemplates'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'

local AggressiveExpansion = function(self, aiBrain, builderManager)
    if aiBrain.coinFlip == 1 then
        --LOG('Aggressive Expansion is true'..' coin flip is '..aiBrain.coinFlip)
        return 1000
    else
        --LOG('Aggressive Expansion is false '..' coin flip is '..aiBrain.coinFlip)
        return 0
    end
end

local NavalExpansionAdjust = function(self, aiBrain, builderManager)
    if aiBrain.MapWaterRatio < 0.20 and not aiBrain.MassMarkersInWater then
        --LOG('NavalExpansionAdjust return 0')
        return 0
    elseif aiBrain.MapWaterRatio < 0.30 then
        --LOG('NavalExpansionAdjust return 200')
        return 200
    elseif aiBrain.MapWaterRatio < 0.40 then
        --LOG('NavalExpansionAdjust return 400')
        return 400
    elseif aiBrain.MapWaterRatio < 0.60 then
        --LOG('NavalExpansionAdjust return 650')
        return 675
    else
        --LOG('NavalExpansionAdjust return 750')
        return 875
    end
end

local FrigateRaid = function(self, aiBrain, builderManager)
    -- Will return the rush naval build if it can raid mexes
    if aiBrain.EnemyIntel.FrigateRaid then
        return 995
    end
    return 0
end

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Expansion Builders Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Vacant Expansion Area 350 Small',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'ExpansionAreaNeedsEngineer', { 'LocationType', 350, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },            
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Expansion Area',
                ExpansionRadius = 50, -- Defines the radius of the builder managers to avoid them intruding on another base if the expansion marker is too close
                LocationRadius = 350,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 2,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    --[[Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area 250 Small First',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 760,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 250, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                ExpansionRadius = 60,
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },]]
    Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area 250 Small',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 760,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 250, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                ExpansionRadius = 60,
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Large Expansion Area 250 Small',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'LargeExpansionNeedsEngineerRNG', { 'LocationType', 250, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Large Expansion Area',
                ExpansionRadius = 60,
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Naval Expansion Area 250 Small',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 650,
        PriorityFunction = NavalExpansionAdjust,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'NavalBaseLimitRNG', { 2 } }, -- Forces limit to the number of naval expansions
            { UCBC, 'ExistingNavalExpansionFactoryGreaterRNG', { 'Naval Area', 3,  categories.FACTORY * categories.STRUCTURE }},
            { UCBC, 'NavalAreaNeedsEngineerRNG', { 'LocationType', 250, -1000, 100, 1, 'AntiSurface' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                ExpansionRadius = 70,
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1SeaFactory',
                }
            },
            NeedGuard = false,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Naval Expansion Area FrigateRaid',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 0,
        PriorityFunction = FrigateRaid,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'NavalBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL } },
            { UCBC, 'NavalAreaNeedsEngineerRNG', { 'LocationType', 250, -1000, 100, 1, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                ExpansionRadius = 70,
                LocationRadius = 250, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1SeaFactory',
                }
            },
            NeedGuard = false,
        }
    },
    --[[
    Builder {
        BuilderName = 'RNGAI T1 Unmarked Expansion Area 1000 Small',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'UnmarkedExpansionNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Unmarked Expansion',
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },]]
    Builder {
        BuilderName = 'RNGAI T1 Large Expansion Area 1000 Small',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 650,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'LargeExpansionNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Large Expansion Area',
                ExpansionRadius = 60,
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area 1000 Small',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                ExpansionRadius = 60,
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Expansion Builders Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Naval Expansion Area 650 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        PriorityFunction = NavalExpansionAdjust,
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'NavalBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'NavalBaseLimitRNG', { 3 } }, -- Forces limit to the number of naval expansions
            { UCBC, 'NavalAreaNeedsEngineerRNG', { 'LocationType', 650, -1000, 100, 1, 'AntiSurface' } },
            { UCBC, 'ExistingNavalExpansionFactoryGreaterRNG', { 'Naval Area', 3, categories.FACTORY * categories.STRUCTURE }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                ExpansionRadius = 60,
                LocationRadius = 650, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1SeaFactory',
                    'T1NavalDefense',
                }
            },
            NeedGuard = false,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Naval Expansion Area FrigateRaid',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 0,
        PriorityFunction = FrigateRaid,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'NavalBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'NavalBaseLimitRNG', { 3 } }, -- Forces limit to the number of naval expansions
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.FACTORY * categories.NAVAL } },
            { UCBC, 'NavalAreaNeedsEngineerRNG', { 'LocationType', 650, -1000, 100, 1, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Naval Area',
                ExpansionRadius = 70,
                LocationRadius = 650, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 1,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1SeaFactory',
                }
            },
            NeedGuard = false,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Aggressive Expansion 250 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 0,
        PriorityFunction = AggressiveExpansion,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'LessThanGameTimeSecondsRNG', { 600 } },
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 0, categories.FACTORY * categories.AIR}},

            { MIBC, 'CanBuildAggressivebaseRNG', { 'LocationType', 250, -1000, 5, 1, 'AntiSurface'} },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                AggressiveExpansion = true, -- This is picked up so that a modified firebase function runs to pick the expansion closest to the enemy
                NearMarkerType = 'Aggressive',
                EnemyRange = 250,
                --NearMarkerType = true, -- This is so the engineerbuildai will still pick up the expansion bool, the aggressive base check uses 3 types of expansion markers.
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                    'T1LandFactory',
                }
            },
            NeedGuard = false,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant StartArea Area 500 Large First',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 900,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'LessThanOneLandExpansion', { } },
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 500, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },            
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                ExpansionRadius = 60, -- Defines the radius of the builder managers to avoid them intruding on another base if the expansion marker is too close
                LocationRadius = 500,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 2,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Expansion Area 350 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'ExpansionAreaNeedsEngineer', { 'LocationType', 350, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },            
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Expansion Area',
                ExpansionRadius = 50, -- Defines the radius of the builder managers to avoid them intruding on another base if the expansion marker is too close
                LocationRadius = 350,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 2,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Expansion Area 1000 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 500,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'ExpansionAreaNeedsEngineer', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },            
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.1}},
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Expansion Area',
                ExpansionRadius = 50, -- Defines the radius of the builder managers to avoid them intruding on another base if the expansion marker is too close
                LocationRadius = 1000,
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 2,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area 500 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 800,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 500, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                ExpansionRadius = 60,
                LocationRadius = 500, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Large Expansion Area 500 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 600,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'LargeExpansionNeedsEngineerRNG', { 'LocationType', 500, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Large Expansion Area',
                ExpansionRadius = 60,
                LocationRadius = 500, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = false,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area 800 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 750,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 800, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                ExpansionRadius = 60,
                LocationRadius = 800, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area 2000 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 700,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'StartLocationNeedsEngineerRNG', { 'LocationType', 2000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                ExpansionRadius = 60,
                LocationRadius = 2000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Large Expansion Area 1000 Large',
        PlatoonTemplate = 'EngineerBuilderT12RNG',
        Priority = 500,
        InstanceCount = 1,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'LargeExpansionNeedsEngineerRNG', { 'LocationType', 1000, -1000, 0, 2, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Large Expansion Area',
                ExpansionRadius = 60,
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = false,
        }
    },
    --[[
    Builder {
        BuilderName = 'RNGAI T1 Unmarked Expansion Area 1000 Large',
        PlatoonTemplate = 'EngineerBuilderRNG',
        Priority = 600,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'ExpansionBaseCheck', { } }, -- related to ScenarioInfo.Options.LandExpansionsAllowed
            { UCBC, 'UnmarkedExpansionNeedsEngineerRNG', { 'LocationType', 1000, -1000, 10, 1, 'AntiSurface' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Unmarked Expansion',
                LocationRadius = 1000, -- radius from LocationType to build
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 10,
                ThreatRings = 0,
                ThreatType = 'AntiSurface',
                BuildStructures = {                    
                    'T1LandFactory',
                }
            },
            NeedGuard = true,
        }
    },]]
}