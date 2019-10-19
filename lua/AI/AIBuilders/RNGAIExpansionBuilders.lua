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

BuilderGroup {
    BuilderGroupName = 'RNGAI Engineer Expansion Builders Small',
    BuildersType = 'EngineerBuilder',
    Builder {
        BuilderName = 'RNGAI T1 Vacant Expansion Area Engineer Small',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 500,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND } },
            { UCBC, 'ExpansionAreaNeedsEngineer', { 'LocationType', 350, -1000, 0, 2, 'StructuresNotMex' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },            
            { EBC, 'MassToFactoryRatioBaseCheck', { 'LocationType' } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Expansion Area',
                LocationRadius = 240, -- radius of platoon control
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 100,
                ThreatRings = 2,
                ThreatType = 'StructuresNotMex',
                BuildStructures = {                    
                    'T1LandFactory',
                    'T1GroundDefense',
                    'T1Radar',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Vacant Starting Area Engineer',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 900,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'StartLocationNeedsEngineer', { 'LocationType', 1000, -1000, 10, 2, 'StructuresNotMex' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            RequireTransport = true,
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Start Location',
                LocationRadius = 350, -- radius of platoon control
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'StructuresNotMex',
                BuildStructures = {                    
                    'T1LandFactory',
                    'T1GroundDefense',
                    'T1Radar',
                }
            },
            NeedGuard = true,
        }
    },
    Builder {
        BuilderName = 'RNGAI T1 Engineer Expansion Builders Combat',
        PlatoonTemplate = 'EngineerBuilder',
        Priority = 500,
        InstanceCount = 2,
        BuilderConditions = {
            { UCBC, 'PoolGreaterAtLocation', {'LocationType', 1, categories.ENGINEER - categories.COMMAND } }, -- Make sure there is an engie available
            { UCBC, 'StartLocationNeedsEngineer', { 'LocationType', 1000, -1000, 0, 2, 'StructuresNotMex' } },
            { UCBC, 'UnitCapCheckLess', { .8 } },
        },
        BuilderType = 'Any',
        BuilderData = {
            Construction = {
                BuildClose = false,
                BaseTemplate = ExBaseTmpl,
                ExpansionBase = true,
                NearMarkerType = 'Combat Zone',
                LocationRadius = 180, -- radius of platoon control
                LocationType = 'LocationType',
                ThreatMin = -1000,
                ThreatMax = 5,
                ThreatRings = 0,
                ThreatType = 'StructuresNotMex',
                BuildStructures = {                    
                    'T1GroundDefense',
                    'T1Radar',
                }
            },
            NeedGuard = true,
        }
    },
}