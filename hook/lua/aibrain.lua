WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibrain.lua' )

local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local DebugArrayRNG = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').DebugArrayRNG
local AIUtils = import('/lua/ai/AIUtilities.lua')
local AIBehaviors = import('/lua/ai/AIBehaviors.lua')
local PlatoonGenerateSafePathToRNG = import('/lua/AI/aiattackutilities.lua').PlatoonGenerateSafePathToRNG

local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local GiveResource = moho.aibrain_methods.GiveResource
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetThreatsAroundPosition = moho.aibrain_methods.GetThreatsAroundPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetConsumptionPerSecondMass = moho.unit_methods.GetConsumptionPerSecondMass
local GetConsumptionPerSecondEnergy = moho.unit_methods.GetConsumptionPerSecondEnergy
local GetProductionPerSecondMass = moho.unit_methods.GetProductionPerSecondMass
local GetProductionPerSecondEnergy = moho.unit_methods.GetProductionPerSecondEnergy
local VDist2Sq = VDist2Sq
local WaitTicks = coroutine.yield
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local RNGINSERT = table.insert
local RNGGETN = table.getn

local RNGAIBrainClass = AIBrain
AIBrain = Class(RNGAIBrainClass) {

    OnCreateAI = function(self, planName)
        RNGAIBrainClass.OnCreateAI(self, planName)
        local per = ScenarioInfo.ArmySetup[self.Name].AIPersonality
        --LOG('Oncreate')
        if string.find(per, 'RNG') then
            --LOG('* AI-RNG: This is RNG')
            self.RNG = true
        end
    end,

    OnSpawnPreBuiltUnits = function(self)
        if not self.RNG then
            return RNGAIBrainClass.OnSpawnPreBuiltUnits(self)
        end
        local factionIndex = self:GetFactionIndex()
        local resourceStructures = nil
        local initialUnits = nil
        local posX, posY = self:GetArmyStartPos()

        if factionIndex == 1 then
            resourceStructures = {'UEB1103', 'UEB1103', 'UEB1103', 'UEB1103'}
            initialUnits = {'UEB0101', 'UEB1101', 'UEB1101', 'UEB1101', 'UEB1101'}
        elseif factionIndex == 2 then
            resourceStructures = {'UAB1103', 'UAB1103', 'UAB1103', 'UAB1103'}
            initialUnits = {'UAB0101', 'UAB1101', 'UAB1101', 'UAB1101', 'UAB1101'}
        elseif factionIndex == 3 then
            resourceStructures = {'URB1103', 'URB1103', 'URB1103', 'URB1103'}
            initialUnits = {'URB0101', 'URB1101', 'URB1101', 'URB1101', 'URB1101'}
        elseif factionIndex == 4 then
            resourceStructures = {'XSB1103', 'XSB1103', 'XSB1103', 'XSB1103'}
            initialUnits = {'XSB0101', 'XSB1101', 'XSB1101', 'XSB1101', 'XSB1101'}
        end

        if resourceStructures then
            -- Place resource structures down
            for k, v in resourceStructures do
                local unit = self:CreateResourceBuildingNearest(v, posX, posY)
                local unitBp = unit:GetBlueprint()
                if unit ~= nil and unitBp.Physics.FlattenSkirt then
                    unit:CreateTarmac(true, true, true, false, false)
                end
                if unit ~= nil then
                    if not self.StructurePool then
                        RUtils.CheckCustomPlatoons(self)
                    end
                    local StructurePool = self.StructurePool
                    self:AssignUnitsToPlatoon(StructurePool, {unit}, 'Support', 'none' )
                    local upgradeID = unitBp.General.UpgradesTo or false
                    --LOG('* AI-RNG: BlueprintID to upgrade to is : '..unitBp.General.UpgradesTo)
                    if upgradeID and __blueprints[upgradeID] then
                        RUtils.StructureUpgradeInitialize(unit, self)
                    end
                    local unitTable = StructurePool:GetPlatoonUnits()
                    --LOG('* AI-RNG: StructurePool now has :'..RNGGETN(unitTable))
                end
            end
        end

        if initialUnits then
            -- Place initial units down
            for k, v in initialUnits do
                local unit = self:CreateUnitNearSpot(v, posX, posY)
                if unit ~= nil and unit:GetBlueprint().Physics.FlattenSkirt then
                    unit:CreateTarmac(true, true, true, false, false)
                end
            end
        end

        self.PreBuilt = true
    end,

    InitializeSkirmishSystems = function(self)
        if not self.RNG then
            return RNGAIBrainClass.InitializeSkirmishSystems(self)
        end
        --LOG('* AI-RNG: Custom Skirmish System for '..ScenarioInfo.ArmySetup[self.Name].AIPersonality)
        -- Make sure we don't do anything for the human player!!!
        if self.BrainType == 'Human' then
            return
        end

        -- TURNING OFF AI POOL PLATOON, I MAY JUST REMOVE THAT PLATOON FUNCTIONALITY LATER
        local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
        if poolPlatoon then
            poolPlatoon:TurnOffPoolAI()
        end
        --local mapSizeX, mapSizeZ = GetMapSize()
        --LOG('Map X size is : '..mapSizeX..'Map Z size is : '..mapSizeZ)
        -- Stores handles to all builders for quick iteration and updates to all
        self.BuilderHandles = {}

        self.MapSize = 10
        local mapSizeX, mapSizeZ = GetMapSize()
        if  mapSizeX > 1000 and mapSizeZ > 1000 then
            self.DefaultLandRatio = 0.5
            self.DefaultAirRatio = 0.4
            self.DefaultNavalRatio = 0.4
            self.MapSize = 20
        elseif mapSizeX > 500 and mapSizeZ > 500 then
            self.DefaultLandRatio = 0.6
            self.DefaultAirRatio = 0.4
            self.DefaultNavalRatio = 0.4
            --LOG('10 KM Map Check true')
            self.MapSize = 10
        elseif mapSizeX > 200 and mapSizeZ > 200 then
            self.DefaultLandRatio = 0.7
            self.DefaultAirRatio = 0.3
            self.DefaultNavalRatio = 0.3
            --LOG('5 KM Map Check true')
            self.MapSize = 5
        end
        self.MapCenterPoint = { (ScenarioInfo.size[1] / 2), 0 ,(ScenarioInfo.size[2] / 2) }

        -- Condition monitor for the whole brain
        self.ConditionsMonitor = BrainConditionsMonitor.CreateConditionsMonitor(self)

        -- Economy monitor for new skirmish - stores out econ over time to get trend over 10 seconds
        self.EconomyData = {}
        self.GraphZones = { 
            FirstRun = true,
            HasRun = false
        }
        self.EconomyTicksMonitor = 80
        self.EconomyCurrentTick = 1
        self.EconomyMonitorThread = self:ForkThread(self.EconomyMonitorRNG)
        self.EconomyOverTimeCurrent = {}
        --self.EconomyOverTimeThread = self:ForkThread(self.EconomyOverTimeRNG)
        self.EngineerAssistManagerActive = false
        self.EngineerAssistManagerEngineerCount = 0
        self.EngineerAssistManagerEngineerCountDesired = 0
        self.EngineerAssistManagerBuildPowerDesired = 5
        self.EngineerAssistManagerBuildPowerRequired = 0
        self.EngineerAssistManagerBuildPower = 0
        self.EngineerAssistManagerPriorityTable = {}
        self.ProductionRatios = {
            Land = self.DefaultLandRatio,
            Air = self.DefaultAirRatio,
            Naval = self.DefaultNavalRatio,
        }
        self.cmanager = {
            income = {
                r  = {
                    m = 0,
                    e = 0,
                },
                t = {
                    m = 0,
                    e = 0,
                },
            },
            spend = {
                m = 0,
                e = 0,
            },
            categoryspend = {
                eng = 0,
                fact = {
                    Land = 0,
                    Air = 0,
                    Naval = 0
                },
                silo = 0,
                mex = {
                      T1 = 0,
                      T2 = 0,
                      T3 = 0
                      },
            },
            storage = {
                current = {
                    m = 0,
                    e = 0,
                },
                max = {
                    m = 0,
                    e = 0,
                },
            },
        }
        self.amanager = {
            Current = {
                Land = {
                    T1 = {
                        scout=0,
                        tank=0,
                        arty=0,
                        aa=0
                    },
                    T2 = {
                        tank=0,
                        mml=0,
                        aa=0,
                        shield=0,
                        stealth=0,
                        bot=0
                    },
                    T3 = {
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0,
                        armoured=0
                    }
                },
                Air = {
                    T1 = {
                        scout=0,
                        interceptor=0,
                        bomber=0,
                        gunship=0
                    },
                    T2 = {
                        bomber=0,
                        gunship=0,
                        fighter=0,
                        mercy=0,
                        torpedo=0,
                    },
                    T3 = {
                        scout=0,
                        asf=0,
                        bomber=0,
                        gunship=0,
                        torpedo=0,
                        transport=0
                    }
                },
                Naval = {
                    T1 = {
                        frigate=0,
                        sub=0,
                        shard=0
                    },
                    T2 = {
                        tank=0,
                        mml=0,
                        aa=0,
                        shield=0
                    },
                    T3 = {
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0
                    }
                },
            },
            Total = {
                Land = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                },
                Air = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                },
                Naval = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                }
            },
            Type = {
                Land = {
                    scout=0,
                    tank=0,
                    sniper=0,
                    arty=0,
                    mml=0,
                    aa=0,
                    shield=0,
                    bot=0,
                    armoured=0
                },
                Air = {
                    scout=0,
                    interceptor=0,
                    bomber=0,
                    gunship=0,
                    fighter=0,
                    mercy=0,
                    torpedo=0,
                    asf=0,
                    transport=0,
                },
                Naval = {
                    frigate=0,
                    sub=0,
                    cruiser=0,
                    destroyer=0,
                    battleship=0,
                    shard=0,
                    shield=0
                },
            },
            Ratios = {
                [1] = {
                    Land = {
                        T1 = {
                            scout=15,
                            tank=65,
                            arty=15,
                            aa=12,
                            total=0
                        },
                        T2 = {
                            tank=55,
                            mml=5,
                            bot=20,
                            aa=10,
                            shield=10,
                            total=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=20,
                            interceptor=60,
                            bomber=20,
                            total=0
                        },
                        T2 = {
                            bomber=70,
                            gunship=30,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=55,
                            bomber=15,
                            gunship=10,
                            transport=5,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [2] = {
                    Land = {
                        T1 = {
                            scout=15,
                            tank=65,
                            arty=15,
                            aa=12,
                            total=0
                        },
                        T2 = {
                            tank=75,
                            mml=5,
                            aa=10,
                            shield=10,
                            total=0
                        },
                        T3 = {
                            tank=45,
                            arty=15,
                            aa=10,
                            sniper=30,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=20,
                            interceptor=60,
                            bomber=20,
                            total=0
                        },
                        T2 = {
                            fighter=85,
                            gunship=15,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=60,
                            bomber=15,
                            gunship=10,
                            torpedo=0,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            shard= 0,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [3] = {
                    Land = {
                        T1 = {
                            scout=15,
                            tank=65,
                            arty=15,
                            aa=12,
                            total=0
                        },
                        T2 = {
                            tank=55,
                            mml=5,
                            bot=25,
                            aa=10,
                            stealth=5,
                            total=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            arty=15,
                            aa=10,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=15,
                            interceptor=55,
                            bomber=20,
                            gunship=10,
                            total=0
                        },
                        T2 = {
                            bomber=85,
                            gunship=15,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=60,
                            bomber=15,
                            gunship=10,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [4] = {
                    Land = {
                        T1 = {
                            scout=15,
                            tank=65,
                            arty=15,
                            aa=12,
                            total=0
                        },
                        T2 = {
                            tank=75,
                            mml=10,
                            aa=15,
                            total=0
                        },
                        T3 = {
                            tank=45,
                            arty=10,
                            aa=10,
                            sniper=30,
                            shield=5,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=20,
                            interceptor=60,
                            bomber=20,
                            total=0
                        },
                        T2 = {
                            bomber=75,
                            gunship=15,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=65,
                            bomber=15,
                            torpedo=0,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [5] = {
                    Land = {
                        T1 = {
                            scout=15,
                            tank=65,
                            arty=15,
                            aa=12,
                            total=0
                        },
                        T2 = {
                            tank=55,
                            mml=5,
                            bot=20,
                            aa=10,
                            shield=10,
                            total=0
                        },
                        T3 = {
                            tank=30,
                            armoured=40,
                            mml=5,
                            arty=15,
                            aa=10,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=15,
                            interceptor=60,
                            bomber=25,
                            total=0
                        },
                        T2 = {
                            bomber=75,
                            gunship=15,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=55,
                            bomber=15,
                            gunship=10,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=15,
                            sub=60,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=55,
                            bomber=15,
                            gunship=10,
                            transport=5,
                            total=0
                        }
                    },
                },
            },
        }
        self.smanager = {
            fact = {
                Land =
                {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0
                },
                Air = {
                    T1=0,
                    T2=0,
                    T3=0
                },
                Naval= {
                    T1=0,
                    T2=0,
                    T3=0
                }
            },
            mex = {
                T1=0,
                T2=0,
                T3=0
            },
            pgen = {
                T1=0,
                T2=0,
                T3=0
            },
            silo = {
                T2=0,
                T3=0
            },
            fabs= {
                T2=0,
                T3=0
            }
        }

        self.LowEnergyMode = false
        self.EcoManager = {
            EcoManagerTime = 30,
            EcoManagerStatus = 'ACTIVE',
            ExtractorUpgradeLimit = {
                TECH1 = 1,
                TECH2 = 1
            },
            ExtractorsUpgrading = {TECH1 = 0, TECH2 = 0},
            EcoMultiplier = 1,
        }
        self.EcoManager.PowerPriorityTable = {
            ENGINEER = 12,
            STATIONPODS = 11,
            TML = 10,
            SHIELD = 8,
            AIR = 9,
            NAVAL = 5,
            RADAR = 3,
            MASSEXTRACTION = 4,
            MASSFABRICATION = 7,
            NUKE = 6,
            LAND = 2,
        }
        self.EcoManager.MassPriorityTable = {
            Advantage = {
                MASSEXTRACTION = 5,
                TML = 12,
                STATIONPODS = 10,
                ENGINEER = 11,
                AIR = 7,
                NAVAL = 8,
                LAND = 6,
                NUKE = 9,
                },
            Disadvantage = {
                MASSEXTRACTION = 8,
                TML = 12,
                STATIONPODS = 10,
                ENGINEER = 11,
                AIR = 6,
                NAVAL = 7,
                NUKE = 9,
            }
        }

        self.DefensiveSupport = {}

        --Tactical Monitor
        self.TacticalMonitor = {
            TacticalMonitorStatus = 'ACTIVE',
            TacticalLocationFound = false,
            TacticalLocations = {},
            TacticalTimeout = 37,
            TacticalMonitorTime = 180,
            TacticalMassLocations = {},
            TacticalUnmarkedMassGroups = {},
            TacticalSACUMode = false,
        }
        -- Intel Data
        self.EnemyIntel = {}
        self.EnemyIntel.NavalRange = {
            Position = {},
            Range = 0,
        }
        self.EnemyIntel.FrigateRaid = false
        self.EnemyIntel.FrigateRaidMarkers = {}
        self.EnemyIntel.EnemyCount = 0
        self.EnemyIntel.ACUEnemyClose = false
        self.EnemyIntel.ACU = {}
        self.EnemyIntel.DirectorData = {
            Strategic = {},
            Energy = {},
            Intel = {},
            Defense = {},
            Mass = {},
            Factory = {},
            Combat = {},
        }
        --LOG('Director Data'..repr(self.EnemyIntel.DirectorData))
        --LOG('Director Energy Table '..repr(self.EnemyIntel.DirectorData.Energy))
        self.EnemyIntel.EnemyStartLocations = {}
        self.EnemyIntel.EnemyThreatLocations = {}
        self.EnemyIntel.EnemyThreatRaw = {}
        self.EnemyIntel.ChokeFlag = false
        self.EnemyIntel.EnemyLandFireBaseDetected = false
        self.EnemyIntel.EnemyAirFireBaseDetected = false
        self.EnemyIntel.ChokePoints = {}
        self.EnemyIntel.EnemyThreatCurrent = {
            Air = 0,
            AntiAir = 0,
            Land = 0,
            Experimental = 0,
            Extractor = 0,
            ExtractorCount = 0,
            Naval = 0,
            NavalSub = 0,
            DefenseAir = 0,
            DefenseSurface = 0,
            DefenseSub = 0,
            ACUGunUpgrades = 0,
        }
        for _, v in ArmyBrains do
            self.EnemyIntel.ACU[v:GetArmyIndex()] = {
                Position = {},
                LastSpotted = 0,
                Threat = 0,
                Hp = 0,
                OnField = false,
                Gun = false,
            }
            self.EnemyIntel.DirectorData[v:GetArmyIndex()] = {
                Strategic = {},
                Energy = {},
                Mass = {},
                Factory = {},
                Combat = {},
            }
        end

        self.BrainIntel = {}
        self.BrainIntel.ExpansionWatchTable = {}
        self.BrainIntel.IMAPConfig = {
            OgridRadius = 0,
            IMAPSize = 0,
            ResolveBlocks = 0,
            ThresholdMult = 0,
            Rings = 0,
        }
        self.BrainIntel.AllyCount = 0
        self.BrainIntel.MassMarker = 0
        self.BrainIntel.AirAttackMode = false
        self.BrainIntel.SelfThreat = {}
        self.BrainIntel.Average = {
            Air = 0,
            Land = 0,
            Experimental = 0,
        }
        self.BrainIntel.SelfThreat = {
            Air = {},
            Extractor = 0,
            ExtractorCount = 0,
            MassMarker = 0,
            MassMarkerBuildable = 0,
            AllyExtractorCount = 0,
            AllyExtractor = 0,
            AllyLandThreat = 0,
            BaseThreatCaution = false,
            AntiAirNow = 0,
            AirNow = 0,
            LandNow = 0,
            NavalNow = 0,
            NavalSubNow = 0,
        }
        self.BrainIntel.ActiveExpansion = false
        -- Structure Upgrade properties
        self.UpgradeIssued = 0
        self.EarlyQueueCompleted = false
        
        self.UpgradeIssuedPeriod = 100

        if mapSizeX < 1000 and mapSizeZ < 1000  then
            self.UpgradeIssuedLimit = 1
            self.EcoManager.ExtractorUpgradeLimit.TECH1 = 1
        else
            self.UpgradeIssuedLimit = 2
            self.EcoManager.ExtractorUpgradeLimit.TECH1 = 2
        end

        self.MapWaterRatio = self:GetMapWaterRatio()
        --LOG('Water Ratio is '..self.MapWaterRatio)

        -- Table to holding the starting reclaim
        self.StartReclaimTable = {}
        self.StartReclaimTaken = false

        self.UpgradeMode = 'Normal'

        -- ACU Support Data
        self.ACUSupport = {}
        self.ACUMaxSearchRadius = 0
        self.ACUSupport.Supported = false
        self.ACUSupport.PlatoonCount = 0
        self.ACUSupport.Position = {}
        self.ACUSupport.TargetPosition = false
        self.ACUSupport.ReturnHome = true

        -- Misc
        self.ReclaimEnabled = true
        self.ReclaimLastCheck = 0
        
        -- Add default main location and setup the builder managers
        self.NumBases = 0 -- AddBuilderManagers will increase the number

        self.BuilderManagers = {}
        SUtils.AddCustomUnitSupport(self)
        self:AddBuilderManagers(self:GetStartVector3f(), 100, 'MAIN', false)

        if RUtils.InitialMassMarkersInWater(self) then
            --LOG('* AI-RNG: Map has mass markers in water')
            self.MassMarkersInWater = true
        else
            --LOG('* AI-RNG: Map does not have mass markers in water')
            self.MassMarkersInWater = false
        end

        --[[ Below was used prior to Uveso adding the expansion generator to provide expansion in locations with multiple mass markers
        RUtils.TacticalMassLocations(self)
        RUtils.MarkTacticalMassLocations(self)
        local MassGroupMarkers = RUtils.GenerateMassGroupMarkerLocations(self)
        if MassGroupMarkers then
            if RNGGETN(MassGroupMarkers) > 0 then
                RUtils.CreateMarkers('Unmarked Expansion', MassGroupMarkers)
            end
        end]]
        
        self:IMAPConfigurationRNG()
        -- Begin the base monitor process

        self:BaseMonitorInitializationRNG()
        --LOG(repr(Scenario))

        local plat = self:GetPlatoonUniquelyNamed('ArmyPool')
        plat:ForkThread(plat.BaseManagersDistressAIRNG)
        --local perlocations, orient, positionsel = RUtils.GetBasePerimeterPoints(self, 'MAIN', 50, 'FRONT', false, 'Land', true)
        --LOG('Perimeter Points '..repr(perlocations))
        --LOG('Orient is '..orient)
        self.DeadBaseThread = self:ForkThread(self.DeadBaseMonitor)
        self.EnemyPickerThread = self:ForkThread(self.PickEnemyRNG)
        self:ForkThread(self.EcoExtractorUpgradeCheckRNG)
        self:ForkThread(self.EcoPowerManagerRNG)
        self:ForkThread(self.EcoMassManagerRNG)
        self:ForkThread(self.EnemyChokePointTestRNG)
        self:ForkThread(self.EngineerAssistManagerBrainRNG)
        self:ForkThread(self.AllyEconomyHelpThread)
        self:ForkThread(self.HeavyEconomyRNG)
        self:ForkThread(self.FactoryEcoManagerRNG)
        self:ForkThread(RUtils.CountSoonMassSpotsRNG)
        self:ForkThread(RUtils.DisplayMarkerAdjacency)
        self:CalculateMassMarkersRNG()
        RUtils.InitialNavalAttackCheck(self)
        self:ForkThread(RUtils.AIConfigureExpansionWatchTableRNG)
        -- This is future goodies.
        
        self:ForkThread(self.ExpansionIntelScanRNG)
        --self:ForkThread(RUtils.MexUpgradeManagerRNG)
    end,

    EconomyMonitorRNG = function(self)
        -- This over time thread is based on Sprouto's LOUD AI.
        self.EconomyData = { ['EnergyIncome'] = {}, ['EnergyRequested'] = {}, ['EnergyStorage'] = {}, ['EnergyTrend'] = {}, ['MassIncome'] = {}, ['MassRequested'] = {}, ['MassStorage'] = {}, ['MassTrend'] = {}, ['Period'] = 300 }
        -- number of sample points
        -- local point
        local samplerate = 10
        local samples = self.EconomyData['Period'] / samplerate
    
        -- create the table to store the samples
        for point = 1, samples do
            self.EconomyData['EnergyIncome'][point] = 0
            self.EconomyData['EnergyRequested'][point] = 0
            self.EconomyData['EnergyStorage'][point] = 0
            self.EconomyData['EnergyTrend'][point] = 0
            self.EconomyData['MassIncome'][point] = 0
            self.EconomyData['MassRequested'][point] = 0
            self.EconomyData['MassStorage'][point] = 0
            self.EconomyData['MassTrend'][point] = 0
        end    
    
        local RNGMIN = math.min
        local RNGMAX = math.max
        local WaitTicks = coroutine.yield
    
        -- array totals
        local eIncome = 0
        local mIncome = 0
        local eRequested = 0
        local mRequested = 0
        local eStorage = 0
        local mStorage = 0
        local eTrend = 0
        local mTrend = 0
    
        -- this will be used to multiply the totals
        -- to arrive at the averages
        local samplefactor = 1/samples
    
        local EcoData = self.EconomyData
    
        local EcoDataEnergyIncome = EcoData['EnergyIncome']
        local EcoDataMassIncome = EcoData['MassIncome']
        local EcoDataEnergyRequested = EcoData['EnergyRequested']
        local EcoDataMassRequested = EcoData['MassRequested']
        local EcoDataEnergyTrend = EcoData['EnergyTrend']
        local EcoDataMassTrend = EcoData['MassTrend']
        local EcoDataEnergyStorage = EcoData['EnergyStorage']
        local EcoDataMassStorage = EcoData['MassStorage']
        
        local e,m
    
        while true do
    
            for point = 1, samples do
    
                -- remove this point from the totals
                eIncome = eIncome - EcoDataEnergyIncome[point]
                mIncome = mIncome - EcoDataMassIncome[point]
                eRequested = eRequested - EcoDataEnergyRequested[point]
                mRequested = mRequested - EcoDataMassRequested[point]
                eTrend = eTrend - EcoDataEnergyTrend[point]
                mTrend = mTrend - EcoDataMassTrend[point]
                
                -- insert the new data --
                EcoDataEnergyIncome[point] = GetEconomyIncome( self, 'ENERGY')
                EcoDataMassIncome[point] = GetEconomyIncome( self, 'MASS')
                EcoDataEnergyRequested[point] = GetEconomyRequested( self, 'ENERGY')
                EcoDataMassRequested[point] = GetEconomyRequested( self, 'MASS')
    
                e = GetEconomyTrend( self, 'ENERGY')
                m = GetEconomyTrend( self, 'MASS')
    
                if e then
                    EcoDataEnergyTrend[point] = e
                else
                    EcoDataEnergyTrend[point] = 0.1
                end
                
                if m then
                    EcoDataMassTrend[point] = m
                else
                    EcoDataMassTrend[point] = 0.1
                end
    
                -- add the new data to totals
                eIncome = eIncome + EcoDataEnergyIncome[point]
                mIncome = mIncome + EcoDataMassIncome[point]
                eRequested = eRequested + EcoDataEnergyRequested[point]
                mRequested = mRequested + EcoDataMassRequested[point]
                eTrend = eTrend + EcoDataEnergyTrend[point]
                mTrend = mTrend + EcoDataMassTrend[point]
                
                -- calculate new OverTime values --
                self.EconomyOverTimeCurrent.EnergyIncome = eIncome * samplefactor
                self.EconomyOverTimeCurrent.MassIncome = mIncome * samplefactor
                self.EconomyOverTimeCurrent.EnergyRequested = eRequested * samplefactor
                self.EconomyOverTimeCurrent.MassRequested = mRequested * samplefactor
                self.EconomyOverTimeCurrent.EnergyEfficiencyOverTime = RNGMIN( (eIncome * samplefactor) / (eRequested * samplefactor), 2)
                self.EconomyOverTimeCurrent.MassEfficiencyOverTime = RNGMIN( (mIncome * samplefactor) / (mRequested * samplefactor), 2)
                self.EconomyOverTimeCurrent.EnergyTrendOverTime = eTrend * samplefactor
                self.EconomyOverTimeCurrent.MassTrendOverTime = mTrend * samplefactor
                
                WaitTicks(samplerate)
            end
        end
    end,
    
    CalculateMassMarkersRNG = function(self)
        local MassMarker = {}
        local massMarkerBuildable = 0
        local markerCount = 0
        local graphCheck = false
        for _, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
            if v.type == 'Mass' then
                if v.position[1] <= 8 or v.position[1] >= ScenarioInfo.size[1] - 8 or v.position[3] <= 8 or v.position[3] >= ScenarioInfo.size[2] - 8 then
                    -- mass marker is too close to border, skip it.
                    continue
                end 
                if v.RNGArea and not self.GraphZones.FirstRun and not self.GraphZones.HasRun then
                    graphCheck = true
                    if not self.GraphZones[v.RNGArea] then
                        self.GraphZones[v.RNGArea] = {}
                        if self.GraphZones[v.RNGArea].MassMarkersInZone == nil then
                            self.GraphZones[v.RNGArea].MassMarkersInZone = 0
                        end
                    end
                    self.GraphZones[v.RNGArea].MassMarkersInZone = self.GraphZones[v.RNGArea].MassMarkersInZone + 1
                end
                if CanBuildStructureAt(self, 'ueb1103', v.position) then
                    massMarkerBuildable = massMarkerBuildable + 1
                end
                markerCount = markerCount + 1
                RNGINSERT(MassMarker, v)
            end
        end
        if graphCheck then
            self.GraphZones.HasRun = true
        end
        self.BrainIntel.SelfThreat.MassMarker = markerCount
        self.BrainIntel.SelfThreat.MassMarkerBuildable = massMarkerBuildable
        --LOG('self.BrainIntel.SelfThreat.MassMarker '..self.BrainIntel.SelfThreat.MassMarker)
        --LOG('self.BrainIntel.SelfThreat.MassMarkerBuildable '..self.BrainIntel.SelfThreat.MassMarkerBuildable)
    end,

    BaseMonitorThreadRNG = function(self)
        while true do
            if self.BaseMonitor.BaseMonitorStatus == 'ACTIVE' then
                self:BaseMonitorCheckRNG()
            end
            WaitSeconds(self.BaseMonitor.BaseMonitorTime)
        end
    end,

    BaseMonitorInitializationRNG = function(self, spec)
        self.BaseMonitor = {
            BaseMonitorStatus = 'ACTIVE',
            BaseMonitorPoints = {},
            AlertSounded = false,
            AlertsTable = {},
            AlertLocation = false,
            AlertSoundedThreat = 0,
            ActiveAlerts = 0,

            PoolDistressRange = 75,
            PoolReactionTime = 7,

            -- Variables for checking a radius for enemy units
            UnitRadiusThreshold = spec.UnitRadiusThreshold or 3,
            UnitCategoryCheck = spec.UnitCategoryCheck or (categories.MOBILE - (categories.SCOUT + categories.ENGINEER)),
            UnitCheckRadius = spec.UnitCheckRadius or 40,

            -- Threat level must be greater than this number to sound a base alert
            AlertLevel = spec.AlertLevel or 0,
            -- Delay time for checking base
            BaseMonitorTime = spec.BaseMonitorTime or 11,
            -- Default distance a platoon will travel to help around the base
            DefaultDistressRange = spec.DefaultDistressRange or 75,
            -- Default how often platoons will check if the base is under duress
            PlatoonDefaultReactionTime = spec.PlatoonDefaultReactionTime or 5,
            -- Default duration for an alert to time out
            DefaultAlertTimeout = spec.DefaultAlertTimeout or 10,

            PoolDistressThreshold = 1,

            -- Monitor platoons for help
            PlatoonDistressTable = {},
            PlatoonDistressThread = false,
            PlatoonAlertSounded = false,
        }
        self:ForkThread(self.BaseMonitorThreadRNG)
        self:ForkThread(self.TacticalMonitorInitializationRNG)
        self:ForkThread(self.TacticalAnalysisThreadRNG)
    end,

    GetStructureVectorsRNG = function(self)
        local structures = GetListOfUnits(self, categories.STRUCTURE - categories.WALL - categories.MASSEXTRACTION, false)
        -- Add all points around location
        local tempGridPoints = {}
        local indexChecker = {}

        for k, v in structures do
            if not v.Dead then
                local pos = AIUtils.GetUnitBaseStructureVector(v)
                if pos then
                    if not indexChecker[pos[1]] then
                        indexChecker[pos[1]] = {}
                    end
                    if not indexChecker[pos[1]][pos[3]] then
                        indexChecker[pos[1]][pos[3]] = true
                        RNGINSERT(tempGridPoints, pos)
                    end
                end
            end
        end

        return tempGridPoints
    end,

    BaseMonitorCheckRNG = function(self)
        
        local gameTime = GetGameTimeSeconds()
        if gameTime < 300 then
            -- default monitor spec
        elseif gameTime > 300 then
            self.BaseMonitor.PoolDistressRange = 130
            self.AlertLevel = 5
        end

        local vecs = self:GetStructureVectorsRNG()
        if RNGGETN(vecs) > 0 then
            -- Find new points to monitor
            for k, v in vecs do
                local found = false
                for subk, subv in self.BaseMonitor.BaseMonitorPoints do
                    if v[1] == subv.Position[1] and v[3] == subv.Position[3] then
                        found = true
                        -- if we found this point already stored, we don't need to continue searching the rest
                        break
                    end
                end
                if not found then
                    RNGINSERT(self.BaseMonitor.BaseMonitorPoints,
                        {
                            Position = v,
                            Threat = GetThreatAtPosition(self, v, 0, true, 'Land'),
                            Alert = false
                        }
                    )
                end
            end
            --LOG('BaseMonitorPoints Threat Data '..repr(self.BaseMonitor.BaseMonitorPoints))
            -- Remove any points that we dont monitor anymore
            for k, v in self.BaseMonitor.BaseMonitorPoints do
                local found = false
                for subk, subv in vecs do
                    if v.Position[1] == subv[1] and v.Position[3] == subv[3] then
                        found = true
                        break
                    end
                end
                -- If point not in list and the num units around the point is small
                if not found and self:GetNumUnitsAroundPoint(categories.STRUCTURE, v.Position, 16, 'Ally') <= 1 then
                    table.remove(self.BaseMonitor.BaseMonitorPoints, k)
                end
            end
            -- Check monitor points for change
            local alertThreat = self.BaseMonitor.AlertLevel
            for k, v in self.BaseMonitor.BaseMonitorPoints do
                if not v.Alert then
                    v.Threat = GetThreatAtPosition(self, v.Position, 0, true, 'Land')
                    if v.Threat > alertThreat then
                        v.Alert = true
                        RNGINSERT(self.BaseMonitor.AlertsTable,
                            {
                                Position = v.Position,
                                Threat = v.Threat,
                            }
                        )
                        self.BaseMonitor.AlertSounded = true
                        self:ForkThread(self.BaseMonitorAlertTimeout, v.Position)
                        self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts + 1
                    end
                end
            end
        end
    end,

    BuildScoutLocationsRNG = function(self)
        local aiBrain = self
        local opponentStarts = {}
        local startLocations = {}
        local startPosMarkers = {}
        local allyStarts = {}
        

        if not aiBrain.InterestList then
            aiBrain.InterestList = {}
            aiBrain.IntelData.HiPriScouts = 0
            aiBrain.IntelData.AirHiPriScouts = 0
            aiBrain.IntelData.AirLowPriScouts = 0
            

            -- Add each enemy's start location to the InterestList as a new sub table
            aiBrain.InterestList.HighPriority = {}
            aiBrain.InterestList.LowPriority = {}
            aiBrain.InterestList.MustScout = {}

            local myArmy = ScenarioInfo.ArmySetup[self.Name]
            if aiBrain.BrainIntel.ExpansionWatchTable then
                for _, v in aiBrain.BrainIntel.ExpansionWatchTable do
                    -- Add any expansion table locations to the must scout table
                    --LOG('Expansion of type '..v.Type..' found, seeting scout location')
                    RNGINSERT(aiBrain.InterestList.MustScout, 
                        {
                            Position = v.Position,
                            LastScouted = 0,
                        }
                    )
                end
            end
            if ScenarioInfo.Options.TeamSpawn == 'fixed' then
                -- Spawn locations were fixed. We know exactly where our opponents are.
                -- Don't scout areas owned by us or our allies.
                local numOpponents = 0
                local enemyStarts = {}
                for i = 1, 16 do
                    local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
                    local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
                    if army and startPos then
                        RNGINSERT(startLocations, startPos)
                        if army.ArmyIndex ~= myArmy.ArmyIndex and (army.Team ~= myArmy.Team or army.Team == 1) then
                        -- Add the army start location to the list of interesting spots.
                        opponentStarts['ARMY_' .. i] = startPos
                        numOpponents = numOpponents + 1
                        RNGINSERT(enemyStarts, startPos)
                        RNGINSERT(aiBrain.InterestList.HighPriority,
                            {
                                Position = startPos,
                                LastScouted = 0,
                            }
                        )
                        else
                            allyStarts['ARMY_' .. i] = startPos
                        end
                    end
                end

                aiBrain.NumOpponents = numOpponents

                -- For each vacant starting location, check if it is closer to allied or enemy start locations (within 100 ogrids)
                -- If it is closer to enemy territory, flag it as high priority to scout.
                local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
                for _, loc in starts do
                    -- If vacant
                    if not opponentStarts[loc.Name] and not allyStarts[loc.Name] then
                        local closestDistSq = 999999999
                        local closeToEnemy = false

                        for _, pos in opponentStarts do
                            local distSq = VDist2Sq(pos[1], pos[3], loc.Position[1], loc.Position[3])
                            -- Make sure to scout for bases that are near equidistant by giving the enemies 100 ogrids
                            if distSq-10000 < closestDistSq then
                                closestDistSq = distSq-10000
                                closeToEnemy = true
                            end
                        end

                        for _, pos in allyStarts do
                            local distSq = VDist2Sq(pos[1], pos[3], loc.Position[1], loc.Position[3])
                            if distSq < closestDistSq then
                                closestDistSq = distSq
                                closeToEnemy = false
                                break
                            end
                        end

                        if closeToEnemy then
                            RNGINSERT(aiBrain.InterestList.LowPriority,
                                {
                                    Position = loc.Position,
                                    LastScouted = 0,
                                }
                            )
                        end
                    end
                end
                aiBrain.EnemyIntel.EnemyStartLocations = enemyStarts
            else -- Spawn locations were random. We don't know where our opponents are. Add all non-ally start locations to the scout list
                local numOpponents = 0
                for i = 1, 16 do
                    local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
                    local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
                    if army and startPos then
                        if army.ArmyIndex == myArmy.ArmyIndex or (army.Team == myArmy.Team and army.Team ~= 1) then
                            allyStarts['ARMY_' .. i] = startPos
                        else
                            numOpponents = numOpponents + 1
                        end
                    end
                end

                aiBrain.NumOpponents = numOpponents

                -- If the start location is not ours or an ally's, it is suspicious
                local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
                for _, loc in starts do
                    -- If vacant
                    if not allyStarts[loc.Name] then
                        RNGINSERT(aiBrain.InterestList.LowPriority,
                            {
                                Position = loc.Position,
                                LastScouted = 0,
                            }
                        )
                        RNGINSERT(startLocations, loc.Position)
                    end
                end
                -- Set Start Locations for brain to reference
                --LOG('Start Locations are '..repr(startLocations))
                aiBrain.EnemyIntel.EnemyStartLocations = startLocations
            end
            
            
            --LOG('* AI-RNG: EnemyStartLocations : '..repr(aiBrain.EnemyIntel.EnemyStartLocations))
            local massLocations = RUtils.AIGetMassMarkerLocations(aiBrain, true)
        
            for _, start in startLocations do
                markersStartPos = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Mass', start, 30)
                for _, marker in markersStartPos do
                    --LOG('* AI-RNG: Start Mass Marker ..'..repr(marker))
                    RNGINSERT(startPosMarkers, marker)
                end
            end
            for k, massMarker in massLocations do
                for c, startMarker in startPosMarkers do
                    if massMarker.Position == startMarker.Position then
                        --LOG('* AI-RNG: Removing Mass Marker Position : '..repr(massMarker.Position))
                        table.remove(massLocations, k)
                    end
                end
            end
            for k, massMarker in massLocations do
                --LOG('* AI-RNG: Inserting Mass Marker Position : '..repr(massMarker.Position))
                RNGINSERT(aiBrain.InterestList.LowPriority,
                        {
                            Position = massMarker.Position,
                            LastScouted = 0,
                        }
                    )
            end
            aiBrain:ForkThread(self.ParseIntelThreadRNG)
        end
    end,

    UnderEnergyThreshold = function(self)
        if not self.RNG then
            return RNGAIBrainClass.UnderEnergyThreshold(self)
        end
    end,

    OverEnergyThreshold = function(self)
        if not self.RNG then
            return RNGAIBrainClass.OverEnergyThreshold(self)
        end
    end,

    UnderMassThreshold = function(self)
        if not self.RNG then
            return RNGAIBrainClass.UnderMassThreshold(self)
        end
    end,

    OverMassThreshold = function(self)
        if not self.RNG then
            return RNGAIBrainClass.OverMassThreshold(self)
        end
    end,

    PickEnemyRNG = function(self)
        while true do
            self:PickEnemyLogicRNG()
            WaitTicks(1200)
        end
    end,

    PickEnemyLogicRNG = function(self)
        local armyStrengthTable = {}
        local selfIndex = self:GetArmyIndex()
        local enemyBrains = {}
        local allyCount = 0
        local enemyCount = 0
        local MainPos = self.BuilderManagers.MAIN.Position
        for _, v in ArmyBrains do
            local insertTable = {
                Enemy = true,
                Strength = 0,
                Position = false,
                Distance = false,
                EconomicThreat = 0,
                ACUPosition = {},
                ACULastSpotted = 0,
                Brain = v,
            }
            -- Share resources with friends but don't regard their strength
            if ArmyIsCivilian(v:GetArmyIndex()) then
                continue
            elseif IsAlly(selfIndex, v:GetArmyIndex()) then
                self:SetResourceSharing(true)
                allyCount = allyCount + 1
                insertTable.Enemy = false
            elseif not IsEnemy(selfIndex, v:GetArmyIndex()) then
                insertTable.Enemy = false
            end
            if insertTable.Enemy == true then
                enemyCount = enemyCount + 1
                RNGINSERT(enemyBrains, v)
            end
            local acuPos = {}
            -- Gather economy information of army to guage economy value of the target
            local enemyIndex = v:GetArmyIndex()
            local startX, startZ = v:GetArmyStartPos()
            local ecoThreat = 0

            if insertTable.Enemy == false then
                local ecoStructures = GetUnitsAroundPoint(self, categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSPRODUCTION), {startX, 0 ,startZ}, 120, 'Ally')
                local GetBlueprint = moho.entity_methods.GetBlueprint
                for _, v in ecoStructures do
                    local bp = v:GetBlueprint()
                    local ecoStructThreat = bp.Defense.EconomyThreatLevel
                    --LOG('* AI-RNG: Eco Structure'..ecoStructThreat)
                    ecoThreat = ecoThreat + ecoStructThreat
                end
            else
                ecoThreat = 1
            end
            -- Doesn't exist yet!!. Check if the ACU's last position is known.
            --LOG('* AI-RNG: Enemy Index is :'..enemyIndex)
            local acuPos, lastSpotted = RUtils.GetLastACUPosition(self, enemyIndex)
            --LOG('* AI-RNG: ACU Position is has data'..repr(acuPos))
            insertTable.ACUPosition = acuPos
            insertTable.ACULastSpotted = lastSpotted
            
            insertTable.EconomicThreat = ecoThreat
            if insertTable.Enemy then
                local enemyTotalStrength = 0
                local highestEnemyThreat = 0
                local threatPos = {}
                local enemyStructureThreat = self:GetThreatsAroundPosition(MainPos, 16, true, 'Structures', enemyIndex)
                for _, threat in enemyStructureThreat do
                    enemyTotalStrength = enemyTotalStrength + threat[3]
                    if threat[3] > highestEnemyThreat then
                        highestEnemyThreat = threat[3]
                        threatPos = {threat[1],0,threat[2]}
                    end
                end
                if enemyTotalStrength > 0 then
                    insertTable.Strength = enemyTotalStrength
                    insertTable.Position = threatPos
                end

                --LOG('Enemy Index is '..enemyIndex)
                --LOG('Enemy name is '..v.Nickname)
                --LOG('* AI-RNG: First Enemy Pass Strength is :'..insertTable.Strength)
                --LOG('* AI-RNG: First Enemy Pass Position is :'..repr(insertTable.Position))
                if insertTable.Strength == 0 then
                    --LOG('Enemy Strength is zero, using enemy start pos')
                    insertTable.Position = {startX, 0 ,startZ}
                end
            else
                insertTable.Position = {startX, 0 ,startZ}
                insertTable.Strength = ecoThreat
                --LOG('* AI-RNG: First Ally Pass Strength is : '..insertTable.Strength..' Ally Position :'..repr(insertTable.Position))
            end
            armyStrengthTable[v:GetArmyIndex()] = insertTable
        end
        
        self.EnemyIntel.EnemyCount = enemyCount
        self.BrainIntel.AllyCount = allyCount
        local allyEnemy = self:GetAllianceEnemyRNG(armyStrengthTable)
        
        if allyEnemy  then
            --LOG('* AI-RNG: Ally Enemy is true or ACU is close')
            self:SetCurrentEnemy(allyEnemy)
        else
            local findEnemy = false
            if not self:GetCurrentEnemy() then
                findEnemy = true
            else
                local cIndex = self:GetCurrentEnemy():GetArmyIndex()
                -- If our enemy has been defeated or has less than 20 strength, we need a new enemy
                if self:GetCurrentEnemy():IsDefeated() or armyStrengthTable[cIndex].Strength < 20 then
                    findEnemy = true
                end
            end
            local enemyTable = {}
            if findEnemy then
                local enemyStrength = false
                local enemy = false

                for k, v in armyStrengthTable do
                    -- Dont' target self
                    if k == selfIndex then
                        continue
                    end

                    -- Ignore allies
                    if not v.Enemy then
                        continue
                    end

                    -- If we have a better candidate; ignore really weak enemies
                    if enemy and v.Strength < 20 then
                        continue
                    end

                    if v.Strength == 0 then
                        name = v.Brain.Nickname
                        --LOG('* AI-RNG: Name is'..name)
                        --LOG('* AI-RNG: v.strenth is 0')
                        if name ~= 'civilian' then
                            --LOG('* AI-RNG: Inserted Name is '..name)
                            RNGINSERT(enemyTable, v.Brain)
                        end
                        continue
                    end

                    -- The closer targets are worth more because then we get their mass spots
                    local distanceWeight = 0.1
                    local distance = VDist3(self:GetStartVector3f(), v.Position)
                    local threatWeight = (1 / (distance * distanceWeight)) * v.Strength
                    --LOG('* AI-RNG: armyStrengthTable Strength is :'..v.Strength)
                    --LOG('* AI-RNG: Threat Weight is :'..threatWeight)
                    if not enemy or threatWeight > enemyStrength then
                        enemy = v.Brain
                        enemyStrength = threatWeight
                        --LOG('* AI-RNG: Enemy Strength is'..enemyStrength)
                    end
                end

                if enemy then
                    --LOG('* AI-RNG: Enemy is :'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                else
                    local num = RNGGETN(enemyTable)
                    --LOG('* AI-RNG: Table number is'..num)
                    local ran = math.random(num)
                    --LOG('* AI-RNG: Random Number is'..ran)
                    enemy = enemyTable[ran]
                    --LOG('* AI-RNG: Random Enemy is'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                end
                
            end
        end
        local selfEnemy = self:GetCurrentEnemy()
        if selfEnemy then
            local enemyIndex = selfEnemy:GetArmyIndex()
            local closest = 9999999
            local expansionName
            local mainDist = VDist2Sq(self.BuilderManagers['MAIN'].Position[1], self.BuilderManagers['MAIN'].Position[3], armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
            --LOG('Main base Position '..repr(self.BuilderManagers['MAIN'].Position))
            --LOG('Enemy base position '..repr(armyStrengthTable[enemyIndex].Position))
            for k, v in self.BuilderManagers do
                --LOG('build k is '..k)
                if (string.find(k, 'Expansion Area')) or (string.find(k, 'ARMY_')) then
                    if v.FactoryManager:GetNumCategoryFactories(categories.ALLUNITS) > 0 then
                        local exDistance = VDist2Sq(self.BuilderManagers[k].Position[1], self.BuilderManagers[k].Position[3], armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
                        --LOG('Distance to Enemy for '..k..' is '..exDistance)
                        if (exDistance < closest) and (mainDist > exDistance) then
                            expansionName = k
                            closest = exDistance
                        end
                    end
                end
            end
            if closest < 9999999 and expansionName then
                --LOG('Closest Base to Enemy is '..expansionName..' at a distance of '..closest)
                self.BrainIntel.ActiveExpansion = expansionName
                --LOG('Active Expansion is '..self.BrainIntel.ActiveExpansion)
            end
            local waterNodePos, waterNodeName, waterNodeDist = AIUtils.AIGetClosestMarkerLocationRNG(self, 'Water Path Node', armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
            if waterNodePos then
                --LOG('Enemy Closest water node pos is '..repr(waterNodePos))
                self.EnemyIntel.NavalRange.Position = waterNodePos
                --LOG('Enemy Closest water node pos distance is '..waterNodeDist)
                self.EnemyIntel.NavalRange.Range = waterNodeDist
            end
            --LOG('Current Naval Range table is '..repr(self.EnemyIntel.NavalRange))
        end
    end,

    ParseIntelThreadRNG = function(self)
        if not self.InterestList or not self.InterestList.MustScout then
            error('Scouting areas must be initialized before calling AIBrain:ParseIntelThread.', 2)
        end
        while true do
            local structures = GetThreatsAroundPosition(self, self.BuilderManagers.MAIN.Position, 16, true, 'StructuresNotMex')
            for _, struct in structures do
                local dupe = false
                local newPos = {struct[1], 0, struct[2]}

                for _, loc in self.InterestList.HighPriority do
                    if VDist2Sq(newPos[1], newPos[3], loc.Position[1], loc.Position[3]) < 10000 then
                        dupe = true
                        break
                    end
                end

                if not dupe then
                    -- Is it in the low priority list?
                    for i = 1, RNGGETN(self.InterestList.LowPriority) do
                        local loc = self.InterestList.LowPriority[i]
                        if VDist2Sq(newPos[1], newPos[3], loc.Position[1], loc.Position[3]) < 10000 then
                            -- Found it in the low pri list. Remove it so we can add it to the high priority list.
                            table.remove(self.InterestList.LowPriority, i)
                            break
                        end
                    end

                    RNGINSERT(self.InterestList.HighPriority,
                        {
                            Position = newPos,
                            LastScouted = GetGameTimeSeconds(),
                        }
                    )
                    -- Sort the list based on low long it has been since it was scouted
                    table.sort(self.InterestList.HighPriority, function(a, b)
                        if a.LastScouted == b.LastScouted then
                            local MainPos = self.BuilderManagers.MAIN.Position
                            local distA = VDist2(MainPos[1], MainPos[3], a.Position[1], a.Position[3])
                            local distB = VDist2(MainPos[1], MainPos[3], b.Position[1], b.Position[3])

                            return distA < distB
                        else
                            return a.LastScouted < b.LastScouted
                        end
                    end)
                end
            end
            WaitTicks(70)
        end
    end,

    GetAllianceEnemyRNG = function(self, strengthTable)
        local returnEnemy = false
        local myIndex = self:GetArmyIndex()
        local highStrength = strengthTable[myIndex].Strength
        local startX, startZ = self:GetArmyStartPos()
        local ACUDist = nil
        self.EnemyIntel.ACUEnemyClose = false
        
        --LOG('* AI-RNG: My Own Strength is'..highStrength)
        for k, v in strengthTable do
            -- It's an enemy, ignore
            if v.Enemy then
                --LOG('* AI-RNG: ACU Position is :'..repr(v.ACUPosition))
                if v.ACUPosition[1] then
                    ACUDist = VDist2(startX, startZ, v.ACUPosition[1], v.ACUPosition[3])
                    --LOG('* AI-RNG: Enemy ACU Distance in Alliance Check is'..ACUDist)
                    if ACUDist < 230 then
                        --LOG('* AI-RNG: Enemy ACU is close switching Enemies to :'..v.Brain.Nickname)
                        returnEnemy = v.Brain
                        self.EnemyIntel.ACU[k].OnField = true
                        if ACUDist < 140 then
                            self.EnemyIntel.ACUEnemyClose = true
                            --LOG('Enemy ACU is within 145 of base')
                        end
                        return returnEnemy
                    elseif v.Threat < 200 and ACUDist < 200 then
                        --LOG('* AI-RNG: Enemy ACU has low threat switching Enemies to :'..v.Brain.Nickname)
                        returnEnemy = v.Brain
                        return returnEnemy
                    end
                    if ACUDist > 230 then
                        self.EnemyIntel.ACU[k].OnField = false
                    end
                end
                continue
            end

            -- Ally too weak
            if v.Strength < highStrength then
                continue
            end

            -- If the brain has an enemy, it's our new enemy
            
            local enemy = v.Brain:GetCurrentEnemy()
            if enemy and not enemy:IsDefeated() and v.Strength > 0 then
                highStrength = v.Strength
                returnEnemy = v.Brain:GetCurrentEnemy()
            end
        end
        if returnEnemy then
            --LOG('* AI-RNG: Ally Enemy Returned is : '..returnEnemy.Nickname)
        else
            --LOG('* AI-RNG: returnEnemy is false')
        end
        return returnEnemy
    end,

    GetUpgradeSpec = function(self, unit)
        local upgradeSpec = {}
        
        if EntityCategoryContains(categories.MASSEXTRACTION, unit) then
            if self.UpgradeMode == 'Aggressive' then
                upgradeSpec.MassLowTrigger = 0.80
                upgradeSpec.EnergyLowTrigger = 0.95
                upgradeSpec.MassHighTrigger = 2.0
                upgradeSpec.EnergyHighTrigger = 99999
                upgradeSpec.UpgradeCheckWait = 18
                upgradeSpec.InitialDelay = 40
                upgradeSpec.EnemyThreatLimit = 10
                return upgradeSpec
            elseif self.UpgradeMode == 'Normal' then
                upgradeSpec.MassLowTrigger = 0.90
                upgradeSpec.EnergyLowTrigger = 1.05
                upgradeSpec.MassHighTrigger = 2.0
                upgradeSpec.EnergyHighTrigger = 99999
                upgradeSpec.UpgradeCheckWait = 18
                upgradeSpec.InitialDelay = 70
                upgradeSpec.EnemyThreatLimit = 5
                return upgradeSpec
            elseif self.UpgradeMode == 'Caution' then
                upgradeSpec.MassLowTrigger = 1.0
                upgradeSpec.EnergyLowTrigger = 1.2
                upgradeSpec.MassHighTrigger = 2.0
                upgradeSpec.EnergyHighTrigger = 99999
                upgradeSpec.UpgradeCheckWait = 18
                upgradeSpec.InitialDelay = 90
                upgradeSpec.EnemyThreatLimit = 0
                return upgradeSpec
            end
        else
            --LOG('* AI-RNG: Unit is not Mass Extractor')
            upgradeSpec = false
            return upgradeSpec
        end
    end,

    BaseMonitorPlatoonDistressRNG = function(self, platoon, threat)
        if not self.BaseMonitor then
            return
        end

        local found = false
        if self.BaseMonitor.PlatoonAlertSounded == false then
            RNGINSERT(self.BaseMonitor.PlatoonDistressTable, {Platoon = platoon, Threat = threat})
        else
            for k, v in self.BaseMonitor.PlatoonDistressTable do
                -- If already calling for help, don't add another distress call
                if table.equal(v.Platoon, platoon) then
                    --LOG('platoon.BuilderName '..platoon.BuilderName..'already exist as '..v.Platoon.BuilderName..' skipping')
                    found = true
                    break
                end
            end
            if not found then
                --LOG('Platoon doesnt already exist, adding')
                RNGINSERT(self.BaseMonitor.PlatoonDistressTable, {Platoon = platoon, Threat = threat})
            end
        end
        -- Create the distress call if it doesn't exist
        if not self.BaseMonitor.PlatoonDistressThread then
            self.BaseMonitor.PlatoonDistressThread = self:ForkThread(self.BaseMonitorPlatoonDistressThreadRNG)
        end
        --LOG('Platoon Distress Table'..repr(self.BaseMonitor.PlatoonDistressTable))
    end,

    BaseMonitorPlatoonDistressThreadRNG = function(self)
        self.BaseMonitor.PlatoonAlertSounded = true
        while true do
            local numPlatoons = 0
            for k, v in self.BaseMonitor.PlatoonDistressTable do
                if self:PlatoonExists(v.Platoon) then
                    local threat = GetThreatAtPosition(self, v.Platoon:GetPlatoonPosition(), 0, true, 'Land')
                    local myThreat = GetThreatAtPosition(self, v.Platoon:GetPlatoonPosition(), 0, true, 'Overall', self:GetArmyIndex())
                    --LOG('* AI-RNG: Threat of attacker'..threat)
                    --LOG('* AI-RNG: Threat of platoon'..myThreat)
                    -- Platoons still threatened
                    if threat and threat > (myThreat * 1.5) then
                        --LOG('* AI-RNG: Created Threat Alert')
                        v.Threat = threat
                        numPlatoons = numPlatoons + 1
                    -- Platoon not threatened
                    else
                        self.BaseMonitor.PlatoonDistressTable[k] = nil
                        v.Platoon.DistressCall = false
                    end
                else
                    self.BaseMonitor.PlatoonDistressTable[k] = nil
                end
            end

            -- If any platoons still want help; continue sounding
            --LOG('Alerted Platoons '..numPlatoons)
            if numPlatoons > 0 then
                self.BaseMonitor.PlatoonAlertSounded = true
            else
                self.BaseMonitor.PlatoonAlertSounded = false
            end
            self.BaseMonitor.PlatoonDistressTable = self:RebuildTable(self.BaseMonitor.PlatoonDistressTable)
            --LOG('Platoon Distress Table'..repr(self.BaseMonitor.PlatoonDistressTable))
            WaitSeconds(self.BaseMonitor.BaseMonitorTime)
        end
    end,

    BaseMonitorDistressLocationRNG = function(self, position, radius, threshold)
        local returnPos = false
        local highThreat = false
        local distance
        
        if self.BaseMonitor.CDRDistress and VDist2(self.BaseMonitor.CDRDistress[1], self.BaseMonitor.CDRDistress[3], position[1], position[3]) < radius
            and self.BaseMonitor.CDRThreatLevel > threshold then
            -- Commander scared and nearby; help it
            return self.BaseMonitor.CDRDistress
        end
        if self.BaseMonitor.AlertSounded then
            --LOG('Base Alert Sounded')
            for k, v in self.BaseMonitor.AlertsTable do
                local tempDist = VDist2(position[1], position[3], v.Position[1], v.Position[3])

                -- Too far away
                if tempDist > radius then
                    continue
                end

                -- Not enough threat in location
                if v.Threat < threshold then
                    continue
                end

                -- Threat lower than or equal to a threat we already have
                if v.Threat <= highThreat then
                    continue
                end

                -- Get real height
                local height = GetTerrainHeight(v.Position[1], v.Position[3])
                local surfHeight = GetSurfaceHeight(v.Position[1], v.Position[3])
                if surfHeight > height then
                    height = surfHeight
                end

                -- currently our winner in high threat
                returnPos = {v.Position[1], height, v.Position[3]}
                distance = tempDist
            end
        end
        if self.BaseMonitor.PlatoonAlertSounded then
            --LOG('Platoon Alert Sounded')
            for k, v in self.BaseMonitor.PlatoonDistressTable do
                if self:PlatoonExists(v.Platoon) then
                    local platPos = v.Platoon:GetPlatoonPosition()
                    if not platPos then
                        self.BaseMonitor.PlatoonDistressTable[k] = nil
                        continue
                    end
                    local tempDist = VDist2(position[1], position[3], platPos[1], platPos[3])

                    -- Platoon too far away to help
                    if tempDist > radius then
                        continue
                    end

                    -- Area not scary enough
                    if v.Threat < threshold then
                        continue
                    end

                    -- Further away than another call for help
                    if tempDist > distance then
                        continue
                    end

                    -- Our current winners
                    returnPos = platPos
                    distance = tempDist
                end
            end
        end
        return returnPos
    end,

    TacticalMonitorInitializationRNG = function(self, spec)
        --LOG('* AI-RNG: Tactical Monitor Is Initializing')
        local ALLBPS = __blueprints
        self:ForkThread(self.TacticalMonitorThreadRNG, ALLBPS)
    end,

    TacticalMonitorThreadRNG = function(self, ALLBPS)
        --LOG('Monitor Tick Count :'..self.TacticalMonitor.TacticalMonitorTime)
        while true do
            if self.TacticalMonitor.TacticalMonitorStatus == 'ACTIVE' then
                --LOG('* AI-RNG: Tactical Monitor Is Active')
                self:SelfThreatCheckRNG(ALLBPS)
                self:EnemyThreatCheckRNG(ALLBPS)
                self:TacticalMonitorRNG(ALLBPS)
                if true then
                    --local EnergyIncome = GetEconomyIncome(self,'ENERGY')
                    --local MassIncome = GetEconomyIncome(self,'MASS')
                    --local EnergyRequested = GetEconomyRequested(self,'ENERGY')
                    --local MassRequested = GetEconomyRequested(self,'MASS')
                    --local EnergyEfficiency = math.min(EnergyIncome / EnergyRequested, 2)
                    --local MassEfficiency = math.min(MassIncome / MassRequested, 2)
                    --LOG('Eco Stats for :'..self.Nickname)
                    --LOG('MassTrend :'..GetEconomyTrend(self, 'MASS')..' Energy Trend :'..GetEconomyTrend(self, 'ENERGY'))
                    --LOG('MassStorage :'..GetEconomyStoredRatio(self, 'MASS')..' Energy Storage :'..GetEconomyStoredRatio(self, 'ENERGY'))
                    --LOG('Mass Efficiency :'..MassEfficiency..'Energy Efficiency :'..EnergyEfficiency)
                    --LOG('Mass Efficiency OverTime :'..self.EconomyOverTimeCurrent.MassEfficiencyOverTime..' Energy Efficiency Overtime:'..self.EconomyOverTimeCurrent.EnergyEfficiencyOverTime)
                    --LOG('Mass Trend OverTime :'..self.EconomyOverTimeCurrent.MassTrendOverTime..' Energy Trend Overtime:'..self.EconomyOverTimeCurrent.EnergyTrendOverTime)
                    --LOG('Mass Income OverTime :'..self.EconomyOverTimeCurrent.MassIncome..' Energy Income Overtime:'..self.EconomyOverTimeCurrent.EnergyIncome)
                    --local mexSpend = (self.cmanager.categoryspend.mex.T1 + self.cmanager.categoryspend.mex.T2 + self.cmanager.categoryspend.mex.T3) or 0
                    --LOG('Spend - Mex Upgrades '..self.cmanager.categoryspend.fact['Land'] / (self.cmanager.income.r.m - mexSpend)..' Should be less than'..self.ProductionRatios['Land'])
                    --LOG('ARMY '..self.Nickname..' eco numbers:'..repr(self.cmanager))
                    --LOG('ARMY '..self.Nickname..' Current Army numbers:'..repr(self.amanager.Current))
                    --LOG('ARMY '..self.Nickname..' Total Army numbers:'..repr(self.amanager.Total))
                    --LOG('ARMY '..self.Nickname..' Type Army numbers:'..repr(self.amanager.Type))
                    --LOG('Current Land Ratio is '..self.ProductionRatios['Land'])
                    --LOG('I am spending approx land '..repr(self.cmanager.categoryspend.fact.Land))
                    --LOG('I should be spending approx land '..self.cmanager.income.r.m * self.ProductionRatios['Land'])
                    --LOG('Current Air Ratio is '..self.ProductionRatios['Air'])
                    --LOG('I am spending approx air '..repr(self.cmanager.categoryspend.fact.Air))
                    --LOG('I should be spending approx air '..self.cmanager.income.r.m * self.ProductionRatios['Air'])
                    --LOG('Current Naval Ratio is '..self.ProductionRatios['Naval'])
                    --LOG('I am spending approx Naval '..repr(self.cmanager.categoryspend.fact.Naval))
                    --LOG('I should be spending approx Naval '..self.cmanager.income.r.m * self.ProductionRatios['Naval'])
                    --LOG('My AntiAir Threat : '..self.BrainIntel.SelfThreat.AntiAirNow..' Enemy AntiAir Threat : '..self.EnemyIntel.EnemyThreatCurrent.AntiAir)
                    --LOG('My Air Threat : '..self.BrainIntel.SelfThreat.AirNow..' Enemy Air Threat : '..self.EnemyIntel.EnemyThreatCurrent.Air)
                    --LOG('My Land Threat : '..(self.BrainIntel.SelfThreat.LandNow + self.BrainIntel.SelfThreat.AllyLandThreat)..' Enemy Land Threat : '..self.EnemyIntel.EnemyThreatCurrent.Land)
                    --LOG(' My Naval Sub Threat : '..self.BrainIntel.SelfThreat.NavalSubNow..' Enemy Naval Sub Threat : '..self.EnemyIntel.EnemyThreatCurrent.NavalSub)
                    --local factionIndex = self:GetFactionIndex()
                    --LOG('Air Current Ratio T1 Fighter: '..(self.amanager.Current['Air']['T1']['interceptor'] / self.amanager.Total['Air']['T1']))
                    --LOG('Air Current Production Ratio Desired T1 Fighter : '..(self.amanager.Ratios[factionIndex]['Air']['T1']['interceptor']/self.amanager.Ratios[factionIndex]['Air']['T1'].total))
                    --LOG('Air Current Ratio T1 Bomber: '..(self.amanager.Current['Air']['T1']['bomber'] / self.amanager.Total['Air']['T1']))
                    --LOG('Air Current Production Ratio Desired T1 Bomber : '..(self.amanager.Ratios[factionIndex]['Air']['T1']['bomber']/self.amanager.Ratios[factionIndex]['Air']['T1'].total))
                    --if self.EnemyIntel.ChokeFlag then
                    --    LOG('Choke Flag is true')
                    --else
                    --    LOG('Choke Flag is false')
                    --end
                    --LOG('Graph Zone Table '..repr(self.GraphZones))
                    --LOG('Total Mass Markers according to infect'..self.BrainIntel.MassMarker)
                    --LOG('Total Mass Markers according to count '..self.BrainIntel.SelfThreat.MassMarker)
                end
            end
            WaitTicks(self.TacticalMonitor.TacticalMonitorTime)
        end
    end,

    TacticalAnalysisThreadRNG = function(self)
        local ALLBPS = __blueprints
        WaitTicks(200)
        while true do
            if self.TacticalMonitor.TacticalMonitorStatus == 'ACTIVE' then
                self:TacticalThreatAnalysisRNG(ALLBPS)
            end
            self:CalculateMassMarkersRNG()
            local enemyCount = 0
            if self.EnemyIntel.EnemyCount > 0 then
                enemyCount = self.EnemyIntel.EnemyCount
            end
            if self.BrainIntel.SelfThreat.LandNow > (self.EnemyIntel.EnemyThreatCurrent.Land / enemyCount) * 1.3 and (not self.EnemyIntel.ChokeFlag) then
                --LOG('Land Threat Higher, shift ratio to 0.5')
                self.ProductionRatios.Land = 0.5
            elseif not self.EnemyIntel.ChokeFlag then
                --LOG('Land Threat Lower, shift ratio to 0.6')
                self.ProductionRatios.Land = self.DefaultLandRatio
            end
            if self.BrainIntel.SelfThreat.AirNow > (self.EnemyIntel.EnemyThreatCurrent.Air / enemyCount) and (not self.EnemyIntel.ChokeFlag) then
                --LOG('Air Threat Higher, shift ratio to 0.4')
                self.ProductionRatios.Air = 0.4
            elseif not self.EnemyIntel.ChokeFlag then
                --LOG('Air Threat lower, shift ratio to 0.5')
                self.ProductionRatios.Air = self.DefaultAirRatio
            end
            if self.BrainIntel.SelfThreat.NavalNow > (self.EnemyIntel.EnemyThreatCurrent.Naval / enemyCount) and (not self.EnemyIntel.ChokeFlag) then
                self.ProductionRatios.Naval = 0.4
            elseif not self.EnemyIntel.ChokeFlag then
                self.ProductionRatios.Naval = self.DefaultNavalRatio
            end
            --LOG('(self.EnemyIntel.EnemyCount + self.BrainIntel.AllyCount) / self.BrainIntel.SelfThreat.MassMarkerBuildable'..self.BrainIntel.SelfThreat.MassMarkerBuildable / (self.EnemyIntel.EnemyCount + self.BrainIntel.AllyCount))
            --LOG('self.EnemyIntel.EnemyCount '..self.EnemyIntel.EnemyCount)
            --LOG('self.BrainIntel.AllyCount '..self.BrainIntel.AllyCount)
            --LOG('self.BrainIntel.SelfThreat.MassMarkerBuildable'..self.BrainIntel.SelfThreat.MassMarkerBuildable)
            WaitTicks(600)
        end
    end,

    EnemyThreatCheckRNG = function(self, ALLBPS)
        local selfIndex = self:GetArmyIndex()
        local enemyBrains = {}
        local enemyAirThreat = 0
        local enemyAntiAirThreat = 0
        local enemyNavalThreat = 0
        local enemyLandThreat = 0
        local enemyNavalSubThreat = 0
        local enemyExtractorthreat = 0
        local enemyExtractorCount = 0
        local enemyDefenseAir = 0
        local enemyDefenseSurface = 0
        local enemyDefenseSub = 0
        local enemyACUGun = 0

        --LOG('Starting Threat Check at'..GetGameTick())
        for index, brain in ArmyBrains do
            if IsEnemy(selfIndex, brain:GetArmyIndex()) then
                RNGINSERT(enemyBrains, brain)
            end
        end
        if RNGGETN(enemyBrains) > 0 then
            for k, enemy in enemyBrains do

                local gunBool = false
                local acuHealth = 0
                local lastSpotted = 0
                local enemyIndex = enemy:GetArmyIndex()
                if not ArmyIsCivilian(enemyIndex) then
                    local enemyAir = GetListOfUnits( enemy, categories.MOBILE * categories.AIR - categories.TRANSPORTFOCUS - categories.SATELLITE, false, false)
                    for _,v in enemyAir do
                        -- previous method of getting unit ID before the property was added.
                        --local unitbpId = v:GetUnitId()
                        --LOG('Unit blueprint id test only on dev branch:'..v.UnitId)
                        bp = ALLBPS[v.UnitId].Defense
            
                        enemyAirThreat = enemyAirThreat + bp.AirThreatLevel + bp.SubThreatLevel + bp.SurfaceThreatLevel
                        enemyAntiAirThreat = enemyAntiAirThreat + bp.AirThreatLevel
                    end
                    WaitTicks(1)
                    local enemyExtractors = GetListOfUnits( enemy, categories.STRUCTURE * categories.MASSEXTRACTION, false, false)
                    for _,v in enemyExtractors do
                        bp = ALLBPS[v.UnitId].Defense

                        enemyExtractorthreat = enemyExtractorthreat + bp.EconomyThreatLevel
                        enemyExtractorCount = enemyExtractorCount + 1
                    end
                    WaitTicks(1)
                    local enemyNaval = GetListOfUnits( enemy, categories.NAVAL * ( categories.MOBILE + categories.DEFENSE ), false, false )
                    for _,v in enemyNaval do
                        bp = ALLBPS[v.UnitId].Defense
                        --LOG('NavyThreat unit is '..v.UnitId)
                        --LOG('NavyThreat is '..bp.SubThreatLevel)
                        enemyNavalThreat = enemyNavalThreat + bp.AirThreatLevel + bp.SubThreatLevel + bp.SurfaceThreatLevel
                        enemyNavalSubThreat = enemyNavalSubThreat + bp.SubThreatLevel
                    end
                    WaitTicks(1)
                    local enemyLand = GetListOfUnits( enemy, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.COMMAND , false, false)
                    for _,v in enemyLand do
                        bp = ALLBPS[v.UnitId].Defense
                        enemyLandThreat = enemyLandThreat + bp.SurfaceThreatLevel
                    end
                    WaitTicks(1)
                    local enemyDefense = GetListOfUnits( enemy, categories.STRUCTURE * categories.DEFENSE - categories.SHIELD, false, false )
                    for _,v in enemyDefense do
                        bp = ALLBPS[v.UnitId].Defense
                        --LOG('DefenseThreat unit is '..v.UnitId)
                        --LOG('DefenseThreat is '..bp.SubThreatLevel)
                        enemyDefenseAir = enemyDefenseAir + bp.AirThreatLevel
                        enemyDefenseSurface = enemyDefenseSurface + bp.SurfaceThreatLevel
                        enemyDefenseSub = enemyDefenseSub + bp.SubThreatLevel
                    end
                    WaitTicks(1)
                    local enemyACU = GetListOfUnits( enemy, categories.COMMAND, false, false )
                    for _,v in enemyACU do
                        local factionIndex = enemy:GetFactionIndex()
                        if factionIndex == 1 then
                            if v:HasEnhancement('HeavyAntiMatterCannon') then
                                enemyACUGun = enemyACUGun + 1
                                gunBool = true
                            end
                        elseif factionIndex == 2 then
                            if v:HasEnhancement('CrysalisBeam') then
                                enemyACUGun = enemyACUGun + 1
                                gunBool = true
                            end
                        elseif factionIndex == 3 then
                            if v:HasEnhancement('CoolingUpgrade') then
                                enemyACUGun = enemyACUGun + 1
                                gunBool = true
                            end
                        elseif factionIndex == 4 then
                            if v:HasEnhancement('RateOfFire') then
                                enemyACUGun = enemyACUGun + 1
                                gunBool = true
                            end
                        end
                        if self.CheatEnabled then
                            acuHealth = v:GetHealth()
                            lastSpotted = GetGameTimeSeconds()
                        end
                    end
                    if gunBool then
                        self.EnemyIntel.ACU[enemyIndex].Gun = true
                        --LOG('Gun Upgrade Present on army '..enemy.Nickname)
                    else
                        self.EnemyIntel.ACU[enemyIndex].Gun = false
                    end
                    if self.CheatEnabled then
                        self.EnemyIntel.ACU[enemyIndex].Hp = acuHealth
                        self.EnemyIntel.ACU[enemyIndex].LastSpotted = lastSpotted
                        --LOG('Cheat is enabled and acu has '..acuHealth..' Health '..'Brain intel says '..self.EnemyIntel.ACU[enemyIndex].Hp)
                    end
                end
            end
        end
        self.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades = enemyACUGun
        self.EnemyIntel.EnemyThreatCurrent.Air = enemyAirThreat
        self.EnemyIntel.EnemyThreatCurrent.AntiAir = enemyAntiAirThreat
        self.EnemyIntel.EnemyThreatCurrent.Extractor = enemyExtractorthreat
        self.EnemyIntel.EnemyThreatCurrent.ExtractorCount = enemyExtractorCount
        self.EnemyIntel.EnemyThreatCurrent.Naval = enemyNavalThreat
        self.EnemyIntel.EnemyThreatCurrent.NavalSub = enemyNavalSubThreat
        self.EnemyIntel.EnemyThreatCurrent.Land = enemyLandThreat
        self.EnemyIntel.EnemyThreatCurrent.DefenseAir = enemyDefenseAir
        self.EnemyIntel.EnemyThreatCurrent.DefenseSurface = enemyDefenseSurface
        self.EnemyIntel.EnemyThreatCurrent.DefenseSub = enemyDefenseSub
        --LOG('Completing Threat Check'..GetGameTick())
    end,

    SelfThreatCheckRNG = function(self, ALLBPS)
        -- Get AI strength
        local selfIndex = self:GetArmyIndex()

        local brainAirUnits = GetListOfUnits( self, (categories.AIR * categories.MOBILE) - categories.TRANSPORTFOCUS - categories.SATELLITE - categories.EXPERIMENTAL, false, false)
        local airthreat = 0
        local antiAirThreat = 0
        local bp

		-- calculate my present airvalue			
		for _,v in brainAirUnits do
            -- previous method of getting unit ID before the property was added.
            --local unitbpId = v:GetUnitId()
            --LOG('Unit blueprint id test only on dev branch:'..v.UnitId)
			bp = ALLBPS[v.UnitId].Defense

            airthreat = airthreat + bp.AirThreatLevel + bp.SubThreatLevel + bp.SurfaceThreatLevel
            antiAirThreat = antiAirThreat + bp.AirThreatLevel
        end
        --LOG('My Air Threat is'..airthreat)
        self.BrainIntel.SelfThreat.AirNow = airthreat
        self.BrainIntel.SelfThreat.AntiAirNow = antiAirThreat

        --[[if airthreat > 0 then
            local airSelfThreat = {Threat = airthreat, InsertTime = GetGameTimeSeconds()}
            RNGINSERT(self.BrainIntel.SelfThreat.Air, airSelfThreat)
            --LOG('Total Air Unit Threat :'..airthreat)
            --LOG('Current Self Air Threat Table :'..repr(self.BrainIntel.SelfThreat.Air))
            local averageSelfThreat = 0
            for k, v in self.BrainIntel.SelfThreat.Air do
                averageSelfThreat = averageSelfThreat + v.Threat
            end
            self.BrainIntel.Average.Air = averageSelfThreat / RNGGETN(self.BrainIntel.SelfThreat.Air)
            --LOG('Current Self Average Air Threat Table :'..repr(self.BrainIntel.Average.Air))
        end]]
        WaitTicks(1)
        local brainExtractors = GetListOfUnits( self, categories.STRUCTURE * categories.MASSEXTRACTION, false, false)
        local selfExtractorCount = 0
        local selfExtractorThreat = 0
        local exBp

        for _,v in brainExtractors do
            exBp = ALLBPS[v.UnitId].Defense
            selfExtractorThreat = selfExtractorThreat + exBp.EconomyThreatLevel
            selfExtractorCount = selfExtractorCount + 1
            -- This bit is important. This is so that if the AI is given or captures any extractors it will start an upgrade thread and distress thread on them.
            if (not v.Dead) and (not v.PlatoonHandle) then
                --LOG('This extractor has no platoon handle')
                if not self.StructurePool then
                    RUtils.CheckCustomPlatoons(self)
                end
                local unitBp = v:GetBlueprint()
                local StructurePool = self.StructurePool
                --LOG('* AI-RNG: Assigning built extractor to StructurePool')
                self:AssignUnitsToPlatoon(StructurePool, {v}, 'Support', 'none' )
                local upgradeID = unitBp.General.UpgradesTo or false
                if upgradeID and unitBp then
                    --LOG('* AI-RNG: UpgradeID')
                    RUtils.StructureUpgradeInitialize(v, self)
                end
            end
        end
        self.BrainIntel.SelfThreat.Extractor = selfExtractorThreat
        self.BrainIntel.SelfThreat.ExtractorCount = selfExtractorCount
        local allyBrains = {}
        for index, brain in ArmyBrains do
            if index ~= self:GetArmyIndex() then
                if IsAlly(selfIndex, brain:GetArmyIndex()) then
                    RNGINSERT(allyBrains, brain)
                end
            end
        end
        local allyExtractorCount = 0
        local allyExtractorthreat = 0
        local allyLandThreat = 0
        --LOG('Number of Allies '..RNGGETN(allyBrains))
        WaitTicks(1)
        if RNGGETN(allyBrains) > 0 then
            for k, ally in allyBrains do
                local allyExtractors = GetListOfUnits( ally, categories.STRUCTURE * categories.MASSEXTRACTION, false, false)
                for _,v in allyExtractors do
                    bp = ALLBPS[v.UnitId].Defense
                    allyExtractorthreat = allyExtractorthreat + bp.EconomyThreatLevel
                    allyExtractorCount = allyExtractorCount + 1
                end
                local allylandThreat = GetListOfUnits( ally, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.COMMAND , false, false)
                
                for _,v in allylandThreat do
                    bp = ALLBPS[v.UnitId].Defense
                    allyLandThreat = allyLandThreat + bp.SurfaceThreatLevel
                end
            end
        end
        self.BrainIntel.SelfThreat.AllyExtractorCount = allyExtractorCount + selfExtractorCount
        self.BrainIntel.SelfThreat.AllyExtractor = allyExtractorthreat + selfExtractorThreat
        self.BrainIntel.SelfThreat.AllyLandThreat = allyLandThreat
        --LOG('AllyExtractorCount is '..self.BrainIntel.SelfThreat.AllyExtractorCount)
        --LOG('SelfExtractorCount is '..self.BrainIntel.SelfThreat.ExtractorCount)
        --LOG('AllyExtractorThreat is '..self.BrainIntel.SelfThreat.AllyExtractor)
        --LOG('SelfExtractorThreat is '..self.BrainIntel.SelfThreat.Extractor)
        WaitTicks(1)
        local brainNavalUnits = GetListOfUnits( self, (categories.MOBILE * categories.NAVAL) + (categories.NAVAL * categories.FACTORY) + (categories.NAVAL * categories.DEFENSE), false, false)
        local navalThreat = 0
        local navalSubThreat = 0
        for _,v in brainNavalUnits do
            bp = ALLBPS[v.UnitId].Defense
            navalThreat = navalThreat + bp.AirThreatLevel + bp.SubThreatLevel + bp.SurfaceThreatLevel
            navalSubThreat = navalSubThreat + bp.SubThreatLevel
        end
        self.BrainIntel.SelfThreat.NavalNow = navalThreat
        self.BrainIntel.SelfThreat.NavalSubNow = navalSubThreat

        WaitTicks(1)
        local brainLandUnits = GetListOfUnits( self, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.COMMAND , false, false)
        local landThreat = 0
        for _,v in brainLandUnits do
            bp = ALLBPS[v.UnitId].Defense
            landThreat = landThreat + bp.SurfaceThreatLevel
        end
        self.BrainIntel.SelfThreat.LandNow = landThreat
        --LOG('Self LandThreat is '..self.BrainIntel.SelfThreat.LandNow)
    end,

    IMAPConfigurationRNG = function(self, ALLBPS)
        -- Used to configure imap values, used for setting threat ring sizes depending on map size to try and get a somewhat decent radius
        local maxmapdimension = math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])

        if maxmapdimension == 256 then
            self.BrainIntel.IMAPConfig.OgridRadius = 11.5
            self.BrainIntel.IMAPConfig.IMAPSize = 16
            self.BrainIntel.IMAPConfig.Rings = 3
        elseif maxmapdimension == 512 then
            self.BrainIntel.IMAPConfig.OgridRadius = 22.5
            self.BrainIntel.IMAPConfig.IMAPSize = 32
            self.BrainIntel.IMAPConfig.Rings = 2
        elseif maxmapdimension == 1024 then
            self.BrainIntel.IMAPConfig.OgridRadius = 45.0
            self.BrainIntel.IMAPConfig.IMAPSize = 64
            self.BrainIntel.IMAPConfig.Rings = 1
        elseif maxmapdimension == 2048 then
            self.BrainIntel.IMAPConfig.OgridRadius = 89.5
            self.BrainIntel.IMAPConfig.IMAPSize = 128
            self.BrainIntel.IMAPConfig.Rings = 0
        else
            self.BrainIntel.IMAPConfig.OgridRadius = 180.0
            self.BrainIntel.IMAPConfig.IMAPSize = 256
            self.BrainIntel.IMAPConfig.Rings = 0
        end
    end,

    TacticalMonitorRNG = function(self, ALLBPS)
        -- Tactical Monitor function. Keeps an eye on the battlefield and takes points of interest to investigate.
        WaitTicks(Random(1,7))
        LOG('* AI-RNG: Tactical Monitor Threat Pass')
        local enemyBrains = {}
        local multiplier
        local enemyStarts = self.EnemyIntel.EnemyStartLocations
        local startX, startZ = self:GetArmyStartPos()
        --LOG('Upgrade Mode is  '..self.UpgradeMode)
        if self.CheatEnabled then
            multiplier = tonumber(ScenarioInfo.Options.BuildMult)
        else
            multiplier = 1
        end

        local gameTime = GetGameTimeSeconds()
        --LOG('gameTime is '..gameTime..' Upgrade Mode is '..self.UpgradeMode)
        if self.EnemyIntel.EnemyCount < 2 and gameTime < (240 / multiplier) then
            self.UpgradeMode = 'Caution'
        elseif gameTime > (240 / multiplier) and self.UpgradeMode == 'Caution' then
            --LOG('Setting UpgradeMode to Normal')
            self.UpgradeMode = 'Normal'
            self.UpgradeIssuedLimit = 1
        elseif gameTime > (240 / multiplier) and self.UpgradeIssuedLimit == 1 and self.UpgradeMode == 'Aggresive' then
            self.UpgradeIssuedLimit = self.UpgradeIssuedLimit + 1
        end
        self.EnemyIntel.EnemyThreatLocations = {}
        

        --LOG('Current Threat Location Table'..repr(self.EnemyIntel.EnemyThreatLocations))
        --[[if RNGGETN(self.EnemyIntel.EnemyThreatLocations) > 0 then
            for k, v in self.EnemyIntel.EnemyThreatLocations do
                --LOG('Game time : Insert Time : Timeout'..gameTime..':'..v.InsertTime..':'..timeout)
                if (gameTime - v.InsertTime) > self.TacticalMonitor.TacticalTimeout then
                    self.EnemyIntel.EnemyThreatLocations[k] = nil
                end
            end
            if self.EnemyIntel.EnemyThreatLocations then
                self.EnemyIntel.EnemyThreatLocations = self:RebuildTable(self.EnemyIntel.EnemyThreatLocations)
            end
        end]]
        -- Rebuild the self threat tables
        --LOG('SelfThreat Table count:'..RNGGETN(self.BrainIntel.SelfThreat))
        --LOG('SelfThreat Table present:'..repr(self.BrainIntel.SelfThreat))
        --[[if self.BrainIntel.SelfThreat then
            for k, v in self.BrainIntel.SelfThreat.Air do
                --LOG('Game time : Insert Time : Timeout'..gameTime..':'..v.InsertTime..':'..timeout)
                if (gameTime - v.InsertTime) > self.TacticalMonitor.TacticalTimeout then
                    self.BrainIntel.SelfThreat.Air[k] = nil
                end
            end
            if self.BrainIntel.SelfThreat.Air then
                self.BrainIntel.SelfThreat.Air = self:RebuildTable(self.BrainIntel.SelfThreat.Air)
            end
        end]]
        -- debug, remove later on
        if enemyStarts then
            --LOG('* AI-RNG: Enemy Start Locations :'..repr(enemyStarts))
        end
        local selfIndex = self:GetArmyIndex()
        local potentialThreats = {}
        local threatTypes = {
            'Land',
            'AntiAir',
            'Naval',
            'StructuresNotMex',
            --'AntiSurface'
        }
        -- Get threats for each threat type listed on the threatTypes table. Full map scan.
        for _, t in threatTypes do
            rawThreats = GetThreatsAroundPosition(self, self.BuilderManagers.MAIN.Position, 16, true, t)
            for _, raw in rawThreats do
                local threatRow = {posX=raw[1], posZ=raw[2], rThreat=raw[3], rThreatType=t}
                RNGINSERT(potentialThreats, threatRow)
            end
        end
        --LOG('Potential Threats :'..repr(potentialThreats))
        WaitTicks(2)
        local phaseTwoThreats = {}
        local threatLimit = 20
        -- Set a raw threat table that is replaced on each loop so we can get a snapshot of current enemy strength across the map.
        self.EnemyIntel.EnemyThreatRaw = potentialThreats

        -- Remove threats that are too close to the enemy base so we are focused on whats happening in the battlefield.
        -- Also set if the threat is on water or not
        -- Set the time the threat was identified so we can flush out old entries
        -- If you want the full map thats what EnemyThreatRaw is for.
        if RNGGETN(potentialThreats) > 0 then
            local threatLocation = {}
            for _, threat in potentialThreats do
                --LOG('* AI-RNG: Threat is'..repr(threat))
                if threat.rThreat > threatLimit then
                    --LOG('* AI-RNG: Tactical Potential Interest Location Found at :'..repr(threat))
                    if RUtils.PositionOnWater(threat.posX, threat.posZ) then
                        onWater = true
                    else
                        onWater = false
                    end
                    threatLocation = {Position = {threat.posX, threat.posZ}, EnemyBaseRadius = false, Threat=threat.rThreat, ThreatType=threat.rThreatType, PositionOnWater=onWater }
                    RNGINSERT(phaseTwoThreats, threatLocation)
                end
            end
            --LOG('* AI-RNG: Pre Sorted Potential Valid Threat Locations :'..repr(phaseTwoThreats))
            for _, threat in phaseTwoThreats do
                for q, pos in enemyStarts do
                    --LOG('* AI-RNG: Distance Between Threat and Start Position :'..VDist2Sq(threat.posX, threat.posZ, pos[1], pos[3]))
                    if VDist2Sq(threat.Position[1], threat.Position[2], pos[1], pos[3]) < 10000 then
                        threat.EnemyBaseRadius = true
                    end
                end
            end
            --[[for Index_1, value_1 in phaseTwoThreats do
                for Index_2, value_2 in phaseTwoThreats do
                    -- no need to check against self
                    if Index_1 == Index_2 then 
                        continue
                    end
                    -- check if we have the same position
                    --LOG('* AI-RNG: checking '..repr(value_1.Position)..' == '..repr(value_2.Position))
                    if value_1.Position[1] == value_2.Position[1] and value_1.Position[2] == value_2.Position[2] then
                        --LOG('* AI-RNG: eual position '..repr(value_1.Position)..' == '..repr(value_2.Position))
                        if value_1.EnemyBaseRadius == false then
                            --LOG('* AI-RNG: deleating '..repr(value_1))
                            phaseTwoThreats[Index_1] = nil
                            break
                        elseif value_2.EnemyBaseRadius == false then
                            --LOG('* AI-RNG: deleating '..repr(value_2))
                            phaseTwoThreats[Index_2] = nil
                            break
                        else
                            --LOG('* AI-RNG: Both entires have true, deleting nothing')
                        end
                    end
                end
            end]]
            --LOG('* AI-RNG: second table pass :'..repr(potentialThreats))
            local currentGameTime = GetGameTimeSeconds()
            for _, threat in phaseTwoThreats do
                threat.InsertTime = currentGameTime
                RNGINSERT(self.EnemyIntel.EnemyThreatLocations, threat)
            end
            LOG('* AI-RNG: Final Valid Threat Locations :'..repr(self.EnemyIntel.EnemyThreatLocations))
        end
        WaitTicks(2)

        local landThreatAroundBase = 0
        --LOG(repr(self.EnemyIntel.EnemyThreatLocations))
        if RNGGETN(self.EnemyIntel.EnemyThreatLocations) > 0 then
            for k, threat in self.EnemyIntel.EnemyThreatLocations do
                if threat.ThreatType == 'Land' then
                    local threatDistance = VDist2Sq(startX, startZ, threat.Position[1], threat.Position[2])
                    if threatDistance < 32400 then
                        landThreatAroundBase = landThreatAroundBase + threat.Threat
                    end
                end
            end
            --LOG('Total land threat around base '..landThreatAroundBase)
            if (gameTime < 900) and (landThreatAroundBase > 30) then
                --LOG('BaseThreatCaution True')
                self.BrainIntel.SelfThreat.BaseThreatCaution = true
            elseif (gameTime > 900) and (landThreatAroundBase > 60) then
                --LOG('BaseThreatCaution True')
                self.BrainIntel.SelfThreat.BaseThreatCaution = true
            else
                --LOG('BaseThreatCaution False')
                self.BrainIntel.SelfThreat.BaseThreatCaution = false
            end
        end
        
        if (gameTime > 1200 and self.BrainIntel.SelfThreat.AllyExtractorCount > self.BrainIntel.SelfThreat.MassMarker / 1.5) or self.EnemyIntel.ChokeFlag then
            --LOG('Switch to agressive upgrade mode')
            self.UpgradeMode = 'Aggressive'
            self.EcoManager.ExtractorUpgradeLimit.TECH1 = 2
        elseif gameTime > 1200 then
            --LOG('Switch to normal upgrade mode')
            self.UpgradeMode = 'Normal'
            self.EcoManager.ExtractorUpgradeLimit.TECH1 = 1
        end
        
        --LOG('Ally Count is '..self.BrainIntel.AllyCount)
        --LOG('Enemy Count is '..self.EnemyIntel.EnemyCount)
        --LOG('Eco Costing Multiplier is '..self.EcoManager.EcoMultiplier)
        --LOG('Current Self Sub Threat :'..self.BrainIntel.SelfThreat.NavalSubNow)
        --LOG('Current Enemy Sub Threat :'..self.EnemyIntel.EnemyThreatCurrent.NavalSub)
        --LOG('Current Self Air Threat :'..self.BrainIntel.SelfThreat.AirNow)
        --LOG('Current Self AntiAir Threat :'..self.BrainIntel.SelfThreat.AntiAirNow)
        --LOG('Current Enemy Air Threat :'..self.EnemyIntel.EnemyThreatCurrent.Air)
        --LOG('Current Enemy AntiAir Threat :'..self.EnemyIntel.EnemyThreatCurrent.AntiAir)
        --LOG('Current Enemy Extractor Threat :'..self.EnemyIntel.EnemyThreatCurrent.Extractor)
        --LOG('Current Enemy Extractor Count :'..self.EnemyIntel.EnemyThreatCurrent.ExtractorCount)
        --LOG('Current Self Extractor Threat :'..self.BrainIntel.SelfThreat.Extractor)
        --LOG('Current Self Extractor Count :'..self.BrainIntel.SelfThreat.ExtractorCount)
        --LOG('Current Mass Marker Count :'..self.BrainIntel.SelfThreat.MassMarker)
        --LOG('Current Defense Air Threat :'..self.EnemyIntel.EnemyThreatCurrent.DefenseAir)
        --LOG('Current Defense Sub Threat :'..self.EnemyIntel.EnemyThreatCurrent.DefenseSub)
        --LOG('Current Enemy Land Threat :'..self.EnemyIntel.EnemyThreatCurrent.Land)
        --LOG('Current Number of Enemy Gun ACUs :'..self.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades)
        WaitTicks(2)
    end,

    TacticalThreatAnalysisRNG = function(self, ALLBPS)

        self.EnemyIntel.DirectorData = {
            DefenseCluster = {},
            Strategic = {},
            Energy = {},
            Intel = {},
            Defense = {},
            Factory = {},
            Mass = {},
            Factory = {},
            Combat = {},
        }
        local energyUnits = {}
        local strategicUnits = {}
        local defensiveUnits = {}
        local intelUnits = {}
        local factoryUnits = {}
        local gameTime = GetGameTimeSeconds()
        local scanRadius = 0
        local IMAPSize = 0
        local maxmapdimension = math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])
        self.EnemyIntel.EnemyLandFireBaseDetected = false
        self.EnemyIntel.EnemyAirFireBaseDetected = false

        if maxmapdimension == 256 then
            scanRadius = 11.5
            IMAPSize = 16
        elseif maxmapdimension == 512 then
            scanRadius = 22.5
            IMAPSize = 32
        elseif maxmapdimension == 1024 then
            scanRadius = 45.0
            IMAPSize = 64
        elseif maxmapdimension == 2048 then
            scanRadius = 89.5
            IMAPSize = 128
        else
            scanRadius = 180.0
            IMAPSize = 256
        end
        
        if RNGGETN(self.EnemyIntel.EnemyThreatLocations) > 0 then
            for k, threat in self.EnemyIntel.EnemyThreatLocations do
                if (gameTime - threat.InsertTime) < 25 and threat.ThreatType == 'StructuresNotMex' then
                    local unitsAtLocation = GetUnitsAroundPoint(self, categories.STRUCTURE - categories.WALL - categories.MASSEXTRACTION, {threat.Position[1], 0, threat.Position[2]}, scanRadius, 'Enemy')
                    for s, unit in unitsAtLocation do
                        local unitIndex = unit:GetAIBrain():GetArmyIndex()
                        if not ArmyIsCivilian(unitIndex) then
                            if EntityCategoryContains( categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL), unit) then
                                --LOG('Inserting Enemy Energy Structure '..unit.UnitId)
                                RNGINSERT(energyUnits, {EnemyIndex = unitIndex, Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel * 2, Object = unit, Shielded = RUtils.ShieldProtectingTargetRNG(self, unit), IMAP = threat.Position, Air = 0, Land = 0 })
                            elseif EntityCategoryContains( categories.DEFENSE * (categories.TECH2 + categories.TECH3), unit) then
                                --LOG('Inserting Enemy Defensive Structure '..unit.UnitId)
                                RNGINSERT(defensiveUnits, {EnemyIndex = unitIndex, Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, Object = unit, Shielded = RUtils.ShieldProtectingTargetRNG(self, unit), IMAP = threat.Position, Air = 0, Land = 0 })
                            elseif EntityCategoryContains( categories.STRATEGIC * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL), unit) then
                                --LOG('Inserting Enemy Strategic Structure '..unit.UnitId)
                                RNGINSERT(strategicUnits, {EnemyIndex = unitIndex, Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, Object = unit, Shielded = RUtils.ShieldProtectingTargetRNG(self, unit), IMAP = threat.Position, Air = 0, Land = 0 })
                            elseif EntityCategoryContains( categories.INTELLIGENCE * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL), unit) then
                                --LOG('Inserting Enemy Intel Structure '..unit.UnitId)
                                RNGINSERT(intelUnits, {EnemyIndex = unitIndex, Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, Object = unit, Shielded = RUtils.ShieldProtectingTargetRNG(self, unit), IMAP = threat.Position, Air = 0, Land = 0 })
                            elseif EntityCategoryContains( categories.FACTORY * (categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY - categories.EXPERIMENTAL - categories.CRABEGG - categories.CARRIER, unit) then
                                --LOG('Inserting Enemy Intel Structure '..unit.UnitId)
                                RNGINSERT(factoryUnits, {EnemyIndex = unitIndex, Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, Object = unit, Shielded = RUtils.ShieldProtectingTargetRNG(self, unit), IMAP = threat.Position, Air = 0, Land = 0 })
                            end
                        end
                    end
                    WaitTicks(1)
                end
            end
        end
        if RNGGETN(energyUnits) > 0 then
            for k, unit in energyUnits do
                for k, threat in self.EnemyIntel.EnemyThreatLocations do
                    if table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'AntiAir' then
                        unit.Air = threat.Threat
                    elseif table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'Land' then
                        unit.Land = threat.Threat
                    end
                end
                --LOG('Enemy Energy Structure has '..unit.Air..' air threat and '..unit.Land..' land threat'..' belonging to energy index '..unit.EnemyIndex)
                --LOG('Unit has an economic value of '..unit.Value)
            end
            self.EnemyIntel.DirectorData.Energy = energyUnits
        end
        WaitTicks(1)
        if RNGGETN(defensiveUnits) > 0 then
            for k, unit in defensiveUnits do
                for q, threat in self.EnemyIntel.EnemyThreatLocations do
                    if not self.EnemyIntel.EnemyThreatLocations[q].LandDefStructureCount then
                        self.EnemyIntel.EnemyThreatLocations[q].LandDefStructureCount = 0
                    end
                    if not self.EnemyIntel.EnemyThreatLocations[q].AirDefStructureCount then
                        self.EnemyIntel.EnemyThreatLocations[q].AirDefStructureCount = 0
                    end
                    if table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'AntiAir' then 
                        unit.Air = threat.Threat
                    elseif table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'Land' then
                        unit.Land = threat.Threat
                    elseif table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'StructuresNotMex' then
                        if ALLBPS[unit.Object.UnitId].Defense.SurfaceThreatLevel > 0 then
                            self.EnemyIntel.EnemyThreatLocations[q].LandDefStructureCount = self.EnemyIntel.EnemyThreatLocations[q].LandDefStructureCount + 1
                        elseif ALLBPS[unit.Object.UnitId].Defense.AirThreatLevel > 0 then
                            self.EnemyIntel.EnemyThreatLocations[q].AirDefStructureCount = self.EnemyIntel.EnemyThreatLocations[q].AirDefStructureCount + 1
                        end
                    end
                    if self.EnemyIntel.EnemyThreatLocations[q].LandDefStructureCount > 5 then
                        self.EnemyIntel.EnemyLandFireBaseDetected = true
                    end
                    if self.EnemyIntel.EnemyThreatLocations[q].AirDefStructureCount > 5 then
                        self.EnemyIntel.EnemyAirFireBaseDetected = true
                    end
                end
                --LOG('Enemy Defense Structure has '..unit.Air..' air threat and '..unit.Land..' land threat'..' belonging to energy index '..unit.EnemyIndex)
            end
            if self.EnemyIntel.EnemyLandFireBaseDetected then
                --LOG('EnemyLandFireBaseDetected is true')
            end
            self.EnemyIntel.DirectorData.Defense = defensiveUnits
        end
        WaitTicks(1)
        if RNGGETN(strategicUnits) > 0 then
            for k, unit in strategicUnits do
                for k, threat in self.EnemyIntel.EnemyThreatLocations do
                    if table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'AntiAir' then
                        unit.Air = threat.Threat
                    elseif table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'Land' then
                        unit.Land = threat.Threat
                    end
                end
                --LOG('Enemy Strategic Structure has '..unit.Air..' air threat and '..unit.Land..' land threat'..' belonging to energy index '..unit.EnemyIndex)
            end
            self.EnemyIntel.DirectorData.Strategic = strategicUnits
        end
        WaitTicks(1)
        if RNGGETN(intelUnits) > 0 then
            for k, unit in intelUnits do
                for k, threat in self.EnemyIntel.EnemyThreatLocations do
                    if table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'AntiAir' then
                        unit.Air = threat.Threat
                    elseif table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'Land' then
                        unit.Land = threat.Threat
                    end
                end
                --LOG('Enemy Intel Structure has '..unit.Air..' air threat and '..unit.Land..' land threat'..' belonging to energy index '..unit.EnemyIndex.. ' Unit ID is '..unit.Object.UnitId)
            end
            self.EnemyIntel.DirectorData.Intel = intelUnits
        end
        if RNGGETN(factoryUnits) > 0 then
            for k, unit in factoryUnits do
                for k, threat in self.EnemyIntel.EnemyThreatLocations do
                    if table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'AntiAir' then
                        unit.Air = threat.Threat
                    elseif table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'Land' then
                        unit.Land = threat.Threat
                    end
                end
                --LOG('Enemy Factory HQ Structure has '..unit.Air..' air threat and '..unit.Land..' land threat'..' belonging to energy index '..unit.EnemyIndex)
                --LOG('Unit has an economic value of '..unit.Value)
            end
            self.EnemyIntel.DirectorData.Factory = factoryUnits
        end
        WaitTicks(1)
    end,

    CheckDirectorTargetAvailable = function(self, threatType, platoonThreat)
        local potentialTarget = false
        local targetType = false
        local potentialTargetValue = 0

        if self.EnemyIntel.DirectorData.Intel and RNGGETN(self.EnemyIntel.DirectorData.Intel) > 0 then
            for k, v in self.EnemyIntel.DirectorData.Intel do
                --LOG('Intel Target Data ')
                --LOG('Air Threat Around unit is '..v.Air)
                --LOG('Land Threat Around unit is '..v.Land)
                --LOG('Enemy Index of unit is '..v.EnemyIndex)
                --LOG('Unit ID is '..v.Object.UnitId)
                if v.Value > potentialTargetValue and v.Object and (not v.Object.Dead) and (not v.Shielded) then
                    if threatType and platoonThreat then
                        if threatType == 'AntiAir' then
                            if v.Air > platoonThreat then
                                continue
                            end
                        elseif threatType == 'Land' then
                            if v.Land > platoonThreat then
                                continue
                            end
                        end
                    end
                    potentialTargetValue = v.Value
                    potentialTarget = v.Object
                end
            end
        end
        if self.EnemyIntel.DirectorData.Energy and RNGGETN(self.EnemyIntel.DirectorData.Energy) > 0 then
            for k, v in self.EnemyIntel.DirectorData.Energy do
                --LOG('Energy Target Data ')
                --LOG('Air Threat Around unit is '..v.Air)
                --LOG('Land Threat Around unit is '..v.Land)
                --LOG('Enemy Index of unit is '..v.EnemyIndex)
                --LOG('Unit ID is '..v.Object.UnitId)
                if v.Value > potentialTargetValue and v.Object and not v.Object.Dead and (not v.Shielded) then
                    if threatType and platoonThreat then
                        if threatType == 'AntiAir' then
                            if v.Air > platoonThreat then
                                continue
                            end
                        elseif threatType == 'Land' then
                            if v.Land > platoonThreat then
                                continue
                            end
                        end
                    end
                    potentialTargetValue = v.Value
                    potentialTarget = v.Object
                end
            end
        end
        if self.EnemyIntel.DirectorData.Factory and RNGGETN(self.EnemyIntel.DirectorData.Factory) > 0 then
            for k, v in self.EnemyIntel.DirectorData.Factory do
                --LOG('Energy Target Data ')
                --LOG('Air Threat Around unit is '..v.Air)
                --LOG('Land Threat Around unit is '..v.Land)
                --LOG('Enemy Index of unit is '..v.EnemyIndex)
                --LOG('Unit ID is '..v.Object.UnitId)
                if v.Value > potentialTargetValue and v.Object and not v.Object.Dead and (not v.Shielded) then
                    if threatType and platoonThreat then
                        if threatType == 'AntiAir' then
                            if v.Air > platoonThreat then
                                continue
                            end
                        elseif threatType == 'Land' then
                            if v.Land > platoonThreat then
                                continue
                            end
                        end
                    end
                    potentialTargetValue = v.Value
                    potentialTarget = v.Object
                end
            end
        end
        if self.EnemyIntel.DirectorData.Strategic and RNGGETN(self.EnemyIntel.DirectorData.Strategic) > 0 then
            for k, v in self.EnemyIntel.DirectorData.Strategic do
                --LOG('Energy Target Data ')
                --LOG('Air Threat Around unit is '..v.Air)
                --LOG('Land Threat Around unit is '..v.Land)
                --LOG('Enemy Index of unit is '..v.EnemyIndex)
                --LOG('Unit ID is '..v.Object.UnitId)
                if v.Value > potentialTargetValue and v.Object and not v.Object.Dead and (not v.Shielded) then
                    if threatType and platoonThreat then
                        if threatType == 'AntiAir' then
                            if v.Air > platoonThreat then
                                continue
                            end
                        elseif threatType == 'Land' then
                            if v.Land > platoonThreat then
                                continue
                            end
                        end
                    end
                    potentialTargetValue = v.Value
                    potentialTarget = v.Object
                end
            end
        end
        if potentialTarget and not potentialTarget.Dead then
            --LOG('Target being returned is '..potentialTarget.UnitId)
            return potentialTarget
        end
        return false
    end,
    
    EcoExtractorUpgradeCheckRNG = function(self)
        -- Keep track of how many extractors are currently upgrading
            WaitTicks(Random(1,7))
            while true do
                local upgradingExtractors = RUtils.ExtractorsBeingUpgraded(self)
                self.EcoManager.ExtractorsUpgrading.TECH1 = upgradingExtractors.TECH1
                self.EcoManager.ExtractorsUpgrading.TECH2 = upgradingExtractors.TECH2
                WaitTicks(30)
            end
        end,

    EcoMassManagerRNG = function(self)
    -- Watches for low power states
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                if GetGameTimeSeconds() < 240 then
                    WaitTicks(50)
                    continue
                end
                local massStateCaution = self:EcoManagerMassStateCheck()
                local unitTypePaused = false
                
                if massStateCaution then
                    --LOG('massStateCaution State Caution is true')
                    local massCycle = 0
                    local unitTypePaused = {}
                    while massStateCaution do
                        local massPriorityTable = {}
                        local priorityNum = 0
                        local priorityUnit = false
                        --LOG('Threat Stats Self + ally :'..self.BrainIntel.SelfThreat.LandNow + self.BrainIntel.SelfThreat.AllyLandThreat..'Enemy : '..self.EnemyIntel.EnemyThreatCurrent.Land)
                        if (self.BrainIntel.SelfThreat.LandNow + self.BrainIntel.SelfThreat.AllyLandThreat) > (self.EnemyIntel.EnemyThreatCurrent.Land * 1.3) then
                            massPriorityTable = self.EcoManager.MassPriorityTable.Advantage
                            --LOG('Land threat advantage mass priority table')
                        else
                            massPriorityTable = self.EcoManager.MassPriorityTable.Disadvantage
                            --LOG('Land thread disadvantage mass priority table')
                        end
                        massCycle = massCycle + 1
                        for k, v in massPriorityTable do
                            local priorityUnitAlreadySet = false
                            for l, b in unitTypePaused do
                                if k == b then
                                    priorityUnitAlreadySet = true
                                end
                            end
                            if priorityUnitAlreadySet then
                                --LOG('priorityUnit already in unitTypePaused, skipping')
                                continue
                            end
                            if v > priorityNum then
                                priorityNum = v
                                priorityUnit = k
                            end
                        end
                        if priorityUnit == 'ENGINEER' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            --LOG('Engineer added to unitTypePaused')
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Engineers, 'pause', 'MASS')
                        elseif priorityUnit == 'STATIONPODS' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, StationPods, 'pause', 'MASS')
                        elseif priorityUnit == 'AIR' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.AIR) * (categories.TECH1 + categories.SUPPORTFACTORY), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'LAND' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * (categories.TECH1 + categories.SUPPORTFACTORY), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'NAVAL' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'MASSEXTRACTION' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Extractors = GetListOfUnits(self, categories.STRUCTURE * categories.MASSEXTRACTION - categories.EXPERIMENTAL, false, false)
                            --LOG('Number of mass extractors'..RNGGETN(Extractors))
                            self:EcoSelectorManagerRNG(priorityUnit, Extractors, 'pause', 'MASS')
                        elseif priorityUnit == 'NUKE' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Nukes, 'pause', 'MASS')
                        elseif priorityUnit == 'TML' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, TMLs, 'pause', 'MASS')
                        end
                        WaitTicks(20)
                        massStateCaution = self:EcoManagerMassStateCheck()
                        if massStateCaution then
                            --LOG('Power State Caution still true after first pass')
                            if massCycle > 8 then
                                --LOG('Power Cycle Threashold met, waiting longer')
                                WaitTicks(100)
                                massCycle = 0
                            end
                        else
                            --LOG('Power State Caution is now false')
                        end
                        WaitTicks(5)
                        --LOG('unitTypePaused table is :'..repr(unitTypePaused))
                    end
                    for k, v in unitTypePaused do
                        if v == 'ENGINEER' then
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND, false, false)
                            self:EcoSelectorManagerRNG(v, Engineers, 'unpause', 'MASS')
                        elseif v == 'STATIONPODS' then
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(v, StationPods, 'unpause', 'MASS')
                        elseif v == 'AIR' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'MASS')
                        elseif v == 'LAND' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'MASS')
                        elseif v == 'NAVAL' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'MASS')
                        elseif v == 'MASSEXTRACTION' then
                            local Extractors = GetListOfUnits(self, categories.STRUCTURE * categories.MASSEXTRACTION - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(v, Extractors, 'unpause', 'MASS')
                        elseif v == 'NUKE' then
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(v, Nukes, 'unpause', 'MASS')
                        elseif v == 'TML' then
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(v, TMLs, 'unpause', 'MASS')
                        end
                    end
                    massStateCaution = false
                end
            end
            WaitTicks(20)
        end
    end,

    --[[EcoManagerPowerStateCheck = function(self)

        local stallTime = GetEconomyStored(self, 'ENERGY') / ((GetEconomyRequested(self, 'ENERGY') * 10) - (GetEconomyIncome(self, 'ENERGY') * 10))
        --LOG('Time to stall for '..stallTime)
        if stallTime >= 0.0 then
            if stallTime < 20 then
                return true
            elseif stallTime > 20 then
                return false
            end
        end
        return false
    end,]]

    EcoManagerMassStateCheck = function(self)
        if GetEconomyTrend(self, 'MASS') <= 0.0 and GetEconomyStored(self, 'MASS') <= 200 then
            return true
        end
        return false
    end,

    EcoManagerPowerStateCheck = function(self)
        if GetEconomyTrend(self, 'ENERGY') <= 0.0 and GetEconomyStoredRatio(self, 'ENERGY') <= 0.2 then
            return true
        end
        return false
    end,
    
    EcoPowerManagerRNG = function(self)
        -- Watches for low power states
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                if GetGameTimeSeconds() < 300 then
                    WaitTicks(50)
                    continue
                end
                local powerStateCaution = self:EcoManagerPowerStateCheck()
                local unitTypePaused = false
                
                if powerStateCaution then
                    --LOG('Power State Caution is true')
                    local powerCycle = 0
                    local unitTypePaused = {}
                    while powerStateCaution do
                        local priorityNum = 0
                        local priorityUnit = false
                        powerCycle = powerCycle + 1
                        for k, v in self.EcoManager.PowerPriorityTable do
                            local priorityUnitAlreadySet = false
                            for l, b in unitTypePaused do
                                if k == b then
                                    priorityUnitAlreadySet = true
                                end
                            end
                            if priorityUnitAlreadySet then
                                --LOG('priorityUnit already in unitTypePaused, skipping')
                                continue
                            end
                            if v > priorityNum then
                                priorityNum = v
                                priorityUnit = k
                            end
                        end
                        --LOG('Doing anti power stall stuff for :'..priorityUnit)
                        if priorityUnit == 'ENGINEER' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            --LOG('Engineer added to unitTypePaused')
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND , false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Engineers, 'pause', 'ENERGY')
                        elseif priorityUnit == 'STATIONPODS' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, StationPods, 'pause', 'ENERGY')
                        elseif priorityUnit == 'AIR' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'LAND' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * (categories.TECH1 + categories.SUPPORTFACTORY), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'NAVAL' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'SHIELD' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Shields = GetListOfUnits(self, categories.STRUCTURE * categories.SHIELD - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Shields, 'pause', 'ENERGY')
                        elseif priorityUnit == 'TML' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, TMLs, 'pause', 'ENERGY')
                        elseif priorityUnit == 'RADAR' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Radars = GetListOfUnits(self, categories.STRUCTURE * (categories.RADAR + categories.SONAR), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Radars, 'pause', 'ENERGY')
                        elseif priorityUnit == 'MASSFABRICATION' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local MassFabricators = GetListOfUnits(self, categories.STRUCTURE * categories.MASSFABRICATION, false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, MassFabricators, 'pause', 'ENERGY')
                        elseif priorityUnit == 'NUKE' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(priorityUnit, Nukes, 'pause', 'ENERGY')
                        end
                        WaitTicks(20)
                        powerStateCaution = self:EcoManagerPowerStateCheck()
                        if powerStateCaution then
                            --LOG('Power State Caution still true after first pass')
                            if powerCycle > 11 then
                                --LOG('Power Cycle Threashold met, waiting longer')
                                WaitTicks(100)
                                powerCycle = 0
                            end
                        else
                            --LOG('Power State Caution is now false')
                        end
                        WaitTicks(5)
                        --LOG('unitTypePaused table is :'..repr(unitTypePaused))
                    end
                    for k, v in unitTypePaused do
                        if v == 'ENGINEER' then
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND, false, false)
                            self:EcoSelectorManagerRNG(v, Engineers, 'unpause', 'ENERGY')
                        elseif v == 'STATIONPODS' then
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(v, StationPods, 'unpause', 'ENERGY')
                        elseif v == 'AIR' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'ENERGY')
                        elseif v == 'LAND' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'ENERGY')
                        elseif v == 'NAVAL' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'ENERGY')
                        elseif v == 'SHIELD' then
                            local Shields = GetListOfUnits(self, categories.STRUCTURE * categories.SHIELD - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(v, Shields, 'unpause', 'ENERGY')
                        elseif v == 'MASSFABRICATION' then
                            local MassFabricators = GetListOfUnits(self, categories.STRUCTURE * categories.MASSFABRICATION, false, false)
                            self:EcoSelectorManagerRNG(v, MassFabricators, 'unpause', 'ENERGY')
                        elseif v == 'NUKE' then
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(v, Nukes, 'unpause', 'ENERGY')
                        elseif v == 'TML' then
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(v, TMLs, 'unpause', 'ENERGY')
                        end
                    end
                    powerStateCaution = false
                end
            end
            WaitTicks(20)
        end
    end,

    FactoryEcoManagerRNG = function(self)
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                if GetGameTimeSeconds() < 240 then
                    WaitTicks(50)
                    continue
                end
                local massStateCaution = self:EcoManagerMassStateCheck()
                local unitTypePaused = false
                local factType = 'Land'
                if massStateCaution then
                    if self.cmanager.categoryspend.fact['Land'] > (self.cmanager.income.r.m * self.ProductionRatios['Land']) then
                        local deficit = self.cmanager.categoryspend.fact['Land'] - (self.cmanager.income.r.m * self.ProductionRatios['Land'])
                        --LOG('Land Factory Deficit is '..deficit)
                        if self.BuilderManagers then
                            for k, v in self.BuilderManagers do
                                if self.BuilderManagers[k].FactoryManager then
                                    if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if EntityCategoryContains(categories.TECH1 * categories.LAND, f) then
                                                if not f.Offline then
                                                    f.Offline = true
                                                    --LOG('Land T1 Factory Taken offline')
                                                    deficit = deficit - 4
                                                end
                                            elseif EntityCategoryContains(categories.TECH2 * categories.LAND, f) then
                                                if not f.Offline then
                                                    f.Offline = true
                                                    --LOG('Land T2 Factory Taken offline')
                                                    deficit = deficit - 7
                                                end
                                            elseif EntityCategoryContains(categories.TECH3 * categories.LAND, f) then
                                                if not f.Offline then
                                                    f.Offline = true
                                                    --LOG('Land T3 Factory Taken offline')
                                                    deficit = deficit - 16
                                                end
                                            end
                                            if deficit <= 0 then
                                                break
                                            end
                                        end
                                    end
                                end
                                if deficit <= 0 then
                                    break
                                end
                            end
                        end
                    end
                    if self.cmanager.categoryspend.fact['Air'] > (self.cmanager.income.r.m * self.ProductionRatios['Air']) then
                        local deficit = self.cmanager.categoryspend.fact['Air'] - (self.cmanager.income.r.m * self.ProductionRatios['Air'])
                        --LOG('Air Factory Deficit is '..deficit)
                        if self.BuilderManagers then
                            for k, v in self.BuilderManagers do
                                if self.BuilderManagers[k].FactoryManager then
                                    if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if EntityCategoryContains(categories.TECH1 * categories.AIR, f) then
                                                if not f.Offline then
                                                    f.Offline = true
                                                    --LOG('Air T1 Factory Taken offline')
                                                    deficit = deficit - 4
                                                end
                                            elseif EntityCategoryContains(categories.TECH2 * categories.AIR, f) then
                                                if not f.Offline then
                                                    f.Offline = true
                                                    --LOG('Air T2 Factory Taken offline')
                                                    deficit = deficit - 7
                                                end
                                            elseif EntityCategoryContains(categories.TECH3 * categories.AIR, f) then
                                                if not f.Offline then
                                                    f.Offline = true
                                                    --LOG('Air T3 Factory Taken offline')
                                                    deficit = deficit - 16
                                                end
                                            end
                                            if deficit <= 0 then
                                                break
                                            end
                                        end
                                    end
                                end
                                if deficit <= 0 then
                                    break
                                end
                            end
                        end
                    end
                    if self.cmanager.categoryspend.fact['Naval'] > (self.cmanager.income.r.m * self.ProductionRatios['Naval']) then
                        local deficit = self.cmanager.categoryspend.fact['Naval'] - (self.cmanager.income.r.m * self.ProductionRatios['Naval'])
                        --LOG('Naval Factory Deficit is '..deficit)
                        if self.BuilderManagers then
                            for k, v in self.BuilderManagers do
                                if self.BuilderManagers[k].FactoryManager then
                                    if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                        for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                            if EntityCategoryContains(categories.TECH1 * categories.NAVAL, f) then
                                                if not f.Offline then
                                                    f.Offline = true
                                                    --LOG('Naval T1 Factory Taken offline')
                                                    deficit = deficit - 4
                                                end
                                            elseif EntityCategoryContains(categories.TECH2 * categories.NAVAL, f) then
                                                if not f.Offline then
                                                    f.Offline = true
                                                    --LOG('Naval T2 Factory Taken offline')
                                                    deficit = deficit - 7
                                                end
                                            elseif EntityCategoryContains(categories.TECH3 * categories.NAVAL, f) then
                                                if not f.Offline then
                                                    f.Offline = true
                                                    --LOG('Naval T3 Factory Taken offline')
                                                    deficit = deficit - 16
                                                end
                                            end
                                            if deficit <= 0 then
                                                break
                                            end
                                        end
                                    end
                                end
                                if deficit <= 0 then
                                    break
                                end
                            end
                        end
                    end
                end
                if self.cmanager.categoryspend.fact['Land'] < (self.cmanager.income.r.m * self.ProductionRatios['Land']) then
                    local surplus = (self.cmanager.income.r.m * self.ProductionRatios['Land']) - self.cmanager.categoryspend.fact['Land']
                    --LOG('Land Factory Surplus is '..surplus)
                    if self.BuilderManagers then
                        for k, v in self.BuilderManagers do
                            if self.BuilderManagers[k].FactoryManager then
                                if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                    for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                        if EntityCategoryContains(categories.TECH1 * categories.LAND, f) then
                                            if f.Offline then
                                                f.Offline = false
                                                --LOG('Land T1 Factory put online')
                                                surplus = surplus - 4
                                            end
                                        elseif EntityCategoryContains(categories.TECH2 * categories.LAND, f) then
                                            if f.Offline then
                                                f.Offline = false
                                                --LOG('Land T2 Factory put online')
                                                surplus = surplus - 7
                                            end
                                        elseif EntityCategoryContains(categories.TECH3 * categories.LAND, f) then
                                            if f.Offline then
                                                f.Offline = false
                                                --LOG('Land T3 Factory put online')
                                                surplus = surplus - 16
                                            end
                                        end
                                        if surplus <= 0 then
                                            break
                                        end
                                    end
                                end
                            end
                            if surplus <= 0 then
                                break
                            end
                        end
                    end
                end
                if self.cmanager.categoryspend.fact['Air'] < (self.cmanager.income.r.m * self.ProductionRatios['Air']) then
                    local surplus = (self.cmanager.income.r.m * self.ProductionRatios['Air']) - self.cmanager.categoryspend.fact['Air']
                    --LOG('Air Factory Surplus is '..surplus)
                    if self.BuilderManagers then
                        for k, v in self.BuilderManagers do
                            if self.BuilderManagers[k].FactoryManager then
                                if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                    for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                        if EntityCategoryContains(categories.TECH1 * categories.AIR, f) then
                                            if f.Offline then
                                                f.Offline = false
                                                --LOG('Air T1 Factory put online')
                                                surplus = surplus - 4
                                            end
                                        elseif EntityCategoryContains(categories.TECH2 * categories.AIR, f) then
                                            if f.Offline then
                                                f.Offline = false
                                                --LOG('Air T2 Factory put online')
                                                surplus = surplus - 7
                                            end
                                        elseif EntityCategoryContains(categories.TECH3 * categories.AIR, f) then
                                            if f.Offline then
                                                f.Offline = false
                                                --LOG('Air T3 Factory put online')
                                                surplus = surplus - 16
                                            end
                                        end
                                        if surplus <= 0 then
                                            break
                                        end
                                    end
                                end
                            end
                            if surplus <= 0 then
                                break
                            end
                        end
                    end
                end
                if self.cmanager.categoryspend.fact['Naval'] < (self.cmanager.income.r.m * self.ProductionRatios['Naval']) then
                    local surplus = (self.cmanager.income.r.m * self.ProductionRatios['Naval']) - self.cmanager.categoryspend.fact['Naval']
                    --LOG('Naval Factory Surplus is '..surplus)
                    if self.BuilderManagers then
                        for k, v in self.BuilderManagers do
                            if self.BuilderManagers[k].FactoryManager then
                                if RNGGETN(self.BuilderManagers[k].FactoryManager.FactoryList) > 1 then
                                    for _, f in self.BuilderManagers[k].FactoryManager.FactoryList do
                                        if EntityCategoryContains(categories.TECH1 * categories.NAVAL, f) then
                                            if f.Offline then
                                                f.Offline = false
                                                --LOG('Naval T1 Factory put online')
                                                surplus = surplus - 4
                                            end
                                        elseif EntityCategoryContains(categories.TECH2 * categories.NAVAL, f) then
                                            if f.Offline then
                                                f.Offline = false
                                                --LOG('Naval T2 Factory put online')
                                                surplus = surplus - 7
                                            end
                                        elseif EntityCategoryContains(categories.TECH3 * categories.NAVAL, f) then
                                            if f.Offline then
                                                f.Offline = false
                                                --LOG('Naval T3 Factory put online')
                                                surplus = surplus - 16
                                            end
                                        end
                                        if surplus <= 0 then
                                            break
                                        end
                                    end
                                end
                            end
                            if surplus <= 0 then
                                break
                            end
                        end
                    end
                end
            end
            --debug
            --[[
            local factories = GetListOfUnits(self, categories.FACTORY * categories.LAND, false, true)
            local offlineFactoryCount = 0
            local onlineFactoryCount = 0
            for k, v in factories do
                if v and not v.Dead then
                    if v.Offline then
                        offlineFactoryCount = offlineFactoryCount + 1
                    else
                        onlineFactoryCount = onlineFactoryCount + 1
                    end
                end
            end
            LOG('Offline Factory Count '..offlineFactoryCount)
            LOG('Online Factory Count '..onlineFactoryCount)]]

            WaitTicks(20)
        end
    end,
    
    EcoSelectorManagerRNG = function(self, priorityUnit, units, action, type)
        --LOG('Eco selector manager for '..priorityUnit..' is '..action..' Type is '..type)
        
        for k, v in units do
            if v.Dead then continue end
            if priorityUnit == 'ENGINEER' then
                --LOG('Priority Unit Is Engineer')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Engineer')
                    v:SetPaused(false)
                    continue
                end
                if EntityCategoryContains( categories.STRUCTURE * (categories.TACTICALMISSILEPLATFORM + categories.ANTIMISSILE + categories.MASSSTORAGE + categories.ENERGYSTORAGE + categories.SHIELD + categories.GATE) , v.UnitBeingBuilt) then
                    v:SetPaused(true)
                    continue
                end
                if not v.PlatoonHandle.PlatoonData.Assist.AssisteeType then continue end
                if not v.UnitBeingAssist then continue end
                if v:IsPaused() then continue end
                if type == 'ENERGY' and not EntityCategoryContains(categories.STRUCTURE * categories.ENERGYPRODUCTION, v.UnitBeingAssist) then
                    --LOG('Pausing Engineer')
                    v:SetPaused(true)
                    continue
                elseif type == 'MASS' then
                    v:SetPaused(true)
                    continue
                end
            elseif priorityUnit == 'STATIONPODS' then
                --LOG('Priority Unit Is STATIONPODS')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing STATIONPODS Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER * categories.TECH1, v.UnitBeingBuilt) then continue end
                if RNGGETN(units) == 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing STATIONPODS')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'AIR' then
                --LOG('Priority Unit Is AIR')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Air Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                if RNGGETN(units) == 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing AIR')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'NAVAL' then
                --LOG('Priority Unit Is NAVAL')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Naval Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                if RNGGETN(units) == 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing NAVAL')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'LAND' then
                --LOG('Priority Unit Is LAND')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Land Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                if RNGGETN(units) <= 2 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing LAND')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'MASSFABRICATION' or priorityUnit == 'SHIELD' or priorityUnit == 'RADAR' then
                --LOG('Priority Unit Is MASSFABRICATION or SHIELD')
                if action == 'unpause' then
                    if v.MaintenanceConsumption then continue end
                    --LOG('Unpausing MASSFABRICATION or SHIELD')
                    v:OnProductionUnpaused()
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if not v.MaintenanceConsumption then continue end
                --LOG('pausing MASSFABRICATION or SHIELD '..v.UnitId)
                v:OnProductionPaused()
            elseif priorityUnit == 'NUKE' then
                --LOG('Priority Unit Is Nuke')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Nuke')
                    v:SetPaused(false)
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing Nuke')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'TML' then
                --LOG('Priority Unit Is TML')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing TML')
                    v:SetPaused(false)
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing TML')
                v:SetPaused(true)
                continue
            elseif priorityUnit == 'MASSEXTRACTION' and action == 'unpause' then
                if not v:IsPaused() then continue end
                v:SetPaused( false )
                --LOG('Unpausing Extractor')
                continue
            end
            if priorityUnit == 'MASSEXTRACTION' and action == 'pause' then
                local upgradingBuilding = {}
                local upgradingBuildingNum = 0
                --LOG('Mass Extractor pause action, gathering upgrading extractors')
                for k, v in units do
                    if v
                        and not v.Dead
                        and not v:BeenDestroyed()
                        and not v:GetFractionComplete() < 1
                    then
                        if v:IsUnitState('Upgrading') then
                            if not v:IsPaused() then
                                RNGINSERT(upgradingBuilding, v)
                                --LOG('Upgrading Extractor not paused found')
                                upgradingBuildingNum = upgradingBuildingNum + 1
                            end
                        end
                    end
                end
                --LOG('Mass Extractor pause action, checking if more than one is upgrading')
                local upgradingTableSize = RNGGETN(upgradingBuilding)
                --LOG('Number of upgrading extractors is '..upgradingBuildingNum)
                if upgradingBuildingNum > 1 then
                    --LOG('pausing all but one upgrading extractor')
                    --LOG('UpgradingTableSize is '..upgradingTableSize)
                    for i=1, (upgradingTableSize - 1) do
                        upgradingBuilding[i]:SetPaused( true )
                        --UpgradingBuilding:SetCustomName('Upgrading paused')
                        --LOG('Upgrading paused')
                    end
                end
            end
        end
    end,

    EnemyChokePointTestRNG = function(self)
        local selfIndex = self:GetArmyIndex()
        local selfStartPos = self.BuilderManagers['MAIN'].Position
        local enemyTestTable = {}

        WaitTicks(100)
        if self.EnemyIntel.EnemyCount > 0 then
            for index, brain in ArmyBrains do
                if IsEnemy(selfIndex, index) and not ArmyIsCivilian(index) then
                    local posX, posZ = brain:GetArmyStartPos()
                    self.EnemyIntel.ChokePoints[index] = {
                        CurrentPathThreat = 0,
                        NoPath = false,
                        StartPosition = {posX, 0, posZ},
                    }
                end
            end
        end

        while true do
            if self.EnemyIntel.EnemyCount > 0 then
                for k, v in self.EnemyIntel.ChokePoints do
                    if not v.NoPath then
                        local path, reason, totalThreat = PlatoonGenerateSafePathToRNG(self, 'Land', selfStartPos, v.StartPosition, 1)
                        if path then
                            --LOG('Total Threat for path is '..totalThreat)
                            self.EnemyIntel.ChokePoints[k].CurrentPathThreat = (totalThreat / RNGGETN(path))
                            --LOG('We have a path to the enemy start position with an average of '..(totalThreat / RNGGETN(path)..' threat'))

                            if self.EnemyIntel.EnemyCount > 0 then
                                --LOG('Land Now Should be Greater than EnemyThreatcurrent divided by enemies')
                                --LOG('LandNow '..self.BrainIntel.SelfThreat.LandNow)
                                --LOG('EnemyThreatcurrent divided by enemies '..(self.EnemyIntel.EnemyThreatCurrent.Land / self.EnemyIntel.EnemyCount))
                                --LOG('EnemyDenseThreatSurface '..self.EnemyIntel.EnemyThreatCurrent.DefenseSurface..' should be greater than LandNow'..self.BrainIntel.SelfThreat.LandNow)
                                --LOG('Total Threat '..totalThreat..' Should be greater than LandNow '..self.BrainIntel.SelfThreat.LandNow)
                                if self.EnemyIntel.EnemyLandFireBaseDetected then
                                    --LOG('Firebase flag is true')
                                end
                                if self.BrainIntel.SelfThreat.LandNow > (self.EnemyIntel.EnemyThreatCurrent.Land / self.EnemyIntel.EnemyCount) 
                                and (self.EnemyIntel.EnemyThreatCurrent.DefenseSurface + self.EnemyIntel.EnemyThreatCurrent.DefenseAir) > self.BrainIntel.SelfThreat.LandNow
                                and totalThreat > self.BrainIntel.SelfThreat.LandNow 
                                and self.EnemyIntel.EnemyLandFireBaseDetected then
                                    self.EnemyIntel.ChokeFlag = true
                                    self.ProductionRatios.Land = 0.3
                                    --LOG('ChokeFlag is true')
                                elseif self.EnemyIntel.ChokeFlag then
                                    --LOG('ChokeFlag is false')
                                    self.EnemyIntel.ChokeFlag = false
                                    self.ProductionRatios.Land = self.DefaultLandRatio
                                end
                            end
                        elseif (not path and reason) then
                            --LOG('We dont have a path to the enemy start position, setting NoPath to true')
                            --LOG('Reason is '..reason)
                            self.EnemyIntel.ChokePoints[k].NoPath = true
                        else
                            WARN('AI-RNG : Chokepoint test has unexpected return')
                        end
                    end
                    --LOG('Current enemy chokepoint data for index '..k)
                    --LOG(repr(self.EnemyIntel.ChokePoints[k]))
                    WaitTicks(20)
                end
            end
            WaitTicks(1200)
        end
    end,

    EngineerAssistManagerBrainRNG = function(self, type)
        WaitTicks(1800)
        while true do
            self.EngineerAssistManagerPriorityTable = {
                MASSEXTRACTION = 1,
                POWER = 2
            }
            local massStorage = GetEconomyStored( self, 'MASS')
            local energyStorage = GetEconomyStored( self, 'ENERGY')
            --LOG('EngineerAssistManagerRNGMass Storage is : '..massStorage)
            --LOG('EngineerAssistManagerRNG Energy Storage is : '..energyStorage)
            if massStorage > 200 and energyStorage > 2000 then
                if self.EngineerAssistManagerBuildPower <= 15 and self.EngineerAssistManagerBuildPowerRequired <= 8 then
                    self.EngineerAssistManagerBuildPowerRequired = self.EngineerAssistManagerBuildPowerRequired + 5
                end
                --LOG('EngineerAssistManager is Active')
                self.EngineerAssistManagerActive = true
            else
                if self.EngineerAssistManagerBuildPowerRequired > 0 then
                    self.EngineerAssistManagerBuildPowerRequired = self.EngineerAssistManagerBuildPowerRequired - 3
                end
                --self.EngineerAssistManagerActive = false
            end
            WaitTicks(30)
        end
    end,

    AllyEconomyHelpThread = function(self)
        local selfIndex = self:GetArmyIndex()
        WaitTicks(180)
        while true do
            if GetEconomyStoredRatio(self, 'ENERGY') > 0.95 and GetEconomyTrend(self, 'ENERGY') > 10 then
                for index, brain in ArmyBrains do
                    if index ~= selfIndex then
                        if IsAlly(selfIndex, brain:GetArmyIndex()) then
                            if GetEconomyStoredRatio(brain, 'ENERGY') < 0.01 then
                                --LOG('Transfer Energy to team mate')
                                local amount
                                amount = GetEconomyStored( self, 'ENERGY') / 100 * 10
                                GiveResource(self, 'ENERGY', amount)
                            end
                        end
                    end
                end
            end
            WaitTicks(100)
        end
    end,

    HeavyEconomyRNG = function(self)

        WaitTicks(Random(80,100))
        --LOG('Heavy Economy thread starting '..self.Nickname)
        -- This section is for debug
        --[[
        self.cmanager = {income={r={m=0,e=0},t={m=0,e=0}},spend={m=0},storage={max={m=0,e=0},current={m=0,e=0}},categoryspend={fac={l=0,a=0,n=0},mex={t1=0,t2=0,t3=0},eng={t1=0,t2=0,t3=0,com=0},silo={t2=0,t3=0}}}
        self.amanager = {t1={scout=0,tank=0,arty=0,aa=0},t2={tank=0,mml=0,aa=0,shield=0},t3={tank=0,sniper=0,arty=0,mml=0,aa=0,shield=0},total={t1=0,t2=0,t3=0}}
        self.smanager={fac={l={t1=0,t2=0,t3=0},a={t1=0,t2=0,t3=0},n={t1=0,t2=0,t3=0}},mex={t1=0,t2=0,t3=0},pgen={t1=0,t2=0,t3=0},silo={t2=0,t3=0},fabs={t2=0,t3=0}}
        ]]



        while not self.defeat do
            --LOG('heavy economy loop started')
            self:HeavyEconomyForkRNG()
            WaitTicks(50)
        end
    end,

    HeavyEconomyForkRNG = function(self)
        local units = GetListOfUnits(self, categories.SELECTABLE, false, true)
        local factionIndex = self:GetFactionIndex()
        --LOG('units grabbed')
        local factories = {Land={T1=0,T2=0,T3=0},Air={T1=0,T2=0,T3=0},Naval={T1=0,T2=0,T3=0}}
        local extractors = {T1=0,T2=0,T3=0}
        local fabs = {T2=0,T3=0}
        local coms = {acu=0,sacu=0}
        local pgens = {T1=0,T2=0,T3=0}
        local silo = {T2=0,T3=0}
        local armyLand={T1={scout=0,tank=0,arty=0,aa=0},T2={tank=0,mml=0,aa=0,shield=0,bot=0},T3={tank=0,sniper=0,arty=0,mml=0,aa=0,shield=0,armoured=0}}
        local armyLandType={scout=0,tank=0,sniper=0,arty=0,mml=0,aa=0,shield=0,bot=0,armoured=0}
        local armyLandTiers={T1=0,T2=0,T3=0}
        local armyAir={T1={scout=0,interceptor=0,bomber=0,gunship=0,transport=0},T2={fighter=0,bomber=0,gunship=0,mercy=0,transport=0},T3={scout=0,asf=0,bomber=0,gunship=0,torpedo=0,transport=0}}
        local armyAirType={scout=0,interceptor=0,bomber=0,asf=0,gunship=0,fighter=0,torpedo=0,transport=0,mercy=0}
        local armyAirTiers={T1=0,T2=0,T3=0}
        local armyNaval={T1={frigate=0,sub=0,shard=0},T2={destroyer=0,cruiser=0,subhunter=0,transport=0},T3={battleship=0}}
        local armyNavalType={frigate=0,sub=0,shard=0,destroyer=0,cruiser=0,subhunter=0,battleship=0}
        local armyNavalTiers={T1=0,T2=0,T3=0}
        local launcherspend = {T2=0,T3=0}
        local facspend = {Land=0,Air=0,Naval=0}
        local mexspend = {T1=0,T2=0,T3=0}
        local engspend = {T1=0,T2=0,T3=0,com=0}
        local rincome = {m=0,e=0}
        local tincome = {m=GetEconomyIncome(self, 'MASS')*10,e=GetEconomyIncome(self, 'ENERGY')*10}
        local storage = {max = {m=GetEconomyStored(self, 'MASS')/GetEconomyStoredRatio(self, 'MASS'),e=GetEconomyStored(self, 'ENERGY')/GetEconomyStoredRatio(self, 'ENERGY')},current={m=GetEconomyStored(self, 'MASS'),e=GetEconomyStored(self, 'ENERGY')}}
        local tspend = {m=0,e=0}
        for _,z in self.amanager.Ratios[factionIndex] do
            for _,c in z do
                c.total=0
                for i,v in c do
                    if i=='total' then continue end
                    c.total=c.total+v
                end
            end
        end

        for _,unit in units do
            if unit.Dead then continue end
            if not unit then continue end
            local spendm=GetConsumptionPerSecondMass(unit)
            local spende=GetConsumptionPerSecondEnergy(unit)
            local producem=GetProductionPerSecondMass(unit)
            local producee=GetProductionPerSecondEnergy(unit)
            tspend.m=tspend.m+spendm
            tspend.e=tspend.e+spende
            rincome.m=rincome.m+producem
            rincome.e=rincome.e+producee
            if EntityCategoryContains(categories.MASSEXTRACTION,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    extractors.T1=extractors.T1+1
                    mexspend.T1=mexspend.T1+spendm
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    extractors.T2=extractors.T2+1
                    mexspend.T2=mexspend.T2+spendm
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    extractors.T3=extractors.T3+1
                    mexspend.T3=mexspend.T3+spendm
                end
            elseif EntityCategoryContains(categories.COMMAND+categories.SUBCOMMANDER,unit) then
                if EntityCategoryContains(categories.COMMAND,unit) then
                    coms.acu=coms.acu+1
                    engspend.com=engspend.com+spendm
                elseif EntityCategoryContains(categories.SUBCOMMANDER,unit) then
                    coms.sacu=coms.sacu+1
                    engspend.com=engspend.com+spendm
                end
            elseif EntityCategoryContains(categories.MASSFABRICATION,unit) then
                if EntityCategoryContains(categories.TECH2,unit) then
                    fabs.T2=fabs.T2+1
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    fabs.T3=fabs.T3+1
                end
            elseif EntityCategoryContains(categories.ENGINEER,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    engspend.T1=engspend.T1+spendm
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    engspend.T2=engspend.T2+spendm
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    engspend.T3=engspend.T3+spendm
                end
            elseif EntityCategoryContains(categories.FACTORY,unit) then
                if EntityCategoryContains(categories.LAND,unit) then
                    facspend.Land=facspend.Land+spendm
                    if EntityCategoryContains(categories.TECH1,unit) then
                        factories.Land.T1=factories.Land.T1+1
                    elseif EntityCategoryContains(categories.TECH2,unit) then
                        factories.Land.T2=factories.Land.T2+1
                    elseif EntityCategoryContains(categories.TECH3,unit) then
                        factories.Land.T3=factories.Land.T3+1
                    end
                elseif EntityCategoryContains(categories.AIR,unit) then
                    facspend.Air=facspend.Air+spendm
                    if EntityCategoryContains(categories.TECH1,unit) then
                        factories.Air.T1=factories.Air.T1+1
                    elseif EntityCategoryContains(categories.TECH2,unit) then
                        factories.Air.T2=factories.Air.T2+1
                    elseif EntityCategoryContains(categories.TECH3,unit) then
                        factories.Air.T3=factories.Air.T3+1
                    end
                elseif EntityCategoryContains(categories.NAVAL,unit) then
                    facspend.Naval=facspend.Naval+spendm
                    if EntityCategoryContains(categories.TECH1,unit) then
                        factories.Naval.T1=factories.Naval.T1+1
                    elseif EntityCategoryContains(categories.TECH2,unit) then
                        factories.Naval.T2=factories.Naval.T2+1
                    elseif EntityCategoryContains(categories.TECH3,unit) then
                        factories.Naval.T3=factories.Naval.T3+1
                    end
                end
            elseif EntityCategoryContains(categories.ENERGYPRODUCTION,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    pgens.T1=pgens.T1+1
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    pgens.T2=pgens.T2+1
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    pgens.T3=pgens.T3+1
                end
            elseif EntityCategoryContains(categories.LAND,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    armyLandTiers.T1=armyLandTiers.T1+1
                    if EntityCategoryContains(categories.SCOUT,unit) then
                        armyLand.T1.scout=armyLand.T1.scout+1
                        armyLandType.scout=armyLandType.scout+1
                    elseif EntityCategoryContains(categories.DIRECTFIRE - categories.ANTIAIR,unit) then
                        armyLand.T1.tank=armyLand.T1.tank+1
                        armyLandType.tank=armyLandType.tank+1
                    elseif EntityCategoryContains(categories.INDIRECTFIRE - categories.ANTIAIR,unit) then
                        armyLand.T1.arty=armyLand.T1.arty+1
                        armyLandType.arty=armyLandType.arty+1
                    elseif EntityCategoryContains(categories.ANTIAIR,unit) then
                        armyLand.T1.aa=armyLand.T1.aa+1
                        armyLandType.aa=armyLandType.aa+1
                    end
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    armyLandTiers.T2=armyLandTiers.T2+1
                    if EntityCategoryContains(categories.DIRECTFIRE - categories.BOT - categories.ANTIAIR,unit) then
                        armyLand.T2.tank=armyLand.T2.tank+1
                        armyLandType.tank=armyLandType.tank+1
                    elseif EntityCategoryContains(categories.DIRECTFIRE * categories.BOT - categories.ANTIAIR,unit) then
                        armyLand.T2.bot=armyLand.T2.bot+1
                        armyLandType.bot=armyLandType.bot+1
                    elseif EntityCategoryContains(categories.SILO,unit) then
                        armyLand.T2.mml=armyLand.T2.mml+1
                        armyLandType.mml=armyLandType.mml+1
                    elseif EntityCategoryContains(categories.ANTIAIR,unit) then
                        armyLand.T2.aa=armyLand.T2.aa+1
                        armyLandType.aa=armyLandType.aa+1
                    elseif EntityCategoryContains(categories.SHIELD,unit) then
                        armyLand.T2.shield=armyLand.T2.shield+1
                        armyLandType.shield=armyLandType.shield+1
                    end
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    armyLandTiers.T3=armyLandTiers.T3+1
                    if EntityCategoryContains(categories.SNIPER,unit) then
                        armyLand.T3.sniper=armyLand.T3.sniper+1
                        armyLandType.sniper=armyLandType.sniper+1
                    elseif EntityCategoryContains(categories.DIRECTFIRE * (categories.xel0305 + categories.xrl0305),unit) then
                        armyLand.T3.armoured=armyLand.T3.armoured+1
                        armyLandType.armoured=armyLandType.armoured+1
                    elseif EntityCategoryContains(categories.DIRECTFIRE - categories.xel0305 - categories.xrl0305 - categories.ANTIAIR,unit) then
                        armyLand.T3.tank=armyLand.T3.tank+1
                        armyLandType.tank=armyLandType.tank+1
                    elseif EntityCategoryContains(categories.SILO,unit) then
                        armyLand.T3.mml=armyLand.T3.mml+1
                        armyLandType.mml=armyLandType.mml+1
                    elseif EntityCategoryContains(categories.INDIRECTFIRE,unit) then
                        armyLand.T3.arty=armyLand.T3.arty+1
                        armyLandType.arty=armyLandType.arty+1
                    elseif EntityCategoryContains(categories.ANTIAIR,unit) then
                        armyLand.T3.aa=armyLand.T3.aa+1
                        armyLandType.aa=armyLandType.aa+1
                    elseif EntityCategoryContains(categories.SHIELD,unit) then
                        armyLand.T3.shield=armyLand.T3.shield+1
                        armyLandType.shield=armyLandType.shield+1
                    end
                end
            elseif EntityCategoryContains(categories.AIR,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    armyAirTiers.T1=armyAirTiers.T1+1
                    if EntityCategoryContains(categories.SCOUT,unit) then
                        armyAir.T1.scout=armyAir.T1.scout+1
                        armyAirType.scout=armyAirType.scout+1
                    elseif EntityCategoryContains(categories.ANTIAIR,unit) then
                        armyAir.T1.interceptor=armyAir.T1.interceptor+1
                        armyAirType.interceptor=armyAirType.interceptor+1
                    elseif EntityCategoryContains(categories.BOMBER,unit) then
                        armyAir.T1.bomber=armyAir.T1.bomber+1
                        armyAirType.bomber=armyAirType.bomber+1
                    elseif EntityCategoryContains(categories.GROUNDATTACK - categories.EXPERIMENTAL,unit) then
                        armyAir.T1.gunship=armyAir.T1.gunship+1
                        armyAirType.gunship=armyAirType.gunship+1
                    elseif EntityCategoryContains(categories.TRANSPORTFOCUS,unit) then
                        armyAir.T1.transport=armyAir.T1.transport+1
                        armyAirType.transport=armyAirType.transport+1
                    end
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    armyAirTiers.T2=armyAirTiers.T2+1
                    if EntityCategoryContains(categories.BOMBER - categories.daa0206,unit) then
                        armyAir.T2.bomber=armyAir.T2.bomber+1
                        armyAirType.bomber=armyAirType.bomber+1
                    elseif EntityCategoryContains(categories.xaa0202 - categories.EXPERIMENTAL,unit) then
                        armyAir.T2.fighter=armyAir.T2.fighter+1
                        armyAirType.fighter=armyAirType.fighter+1
                    elseif EntityCategoryContains(categories.GROUNDATTACK - categories.EXPERIMENTAL,unit) then
                        armyAir.T2.gunship=armyAir.T2.gunship+1
                        armyAirType.gunship=armyAirType.gunship+1
                    elseif EntityCategoryContains(categories.ANTINAVY - categories.EXPERIMENTAL,unit) then
                        armyAir.T2.torpedo=armyAir.T2.torpedo+1
                        armyAirType.torpedo=armyAirType.torpedo+1
                    elseif EntityCategoryContains(categories.daa0206,unit) then
                        armyAir.T2.mercy=armyAir.T2.mercy+1
                        armyAirType.mercy=armyAirType.mercy+1
                    elseif EntityCategoryContains(categories.TRANSPORTFOCUS,unit) then
                        armyAir.T2.transport=armyAir.T2.transport+1
                        armyAirType.transport=armyAirType.transport+1
                    end
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    armyAirTiers.T3=armyAirTiers.T3+1
                    if EntityCategoryContains(categories.SCOUT,unit) then
                        armyAir.T3.scout=armyAir.T3.scout+1
                        armyAirType.scout=armyAirType.scout+1
                    elseif EntityCategoryContains(categories.ANTIAIR - categories.BOMBER - categories.GROUNDATTACK ,unit) then
                        armyAir.T3.asf=armyAir.T3.asf+1
                        armyAirType.asf=armyAirType.asf+1
                    elseif EntityCategoryContains(categories.BOMBER,unit) then
                        armyAir.T3.bomber=armyAir.T3.bomber+1
                        armyAirType.bomber=armyAirType.bomber+1
                    elseif EntityCategoryContains(categories.GROUNDATTACK - categories.EXPERIMENTAL,unit) then
                        armyAir.T3.gunship=armyAir.T3.gunship+1
                        armyAirType.gunship=armyAirType.gunship+1
                    elseif EntityCategoryContains(categories.TRANSPORTFOCUS,unit) then
                        armyAir.T3.transport=armyAir.T3.transport+1
                        armyAirType.transport=armyAirType.transport+1
                    elseif EntityCategoryContains(categories.ANTINAVY - categories.EXPERIMENTAL,unit) then
                        armyAir.T3.torpedo=armyAir.T3.torpedo+1
                        armyAirType.torpedo=armyAirType.torpedo+1
                    end
                end
            elseif EntityCategoryContains(categories.NAVAL,unit) then
                if EntityCategoryContains(categories.TECH1,unit) then
                    armyNavalTiers.T1=armyNavalTiers.T1+1
                    if EntityCategoryContains(categories.FRIGATE,unit) then
                        armyNaval.T1.frigate=armyNaval.T1.frigate+1
                        armyNavalType.frigate=armyNavalType.frigate+1
                    elseif EntityCategoryContains(categories.T1SUBMARINE,unit) then
                        armyNaval.T1.sub=armyNaval.T1.sub+1
                        armyNavalType.sub=armyNavalType.sub+1
                    elseif EntityCategoryContains(categories.uas0102,unit) then
                        armyNaval.T1.shard=armyNaval.T1.shard+1
                        armyNavalType.shard=armyNavalType.shard+1
                    end
                elseif EntityCategoryContains(categories.TECH2,unit) then
                    armyNavalTiers.T2=armyNavalTiers.T2+1
                    if EntityCategoryContains(categories.DESTROYER,unit) then
                        armyNaval.T2.destroyer=armyNaval.T2.destroyer+1
                        armyNavalType.destroyer=armyNavalType.destroyer+1
                    elseif EntityCategoryContains(categories.CRUISER,unit) then
                        armyNaval.T2.cruiser=armyNaval.T2.cruiser+1
                        armyNavalType.cruiser=armyNavalType.cruiser+1
                    elseif EntityCategoryContains(categories.T2SUBMARINE + categories.xes0102,unit) then
                        armyNaval.T2.subhunter=armyNaval.T2.subhunter+1
                        armyNavalType.subhunter=armyNavalType.subhunter+1
                    end
                --[[elseif EntityCategoryContains(categories.TECH3,unit) then
                    armyNavalTiers.T3=armyNavalTiers.T3+1
                    if EntityCategoryContains(categories.SCOUT,unit) then
                        armyNaval.T3.scout=armyNaval.T3.scout+1
                        armyNavalType.scout=armyNavalType.scout+1
                    elseif EntityCategoryContains(categories.ANTIAIR - categories.BOMBER - categories.GROUNDATTACK ,unit) then
                        armyNaval.T3.asf=armyNaval.T3.asf+1
                        armyNavalType.asf=armyNavalType.asf+1
                    elseif EntityCategoryContains(categories.BOMBER,unit) then
                        armyNaval.T3.bomber=armyNaval.T3.bomber+1
                        armyNavalType.bomber=armyNavalType.bomber+1
                    elseif EntityCategoryContains(categories.GROUNDATTACK - categories.EXPERIMENTAL,unit) then
                        armyNaval.T3.gunship=armyNaval.T3.gunship+1
                        armyNavalType.gunship=armyNavalType.gunship+1
                    elseif EntityCategoryContains(categories.TRANSPORTFOCUS,unit) then
                        armyNaval.T3.transport=armyNaval.T3.transport+1
                        armyNavalType.transport=armyNavalType.transport+1
                    elseif EntityCategoryContains(categories.ANTINAVY - categories.EXPERIMENTAL,unit) then
                        armyNaval.T3.torpedo=armyNaval.T3.torpedo+1
                        armyNavalType.torpedo=armyNavalType.torpedo+1
                    end]]
                end
            elseif EntityCategoryContains(categories.SILO,unit) then
                if EntityCategoryContains(categories.TECH2,unit) then
                    silo.T2=silo.T2+1
                    launcherspend.T2=launcherspend.T2+spendm
                elseif EntityCategoryContains(categories.TECH3,unit) then
                    silo.T3=silo.T3+1
                    launcherspend.T3=launcherspend.T3+spendm
                end
            end
        end
        self.cmanager.income.r.m=rincome.m
        self.cmanager.income.r.e=rincome.e
        self.cmanager.income.t.m=tincome.m
        self.cmanager.income.t.e=tincome.e
        self.cmanager.spend.m=tspend.m
        self.cmanager.spend.e=tspend.e
        self.cmanager.categoryspend.eng=engspend
        self.cmanager.categoryspend.fact=facspend
        self.cmanager.categoryspend.silo=launcherspend
        self.cmanager.categoryspend.mex=mexspend
        self.cmanager.storage.current.m=storage.current.m
        self.cmanager.storage.current.e=storage.current.e
        if storage.current.m>0 and storage.current.e>0 then
            self.cmanager.storage.max.m=storage.max.m
            self.cmanager.storage.max.e=storage.max.e
        end
        self.amanager.Current.Land=armyLand
        self.amanager.Total.Land=armyLandTiers
        self.amanager.Type.Land=armyLandType
        self.amanager.Current.Air=armyAir
        self.amanager.Total.Air=armyAirTiers
        self.amanager.Type.Air=armyAirType
        self.amanager.Current.Naval=armyNaval
        self.amanager.Total.Naval=armyNavalTiers
        self.amanager.Type.Naval=armyNavalType
        self.smanager={fact=factories,mex=extractors,silo=silo,fabs=fabs,pgen=pgens,}
    end,

--[[
    GetManagerCount = function(self, type)
        if not self.RNG then
            return RNGAIBrainClass.GetManagerCount(self, type)
        end
        local count = 0
        for k, v in self.BuilderManagers do
            if type then
                LOG('BuilderManager Type is '..k)
                if type == 'Start Location' and not (string.find(k, 'ARMY_') or string.find(k, 'Large Expansion')) then
                    continue
                elseif type == 'Naval Area' and not (string.find(k, 'Naval Area')) then
                    continue
                elseif type == 'Expansion Area' and (not (string.find(k, 'Expansion Area') or string.find(k, 'EXPANSION_AREA')) or string.find(k, 'Large Expansion')) then
                    continue
                end
            end

            if v.EngineerManager:GetNumCategoryUnits('Engineers', categories.ALLUNITS) <= 0 and v.FactoryManager:GetNumCategoryFactories(categories.ALLUNITS) <= 0 then
                continue
            end

            count = count + 1
        end
        LOG('Type is '..type..' Count is '..count)
        return count
    end,]]

    ExpansionIntelScanRNG = function(self)
        --LOG('Pre-Start ExpansionIntelScan')
        WaitTicks(50)
        if RNGGETN(self.BrainIntel.ExpansionWatchTable) == 0 then
            --LOG('ExpansionWatchTable not ready or is empty')
            return
        end
        local threatTypes = {
            'Land',
            'Commander',
            'Structures',
        }
        local rawThreat = 0
        if ScenarioInfo.Options.AIDebugDisplay == 'displayOn' then
            self:ForkThread(RUtils.RenderBrainIntelRNG)
        end
        local GetClosestPathNodeInRadiusByLayer = import('/lua/AI/aiattackutilities.lua').GetClosestPathNodeInRadiusByLayer
        --LOG('Starting ExpansionIntelScan')
        while self.Result ~= "defeat" do
            for k, v in self.BrainIntel.ExpansionWatchTable do
                if v.PlatoonAssigned.Dead then
                    v.PlatoonAssigned = false
                end
                if v.ScoutAssigned.Dead then
                    v.ScoutAssigned = false
                end
                if not v.Zone then
                    --[[
                        This is the information available in the Path Node currently. subject to change 7/13/2021
                        info: Check for position {
                        info:   GraphArea="LandArea_133",
                        info:   RNGArea="Land15-24",
                        info:   adjacentTo="Land19-11 Land20-11 Land20-12 Land20-13 Land18-11",
                        info:   armydists={ ARMY_1=209.15859985352, ARMY_2=218.62866210938 },
                        info:   bestarmy="ARMY_1",
                        info:   bestexpand="Expansion Area 6",
                        info:   color="fff4a460",
                        info:   expanddists={
                        info:     ARMY_1=209.15859985352,
                        info:     ARMY_2=218.62866210938,
                        info:     ARMY_3=118.64562988281,
                        info:     ARMY_4=290.41003417969,
                        info:     ARMY_5=270.42752075195,
                        info:     ARMY_6=125.28052520752,
                        info:     Expansion Area 1=354.38958740234,
                        info:     Expansion Area 2=354.2922668457,
                        info:     Expansion Area 5=222.54640197754,
                        info:     Expansion Area 6=0
                        info:   },
                        info:   graph="DefaultLand",
                        info:   hint=true,
                        info:   orientation={ 0, 0, 0 },
                        info:   position={ 312, 16.21875, 200, type="VECTOR3" },
                        info:   prop="/env/common/props/markers/M_Path_prop.bp",
                        info:   type="Land Path Node"
                        info: }
                    ]]
                    local expansionNode = Scenario.MasterChain._MASTERCHAIN_.Markers[GetClosestPathNodeInRadiusByLayer(v.Position, 60, 'Land').name]
                    --LOG('Check for position '..repr(expansionNode))
                    if expansionNode then
                        self.BrainIntel.ExpansionWatchTable[k].Zone = expansionNode.RNGArea
                    else
                        self.BrainIntel.ExpansionWatchTable[k].Zone = false
                    end
                end
                if v.MassPoints > 2 then
                    for _, t in threatTypes do
                        rawThreat = GetThreatAtPosition(self, v.Position, self.BrainIntel.IMAPConfig.Rings, true, t)
                        if rawThreat > 0 then
                            --LOG('Threats as ExpansionWatchTable for type '..t..' threat is '..rawThreat)
                        end
                        self.BrainIntel.ExpansionWatchTable[k][t] = rawThreat
                    end
                elseif v.MassPoints == 2 then
                    rawThreat = GetThreatAtPosition(self, v.Position, self.BrainIntel.IMAPConfig.Rings, true, 'Structures')
                    self.BrainIntel.ExpansionWatchTable[k]['Structures'] = rawThreat
                end
            end
            WaitTicks(50)
            -- don't do this, it might have a platoon inside it LOG('Current Expansion Watch Table '..repr(self.BrainIntel.ExpansionWatchTable))
        end
    end,
}
