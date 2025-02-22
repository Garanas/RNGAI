--[[
    File    :   /lua/AI/AIBaseTemplates/RNGAIEconomicBuilders.lua
    Author  :   relentless
    Summary :
        Economic Builders
]]

local SAI = '/lua/ScenarioPlatoonAI.lua'
local IBC = '/lua/editor/InstantBuildConditions.lua'
local UCBC = '/lua/editor/UnitCountBuildConditions.lua'
local EBC = '/lua/editor/EconomyBuildConditions.lua'
local MIBC = '/lua/editor/MiscBuildConditions.lua'
local MABC = '/lua/editor/MarkerBuildConditions.lua'
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()

local NavalAdjust = function(self, aiBrain, builderManager)
    local pathCount = 0
    if aiBrain.EnemyIntel.ChokePoints then
        for _, v in aiBrain.EnemyIntel.ChokePoints do
            if not v.NoPath then
                pathCount = pathCount + 1
            end
        end
    end
    if pathCount > 0 then
        --LOG('We have a path to an enemy')
        return 1005
    else
        --LOG('No path to an enemy')
        return 1010
    end
end


BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 0M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 0 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 1M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 1 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 2M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 2 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 3M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 3 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 4M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 4 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Small Close 5+M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 5 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                MexThreat = true,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Prebuilt Land Standard Small Close',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'PreBuiltBase', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                MaxDistance = 30,
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI Initial ACU Builder Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large 0M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 0 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large 1M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 1 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large 2M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 2 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large 3M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 3 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large 4M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 4 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Land Standard Large Close 5+M',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'NotPreBuilt', {}},
            { MIBC, 'NumCloseMassMarkers', { 5 }}
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                MexThreat = true,
                BaseTemplateFile = '/mods/rngai/lua/AI/AIBuilders/ACUBaseTemplate.lua',
                BaseTemplate = 'ACUBaseTemplate',
                MaxDistance = 30,
                BuildStructures = {
                    'T1LandFactory',
                    'T1EnergyProduction',
                    'T1Resource',
                    'T1Resource',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Initial Prebuilt Land Standard Large',
        PlatoonAddBehaviors = {'CommanderBehaviorRNG', 'ACUDetection'},
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 2000,
        PriorityFunction = function(self, aiBrain)
			return 0, false
		end,
        BuilderConditions = {
            { IBC, 'PreBuiltBase', {}},
        },
        InstantCheck = true,
        BuilderType = 'Any',
        BuilderData = {
            ScanWait = 40,
            Construction = {
                MaxDistance = 30,
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Structure Builders',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1005,
        DelayEqualBuildPlattons = {'Factories', 5},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.LAND * (categories.TECH1 + categories.TECH2 + categories.TECH3) }},
            { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 0.5, 5.0}},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Land Factory Higher Pri'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.05}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Lower Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 750,
        DelayEqualBuildPlattons = {'Factories', 5},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.30, 'FACTORY'}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Higher Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1005,
        DelayEqualBuildPlattons = {'Factories', 5},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 0.7, 8.0}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.4, 0.30}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 1, categories.FACTORY * categories.AIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) }},
            { UCBC, 'IsEngineerNotBuilding', { categories.FACTORY * categories.AIR * categories.TECH1 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                AdjacencyPriority = {
                    categories.HYDROCARBON,
                    categories.ENERGYPRODUCTION * categories.STRUCTURE,
                },
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Lower Pri',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 750,
        DelayEqualBuildPlattons = {'Factories', 5},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Air Factory Lower Pri'}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.80}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 1.0 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) }},
            { UCBC, 'IsEngineerNotBuilding', {categories.FACTORY * categories.AIR * categories.TECH1}},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU Mass 30',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1005,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 30, nil, nil, 0, 'AntiSurface', 1}},
            { EBC, 'LessThanEconEfficiencyRNG', { 0.8, 2.0 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = false,
                MexThreat = true,
                Type = 'Mass',
                MaxDistance = 30,
                MinDistance = 0,
                ThreatMin = -500,
                ThreatMax = 20,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Trend',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 0.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.ENERGYPRODUCTION - categories.HYDROCARBON } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH2 }},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Power Trend'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Scale',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyEfficiencyOverTimeRNG', { 1.3 } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.85, 0.1 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.ENERGYPRODUCTION - categories.HYDROCARBON } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH1,
                maxUnits = 1,
                maxRadius = 3,
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T2 Power Engineer Negative Trend',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CmdrHasUpgrade', { 'AdvancedEngineering', true }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T3 Power Engineer Negative Trend',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CmdrHasUpgrade', { 'T3Engineering', true }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Land',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE}},
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
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
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Air',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 900,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE}},
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, 'DEFENSE' } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Structure Builders Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Higher Pri Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1005,
        DelayEqualBuildPlattons = {'Factories', 5},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 0.5, 5.0}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.05, 0.30}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 3, categories.FACTORY * categories.LAND * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.TECH1 * categories.ENERGYPRODUCTION } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Land Factory Lower Pri Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Factories', 5},
        BuilderConditions = {
            { MIBC, 'CanPathToCurrentEnemyRNG', { 'LocationType', true } },
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.06, 0.80, 'FACTORY'}}, -- Ratio from 0 to 1. (1=100%)
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 1.0 }},
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Land' } },
            { EBC, 'MassToFactoryRatioBaseCheckRNG', { 'LocationType' } },
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 6, categories.FACTORY * categories.LAND * (categories.TECH2 + categories.TECH3) }},
         },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                Location = 'LocationType',
                BuildClose = false,
                BuildStructures = {
                    'T1LandFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T1 Air Factory Higher Pri Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 1005,
        PriorityFunction = NavalAdjust,
        DelayEqualBuildPlattons = {'Factories', 5},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Factories' }},
            { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 0.5, 5.0}},
            { EBC, 'GreaterThanEconStorageRatioRNG', { 0.04, 0.20}},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.8 }},
            { UCBC, 'FactoryLessAtLocationRNG', { 'LocationType', 2, categories.FACTORY * categories.AIR * ( categories.TECH1 + categories.TECH2 + categories.TECH3 ) }},
            { UCBC, 'HaveGreaterThanUnitsWithCategory', { 2, categories.TECH1 * categories.ENERGYPRODUCTION } },
            { UCBC, 'FactoryCapCheck', { 'LocationType', 'Air' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AirFactory',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU Mass 30 Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        BuilderConditions = { 
            { MABC, 'CanBuildOnMassDistanceRNG', { 'LocationType', 0, 30, nil, nil, 0, 'AntiSurface', 1}},
        },
        BuilderType = 'Any',
        BuilderData = {
            NeedGuard = false,
            DesiresAssist = false,
            Construction = {
                RepeatBuild = false,
                MexThreat = true,
                Type = 'Mass',
                MaxDistance = 30,
                MinDistance = 0,
                ThreatMin = -500,
                ThreatMax = 20,
                ThreatType = 'AntiSurface',
                BuildStructures = {
                    'T1Resource',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Trend Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 0.0 } }, -- If our energy is trending into negatives
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 3, categories.ENERGYPRODUCTION - categories.HYDROCARBON } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * categories.TECH2 }},
            --{ UCBC, 'IsAcuBuilder', {'RNGAI ACU T1 Power Trend'}},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                BuildStructures = {
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {    	
        BuilderName = 'RNGAI ACU T1 Power Scale Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 800,
        DelayEqualBuildPlattons = {'Energy', 3},
        BuilderConditions = {
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyEfficiencyOverTimeRNG', { 1.3 } },
            { EBC, 'GreaterThanEconEfficiencyOverTimeRNG', { 0.85, 0.1 }},
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.ENERGYPRODUCTION - categories.HYDROCARBON } },
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }}, -- Don't build after 1 T3 Pgen Exist
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = false,
            Construction = {
                AdjacencyCategory = categories.FACTORY * categories.STRUCTURE * (categories.AIR + categories.LAND),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH1,
                maxUnits = 1,
                maxRadius = 3,
                BuildStructures = {
                    'T1EnergyProduction',
                    'T1EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T2 Power Engineer Negative Trend Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CmdrHasUpgrade', { 'AdvancedEngineering', true }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH2,
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    'T2EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI ACU T3 Power Engineer Negative Trend Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 850,
        InstanceCount = 1,
        DelayEqualBuildPlattons = {'Energy', 9},
        BuilderConditions = {
            { UCBC, 'CmdrHasUpgrade', { 'T3Engineering', true }},
            { UCBC, 'CheckBuildPlatoonDelayRNG', { 'Energy' }},
            { EBC, 'LessThanEnergyTrendOverTimeRNG', { 0.0 } },
            { UCBC, 'HaveLessThanUnitsInCategoryBeingBuiltRNG', { 2, categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3) }},
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.1 }},
        },
        BuilderType = 'Any',
        BuilderData = {
            DesiresAssist = true,
            NumAssistees = 10,
            Construction = {
                AdjacencyCategory = (categories.STRUCTURE * categories.SHIELD) + (categories.FACTORY * (categories.TECH3 + categories.TECH2 + categories.TECH1)),
                AvoidCategory = categories.ENERGYPRODUCTION * categories.TECH3,
                maxUnits = 1,
                maxRadius = 10,
                BuildStructures = {
                    'T3EnergyProduction',
                },
            }
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Land Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.LAND - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE}},
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, categories.DEFENSE } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
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
        BuilderName = 'RNGAI T1 Defence ACU Restricted Breach Air Large',
        PlatoonTemplate = 'CommanderBuilderRNG',
        Priority = 950,
        BuilderConditions = {
            { UCBC, 'EnemyUnitsGreaterAtLocationRadiusRNG', {  BaseRestrictedArea, 'LocationType', 0, categories.MOBILE * categories.AIR - categories.SCOUT }},
            { UCBC, 'UnitsLessAtLocationRNG', { 'LocationType', 4, categories.DEFENSE}},
            { MIBC, 'GreaterThanGameTimeRNG', { 300 } },
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.7, 0.8 }},
            { UCBC, 'LocationEngineersBuildingLess', { 'LocationType', 1, categories.DEFENSE } },
            { UCBC, 'UnitCapCheckLess', { .9 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = true,
                BuildStructures = {
                    'T1AADefense',
                },
                Location = 'LocationType',
            }
        }
    },
}

BuilderGroup {
    BuilderGroupName = 'RNGAI ACU Build Assist',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Engineer',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 850,
        DelayEqualBuildPlattons = {'ACUAssist', 3},
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.8, 0.3}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = categories.ENGINEER,
                AssistRange = 30,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {categories.ENERGYPRODUCTION, categories.FACTORY, categories.STRUCTURE * categories.DEFENSE},
                Time = 45,
            },
        }
    },
    Builder {
        BuilderName = 'RNGAI CDR Assist Assist Hydro',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 860,
        BuilderConditions = {
            { UCBC, 'HaveGreaterThanUnitsInCategoryBeingBuiltAtLocationRadiusRNG', { 'LocationType', 0,60, categories.STRUCTURE * categories.HYDROCARBON, }},
            { UCBC, 'HaveLessThanUnitsWithCategory', { 1, categories.STRUCTURE * categories.HYDROCARBON }},
            { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 0.5, 0.0}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssistLocation = 'LocationType',
                AssisteeType = categories.STRUCTURE,
                AssistRange = 60,
                BeingBuiltCategories = {categories.STRUCTURE * categories.HYDROCARBON},
                AssistUntilFinished = true,
                Time = 0,
            },
        }
    },
    
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Factory',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.9, 0.9}},
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = categories.FACTORY,
                AssistRange = 30,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {categories.ALLUNITS},
                Time = 20,
            },
        }
    },
    --[[
    Builder {
        BuilderName = 'RNGAI CDR Assist T1 Structure',
        PlatoonTemplate = 'CommanderAssistRNG',
        Priority = 700,
        BuilderConditions = {
            { EBC, 'GreaterThanEconEfficiencyRNG', { 0.6, 0.6} },
        },
        BuilderType = 'Any',
        BuilderData = {
            Assist = {
                AssisteeType = categories.STRUCTURE',
                AssistRange = 60,
                AssistLocation = 'LocationType',
                BeingBuiltCategories = {categories.ENERGYPRODUCTION, categories.FACTORY, categories.STRUCTURE * categories.DEFENSE},
                Time = 30,
            },
        }
    },]]
}
--[[
BuilderGroup { 
    BuilderGroupName = 'RNGAI ACU Enhancements Gun',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'UEF CDR Enhancement HeavyAntiMatter',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 1.2, 65.0}},
                { UCBC, 'CmdrHasUpgrade', { 'HeavyAntiMatterCannon', false }},
                { MIBC, 'FactionIndex', {1}},
            },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'HeavyAntiMatterCannon' },
        },

    },
    Builder {
        BuilderName = 'Aeon CDR Enhancement Crysalis',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 1.2, 65.0}},
                { UCBC, 'CmdrHasUpgrade', { 'CrysalisBeam', false }},
                { MIBC, 'FactionIndex', {2}},
            },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            TimeBetweenEnhancements = 20,
            Enhancement = { 'HeatSink', 'CrysalisBeam'},
        },
    },
    Builder {
        BuilderName = 'Cybran CDR Enhancement CoolingUpgrade',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 1.2, 65.0}},
                { UCBC, 'CmdrHasUpgrade', { 'CoolingUpgrade', false }},
                { MIBC, 'FactionIndex', {3}},
            },
        BuilderType = 'Any',
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderData = {
            Enhancement = { 'CoolingUpgrade'},
        },

    },
    Builder {
        BuilderName = 'Seraphim CDR Enhancement RateOfFire',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'IsIsland', { false } },
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 4, 'FACTORY' }},
                { UCBC, 'HaveGreaterThanUnitsWithCategory', { 6, 'MASSEXTRACTION' }},
                { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 1.2, 65.0}},
                { UCBC, 'CmdrHasUpgrade', { 'RateOfFire', false }},
                { MIBC, 'FactionIndex', {4}},
            },
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderType = 'Any',
        BuilderData = {
            Enhancement = { 'RateOfFire' },
        },

    },
}

BuilderGroup { 
    BuilderGroupName = 'RNGAI ACU Enhancements Tier',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'CDR Enhancement AdvancedEngineering Mid Game',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { MIBC, 'GreaterThanGameTimeRNG', { 1500 } },
                { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
                { UCBC, 'CmdrHasUpgrade', { 'AdvancedEngineering', false }},
                { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 1.2, 120.0}},
                --{ MIBC, 'FactionIndex', {4}},
            },
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderType = 'Any',
        BuilderData = {
            Enhancement = { 'AdvancedEngineering' },
        },
    },
}
BuilderGroup { 
    BuilderGroupName = 'RNGAI ACU Enhancements Tier Large',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'CDR Enhancement AdvancedEngineering Mid Game Large',
        PlatoonTemplate = 'CommanderEnhance',
        Priority = 900,
        BuilderConditions = {
                { EBC, 'GreaterThanEnergyTrendRNG', { 0.0 } },
                { UCBC, 'CmdrHasUpgrade', { 'AdvancedEngineering', false }},
                { EBC, 'GreaterThanEconIncomeOverTimeRNG',  { 1.2, 120.0}},
                --{ MIBC, 'FactionIndex', {4}},
            },
        PlatoonAddFunctions = { {SAI, 'BuildOnce'}, },
        BuilderType = 'Any',
        BuilderData = {
            Enhancement = { 'AdvancedEngineering' },
        },
    },
}]]