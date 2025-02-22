WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset platoon.lua' )

local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local AIUtils = import('/lua/ai/aiutilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local ALLBPS = __blueprints
local SUtils = import('/lua/AI/sorianutilities.lua')
local ToString = import('/lua/sim/CategoryUtils.lua').ToString
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local RNGGETN = table.getn
local RNGINSERT = table.insert
local WaitTicks = coroutine.yield

RNGAIPlatoon = Platoon
Platoon = Class(RNGAIPlatoon) {

    AirHuntAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local data = self.PlatoonData
        local categoryList = {}
        local atkPri = {}
        local target
        local startX, startZ = aiBrain:GetArmyStartPos()
        local homeBaseLocation = aiBrain.BuilderManagers['MAIN'].Position
        local currentPlatPos
        local distSq
        local avoidBases = data.AvoidBases or false
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local defensive = data.Defensive or false
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(atkPri, v)
                if type(v) == 'string' then
                    RNGINSERT(categoryList, ParseEntityCategory(v))
                else
                    RNGINSERT(categoryList, v)
                end
            end
        else
            RNGINSERT(atkPri, categories.MOBILE * categories.AIR)
            RNGINSERT(categoryList, categories.MOBILE * categories.AIR)
        end
        local platoonUnits = GetPlatoonUnits(self)
        for k, v in platoonUnits do
            if not v.Dead and v:TestToggleCaps('RULEUTC_StealthToggle') then
                v:SetScriptBit('RULEUTC_StealthToggle', false)
            end
            if not v.Dead and v:TestToggleCaps('RULEUTC_CloakToggle') then
                v:SetScriptBit('RULEUTC_CloakToggle', false)
            end
        end
        self:SetPrioritizedTargetList('Attack', categoryList)
        local maxRadius = data.SearchRadius or 1000
        local threatCountLimit = 0
        while PlatoonExists(aiBrain, self) do
            local currentPlatPos = GetPlatoonPosition(self)
            local platoonThreat = self:CalculatePlatoonThreat('AntiAir', categories.ALLUNITS)
            if not target or target.Dead then
                if defensive then
                    target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri, avoidBases)
                    if not PlatoonExists(aiBrain, self) then
                        return
                    end
                else
                    local mult = { 1,10,25 }
                    for _,i in mult do
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius * i, atkPri, avoidBases)
                        if target then
                            break
                        end
                        WaitTicks(10) --DUNCAN - was 3
                        if not PlatoonExists(aiBrain, self) then
                            return
                        end
                    end
                end
            end

            if target then
                local targetPos = target:GetPosition()
                local platoonCount = RNGGETN(GetPlatoonUnits(self))
                if (threatCountLimit < 5 ) and (VDist2Sq(currentPlatPos[1], currentPlatPos[2], startX, startZ) < 22500) and (GetThreatAtPosition(aiBrain, targetPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir') * 1.3 > platoonThreat) and platoonCount < platoonLimit then
                    --LOG('Target air threat too high')
                    threatCountLimit = threatCountLimit + 1
                    self:MoveToLocation(homeBaseLocation, false)
                    WaitTicks(80)
                    self:Stop()
                    self:MergeWithNearbyPlatoonsRNG('AirHuntAIRNG', 60, 20)
                    continue
                end
                --LOG ('Target has'..GetThreatAtPosition(aiBrain, targetPos, 0, true, 'AntiAir')..' platoon threat is '..platoonThreat)
                --LOG('threatCountLimit is'..threatCountLimit)
                self:Stop()
                --LOG('* AI-RNG: Attacking Target')
                --LOG('* AI-RNG: AirHunt Target is at :'..repr(target:GetPosition()))
                self:AttackTarget(target)
                while PlatoonExists(aiBrain, self) do
                    currentPlatPos = GetPlatoonPosition(self)
                    if aiBrain.EnemyIntel.EnemyStartLocations then
                        if RNGGETN(aiBrain.EnemyIntel.EnemyStartLocations) > 0 then
                            for e, pos in aiBrain.EnemyIntel.EnemyStartLocations do
                                if VDist2Sq(targetPos[1],  targetPos[3], pos[1], pos[3]) < 10000 then
                                    --LOG('AirHuntAI target within enemy start range, return to base')
                                    target = false
                                    if PlatoonExists(aiBrain, self) then
                                        self:Stop()
                                        self:MoveToLocation(homeBaseLocation, false)
                                        --LOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                                        while PlatoonExists(aiBrain, self) do
                                            currentPlatPos = self:GetPlatoonPosition()
                                            --LOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3]))
                                            --LOG('Air Unit Platoon Position is :'..repr(currentPlatPos))
                                            distSq = VDist2Sq(currentPlatPos[1], currentPlatPos[3], homeBaseLocation[1], homeBaseLocation[3])
                                            if distSq < 6400 then
                                                break
                                            end
                                            WaitTicks(20)
                                            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri, avoidBases)
                                            if target then
                                                return self:SetAIPlanRNG('AirHuntAIRNG')
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    WaitTicks(20)
                    if (target.Dead or not target or target:BeenDestroyed()) then
                        --LOG('* AI-RNG: Target Dead or not or Destroyed, breaking loop')
                        break
                    end
                end
                WaitTicks(20)
            end
            if not PlatoonExists(aiBrain, self) then
                return
            else
                WaitTicks(2)
                currentPlatPos = GetPlatoonPosition(self)
            end
            if (target.Dead or not target or target:BeenDestroyed()) and VDist2Sq(currentPlatPos[1], currentPlatPos[3], startX, startZ) > 6400 then
                --LOG('* AI-RNG: No Target Returning to base')
                if PlatoonExists(aiBrain, self) then
                    self:Stop()
                    self:MoveToLocation(homeBaseLocation, false)
                    --LOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                    while PlatoonExists(aiBrain, self) do
                        currentPlatPos = self:GetPlatoonPosition()
                        --LOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3]))
                        --LOG('Air Unit Platoon Position is :'..repr(currentPlatPos))
                        distSq = VDist2Sq(currentPlatPos[1], currentPlatPos[3], homeBaseLocation[1], homeBaseLocation[3])
                        if distSq < 6400 then
                            break
                        end
                        WaitTicks(20)
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri, avoidBases)
                        if target then
                            self:SetAIPlanRNG('AirHuntAIRNG')
                        end
                    end
                end
            end
            WaitTicks(25)
        end
    end,
    
    MercyAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local startX = nil
        local StartZ = nil
        startX, startZ = aiBrain:GetArmyStartPos()
        while PlatoonExists(aiBrain, self) do
            if self:IsOpponentAIRunning() then
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.COMMAND )
                if target then
                    blip = target:GetBlip(armyIndex)
                    self:Stop()
                    self:AttackTarget(target)
                end
            end
            WaitTicks(170)
            self:MoveToLocation({startX, 0, startZ}, false)
        end
    end,

    GuardMarkerRNG = function(self)
        local aiBrain = self:GetBrain()

        local platLoc = GetPlatoonPosition(self)

        if not PlatoonExists(aiBrain, self) or not platLoc then
            return
        end

        -----------------------------------------------------------------------
        -- Platoon Data
        -----------------------------------------------------------------------
        -- type of marker to guard
        -- Start location = 'Start Location'... see MarkerTemplates.lua for other types
        local markerType = self.PlatoonData.MarkerType or 'Expansion Area'

        -- what should we look for for the first marker?  This can be 'Random',
        -- 'Threat' or 'Closest'
        local moveFirst = self.PlatoonData.MoveFirst or 'Threat'

        -- should our next move be no move be (same options as before) as well as 'None'
        -- which will cause the platoon to guard the first location they get to
        local moveNext = self.PlatoonData.MoveNext or 'None'

        -- Minimum distance when looking for closest
        local avoidClosestRadius = self.PlatoonData.AvoidClosestRadius or 0

        -- set time to wait when guarding a location with moveNext = 'None'
        local guardTimer = self.PlatoonData.GuardTimer or 0

        -- threat type to look at
        local threatType = self.PlatoonData.ThreatType or 'AntiSurface'

        -- should we look at our own threat or the enemy's
        local bSelfThreat = self.PlatoonData.SelfThreat or false

        -- if true, look to guard highest threat, otherwise,
        -- guard the lowest threat specified
        local bFindHighestThreat = self.PlatoonData.FindHighestThreat or false

        -- minimum threat to look for
        local minThreatThreshold = self.PlatoonData.MinThreatThreshold or -1
        -- maximum threat to look for
        local maxThreatThreshold = self.PlatoonData.MaxThreatThreshold  or 99999999

        -- Avoid bases (true or false)
        local bAvoidBases = self.PlatoonData.AvoidBases or false

        -- Radius around which to avoid the main base
        local avoidBasesRadius = self.PlatoonData.AvoidBasesRadius or 0

        -- Use Aggresive Moves Only
        local bAggroMove = self.PlatoonData.AggressiveMove or false

        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        
        -- Ignore markers with friendly structure threatlevels
        local IgnoreFriendlyBase = self.PlatoonData.IgnoreFriendlyBase or false

        local maxPathDistance = self.PlatoonData.MaxPathDistance or 200

        local safeZone = self.PlatoonData.SafeZone or false

        -----------------------------------------------------------------------
        local markerLocations

        AIAttackUtils.GetMostRestrictiveLayer(self)
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local enemyRadius = 40
        local MaxPlatoonWeaponRange
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        local platoonUnits = GetPlatoonUnits(self)
        local rangeModifier = 0
        local atkPri = {}
        local platoonThreat = self:CalculatePlatoonThreat('Surface', categories.ALLUNITS)

        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if EntityCategoryContains(categories.SCOUT, v) then
                        self.ScoutPresent = true
                    end
                    for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                            -- save the weaponrange 
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                        if not MaxPlatoonWeaponRange or MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end

        if self.PlatoonData.PrioritizedCategories then
            for k,v in self.PlatoonData.PrioritizedCategories do
                RNGINSERT(atkPri, v)
            end
            RNGINSERT(atkPri, 'ALLUNITS')
        end
        
        if IgnoreFriendlyBase then
            --LOG('* AI-RNG: ignore friendlybase true')
            local markerPos = AIUtils.AIGetMarkerLocationsNotFriendly(aiBrain, markerType)
            markerLocations = markerPos
        else
            --LOG('* AI-RNG: ignore friendlybase false')
            local markerPos = AIUtils.AIGetMarkerLocations(aiBrain, markerType)
            markerLocations = markerPos
        end
        
        local bestMarker = false

        if not self.LastMarker then
            self.LastMarker = {nil,nil}
        end

        -- look for a random marker
        --[[Marker table examples for better understanding what is happening below 
        info: Marker Current{ Name="Mass7", Position={ 189.5, 24.240200042725, 319.5, type="VECTOR3" } }
        info: Marker Last{ { 374.5, 20.650400161743, 154.5, type="VECTOR3" } }
        ]] 
        if moveFirst == 'Random' then
            if RNGGETN(markerLocations) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end
            for _,marker in RandomIter(markerLocations) do
                if RNGGETN(markerLocations) <= 2 then
                    self.LastMarker[1] = nil
                    self.LastMarker[2] = nil
                end
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) then
                    if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                        continue
                    end
                    if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                        continue
                    end
                    bestMarker = marker
                    break
                end
            end
        elseif moveFirst == 'Threat' then
            --Guard the closest least-defended marker
            local bestMarkerThreat = 0
            if not bFindHighestThreat then
                bestMarkerThreat = 99999999
            end

            local bestDistSq = 99999999


            -- find best threat at the closest distance
            for _,marker in markerLocations do
                local markerThreat
                if bSelfThreat then
                    markerThreat = GetThreatAtPosition(aiBrain, marker.Position, 0, true, threatType, aiBrain:GetArmyIndex())
                else
                    markerThreat = GetThreatAtPosition(aiBrain, marker.Position, 0, true, threatType)
                end
                local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])

                if distSq > 100 then
                    if markerThreat >= minThreatThreshold and markerThreat <= maxThreatThreshold then
                        if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) then
                            if self.IsBetterThreat(bFindHighestThreat, markerThreat, bestMarkerThreat) then
                                bestDistSq = distSq
                                bestMarker = marker
                                bestMarkerThreat = markerThreat
                            elseif markerThreat == bestMarkerThreat then
                                if distSq < bestDistSq then
                                    bestDistSq = distSq
                                    bestMarker = marker
                                    bestMarkerThreat = markerThreat
                                end
                            end
                        end
                    end
                end
            end

        else
            -- if we didn't want random or threat, assume closest (but avoid ping-ponging)
            local bestDistSq = 99999999
            if RNGGETN(markerLocations) <= 2 then
                self.LastMarker[1] = nil
                self.LastMarker[2] = nil
            end
            for _,marker in markerLocations do
                local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
                    if distSq < bestDistSq then
                        if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                            continue
                        end
                        if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                            continue
                        end
                        bestDistSq = distSq
                        bestMarker = marker
                    end
                end
            end
        end


        -- did we find a threat?
        local usedTransports = false
        if bestMarker then
            self.LastMarker[2] = self.LastMarker[1]
            self.LastMarker[1] = bestMarker.Position
            --LOG('* AI-RNG: GuardMarker: Attacking '' .. bestMarker.Name)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestMarker.Position, 10, maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                local position = GetPlatoonPosition(self)
                if not success or VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 512 then
                    --LOG('* AI-RNG: GuardMarkerRNG marker position > 512')
                    if safeZone then
                        --LOG('* AI-RNG: GuardMarkerRNG Safe Zone is true')
                    end
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true, false, safeZone)
                elseif VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 256 then
                    --LOG('* AI-RNG: GuardMarkerRNG marker position > 256')
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, false, false, safeZone)
                end
                if not usedTransports then
                    local pathLength = RNGGETN(path)
                    local prevpoint = position or false
                    --LOG('* AI-RNG: GuardMarkerRNG movement logic')
                    for i=1, pathLength-1 do
                        local direction = RUtils.GetDirectionInDegrees( prevpoint, path[i] )
                        if bAggroMove then
                            --self:AggressiveMoveToLocation(path[i])
                            IssueFormAggressiveMove( self:GetPlatoonUnits(), path[i], PlatoonFormation, direction)
                        else
                            --self:MoveToLocation(path[i], false)
                            if self:GetSquadUnits('Attack') and RNGGETN(self:GetSquadUnits('Attack')) > 0 then
                                IssueFormMove( self:GetSquadUnits('Attack'), path[i], PlatoonFormation, direction)
                            end
                            if self:GetSquadUnits('Artillery') and RNGGETN(self:GetSquadUnits('Artillery')) > 0 then
                                IssueFormAggressiveMove( self:GetSquadUnits('Artillery'), path[i], PlatoonFormation, direction)
                            end
                        end
                        while PlatoonExists(aiBrain, self) do
                            platoonPosition = GetPlatoonPosition(self)
                            pathDistance = VDist2Sq(path[i][1], path[i][3], platoonPosition[1], platoonPosition[3])
                            if pathDistance < 400 then
                                -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                self:Stop()
                                break
                            end
                            --LOG('Waiting to reach target loop')
                            WaitTicks(15)
                        end
                        prevpoint = table.copy(path[i])
                    end
                end
            elseif (not path and reason == 'NoPath') then
                --LOG('* AI-RNG: Guardmarker NoPath requesting transports')
                usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true, false, safeZone)
                --DUNCAN - if we need a transport and we cant get one the disband
                if not usedTransports then
                    --LOG('* AI-RNG: Guardmarker no transports available disbanding')
                    self:PlatoonDisband()
                    return
                end
                --LOG('* AI-RNG: Guardmarker found transports')
            else
                --LOG('* AI-RNG: GuardmarkerRNG bad path response disbanding')
                self:PlatoonDisband()
                return
            end

            if (not path or not success) and not usedTransports then
                --LOG('* AI-RNG: GuardmarkerRNG not path or not success and not usedTransports. Disbanding')
                self:PlatoonDisband()
                return
            end

            if moveNext == 'None' then
                -- guard
                IssueGuard(GetPlatoonUnits(self), bestMarker.Position)
                -- guard forever
                if guardTimer <= 0 then return end
            else
                -- otherwise, we're moving to the location
                self:AggressiveMoveToLocation(bestMarker.Position)
            end

            -- wait till we get there
            local oldPlatPos = GetPlatoonPosition(self)
            local StuckCount = 0
            repeat
                WaitTicks(50)
                platLoc = GetPlatoonPosition(self)
                if VDist3(oldPlatPos, platLoc) < 1 then
                    StuckCount = StuckCount + 1
                else
                    StuckCount = 0
                end
                if StuckCount > 5 then
                    --LOG('* AI-RNG: GuardmarkerRNG detected stuck. Restarting.')
                    return self:SetAIPlanRNG('GuardMarkerRNG')
                end
                oldPlatPos = platLoc
            until VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) < 900 or not PlatoonExists(aiBrain, self)

            -- if we're supposed to guard for some time
            if moveNext == 'None' then
                -- this won't be 0... see above
                WaitSeconds(guardTimer)
                --LOG('Move Next set to None, disbanding')
                self:PlatoonDisband()
                return
            end

            -- we're there... wait here until we're done
            --LOG('Checking if GuardMarker platoon has enemy units around marker position')
            local numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 30, 'Enemy')
            while numGround > 0 and PlatoonExists(aiBrain, self) do
                --LOG('GuardMarker has enemy units around marker position, looking for target')
                local target, acuInRange, acuUnit = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, bestMarker.Position, 'Attack', enemyRadius, (categories.LAND + categories.NAVAL + categories.STRUCTURE), atkPri, false)
                --target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                local attackSquad = self:GetSquadUnits('Attack')
                IssueClearCommands(attackSquad)
                while PlatoonExists(aiBrain, self) do
                    --LOG('Micro target Loop '..debugloop)
                    --debugloop = debugloop + 1
                    if target and not target.Dead then
                        --LOG('Activating GuardMarker Micro')
                        platoonThreat = self:CalculatePlatoonThreat('Surface', categories.DIRECTFIRE)
                        if acuUnit and platoonThreat > 30 then
                            --LOG('ACU is close and we have decent threat')
                            target = acuUnit
                            rangeModifier = 5
                        end
                        local targetPosition = target:GetPosition()
                        local microCap = 50
                        for _, unit in attackSquad do
                            microCap = microCap - 1
                            if microCap <= 0 then break end
                            if unit.Dead then continue end
                            if not unit.MaxWeaponRange then
                                continue
                            end
                            unitPos = unit:GetPosition()
                            alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                            x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange - rangeModifier or MaxPlatoonWeaponRange)
                            y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange - rangeModifier or MaxPlatoonWeaponRange)
                            smartPos = { x, GetTerrainHeight( x, y), y }
                            -- check if the move position is new or target has moved
                            if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                -- clear move commands if we have queued more than 4
                                if RNGGETN(unit:GetCommandQueue()) > 2 then
                                    IssueClearCommands({unit})
                                    coroutine.yield(3)
                                end
                                -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                IssueMove({unit}, smartPos )
                                if target.Dead then break end
                                IssueAttack({unit}, target)
                                --unit:SetCustomName('Fight micro moving')
                                unit.smartPos = smartPos
                                unit.TargetPos = targetPosition
                            -- in case we don't move, check if we can fire at the target
                            else
                                local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                    --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                    IssueMove({unit}, targetPosition )
                                else
                                    --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                end
                            end
                        end
                    else
                        break
                    end
                    WaitTicks(10)
                end
                WaitTicks(Random(30,60))
                numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 30, 'Enemy')
            end

            if not PlatoonExists(aiBrain, self) then
                return
            end

            -- set our MoveFirst to our MoveNext
            self.PlatoonData.MoveFirst = moveNext
            return self:GuardMarkerRNG()
        else
            -- no marker found, disband!
            --LOG('* AI-RNG: GuardmarkerRNG No best marker. Disbanding.')
            self:PlatoonDisband()
        end
    end,
    
    ReclaimAIRNG = function(self)
        --LOG('* AI-RNG: ReclaimAIRNG has been started')
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local eng
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.MOBILE * categories.ENGINEER, v) then
                eng = v
                break
            end
        end
        if eng then
            --LOG('* AI-RNG: Engineer Condition is true')
            eng.UnitBeingBuilt = eng -- this is important, per uveso (It's a build order fake, i assigned the engineer to itself so it will not produce errors because UnitBeingBuilt must be a unit and can not just be set to true)
            RUtils.ReclaimRNGAIThread(self,eng,aiBrain)
            eng.UnitBeingBuilt = nil
        else
            --LOG('* AI-RNG: Engineer Condition is false')
        end
        --LOG('* AI-RNG: Ending ReclaimAIRNG..Disbanding')
        self:PlatoonDisband()
    end,

    RepairAIRNG = function(self)
        local aiBrain = self:GetBrain()
        if not self.PlatoonData or not self.PlatoonData.LocationType then
            self:PlatoonDisband()
            return
        end
        local eng = self:GetPlatoonUnits()[1]
        local repairingUnit = false
        local engineerManager = aiBrain.BuilderManagers[self.PlatoonData.LocationType].EngineerManager
        local Structures = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.STRUCTURE - (categories.TECH1 - categories.FACTORY), engineerManager:GetLocationCoords(), engineerManager:GetLocationRadius())
        for k,v in Structures do
            -- prevent repairing a unit while reclaim is in progress (see ReclaimStructuresAI)
            if not v.Dead and not v.ReclaimInProgress and v:GetHealthPercent() < .8 then
                self:Stop()
                IssueRepair(self:GetPlatoonUnits(), v)
                repairingUnit = v
                break
            end
        end
        local count = 0
        repeat
            WaitTicks(20)
            if not aiBrain:PlatoonExists(self) then
                return
            end
            if repairingUnit.ReclaimInProgress then
                self:Stop()
                self:PlatoonDisband()
            end
            count = count + 1
            if eng:IsIdleState() then break end
        until count >= 30
        self:PlatoonDisband()
    end,

    ReclaimUnitsAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local index = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local pos = self:GetPlatoonPosition()
        local radius = data.Radius or 500
        local positionUnits = {}
        if not data.Categories then
            error('PLATOON.LUA ERROR- ReclaimUnitsAI requires Categories field',2)
        end

        local checkThreat = false
        if data.ThreatMin and data.ThreatMax and data.ThreatRings then
            checkThreat = true
        end
        while PlatoonExists(aiBrain, self) do
            local target = AIAttackUtils.AIFindUnitRadiusThreatRNG(aiBrain, 'Enemy', data.Categories, pos, radius, data.ThreatMin, data.ThreatMax, data.ThreatRings)
            if target and not target.Dead then
                local targetPos = target:GetPosition()
                local blip = target:GetBlip(index)
                local platoonUnits = self:GetPlatoonUnits()
                if blip then
                    IssueClearCommands(platoonUnits)
                    positionUnits = GetUnitsAroundPoint(aiBrain, data.Categories[1], targetPos, 10, 'Enemy')
                    --LOG('Number of units found by reclaim ai is '..RNGGETN(positionUnits))
                    if RNGGETN(positionUnits) > 1 then
                        --LOG('Reclaim Units AI got more than one at target position')
                        for k, v in positionUnits do
                            IssueReclaim(platoonUnits, v)
                        end
                    else
                        --LOG('Reclaim Units AI got a single target at position')
                        IssueReclaim(platoonUnits, target)
                    end
                    -- Set ReclaimInProgress to prevent repairing (see RepairAI)
                    target.ReclaimInProgress = true
                    local allIdle
                    repeat
                        WaitTicks(30)
                        if not PlatoonExists(aiBrain, self) then
                            return
                        end
                        if target and not target.ReclaimInProgress then
                            target.ReclaimInProgress = true
                        end
                        allIdle = true
                        for k,v in self:GetPlatoonUnits() do
                            if not v.Dead and not v:IsIdleState() then
                                allIdle = false
                                break
                            end
                        end
                    until allIdle or blip:BeenDestroyed() or blip:IsKnownFake(index) or blip:IsMaybeDead(index)
                else
                    WaitTicks(20)
                end
            else
                local location = AIUtils.RandomLocation(aiBrain:GetArmyStartPos())
                self:MoveToLocation(location, false)
                self:PlatoonDisband()
            end
            WaitTicks(30)
        end
    end,

    ScoutingAIRNG = function(self)
        AIAttackUtils.GetMostRestrictiveLayer(self)

        if self.MovementLayer == 'Air' then
            return self:AirScoutingAIRNG()
        else
            return self:LandScoutingAIRNG()
        end
    end,

    AirScoutingAIRNG = function(self)
        --LOG('* AI-RNG: Starting AirScoutAIRNG')
        local patrol = self.PlatoonData.Patrol or false
        local acuSupport = self.PlatoonData.ACUSupport or false
        local scout = GetPlatoonUnits(self)[1]
        local unknownLoop = 0
        if not scout then
            return
        end
        --LOG('* AI-RNG: Patrol function is :'..tostring(patrol))
        local aiBrain = self:GetBrain()

        -- build scoutlocations if not already done.
        if not aiBrain.InterestList then
            aiBrain:BuildScoutLocations()
        end

        --If we have Stealth (are cybran), then turn on our Stealth
        if scout:TestToggleCaps('RULEUTC_CloakToggle') then
            scout:SetScriptBit('RULEUTC_CloakToggle', false)
        end
        local estartX = nil
        local estartZ = nil
        local startX = nil 
        local startZ = nil
        
        if patrol == true then
            --LOG('* AI-RNG: Patrol function is true, starting patrol function')
            local patrolTime = self.PlatoonData.PatrolTime or 30
            --local baseArea = self.PlatoonData.MilitaryArea or 'BaseDMZArea'

            local patrolPositionX = nil
            local patrolPositionZ = nil
            while not scout.Dead do
                startX, startZ = aiBrain:GetArmyStartPos()
                --LOG('* AI-RNG: Start Location X Z :'..startX..startZ)
                if aiBrain:GetCurrentEnemy() then
                    estartX, estartZ = aiBrain:GetCurrentEnemy():GetArmyStartPos()
                else
                    --LOG('No Current enemy')
                end
                local rng = math.random(1,3)
                if rng == 1 then
                    --LOG('* AI-RNG: Patroling BaseMilitaryArea')
                    patrolPositionX = (estartX + startX) / 2.2
                    patrolPositionZ = (estartZ + startZ) / 2.2
                elseif rng == 2 then
                    --LOG('* AI-RNG: Patroling BaseRestrictedArea')
                    patrolPositionX = (estartX + startX) / 2
                    patrolPositionZ = (estartZ + startZ) / 2
                    patrolPositionX = (patrolPositionX + startX) / 2
                    patrolPositionZ = (patrolPositionZ + startZ) / 2
                elseif rng == 3 then
                    --LOG('* AI-RNG: Patroling BaseDMZArea')
                    patrolPositionX = (estartX + startX) / 2
                    patrolPositionZ = (estartZ + startZ) / 2
                end
                --LOG('* AI-RNG: Patrol Location X, Z :'..patrolPositionX..' '..patrolPositionZ)
                patrolLocations = RUtils.SetArcPoints({startX,0,startZ},{patrolPositionX,0,patrolPositionZ},40,5,50)
                --LOG('Patrol Locations :'..repr(patrolLocations))
                --LOG('* AI-RNG: Moving to Patrol Location'..patrolPositionX..' '..patrolPositionZ)
                self:MoveToLocation({patrolPositionX, 0, patrolPositionZ}, false)
                --LOG('* AI-RNG: Issuing Patrol Commands')
                local patrolunits = GetPlatoonUnits(self)
                for k, v in patrolLocations do
                    IssuePatrol(patrolunits, {v[1],0,v[3]})
                end
                WaitSeconds(patrolTime)
                --LOG('* AI-RNG: Scout Returning to base after patrol : {'..startX..', 0, '..startZ..'}')
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
        elseif acuSupport == true then
            while not scout.Dead and aiBrain.ACUSupport.Supported == true do
                local acuPos = aiBrain.ACUSupport.Position
                --LOG('ACU Supported is true, scout moving to patrol :'..repr(acuPos))
                local patrolTime = self.PlatoonData.PatrolTime or 30
                self:MoveToLocation(acuPos, false)
                local patrolunits = GetPlatoonUnits(self)
                IssueClearCommands(patrolunits)
                IssuePatrol(patrolunits, AIUtils.RandomLocation(acuPos[1], acuPos[3]))
                IssuePatrol(patrolunits, AIUtils.RandomLocation(acuPos[1], acuPos[3]))
                WaitSeconds(patrolTime)
                self:Stop()
                --LOG('* AI-RNG: Scout looping ACU support movement')
                WaitTicks(2)
            end
        elseif self.PlatoonData.ExpansionPatrol and not self.ExpansionsValidated then
            --LOG('Excess scout looking for expansion')
            local scoutPos = GetPlatoonPosition(self)
            local scoutMarker
            if RNGGETN(aiBrain.BrainIntel.ExpansionWatchTable) > 0  then
                for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
                    local distSq = VDist2Sq(v.Position[1],v.Position[3], scoutPos[1],  scoutPos[3])
                    if not v.ScoutAssigned then
                        scoutMarker = v
                        aiBrain.BrainIntel.ExpansionWatchTable[k].ScoutAssigned = self
                        --LOG('Expansion Best marker selected is index '..k..' at '..repr(scoutMarker.Position))
                        break
                    end
                end
            end
            if scoutMarker then
                self:Stop()
                self:MoveToLocation(scoutMarker.Position, false)
                while PlatoonExists(aiBrain, self) do
                   --('Air Expansion Scout Marker found, waiting to arrive')
                    --LOG('Distance from scout marker is '..VDist2Sq(scoutPos[1],scoutPos[3], scoutMarker.Position[1],scoutMarker.Position[3]))
                    WaitTicks(30)
                    if VDist2Sq(scoutPos[1],scoutPos[3], scoutMarker.Position[1],scoutMarker.Position[3]) < 2500 then
                        self:Stop()
                        --LOG('Scout has arrived at expansion, scanning for engineers')
                        for _, unit in GetPlatoonUnits(self) do
                            IssueClearCommands({unit})
                            IssuePatrol({unit}, AIUtils.RandomLocation(scoutMarker.Position[1],scoutMarker.Position[3]))
                            IssuePatrol({unit}, AIUtils.RandomLocation(scoutMarker.Position[1],scoutMarker.Position[3]))
                        end
                        while PlatoonExists(aiBrain, self) do
                            WaitTicks(300)
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        end
                    end
                    scoutPos = GetPlatoonPosition(self)
                end
            else
                self.ExpansionsValidated = true
            end
        else
            while not scout.Dead do
                local targetArea = false
                local highPri = false

                local mustScoutArea, mustScoutIndex = aiBrain:GetUntaggedMustScoutArea()
                local unknownThreats = aiBrain:GetThreatsAroundPosition(scout:GetPosition(), 16, true, 'Unknown')
                --LOG('Unknown Threat is'..repr(unknownThreats))

                --1) If we have any "must scout" (manually added) locations that have not been scouted yet, then scout them
                if mustScoutArea then
                    mustScoutArea.TaggedBy = scout
                    targetArea = mustScoutArea.Position

                --2) Scout high priority locations
                elseif aiBrain.IntelData.AirHiPriScouts < aiBrain.NumOpponents and aiBrain.IntelData.AirLowPriScouts < 1
                and RNGGETN(aiBrain.InterestList.HighPriority) > 0 then
                    aiBrain.IntelData.AirHiPriScouts = aiBrain.IntelData.AirHiPriScouts + 1
                    highPri = true
                    targetData = aiBrain.InterestList.HighPriority[1]
                    targetData.LastScouted = GetGameTimeSeconds()
                    targetArea = targetData.Position
                    aiBrain:SortScoutingAreas(aiBrain.InterestList.HighPriority)

                --3) Every time we scout NumOpponents number of high priority locations, scout a low priority location
                elseif aiBrain.IntelData.AirLowPriScouts < 1 and RNGGETN(aiBrain.InterestList.LowPriority) > 0 then
                    aiBrain.IntelData.AirHiPriScouts = 0
                    --LOG('Increase AirlowPriScouts')
                    aiBrain.IntelData.AirLowPriScouts = aiBrain.IntelData.AirLowPriScouts + 1
                    targetData = aiBrain.InterestList.LowPriority[1]
                    targetData.LastScouted = GetGameTimeSeconds()
                    targetArea = targetData.Position
                    aiBrain:SortScoutingAreas(aiBrain.InterestList.LowPriority)

                --4) Scout "unknown threat" areas with a threat higher than 25
                elseif RNGGETN(unknownThreats) > 0 and unknownThreats[1][3] > 25 and unknownLoop < 3 then
                    --LOG('Unknown Threats adding to scouts')
                    aiBrain:AddScoutArea({unknownThreats[1][1], 0, unknownThreats[1][2]})
                    unknownLoop = unknownLoop + 1
                
                else
                    --LOG('Reset scout priorities')
                    --Reset number of scoutings and start over
                    aiBrain.IntelData.AirLowPriScouts = 0
                    aiBrain.IntelData.AirHiPriScouts = 0
                end

                --Air scout do scoutings.
                if targetArea then
                    self:Stop()

                    local vec = self:DoAirScoutVecs(scout, targetArea)

                    while not scout.Dead and not scout:IsIdleState() do

                        --If we're close enough...
                        if VDist2Sq(vec[1], vec[3], scout:GetPosition()[1], scout:GetPosition()[3]) < 15625 then
                           if mustScoutArea then
                            --Untag and remove
                                for idx,loc in aiBrain.InterestList.MustScout do
                                    if loc == mustScoutArea then
                                       table.remove(aiBrain.InterestList.MustScout, idx)
                                       break
                                    end
                                end
                            end
                            --Break within 125 ogrids of destination so we don't decelerate trying to stop on the waypoint.
                            break
                        end

                        if VDist3(scout:GetPosition(), targetArea) < 25 then
                            break
                        end

                        WaitTicks(50)
                        --LOG('* AI-RNG: Scout looping position < 25 to targetArea')
                    end
                else
                    --LOG('No targetArea found')
                    --LOG('No target area, number of high pri scouts is '..aiBrain.IntelData.AirHiPriScouts)
                    --LOG('Num opponents is '..aiBrain.NumOpponents)
                    --LOG('Low pri scouts '..aiBrain.IntelData.AirLowPriScouts)
                    --LOG('HighPri Interest table scout is '..RNGGETN(aiBrain.InterestList.HighPriority))
                    WaitTicks(10)
                end
                WaitTicks(10)
                --LOG('* AI-RNG: Scout looping end of scouting interest table')
            end
        end
        startX, startZ = aiBrain:GetArmyStartPos()
        --LOG('* AI-RNG: Scout Returning to base : {'..startX..', 0, '..startZ..'}')
        self:MoveToLocation({startX, 0, startZ}, false)
        WaitTicks(50)
        self:PlatoonDisband()
    end,

    LandScoutingAIRNG = function(self)
        AIAttackUtils.GetMostRestrictiveLayer(self)

        local aiBrain = self:GetBrain()
        local scout = GetPlatoonUnits(self)[1]
        local intelRange = ALLBPS[scout.UnitId].Intel.RadarRadius
        local enemyUnitCheck = false
        local supportPlatoon = false
        local platoonNeedScout = false
        local scoutPos = false
        

        -- build scoutlocations if not already done.
        if not aiBrain.InterestList then
            aiBrain:BuildScoutLocations()
        end

        --If we have cloaking (are cybran), then turn on our cloaking
        --DUNCAN - Fixed to use same bits
        if scout:TestToggleCaps('RULEUTC_CloakToggle') then
            scout:SetScriptBit('RULEUTC_CloakToggle', false)
        end

        while not scout.Dead do
            --Head towards the the area that has not had a scout sent to it in a while
            local targetData = false
            local findPlatoonCounter = 0
            local excessPathFailures = 0

            --For every scouts we send to all opponents, send one to scout a low pri area.
            if aiBrain.IntelData.HiPriScouts < aiBrain.NumOpponents and RNGGETN(aiBrain.InterestList.HighPriority) > 0 then
                targetData = aiBrain.InterestList.HighPriority[1]
                aiBrain.IntelData.HiPriScouts = aiBrain.IntelData.HiPriScouts + 1
                targetData.LastScouted = GetGameTimeSeconds()

                aiBrain:SortScoutingAreas(aiBrain.InterestList.HighPriority)

            elseif RNGGETN(aiBrain.InterestList.LowPriority) > 0 then
                targetData = aiBrain.InterestList.LowPriority[1]
                aiBrain.IntelData.HiPriScouts = 0
                targetData.LastScouted = GetGameTimeSeconds()

                aiBrain:SortScoutingAreas(aiBrain.InterestList.LowPriority)
            else
                --Reset number of scoutings and start over
                aiBrain.IntelData.HiPriScouts = 0
            end

            --Is there someplace we should scout?
            if targetData then
                --Can we get there safely?
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, scout:GetPosition(), targetData.Position, 50) --DUNCAN - Increase threatwieght from 100
                self:Stop()
                WaitTicks(20)
                --Scout until we reach our destination
                if path then
                    local pathLength = RNGGETN(path)
                    for i=1, pathLength do
                        self:Stop()
                        self:MoveToLocation(path[i], false)
                        while not scout.Dead and not scout:IsIdleState() do
                            if self.PlatoonData.ExcessScout and (not platoonNeedScout) and findPlatoonCounter < 5 then
                                --LOG('Look for platoon that needs a scout')
                                WaitTicks(10)
                                platoonNeedScout, supportPlatoon = self:ScoutFindNearbyPlatoonsRNG(250)
                            end
                            if self.PlatoonData.ExcessScout and platoonNeedScout then
                                if PlatoonExists(aiBrain, supportPlatoon) then
                                    while not scout.Dead and PlatoonExists(aiBrain, supportPlatoon) do
                                        --LOG('Move to support platoon position')
                                        self:Stop()
                                        self:MoveToLocation(GetPlatoonPosition(supportPlatoon), false)
                                        WaitTicks(15)
                                    end
                                else
                                    platoonNeedScout = false
                                    findPlatoonCounter = findPlatoonCounter + 1
                                    self:Stop()
                                    break
                                end
                            end
                            if self.PlatoonData.ExcessScout and (not platoonNeedScout) and (not self.ExpansionsValidated) then
                                --LOG('Excess scout looking for expansion')
                                local scoutPos = scout:GetPosition()
                                local scoutMarker
                                if RNGGETN(aiBrain.BrainIntel.ExpansionWatchTable) > 0  then
                                    for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
                                        local distSq = VDist3Sq(v.Position, scoutPos)
                                        if AIAttackUtils.CanGraphToRNG(scoutPos, v.Position, self.MovementLayer) then
                                            if not v.ScoutAssigned then
                                                scoutMarker = v
                                                aiBrain.BrainIntel.ExpansionWatchTable[k].ScoutAssigned = self
                                                --LOG('Expansion Best marker selected is index '..k..' at '..repr(scoutMarker.Position))
                                                break
                                            end
                                        else
                                            WaitTicks(2)
                                        end
                                    end
                                end
                                if scoutMarker then
                                    --LOG('Scout Marker Found, moving to position')
                                    if PlatoonExists(aiBrain, self) then
                                        local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, scout:GetPosition(), scoutMarker.Position, 50)
                                        self:Stop()
                                        if path then
                                            local pathLength = RNGGETN(path)
                                            for i=1, pathLength-1 do
                                                self:MoveToLocation(path[i], false)
                                            end
                                            self:MoveToLocation(scoutMarker.Position, false)
                                        else
                                            excessPathFailures = excessPathFailures + 1
                                        end
                                        while PlatoonExists(aiBrain, self) do
                                            --LOG('Scout Marker Found, waiting to arrive, unit ID is '..scout.UnitId)
                                            --LOG('Distance from scout marker is '..VDist2Sq(scoutPos[1],scoutPos[3], scoutMarker.Position[1],scoutMarker.Position[3]))
                                            WaitTicks(50)
                                            scoutPos = scout:GetPosition()
                                            if scout.UnitId == 'xsl0101' and VDist2Sq(scoutPos[1],scoutPos[3], scoutMarker.Position[1],scoutMarker.Position[3]) < 625 then
                                                IssueStop({scout})
                                                --LOG('Scout has arrived at expansion, scanning for engineers')
                                                while PlatoonExists(aiBrain, self) do
                                                    if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), scoutPos, 25, 'Enemy') > 0 then
                                                        local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), scoutPos, 25, 'Enemy')
                                                        if enemyEngineer[1] and not enemyEngineer[1].Dead then
                                                            --LOG('Scout Marker enemy engineer found, attacking')
                                                            while enemyEngineer[1] and not enemyEngineer[1].Dead do
                                                                IssueStop({scout})
                                                                IssueAttack({scout}, enemyEngineer[1])
                                                                WaitTicks(30)
                                                            end
                                                            self:MoveToLocation(scoutMarker.Position, false)
                                                            WaitTicks(30)
                                                            IssueStop({scout})
                                                        end
                                                    end
                                                    WaitTicks(50)
                                                end
                                            end
                                        end
                                    end
                                else
                                    self.ExpansionsValidated = true
                                end
                            end
                            WaitTicks(20)
                            if not scout.Dead then
                                scoutPos = scout:GetPosition()
                                if VDist2Sq(scoutPos[1], scoutPos[3], targetData.Position[1], targetData.Position[3]) > 14400 then
                                    enemyUnitCheck = GetUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND * categories.DIRECTFIRE - categories.SCOUT, scoutPos, intelRange, 'Enemy')
                                    if RNGGETN(enemyUnitCheck) > 0 then
                                        for _, v in enemyUnitCheck do
                                            if not v.Dead then
                                                self:Stop()
                                                self:MoveToLocation(RUtils.AvoidLocation(v:GetPosition(), scoutPos, intelRange - 5), false)
                                                break
                                            end
                                        end
                                    end
                                end
                                if VDist2Sq(scoutPos[1], scoutPos[3], path[i][1], path[i][3]) < 400 then
                                    break
                                end
                            end
                        end
                    end
                else
                    WaitTicks(50)
                end
            end
            WaitTicks(10)
        end
    end,

    HuntAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local blip
        local platoonUnits = GetPlatoonUnits(self)
        local enemyRadius = 40
        local movingToScout = false
        local MaxPlatoonWeaponRange
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        local scoutUnit
        AIAttackUtils.GetMostRestrictiveLayer(self)
        local function VariableKite(platoon,unit,target)
            local function KiteDist(pos1,pos2,distance)
                local vec={}
                local dist=VDist3(pos1,pos2)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel = {}
                vel[1], vel[2], vel[3]=target:GetVelocity()
                --LOG('vel is '..repr(vel))
                --LOG(repr(pos1))
                --LOG(repr(pos2))
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            if target.Dead then return end
            if unit.Dead then return end
                
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=3
            if CheckRetreat(pos,tpos,target) then
                mod=8
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod)
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod)
            end
            if VDist3Sq(pos,dest)>6 then
                IssueMove({unit},dest)
                WaitTicks(20)
                return
            else
                WaitTicks(20)
                return
            end
        end

        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if EntityCategoryContains(categories.SCOUT, v) then
                        self.ScoutPresent = true
                        scoutUnit = v
                    end
                    for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                            -- save the weaponrange 
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                        if not MaxPlatoonWeaponRange or MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        while PlatoonExists(aiBrain, self) do
            if aiBrain.EnemyIntel.ACUEnemyClose then
                --LOG('HuntAI Enemy ACU Close, setting attack priority')
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.MOBILE * categories.COMMAND)
            else
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.AIR - categories.SCOUT - categories.WALL - categories.NAVAL)
            end
            if target then
                local threatAroundplatoon = 0
                local platoonThreat = self:GetPlatoonThreat('Land', categories.MOBILE * categories.LAND)
                local targetPosition = target:GetPosition()
                local platoonPos = GetPlatoonPosition(self)
                if not AIAttackUtils.CanGraphToRNG(platoonPos, targetPosition, self.MovementLayer) then return self:SetAIPlanRNG('HuntAIPATHRNG') end
                local platoonThreat = self:CalculatePlatoonThreat('AntiSurface', categories.ALLUNITS)

                self:Stop()
                self:AggressiveMoveToLocation(table.copy(target:GetPosition()))
                local position = AIUtils.RandomLocation(target:GetPosition()[1],target:GetPosition()[3])
                self:MoveToLocation(position, false)
                WaitTicks(30)
                platoonPos = GetPlatoonPosition(self)
                if scoutUnit and (not scoutUnit.Dead) then
                    IssueClearCommands({scoutUnit})
                    IssueMove({scoutUnit}, platoonPos)
                end
                if not platoonPos then break end
                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, platoonPos, enemyRadius, 'Enemy')
                if enemyUnitCount > 0 then
                    target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                    attackSquad = self:GetSquadUnits('Attack')
                    IssueClearCommands(attackSquad)
                    if target then
                        if EntityCategoryContains(categories.COMMAND, target) and not aiBrain.ACUSupport.Supported then
                            if platoonThreat < 30 then
                                self:Stop()
                                self:MoveToLocation(RUtils.AvoidLocation(self:GetPosition(), targetPosition, 40), false)
                                --LOG('Target is ACU retreating')
                                --LOG('Threat Around platoon at 50 Radius = '..threatAroundplatoon)
                                --LOG('Platoon Threat = '..platoonThreat)
                                WaitTicks(40)
                                continue
                            end
                        end
                        while PlatoonExists(aiBrain, self) do
                            if not target.Dead then
                                --targetPosition = target:GetPosition()
                                local microCap = 50
                                for _, unit in attackSquad do
                                    microCap = microCap - 1
                                    if microCap <= 0 then break end
                                    if unit.Dead then continue end
                                    if not unit.MaxWeaponRange then
                                        continue
                                    end
                                    VariableKite(self,unit,target)
                                    if target.Dead then break end
                                end
                            else
                                break
                            end
                        WaitTicks(10)
                        end
                    end
                end
            elseif not movingToScout then
                movingToScout = true
                self:Stop()
                for k,v in AIUtils.AIGetSortedMassLocations(aiBrain, 10, nil, nil, nil, nil, GetPlatoonPosition(self)) do
                    if v[1] < 0 or v[3] < 0 or v[1] > ScenarioInfo.size[1] or v[3] > ScenarioInfo.size[2] then
                        --LOG('*AI DEBUG: STRIKE FORCE SENDING UNITS TO WRONG LOCATION - ' .. v[1] .. ', ' .. v[3])
                    end
                    self:MoveToLocation((v), false)
                end
            end
        WaitTicks(40)
        end
    end,

    HuntAIPATHRNG = function(self)
        --LOG('* AI-RNG: * HuntAIPATH: Starting')
        self:Stop()
        AIAttackUtils.GetMostRestrictiveLayer(self)
        local DEBUG = false
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target, acuInRange
        local blip
        local categoryList = {}
        local atkPri = {}
        local platoonUnits = GetPlatoonUnits(self)
        local maxPathDistance = 250
        local enemyRadius = 40
        local data = self.PlatoonData
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local bAggroMove = self.PlatoonData.AggressiveMove
        local LocationType = self.PlatoonData.LocationType or 'MAIN'
        local maxRadius = data.SearchRadius or 250
        local mainBasePos
        local scoutUnit
        if LocationType then
            mainBasePos = aiBrain.BuilderManagers[LocationType].Position
        else
            mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        end
        local MaxPlatoonWeaponRange
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        local rangeModifier = 0
        local platoonThreat = false
        
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if EntityCategoryContains(categories.SCOUT, v) then
                        self.ScoutPresent = true
                        scoutUnit = v
                    end
                    for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                            -- save the weaponrange 
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                        if not MaxPlatoonWeaponRange or MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        if data.TargetSearchPriorities then
            --LOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                RNGINSERT(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    RNGINSERT(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end

        RNGINSERT(atkPri, categories.ALLUNITS)
        RNGINSERT(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Attack', categoryList)

        --local debugloop = 0

        while PlatoonExists(aiBrain, self) do
            --LOG('* AI-RNG: * HuntAIPATH:: Check for target')
            --target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
            if DEBUG then
                for _, v in platoonUnits do
                    if v and not v.Dead then
                        v:SetCustomName('HuntAIPATH Looking for Target')
                    end
                end
            end
            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri)
            --[[if not target then
                LOG('No target on huntaipath loop')
                LOG('Max Radius is '..maxRadius)
                LOG('Debug loop is '..debugloop)
                debugloop = debugloop + 1
            end]]
            platoonThreat = self:CalculatePlatoonThreat('AntiSurface', categories.ALLUNITS)
            local platoonCount = RNGGETN(GetPlatoonUnits(self))
            if target then
                local targetPosition = target:GetPosition()
                local platoonPos = GetPlatoonPosition(self)
                local targetThreat
                if platoonThreat and platoonCount < platoonLimit then
                    self.PlatoonFull = false
                    --LOG('Merging with patoon count of '..platoonCount)
                    if VDist2Sq(platoonPos[1], platoonPos[3], mainBasePos[1], mainBasePos[3]) > 6400 then
                        targetThreat = GetThreatAtPosition(aiBrain, targetPosition, 0, true, 'Land')
                        --LOG('HuntAIPath targetThreat is '..targetThreat)
                        if targetThreat > platoonThreat then
                            --LOG('HuntAIPath attempting merge and formation ')
                            if DEBUG then
                                for _, v in platoonUnits do
                                    if v and not v.Dead then
                                        v:SetCustomName('HuntAIPATH Trying to Merge')
                                    end
                                end
                            end
                            self:Stop()
                            local merged = self:MergeWithNearbyPlatoonsRNG('HuntAIPATHRNG', 60, 25)
                            if merged then
                                self:SetPlatoonFormationOverride('AttackFormation')
                                WaitTicks(40)
                                --LOG('HuntAIPath merge and formation completed')
                                self:SetPlatoonFormationOverride('NoFormation')
                                continue
                            else
                                --LOG('No merge done')
                            end
                        end
                    end
                else
                    --LOG('Setting platoon to full as platoonCount is greater than 15')
                    self.PlatoonFull = true
                end
                --LOG('* AI-RNG: * HuntAIPATH: Performing Path Check')
                --LOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' Target Position :'..repr(targetPosition))
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), targetPosition, 10 , maxPathDistance)
                local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, targetPosition)
                IssueClearCommands(GetPlatoonUnits(self))
                local usedTransports = false
                if path then
                    local threatAroundplatoon = 0
                    --LOG('* AI-RNG: * HuntAIPATH:: Target Found')
                    if EntityCategoryContains(categories.COMMAND, target) and not aiBrain.ACUSupport.Supported then
                        platoonPos = GetPlatoonPosition(self)
                        targetPosition = target:GetPosition()
                        if platoonThreat < 30 then
                            local retreatPos = RUtils.lerpy(platoonPos, targetPosition, {50, 1})
                            self:MoveToLocation(retreatPos, false)
                            --LOG('Target is ACU retreating')
                            WaitTicks(30)
                            continue
                        end
                    end
                    local attackUnits =  self:GetSquadUnits('Attack')
                    local attackUnitCount = RNGGETN(attackUnits)
                    local guardUnits = self:GetSquadUnits('Guard')
                    
                    --LOG('* AI-RNG: * HuntAIPATH: Path found')
                    local position = GetPlatoonPosition(self)
                    if not success or VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 512 then
                        usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                    elseif VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 256 then
                        usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, false)
                    end
                    
                    if not usedTransports then
                        local pathNodesCount = RNGGETN(path)
                        for i=1, pathNodesCount do
                            local PlatoonPosition
                            local distEnd = false
                            if DEBUG then
                                for _, v in platoonUnits do
                                    if v and not v.Dead then
                                        v:SetCustomName('HuntAIPATH Performing Path Movement')
                                    end
                                end
                            end
                            if guardUnits then
                                local guardedUnit = 1
                                if attackUnitCount > 0 then
                                    while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                                        guardedUnit = guardedUnit + 1
                                        WaitTicks(3)
                                        if guardedUnit > attackUnitCount then
                                            guardedUnit = false
                                            break
                                        end
                                    end
                                else
                                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                                end
                                IssueClearCommands(guardUnits)
                                if not guardedUnit then
                                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                                else
                                    IssueGuard(guardUnits, attackUnits[guardedUnit])
                                end
                            end
                            local currentLayerSeaBed = false
                            for _, v in attackUnits do
                                if v and not v.Dead then
                                    if v:GetCurrentLayer() ~= 'Seabed' then
                                        currentLayerSeaBed = false
                                        break
                                    else
                                        --LOG('Setting currentLayerSeaBed to true')
                                        currentLayerSeaBed = true
                                        break
                                    end
                                end
                            end
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to destination. i: '..i..' coords '..repr(path[i]))
                            if bAggroMove and attackUnits and (not currentLayerSeaBed) then
                                if distEnd and distEnd > 6400 then
                                    self:SetPlatoonFormationOverride('NoFormation')
                                    attackFormation = false
                                end
                                self:AggressiveMoveToLocation(path[i], 'Attack')
                            elseif attackUnits then
                                if distEnd and distEnd > 6400 then
                                    self:SetPlatoonFormationOverride('NoFormation')
                                    attackFormation = false
                                end
                                self:MoveToLocation(path[i], false, 'Attack')
                            end
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to Waypoint')
                            local Lastdist
                            local dist
                            local Stuck = 0
                            local retreatCount = 2
                            local attackFormation = false
                            while PlatoonExists(aiBrain, self) do
                                --LOG('Movement Loop '..debugloop)
                                --debugloop = debugloop + 1
                                local SquadPosition = self:GetSquadPosition('Attack') or nil
                                if not SquadPosition then break end
                                if scoutUnit and (not scoutUnit.Dead) then
                                    IssueClearCommands({scoutUnit})
                                    IssueMove({scoutUnit}, SquadPosition)
                                end
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, enemyRadius, 'Enemy')
                                if enemyUnitCount > 0 and (not currentLayerSeaBed) then
                                    if DEBUG then
                                        for _, v in platoonUnits do
                                            if v and not v.Dead then
                                                v:SetCustomName('HuntAIPATH Found close target, searching for target')
                                            end
                                        end
                                    end
                                    target, acuInRange, acuUnit = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, SquadPosition, 'Attack', enemyRadius, categories.LAND * (categories.STRUCTURE + categories.MOBILE), atkPri, false)
                                    --target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    while PlatoonExists(aiBrain, self) do
                                        --LOG('Micro target Loop '..debugloop)
                                        --debugloop = debugloop + 1
                                        platoonThreat = self:CalculatePlatoonThreat('Surface', categories.DIRECTFIRE)
                                        if target and not target.Dead then
                                            if DEBUG then
                                                for _, v in platoonUnits do
                                                    if v and not v.Dead then
                                                        v:SetCustomName('HuntAIPATH Target Found, attacking')
                                                    end
                                                end
                                            end
                                            if acuUnit and platoonThreat > 30 then
                                                --LOG('ACU is close and we have decent threat')
                                                target = acuUnit
                                                rangeModifier = 5
                                            end
                                            targetPosition = target:GetPosition()
                                            local microCap = 50
                                            for _, unit in attackSquad do
                                                microCap = microCap - 1
                                                if microCap <= 0 then break end
                                                if unit.Dead then continue end
                                                if not unit.MaxWeaponRange then
                                                    continue
                                                end
                                                unitPos = unit:GetPosition()
                                                alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                                x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange - rangeModifier or MaxPlatoonWeaponRange)
                                                y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange - rangeModifier or MaxPlatoonWeaponRange)
                                                smartPos = { x, GetTerrainHeight( x, y), y }
                                                -- check if the move position is new or target has moved
                                                if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                                    -- clear move commands if we have queued more than 4
                                                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                                                        IssueClearCommands({unit})
                                                        coroutine.yield(3)
                                                    end
                                                    -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                                    IssueMove({unit}, smartPos )
                                                    if target.Dead then break end
                                                    IssueAttack({unit}, target)
                                                    --unit:SetCustomName('Fight micro moving')
                                                    unit.smartPos = smartPos
                                                    unit.TargetPos = targetPosition
                                                -- in case we don't move, check if we can fire at the target
                                                else
                                                    local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                        --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                        IssueMove({unit}, targetPosition )
                                                    else
                                                        --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                    end
                                                end
                                            end
                                        else
                                            break
                                        end
                                        WaitTicks(10)
                                    end
                                end
                                distEnd = VDist2Sq(path[pathNodesCount][1], path[pathNodesCount][3], SquadPosition[1], SquadPosition[3] )
                                --LOG('* AI-RNG: * MovePath: dist to Path End: '..distEnd)
                                if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                                    attackFormation = true
                                    --LOG('* AI-RNG: * MovePath: distEnd < 6400 '..distEnd..' Switching to attack formation')
                                    self:SetPlatoonFormationOverride('AttackFormation')
                                end
                                dist = VDist2Sq(path[i][1], path[i][3], SquadPosition[1], SquadPosition[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                --LOG('* AI-RNG: * HuntAIPATH: Distance to path node'..dist)
                                if dist < 400 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    self:Stop()
                                    break
                                end
                                if Lastdist ~= dist then
                                    Stuck = 0
                                    Lastdist = dist
                                -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                else
                                    Stuck = Stuck + 1
                                    if Stuck > 15 then
                                        --LOG('* AI-RNG: * HuntAIPATH: Stuck while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                end
                                --LOG('* AI-RNG: * HuntAIPATH: End of movement loop, wait 10 ticks at :'..GetGameTimeSeconds())
                                WaitTicks(15)
                            end
                            --LOG('* AI-RNG: * HuntAIPATH: Ending Loop at :'..GetGameTimeSeconds())
                        end
                    end
                elseif (not path and reason == 'NoPath') then
                    --LOG('* AI-RNG: * HuntAIPATH: NoPath reason from path')
                    --LOG('Guardmarker requesting transports')
                    if DEBUG then
                        for _, v in platoonUnits do
                            if v and not v.Dead then
                                v:SetCustomName('HuntAIPATH Requesting Transport')
                            end
                        end
                    end
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                    --DUNCAN - if we need a transport and we cant get one the disband
                    if not usedTransports then
                        --LOG('* AI-RNG: * HuntAIPATH: not used transports')
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    --LOG('Guardmarker found transports')
                else
                    --LOG('* AI-RNG: * HuntAIPATH: No Path found, no reason')
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end

                if (not path or not success) and not usedTransports then
                    --LOG('* AI-RNG: * HuntAIPATH: No Path found, no transports used')
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
            elseif self.PlatoonData.GetTargetsFromBase then
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            --LOG('* AI-RNG: * HuntAIPATH: No target, waiting 5 seconds')
            WaitTicks(50)
        end
    end,

    NavalRangedAIRNG = function(self)
        --LOG('* AI-RNG: * NavalRangedAIRNG: Starting')
        self:Stop()
        AIAttackUtils.GetMostRestrictiveLayer(self)
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target, acuInRange
        local blip
        local categoryList = {}
        local atkPri = {}
        local platoonUnits = GetPlatoonUnits(self)
        local enemyRadius = 40
        local data = self.PlatoonData
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local bAggroMove = self.PlatoonData.AggressiveMove
        local maxRadius = data.SearchRadius or 200
        local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        local MaxPlatoonWeaponRange
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        local platoonThreat = false
        local rangedPosition = false
        local SquadPosition = {}
        local rangedPositionDistance = 99999999
        
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                            -- save the weaponrange 
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                        if not MaxPlatoonWeaponRange or MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        if data.TargetSearchPriorities then
            --LOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                RNGINSERT(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    RNGINSERT(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end

        RNGINSERT(atkPri, 'ALLUNITS')
        RNGINSERT(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Artillery', categoryList)
        self:SetPrioritizedTargetList('Attack', {categories.MOBILE * categories.NAVAL, categories.ALLUNITS})

        while PlatoonExists(aiBrain, self) do
            --LOG('* AI-RNG: * NavalRangedAIRNG:: Check for target')
            rangedPosition = RUtils.AIFindRangedAttackPositionRNG(aiBrain, self, MaxPlatoonWeaponRange)
            --target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri)
            platoonThreat = self:CalculatePlatoonThreat('Naval', categories.ALLUNITS)
            local platoonCount = RNGGETN(GetPlatoonUnits(self))
            if rangedPosition then
                local platoonPos = GetPlatoonPosition(self)
                local positionThreat
                if platoonThreat and platoonCount < platoonLimit then
                    self.PlatoonFull = false
                    --LOG('Merging with patoon count of '..platoonCount)
                    if VDist2Sq(platoonPos[1], platoonPos[3], mainBasePos[1], mainBasePos[3]) > 6400 then
                        positionThreat = GetThreatAtPosition(aiBrain, rangedPosition, 0, true, 'Naval')
                        --LOG('NavalRangedAIRNG targetThreat is '..targetThreat)
                        if positionThreat > platoonThreat then
                            --LOG('NavalRangedAIRNG attempting merge and formation ')
                            self:Stop()
                            local merged = self:MergeWithNearbyPlatoonsRNG('NavalAIPATHRNG', 60, 15)
                            if merged then
                                self:SetPlatoonFormationOverride('AttackFormation')
                                WaitTicks(40)
                                --LOG('NavalRangedAIRNG merge and formation completed')
                                continue
                            else
                                --LOG('No merge done')
                            end
                        end
                    end
                else
                    --LOG('Setting platoon to full as platoonCount is greater than 15')
                    self.PlatoonFull = true
                end
                --LOG('* AI-RNG: * HuntAIPATH: Performing Path Check')
                rangedPositionDistance = VDist2Sq(platoonPos[1], platoonPos[3], rangedPosition[1], rangedPosition[3])
                if rangedPositionDistance > 6400 then
                    --LOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' rangedPosition Position :'..repr(rangedPosition))
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), rangedPosition, 10 , 1000)
                    local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, rangedPosition)
                    IssueClearCommands(GetPlatoonUnits(self))
                    if path then
                        local threatAroundplatoon = 0
                        --LOG('* AI-RNG: * HuntAIPATH:: Target Found')
                        local attackUnits =  self:GetSquadUnits('Attack')
                        local attackUnitCount = RNGGETN(attackUnits)
                        --LOG('* AI-RNG: * HuntAIPATH: Path found')
                        local position = GetPlatoonPosition(self)
                        if not success then
                            --LOG('Cant path to target position')
                        end
                        local pathNodesCount = RNGGETN(path)
                        for i=1, pathNodesCount do
                            local PlatoonPosition
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to destination. i: '..i..' coords '..repr(path[i]))
                            if bAggroMove and attackUnits then
                                self:AggressiveMoveToLocation(path[i])
                            elseif attackUnits then
                                self:MoveToLocation(path[i], false)
                            end
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to Waypoint')
                            local Lastdist
                            local dist
                            local Stuck = 0
                            local retreatCount = 2
                            local attackFormation = false
                            rangedPositionDistance = 99999999
                            while PlatoonExists(aiBrain, self) do
                                platoonPos = GetPlatoonPosition(self)
                                if not platoonPos then break end
                                local targetPosition
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.NAVAL - categories.SCOUT - categories.ENGINEER, platoonPos, enemyRadius, 'Enemy')
                                if enemyUnitCount > 0 then
                                    --target = self:FindClosestUnit('Attack', 'Enemy', true, categories.MOBILE * (categories.NAVAL) - categories.SCOUT - categories.WALL)
                                    target, acuInRange = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPos, 'Attack', enemyRadius, categories.MOBILE * (categories.NAVAL + categories.AMPHIBIOUS) - categories.AIR - categories.SCOUT - categories.WALL, atkPri, false)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    while PlatoonExists(aiBrain, self) do
                                        if target and not target.Dead then
                                            targetPosition = target:GetPosition()
                                            local microCap = 50
                                            for _, unit in attackSquad do
                                                microCap = microCap - 1
                                                if microCap <= 0 then break end
                                                if unit.Dead then continue end
                                                if not unit.MaxWeaponRange then
                                                    continue
                                                end
                                                unitPos = unit:GetPosition()
                                                alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                                x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange or MaxPlatoonWeaponRange)
                                                y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange or MaxPlatoonWeaponRange)
                                                smartPos = { x, GetTerrainHeight( x, y), y }
                                                -- check if the move position is new or target has moved
                                                if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                                    -- clear move commands if we have queued more than 4
                                                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                                                        IssueClearCommands({unit})
                                                        coroutine.yield(3)
                                                    end
                                                    -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                                    IssueMove({unit}, smartPos )
                                                    if target.Dead then break end
                                                    IssueAttack({unit}, target)
                                                    --unit:SetCustomName('Fight micro moving')
                                                    unit.smartPos = smartPos
                                                    unit.TargetPos = targetPosition
                                                -- in case we don't move, check if we can fire at the target
                                                else
                                                    local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                        --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                        IssueMove({unit}, targetPosition )
                                                    else
                                                        --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                    end
                                                end
                                            end
                                        else
                                            break
                                        end
                                        WaitTicks(10)
                                    end
                                end
                                distEnd = VDist2Sq(path[pathNodesCount][1], path[pathNodesCount][3], platoonPos[1], platoonPos[3] )
                                --LOG('* AI-RNG: * MovePath: dist to Path End: '..distEnd)
                                if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                                    attackFormation = true
                                    --LOG('* AI-RNG: * MovePath: distEnd < 50 '..distEnd)
                                    self:SetPlatoonFormationOverride('AttackFormation')
                                end
                                dist = VDist2Sq(path[i][1], path[i][3], platoonPos[1], platoonPos[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                --LOG('* AI-RNG: * HuntAIPATH: Distance to path node'..dist)
                                if dist < 400 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    self:Stop()
                                    break
                                end
                                if Lastdist ~= dist then
                                    Stuck = 0
                                    Lastdist = dist
                                -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                else
                                    Stuck = Stuck + 1
                                    if Stuck > 15 then
                                        --LOG('* AI-RNG: * HuntAIPATH: Stuck while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                end
                                --LOG('* AI-RNG: * HuntAIPATH: End of movement loop, wait 20 ticks at :'..GetGameTimeSeconds())
                                WaitTicks(20)
                                rangedPositionDistance = VDist2Sq(platoonPos[1], platoonPos[3], rangedPosition[1], rangedPosition[3])
                                --LOG('MaxPlatoonWeaponRange is '..MaxPlatoonWeaponRange..' current distance is '..rangedPositionDistance)
                                if rangedPositionDistance < (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange) then
                                    --LOG('Within Range of End Position')
                                    break
                                end
                            end
                            --LOG('* AI-RNG: * HuntAIPATH: Ending Loop at :'..GetGameTimeSeconds())
                        end
                    elseif (not path and reason == 'NoPath') then
                        --LOG('* AI-RNG: * NavalAIPATH: NoPath reason from path')
                    else
                        --LOG('* AI-RNG: * HuntAIPATH: No Path found, no reason')
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    if not path or not success then
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                end
                if rangedPosition then
                    --LOG('Ranged position is true')
                    local artillerySquadPosition = self:GetSquadPosition('Artillery') or nil
                    if not artillerySquadPosition then self:ReturnToBaseAIRNG() end
                    rangedPositionDistance = VDist2Sq(artillerySquadPosition[1], artillerySquadPosition[3], rangedPosition[1], rangedPosition[3])
                    if rangedPositionDistance < (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange) then
                        --LOG('Within Range of End Position, looking for target')
                        --target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Artillery', maxRadius, atkPri)
                        --LOG('Looking for target close range to rangedPosition')
                        target, acuInRange = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, rangedPosition, 'Artillery', MaxPlatoonWeaponRange + 30, categories.STRUCTURE, atkPri, false)
                        if target then
                            --LOG('Target Aquired by Artillery Squad')
                            local artillerySquad = self:GetSquadUnits('Artillery')
                            local attackUnits = self:GetSquadUnits('Attack')
                            if attackUnits then
                                --LOG('Number of attack units is '..RNGGETN(attackUnits))
                            end
                            if RNGGETN(artillerySquad) > 0 and RNGGETN(attackUnits) > 0 then
                                --LOG('Forking thread for artillery guard')
                                self:ForkThread(self.GuardArtillerySquadRNG, aiBrain, target)
                            end
                            while PlatoonExists(aiBrain, self) do
                                if target and not target.Dead then
                                    targetPosition = target:GetPosition()
                                    local microCap = 50
                                    for _, unit in artillerySquad do
                                        microCap = microCap - 1
                                        if microCap <= 0 then break end
                                        if unit.Dead then continue end
                                        if not unit.MaxWeaponRange then
                                            continue
                                        end
                                        unitPos = unit:GetPosition()
                                        alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                        x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange - 10 or MaxPlatoonWeaponRange)
                                        y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange - 10 or MaxPlatoonWeaponRange)
                                        smartPos = { x, GetTerrainHeight( x, y), y }
                                        -- check if the move position is new or target has moved
                                        if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                            -- clear move commands if we have queued more than 4
                                            if RNGGETN(unit:GetCommandQueue()) > 2 then
                                                IssueClearCommands({unit})
                                                coroutine.yield(3)
                                            end
                                            -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                            IssueMove({unit}, smartPos )
                                            if target.Dead then break end
                                            IssueAttack({unit}, target)
                                            --unit:SetCustomName('Fight micro moving')
                                            unit.smartPos = smartPos
                                            unit.TargetPos = targetPosition
                                        -- in case we don't move, check if we can fire at the target
                                        else
                                            local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                            if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                IssueMove({unit}, targetPosition )
                                            else
                                                --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                            end
                                        end
                                    end
                                else
                                    break
                                end
                                WaitTicks(10)
                            end
                        end
                    end
                end
                
            end
            --LOG('* AI-RNG: * HuntAIPATH: No target, waiting 5 seconds')
            WaitTicks(50)
        end
    end,

    NavalAttackAIRNG = function(self)
        --LOG('* AI-RNG: * NavalAttackAIRNG: Starting')
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target, acuInRange
        local blip
        local categoryList = {}
        local atkPri = {}
        local platoonUnits = GetPlatoonUnits(self)
        local enemyRadius = 60
        local data = self.PlatoonData
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local bAggroMove = self.PlatoonData.AggressiveMove
        local maxRadius = data.SearchRadius or 200
        local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        local MaxPlatoonWeaponRange
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        local platoonThreat = false
        local rangedPosition = false
        local SquadPosition = {}
        local rangedPositionDistance = 99999999
        AIAttackUtils.GetMostRestrictiveLayer(self)
        
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if weapon.WeaponCategory == 'Anti Air' then
                            continue
                        end
                        if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                            -- save the weaponrange 
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                        if not MaxPlatoonWeaponRange or MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        if data.TargetSearchPriorities then
            --LOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                RNGINSERT(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    RNGINSERT(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end

        RNGINSERT(atkPri, 'ALLUNITS')
        RNGINSERT(categoryList, categories.ALLUNITS)
        self:Stop()
        self:SetPrioritizedTargetList('Artillery', categoryList)
        self:SetPrioritizedTargetList('Attack', categoryList)
        self:SetPrioritizedTargetList('Guard', categories.NAVAL + categories.AMPHIBIOUS)

        while PlatoonExists(aiBrain, self) do
            --LOG('* AI-RNG: * NavalAttackAIRNG:: Check for attack position')
            --attackPosition = RUtils.AIFindRangedAttackPositionRNG(aiBrain, self, MaxPlatoonWeaponRange)
            local attackPosition = AIAttackUtils.GetBestNavalTargetRNG(aiBrain, self)
            if attackPosition then
                --LOG('position to attack '..repr(attackPosition))
            else
                --LOG('No position to attack for intelli naval')
            end
            platoonThreat = self:CalculatePlatoonThreat('Naval', categories.ALLUNITS)
            --('Platoon Naval Threat is '..platoonThreat)
            local platoonCount = RNGGETN(GetPlatoonUnits(self))
            if attackPosition then
                local platoonPos = GetPlatoonPosition(self)
                local positionThreat
                if platoonThreat and platoonCount < platoonLimit then
                    self.PlatoonFull = false
                    --LOG('Merging with patoon count of '..platoonCount)
                    if VDist2Sq(platoonPos[1], platoonPos[3], mainBasePos[1], mainBasePos[3]) > 6400 then
                        positionThreat = GetThreatAtPosition(aiBrain, attackPosition, 0, true, 'Naval')
                        --LOG('NavalRangedAIRNG targetThreat is '..targetThreat)
                        if positionThreat > platoonThreat then
                            --LOG('NavalRangedAIRNG attempting merge and formation ')
                            self:Stop()
                            local merged = self:MergeWithNearbyPlatoonsRNG('NavalAttackAIRNG', 120, 18)
                            if merged then
                                self:SetPlatoonFormationOverride('AttackFormation')
                                WaitTicks(40)
                                --LOG('NavalAttackAIRNG merge and formation completed')
                                continue
                            else
                                --LOG('No merge done')
                            end
                        end
                    end
                else
                    --LOG('Setting platoon to full as platoonCount is greater than 15')
                    self.PlatoonFull = true
                end
                --LOG('* AI-RNG: * HuntAIPATH: Performing Path Check')
                attackPositionDistance = VDist2Sq(platoonPos[1], platoonPos[3], attackPosition[1], attackPosition[3])
                if attackPositionDistance > 6400 then
                    --LOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' rangedPosition Position :'..repr(rangedPosition))
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), attackPosition, 10 , 1000)
                    local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, attackPosition)
                    IssueClearCommands(GetPlatoonUnits(self))
                    if path then
                        local threatAroundplatoon = 0
                        --LOG('* AI-RNG: * HuntAIPATH:: Target Found')
                        local attackUnits =  self:GetSquadUnits('Attack')
                        local attackUnitCount = RNGGETN(attackUnits)
                        --LOG('* AI-RNG: * HuntAIPATH: Path found')
                        local position = GetPlatoonPosition(self)
                        if not success then
                            --LOG('Cant path to target position')
                        end
                        local pathNodesCount = RNGGETN(path)
                        --LOG('NavalAttackAIRNG moving to attack position, check for squads that dont move')
                        for i=1, pathNodesCount do
                            local PlatoonPosition
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to destination. i: '..i..' coords '..repr(path[i]))
                            if bAggroMove and attackUnits then
                                self:AggressiveMoveToLocation(path[i])
                            elseif attackUnits and i ~= pathNodesCount then
                                self:MoveToLocation(path[i], false)
                            elseif attackUnits and i == pathNodesCount then
                                self:AggressiveMoveToLocation(path[i])
                            end
                            --LOG('* AI-RNG: * HuntAIPATH:: moving to Waypoint')
                            local Lastdist
                            local dist
                            local Stuck = 0
                            local retreatCount = 2
                            local attackFormation = false
                            attackPositionDistance = 99999999
                            while PlatoonExists(aiBrain, self) do
                                platoonPos = GetPlatoonPosition(self)
                                if not platoonPos then break end
                                local targetPosition
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.NAVAL - categories.SCOUT - categories.ENGINEER - categories.AIR, platoonPos, enemyRadius, 'Enemy')
                                if enemyUnitCount > 0 then
                                    --target = self:FindClosestUnit('Attack', 'Enemy', true, categories.MOBILE * (categories.NAVAL + categories.AMPHIBIOUS) - categories.AIR - categories.SCOUT - categories.WALL)
                                    target, acuInRange = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, platoonPos, 'Attack', enemyRadius, categories.MOBILE * (categories.NAVAL + categories.AMPHIBIOUS) - categories.AIR - categories.SCOUT - categories.WALL, atkPri, false)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    while PlatoonExists(aiBrain, self) do
                                        if target and not target.Dead then
                                            targetPosition = target:GetPosition()
                                            local microCap = 50
                                            for _, unit in attackSquad do
                                                microCap = microCap - 1
                                                if microCap <= 0 then break end
                                                if unit.Dead then continue end
                                                if not unit.MaxWeaponRange then
                                                    continue
                                                end
                                                unitPos = unit:GetPosition()
                                                alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                                x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange or MaxPlatoonWeaponRange)
                                                y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange or MaxPlatoonWeaponRange)
                                                smartPos = { x, GetTerrainHeight( x, y), y }
                                                -- check if the move position is new or target has moved
                                                if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                                    -- clear move commands if we have queued more than 4
                                                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                                                        IssueClearCommands({unit})
                                                        coroutine.yield(3)
                                                    end
                                                    -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                                    IssueMove({unit}, smartPos )
                                                    if target.Dead then break end
                                                    IssueAttack({unit}, target)
                                                    --unit:SetCustomName('Fight micro moving')
                                                    unit.smartPos = smartPos
                                                    unit.TargetPos = targetPosition
                                                -- in case we don't move, check if we can fire at the target
                                                else
                                                    local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                        --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                        IssueMove({unit}, targetPosition )
                                                    else
                                                        --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                    end
                                                end
                                            end
                                        else
                                            break
                                        end
                                        WaitTicks(10)
                                    end
                                end
                                distEnd = VDist2Sq(path[pathNodesCount][1], path[pathNodesCount][3], platoonPos[1], platoonPos[3] )
                                --LOG('* AI-RNG: * MovePath: dist to Path End: '..distEnd)
                                if not attackFormation and distEnd < 6400 and enemyUnitCount == 0 then
                                    attackFormation = true
                                    --LOG('* AI-RNG: * MovePath: distEnd < 50 '..distEnd)
                                    self:SetPlatoonFormationOverride('AttackFormation')
                                end
                                dist = VDist2Sq(path[i][1], path[i][3], platoonPos[1], platoonPos[3])
                                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                --LOG('* AI-RNG: * HuntAIPATH: Distance to path node'..dist)
                                if dist < 625 then
                                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                    self:Stop()
                                    break
                                end
                                if Lastdist ~= dist then
                                    Stuck = 0
                                    Lastdist = dist
                                -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                else
                                    Stuck = Stuck + 1
                                    if Stuck > 15 then
                                        --LOG('* AI-RNG: * HuntAIPATH: Stuck while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                end
                                --LOG('* AI-RNG: * HuntAIPATH: End of movement loop, wait 20 ticks at :'..GetGameTimeSeconds())
                                WaitTicks(20)
                                attackPositionDistance = VDist2Sq(platoonPos[1], platoonPos[3], attackPosition[1], attackPosition[3])
                                --LOG('MaxPlatoonWeaponRange is '..MaxPlatoonWeaponRange..' current distance is '..rangedPositionDistance)
                                if attackPositionDistance < (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange) then
                                    --LOG('Within Range of End Position')
                                    break
                                end
                            end
                            --LOG('* AI-RNG: * HuntAIPATH: Ending Loop at :'..GetGameTimeSeconds())
                        end
                    elseif (not path and reason == 'NoPath') then
                        --LOG('* AI-RNG: * NavalAIPATH: NoPath reason from path')
                    else
                        --LOG('* AI-RNG: * HuntAIPATH: No Path found, no reason')
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    if not path or not success then
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                end
            end
            WaitTicks(50)
        end
    end,

    StrikeForceAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local categoryList = {}
        local atkPri = {}
        local basePosition = false
        local platoonPosition
        local platoonLimit = self.PlatoonData.PlatoonLimit or 18
        local mergeRequired = false
        local platoonCount = 0
        local myThreat
        local unitPos
        local alpha
        local x
        local y
        local smartPos
        local platoonUnits = GetPlatoonUnits(self)
        local enemyRadius = 40
        local MaxPlatoonWeaponRange
        local target
        local acuTargeting = false
        local acuTargetIndex = {}
        local blip = false
        local maxRadius = data.SearchRadius or 50
        local movingToScout = false
        local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
        
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if EntityCategoryContains(categories.SCOUT, v) then
                        self.ScoutPresent = true
                    end
                    for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                            -- save the weaponrange 
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                        if not MaxPlatoonWeaponRange or MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end
        
        if data.TargetSearchPriorities then
            --LOG('TargetSearch present for '..self.BuilderName)
            for k,v in data.TargetSearchPriorities do
                RNGINSERT(atkPri, v)
            end
        else
            if data.PrioritizedCategories then
                for k,v in data.PrioritizedCategories do
                    RNGINSERT(atkPri, v)
                end
            end
        end
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end
        AIAttackUtils.GetMostRestrictiveLayer(self)
        
        -- Removing ALLUNITS so we rely on the builder config. Stops bombers trying to attack fighters.
        --RNGINSERT(atkPri, categories.ALLUNITS)
        --RNGINSERT(categoryList, categories.ALLUNITS)

        --LOG('Platoon is '..self.BuilderName..' table'..repr(categoryList))
        self:SetPrioritizedTargetList('Attack', categoryList)
        AIAttackUtils.GetMostRestrictiveLayer(self)

        if data.LocationType then
            basePosition = aiBrain.BuilderManagers[data.LocationType].Position
        end
        local myThreat = self:CalculatePlatoonThreat('AntiSurface', categories.ALLUNITS)
        --LOG('StrikeForceAI my threat is '..myThreat)
        --LOG('StrikeForceAI my movement layer is '..self.MovementLayer)
        if aiBrain.EnemyIntel.EnemyThreatCurrent.ACUGunUpgrades > 0 and myThreat > 0 and self.MovementLayer == 'Air' then
            for k, v in aiBrain.EnemyIntel.ACU do
                if v.OnField and v.Gun then
                    acuTargeting = true
                    RNGINSERT(acuTargetIndex, k)
                end
            end
        end
        while PlatoonExists(aiBrain, self) do
            if not target or target.Dead then
                if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                    aiBrain:PickEnemyLogicRNG()
                end
                if acuTargeting and not data.ACUOnField then
                    --LOG('GUN ACU OnField LOOKING FOR TARGET')
                    target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, myThreat)
                end
                if not target and self.MovementLayer == 'Air' then
                    --LOG('Checking for possible acu snipe')
                    local enemyACUIndexes = {}
                    for k, v in aiBrain.EnemyIntel.ACU do
                        if v.Hp != 0 and v.LastSpotted != 0 then
                            --LOG('ACU has '..v.Hp..' last spotted at '..v.LastSpotted..' our threat is '..myThreat)
                            if ((v.Hp / 275) < myThreat or v.Hp < 2000) and ((GetGameTimeSeconds() - 120) < v.LastSpotted) then
                                --LOG('ACU Target valid, adding to index list')
                                RNGINSERT(enemyACUIndexes, k)
                            end
                        end
                    end
                    if RNGGETN(enemyACUIndexes) > 0 then
                        --LOG('There is an ACU that could be sniped, look for targets')
                        target = RUtils.AIFindACUTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, myThreat, enemyACUIndexes)
                        if target then
                            --LOG('ACU found that coule be sniped, set to target')
                        end
                    end
                    if not target and myThreat > 8 and data.UnitType != 'GUNSHIP' then
                        --LOG('Checking for director target')
                        target = aiBrain:CheckDirectorTargetAvailable('AntiAir', myThreat)
                        if target then
                            --LOG('Target ID is '..target.UnitId)
                        end
                    end
                end
                
                if not target then
                    --LOG('Standard Target search for strikeforce platoon ')
                    if data.ACUOnField then
                        --LOG('Platoon has ACUOnField data, searching for energy to kill')
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri, false, myThreat, acuTargetIndex)
                    elseif data.Defensive then
                        target = RUtils.AIFindBrainTargetInRangeOrigRNG(aiBrain, basePosition, self, 'Attack', maxRadius , atkPri, aiBrain:GetCurrentEnemy())
                    elseif data.AvoidBases then
                        --LOG('Avoid Bases is set to true')
                        target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius , atkPri, data.AvoidBases, myThreat)
                    else
                        local mult = { 1,10,25 }
                        for _,i in mult do
                            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius * i, atkPri, false, myThreat)
                            if target then
                                break
                            end
                            WaitTicks(10) --DUNCAN - was 3
                            if not PlatoonExists(aiBrain, self) then
                                return
                            end
                        end
                    end
                end
                
                -- Check for experimentals but don't attack if they have strong antiair threat unless close to base.
                local newtarget
                if AIAttackUtils.GetSurfaceThreatOfUnits(self) > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * (categories.LAND + categories.NAVAL + categories.STRUCTURE))
                elseif AIAttackUtils.GetAirThreatOfUnits(self) > 0 then
                    newtarget = self:FindClosestUnit('Attack', 'Enemy', true, categories.EXPERIMENTAL * categories.AIR)
                end

                if newtarget then
                    local targetExpPos
                    local targetExpThreat
                    if self.MovementLayer == 'Air' then
                        targetExpPos = newtarget:GetPosition()
                        targetExpThreat = GetThreatAtPosition(aiBrain, targetExpPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                        --LOG('Target Air Threat is '..targetExpThreat)
                        --LOG('My Air Threat is '..myThreat)
                        if myThreat > targetExpThreat then
                            target = newtarget
                        elseif VDist2Sq(targetExpPos[1], targetExpPos[3], mainBasePos[1], mainBasePos[3]) < 22500 then
                            target = newtarget
                        end
                    else
                        target = newtarget
                    end
                end

                if not target and platoonCount < platoonLimit then
                    --LOG('StrikeForceAI mergeRequired set true')
                    mergeRequired = true
                end

                if target and not target.Dead then
                    if self.MovementLayer == 'Air' then
                        local targetPosition = target:GetPosition()
                        platoonPosition = GetPlatoonPosition(self)
                        platoonCount = RNGGETN(GetPlatoonUnits(self))
                        local targetDistance = VDist2Sq(platoonPosition[1], platoonPosition[3], targetPosition[1], targetPosition[3])
                        local path = false
                        if targetDistance < 10000 then
                            self:Stop()
                            self:AttackTarget(target)
                        else
                            local path, reason, totalThreat = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoonPosition, targetPosition, 10 , 10000)
                            self:Stop()
                            if path then
                                local pathLength = RNGGETN(path)
                                if not totalThreat then
                                    totalThreat = 1
                                end
                                --LOG('Total Threat for air is '..totalThreat)
                                local averageThreat = totalThreat / pathLength
                                local pathDistance
                                --LOG('StrikeForceAI average path threat is '..averageThreat)
                                --LOG('StrikeForceAI platoon threat is '..myThreat)
                                if averageThreat < myThreat or platoonCount >= platoonLimit then
                                    --LOG('StrikeForce air assigning path')
                                    for i=1, pathLength do
                                        self:MoveToLocation(path[i], false)
                                        while PlatoonExists(aiBrain, self) do
                                            platoonPosition = GetPlatoonPosition(self)
                                            targetPosition = target:GetPosition()
                                            targetDistance = VDist2Sq(platoonPosition[1], platoonPosition[3], targetPosition[1], targetPosition[3])
                                            if targetDistance < 10000 then
                                                --LOG('strikeforce air attack command on target')
                                                self:Stop()
                                                self:AttackTarget(target)
                                                break
                                            end
                                            pathDistance = VDist2Sq(path[i][1], path[i][3], platoonPosition[1], platoonPosition[3])
                                            if pathDistance < 900 then
                                                -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                                self:Stop()
                                                break
                                            end
                                            --LOG('Waiting to reach target loop')
                                            WaitTicks(10)
                                        end
                                        if not target or target.Dead then
                                            target = false
                                            --LOG('Target dead or lost during strikeforce')
                                            break
                                        end
                                    end
                                else
                                    --LOG('StrikeForceAI Path threat is too high, waiting and merging')
                                    mergeRequired = true
                                    target = false
                                    WaitTicks(30)
                                end
                            else
                                self:AttackTarget(target)
                            end
                        end
                    else
                        self:AttackTarget(target)
                        while PlatoonExists(aiBrain, self) do
                            if data.AggressiveMove then
                                SquadPosition = self:GetSquadPosition('Attack') or nil
                                if not SquadPosition then break end
                                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, enemyRadius, 'Enemy')
                                if enemyUnitCount > 0 then
                                    --LOG('Strikeforce land detected close target starting micro')
                                    target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                                    local attackSquad = self:GetSquadUnits('Attack')
                                    IssueClearCommands(attackSquad)
                                    while PlatoonExists(aiBrain, self) do
                                        if target and not target.Dead then
                                            local targetPosition = target:GetPosition()
                                            local microCap = 50
                                            for _, unit in attackSquad do
                                                microCap = microCap - 1
                                                if microCap <= 0 then break end
                                                if unit.Dead then continue end
                                                if not unit.MaxWeaponRange then
                                                    continue
                                                end
                                                unitPos = unit:GetPosition()
                                                alpha = math.atan2 (targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                                x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange or MaxPlatoonWeaponRange)
                                                y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange or MaxPlatoonWeaponRange)
                                                smartPos = { x, GetTerrainHeight( x, y), y }
                                                -- check if the move position is new or target has moved
                                                if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                                    -- clear move commands if we have queued more than 4
                                                    if RNGGETN(unit:GetCommandQueue()) > 2 then
                                                        IssueClearCommands({unit})
                                                        coroutine.yield(3)
                                                    end
                                                    -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                                    IssueMove({unit}, smartPos )
                                                    if target.Dead then break end
                                                    IssueAttack({unit}, target)
                                                    --unit:SetCustomName('Fight micro moving')
                                                    unit.smartPos = smartPos
                                                    unit.TargetPos = targetPosition
                                                -- in case we don't move, check if we can fire at the target
                                                else
                                                    local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                                    if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                                        --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                                        IssueMove({unit}, targetPosition )
                                                    else
                                                        --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                                    end
                                                end
                                            end
                                        else
                                            break
                                        end
                                        WaitTicks(10)
                                    end
                                end
                            end
                            if not target or target.Dead then
                                break
                            end
                            WaitTicks(30)
                        end
                    end
                elseif data.Defensive then 
                    WaitTicks(30)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG', true)
                elseif target.Dead then
                    --LOG('Strikeforce Target Dead performing loop')
                    target = false
                    WaitTicks(10)
                    continue
                else
                    --LOG('Strikeforce No Target we should be returning to base')
                    WaitTicks(30)
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG', true)
                end
            end
            WaitTicks(30)
            if not target and self.MovementLayer == 'Air' and mergeRequired then
                --LOG('StrkeForce Air AI Attempting Merge')
                self:MoveToLocation(mainBasePos, false)
                local baseDist
                --LOG('StrikefoceAI Returning to base')
                myThreat = self:CalculatePlatoonThreat('AntiSurface', categories.ALLUNITS)
                while PlatoonExists(aiBrain, self) do
                    platoonPosition = GetPlatoonPosition(self)
                    baseDist = VDist2Sq(platoonPosition[1], platoonPosition[3], mainBasePos[1], mainBasePos[3])
                    if baseDist < 6400 then
                        break
                    end
                    if not target and myThreat > 8 and data.UnitType != 'GUNSHIP' then
                        --LOG('Checking for director target')
                        target = aiBrain:CheckDirectorTargetAvailable('AntiAir', myThreat)
                        if target then
                            break
                        end
                    end
                    --LOG('StrikeforceAI base distance is '..baseDist)
                    WaitTicks(50)
                end
                --LOG('MergeRequired, performing merge')
                self:Stop()
                self:MergeWithNearbyPlatoonsRNG('StrikeForceAIRNG', 60, 20, true)
                mergeRequired = false
            end
        end
    end,

    -------------------------------------------------------
    --   Function: EngineerBuildAIRNG
    --   Args:
    --       self - the single-engineer platoon to run the AI on
    --   Description:
    --       a single-unit platoon made up of an engineer, this AI will determine
    --       what needs to be built (based on platoon data set by the calling
    --       abstraction, and then issue the build commands to the engineer
    --   Returns:
    --       nil (tail calls into a behavior function)
    -------------------------------------------------------
    EngineerBuildAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local armyIndex = aiBrain:GetArmyIndex()
        --local x,z = aiBrain:GetArmyStartPos()
        local cons = self.PlatoonData.Construction
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault

        local eng
        for k, v in platoonUnits do
            if not v.Dead and EntityCategoryContains(categories.ENGINEER, v) then --DUNCAN - was construction
                IssueClearCommands({v})
                if not eng then
                    eng = v
                else
                    IssueGuard({v}, eng)
                end
            end
        end

        if not eng or eng.Dead then
            WaitTicks(1)
            self:PlatoonDisband()
            return
        end
        
        --DUNCAN - added
        if eng:IsUnitState('Building') or eng:IsUnitState('Upgrading') or eng:IsUnitState("Enhancing") then
           return
        end

        local FactionToIndex  = { UEF = 1, AEON = 2, CYBRAN = 3, SERAPHIM = 4, NOMADS = 5}
        local factionIndex = cons.FactionIndex or FactionToIndex[eng.factionCategory]

        buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
        baseTmplFile = import(cons.BaseTemplateFile or '/lua/BaseTemplates.lua')
        baseTmplDefault = import('/lua/BaseTemplates.lua')
        buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]
        baseTmpl = baseTmplFile[(cons.BaseTemplate or 'BaseTemplates')][factionIndex]

        --LOG('*AI DEBUG: EngineerBuild AI ' .. eng.Sync.id)

        if self.PlatoonData.NeedGuard then
            eng.NeedGuard = true
        end

        -------- CHOOSE APPROPRIATE BUILD FUNCTION AND SETUP BUILD VARIABLES --------
        local reference = false
        local refName = false
        local buildFunction
        local closeToBuilder
        local relative
        local baseTmplList = {}

        -- if we have nothing to build, disband!
        if not cons.BuildStructures then
            WaitTicks(1)
            self:PlatoonDisband()
            return
        end
        if cons.NearUnitCategory then
            self:SetPrioritizedTargetList('support', {ParseEntityCategory(cons.NearUnitCategory)})
            local unitNearBy = self:FindPrioritizedUnit('support', 'Ally', false, GetPlatoonPosition(self), cons.NearUnitRadius or 50)
            --LOG("ENGINEER BUILD: " .. cons.BuildStructures[1] .." attempt near: ", cons.NearUnitCategory)
            if unitNearBy then
                reference = table.copy(unitNearBy:GetPosition())
                -- get commander home position
                --LOG("ENGINEER BUILD: " .. cons.BuildStructures[1] .." Near unit: ", cons.NearUnitCategory)
                if cons.NearUnitCategory == 'COMMAND' and unitNearBy.CDRHome then
                    reference = unitNearBy.CDRHome
                end
            else
                reference = table.copy(eng:GetPosition())
            end
            relative = false
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
        elseif cons.OrderedTemplate then
            local relativeTo = table.copy(eng:GetPosition())
            --LOG('relativeTo is'..repr(relativeTo))
            relative = true
            local tmpReference = aiBrain:FindPlaceToBuild('T2EnergyProduction', 'uab1201', baseTmplDefault['BaseTemplates'][factionIndex], relative, eng, nil, relativeTo[1], relativeTo[3])
            if tmpReference then
                reference = eng:CalculateWorldPositionFromRelative(tmpReference)
            else
                return
            end
            --LOG('reference is '..repr(reference))
            --LOG('World Pos '..repr(tmpReference))
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrderedRNG
            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            --LOG('baseTmpList is :'..repr(baseTmplList))
        elseif cons.NearPerimeterPoints then
            --LOG('NearPerimeterPoints')
            reference = RUtils.GetBasePerimeterPoints(aiBrain, cons.Location or 'MAIN', cons.Radius or 60, cons.BasePerimeterOrientation or 'FRONT', cons.BasePerimeterSelection or false)
            --LOG('referece is '..repr(reference))
            relative = false
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            for k,v in reference do
                RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, v))
            end
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
        elseif cons.NearBasePatrolPoints then
            relative = false
            reference = AIUtils.GetBasePatrolPoints(aiBrain, cons.Location or 'MAIN', cons.Radius or 100)
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            for k,v in reference do
                RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, v))
            end
            -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
            buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
        elseif cons.FireBase and cons.FireBaseRange then
            --DUNCAN - pulled out and uses alt finder
            reference, refName = AIUtils.AIFindFirebaseLocation(aiBrain, cons.LocationType, cons.FireBaseRange, cons.NearMarkerType,
                                                cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType,
                                                cons.MarkerUnitCount, cons.MarkerUnitCategory, cons.MarkerRadius)
            if not reference or not refName then
                self:PlatoonDisband()
                return
            end

        elseif cons.NearMarkerType and cons.ExpansionBase then
            local pos = aiBrain:PBMGetLocationCoords(cons.LocationType) or cons.Position or GetPlatoonPosition(self)
            local radius = cons.LocationRadius or aiBrain:PBMGetLocationRadius(cons.LocationType) or 100

            if cons.AggressiveExpansion then
                --DUNCAN - pulled out and uses alt finder
                --LOG('Aggressive Expansion Triggered')
                reference, refName = AIUtils.AIFindAggressiveBaseLocationRNG(aiBrain, cons.LocationType, cons.EnemyRange,
                                                    cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                if not reference or not refName then
                    --LOG('No reference or refName from firebaselocaiton finder')
                    self:PlatoonDisband()
                    return
                end
            elseif cons.NearMarkerType == 'Expansion Area' then
                reference, refName = RUtils.AIFindExpansionAreaNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                    return
                end
            elseif cons.NearMarkerType == 'Naval Area' then
                reference, refName = AIUtils.AIFindNavalAreaNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                if not reference or not refName then
                    --LOG('No reference or refname for Naval Area Expansion')
                    self:PlatoonDisband()
                    return
                end
            elseif cons.NearMarkerType == 'Unmarked Expansion' then
                reference, refName = RUtils.AIFindUnmarkedExpansionMarkerNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                --LOG('refName is : '..refName)
                if not reference or not refName then
                    --LOG('Unmarked Expansion Builder reference or refName missing')
                    self:PlatoonDisband()
                    return
                end
            elseif cons.NearMarkerType == 'Large Expansion Area' then
                reference, refName = RUtils.AIFindLargeExpansionMarkerNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                -- didn't find a location to build at
                --LOG('refName is : '..refName)
                if not reference or not refName then
                    --LOG('Large Expansion Builder reference or refName missing')
                    self:PlatoonDisband()
                    return
                end
            else
                --DUNCAN - use my alternative expansion finder on large maps below a certain time
                local mapSizeX, mapSizeZ = GetMapSize()
                if GetGameTimeSeconds() <= 780 and mapSizeX > 512 and mapSizeZ > 512 then
                    reference, refName = AIUtils.AIFindFurthestStartLocationNeedsEngineer(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                    if not reference or not refName then
                        reference, refName = RUtils.AIFindStartLocationNeedsEngineerRNG(aiBrain, cons.LocationType,
                            (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                    end
                else
                    reference, refName = RUtils.AIFindStartLocationNeedsEngineerRNG(aiBrain, cons.LocationType,
                        (cons.LocationRadius or 100), cons.ThreatMin, cons.ThreatMax, cons.ThreatRings, cons.ThreatType)
                end
                -- didn't find a location to build at
                if not reference or not refName then
                    self:PlatoonDisband()
                    return
                end
            end

            -- If moving far from base, tell the assisting platoons to not go with
            if cons.FireBase or cons.ExpansionBase then
                local guards = eng:GetGuards()
                for k,v in guards do
                    if not v.Dead and v.PlatoonHandle then
                        v.PlatoonHandle:PlatoonDisband()
                    end
                end
            end

            if not cons.BaseTemplate and (cons.NearMarkerType == 'Naval Area' or cons.NearMarkerType == 'Defensive Point' or cons.NearMarkerType == 'Expansion Area') then
                baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            end
            if cons.ExpansionBase and refName then
                --LOG('New Expansion Base being created')
                AIBuildStructures.AINewExpansionBase(aiBrain, refName, reference, eng, cons)
            end
            relative = false
            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            -- Must use BuildBaseOrdered to start at the marker; otherwise it builds closest to the eng
            --buildFunction = AIBuildStructures.AIBuildBaseTemplateOrdered
            buildFunction = AIBuildStructures.AIBuildBaseTemplate
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIFindDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.NearMarkerType and cons.NearMarkerType == 'Naval Defensive Point' then
            baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]

            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIFindNavalDefensivePointNeedsStructure(aiBrain, cons.LocationType, (cons.LocationRadius or 100),
                            cons.MarkerUnitCategory, cons.MarkerRadius, cons.MarkerUnitCount, (cons.ThreatMin or 0), (cons.ThreatMax or 1),
                            (cons.ThreatRings or 1), (cons.ThreatType or 'AntiSurface'))

            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))

            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.NearMarkerType and (cons.NearMarkerType == 'Rally Point' or cons.NearMarkerType == 'Protected Experimental Construction') then
            --DUNCAN - add so experimentals build on maps with no markers.
            if not cons.ThreatMin or not cons.ThreatMax or not cons.ThreatRings then
                cons.ThreatMin = -1000000
                cons.ThreatMax = 1000000
                cons.ThreatRings = 0
            end
            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIGetClosestThreatMarkerLoc(aiBrain, cons.NearMarkerType, pos[1], pos[3],
                                                            cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            if not reference then
                reference = pos
            end
            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.NearMarkerType then
            --WARN('*Data weird for builder named - ' .. self.BuilderName)
            if not cons.ThreatMin or not cons.ThreatMax or not cons.ThreatRings then
                cons.ThreatMin = -1000000
                cons.ThreatMax = 1000000
                cons.ThreatRings = 0
            end
            if not cons.BaseTemplate and (cons.NearMarkerType == 'Defensive Point' or cons.NearMarkerType == 'Expansion Area') then
                baseTmpl = baseTmplFile['ExpansionBaseTemplates'][factionIndex]
            end
            relative = false
            local pos = GetPlatoonPosition(self)
            reference, refName = AIUtils.AIGetClosestThreatMarkerLoc(aiBrain, cons.NearMarkerType, pos[1], pos[3],
                                                            cons.ThreatMin, cons.ThreatMax, cons.ThreatRings)
            if cons.ExpansionBase and refName then
                AIBuildStructures.AINewExpansionBase(aiBrain, refName, reference, (cons.ExpansionRadius or 100), cons.ExpansionTypes, nil, cons)
            end
            RNGINSERT(baseTmplList, AIBuildStructures.AIBuildBaseTemplateFromLocation(baseTmpl, reference))
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        elseif cons.AdjacencyPriority then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local cats = {}
            --LOG('setting up adjacencypriority... cats are '..repr(cons.AdjacencyPriority))
            for _,v in cons.AdjacencyPriority do
                RNGINSERT(cats,v)
            end
            reference={}
            if not pos or not pos then
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
            for i,cat in cats do
                -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
                if type(cat) == 'string' then
                    cat = ParseEntityCategory(cat)
                end
                local radius = (cons.AdjacencyDistance or 50)
                local refunits=AIUtils.GetOwnUnitsAroundPoint(aiBrain, cat, pos, radius, cons.ThreatMin,cons.ThreatMax, cons.ThreatRings)
                RNGINSERT(reference,refunits)
                --LOG('cat '..i..' had '..repr(RNGGETN(refunits))..' units')
            end
            buildFunction = AIBuildStructures.AIBuildAdjacencyPriorityRNG
            RNGINSERT(baseTmplList, baseTmpl)
        elseif cons.AvoidCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local cat = cons.AdjacencyCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(cat) == 'string' then
                cat = ParseEntityCategory(cat)
            end
            local avoidCat = cons.AvoidCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(avoidCat) == 'string' then
                avoidCat = ParseEntityCategory(avoidCat)
            end
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.FindUnclutteredArea(aiBrain, cat, pos, radius, cons.maxUnits, cons.maxRadius, avoidCat)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            RNGINSERT(baseTmplList, baseTmpl)
        elseif cons.AdjacencyCategory then
            relative = false
            local pos = aiBrain.BuilderManagers[eng.BuilderManagerData.LocationType].EngineerManager.Location
            local cat = cons.AdjacencyCategory
            -- convert text categories like 'MOBILE AIR' to 'categories.MOBILE * categories.AIR'
            if type(cat) == 'string' then
                cat = ParseEntityCategory(cat)
            end
            local radius = (cons.AdjacencyDistance or 50)
            if not pos or not pos then
                WaitTicks(1)
                self:PlatoonDisband()
                return
            end
            reference  = AIUtils.GetOwnUnitsAroundPoint(aiBrain, cat, pos, radius, cons.ThreatMin,
                                                        cons.ThreatMax, cons.ThreatRings)
            buildFunction = AIBuildStructures.AIBuildAdjacency
            RNGINSERT(baseTmplList, baseTmpl)
        else
            RNGINSERT(baseTmplList, baseTmpl)
            relative = true
            reference = true
            buildFunction = AIBuildStructures.AIExecuteBuildStructureRNG
        end
        if cons.BuildClose then
            closeToBuilder = eng
        end
        if cons.BuildStructures[1] == 'T1Resource' or cons.BuildStructures[1] == 'T2Resource' or cons.BuildStructures[1] == 'T3Resource' then
            relative = true
            closeToBuilder = eng
            local guards = eng:GetGuards()
            for k,v in guards do
                if not v.Dead and v.PlatoonHandle and PlatoonExists(aiBrain, v.PlatoonHandle) then
                    v.PlatoonHandle:PlatoonDisband()
                end
            end
        end

        --LOG("*AI DEBUG: Setting up Callbacks for " .. eng.Sync.id)
        self.SetupEngineerCallbacksRNG(eng)

        -------- BUILD BUILDINGS HERE --------
        for baseNum, baseListData in baseTmplList do
            for k, v in cons.BuildStructures do
                if PlatoonExists(aiBrain, self) then
                    if not eng.Dead then
                        local faction = SUtils.GetEngineerFaction(eng)
                        if aiBrain.CustomUnits[v] and aiBrain.CustomUnits[v][faction] then
                            local replacement = SUtils.GetTemplateReplacement(aiBrain, v, faction, buildingTmpl)
                            if replacement then
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, replacement, baseListData, reference, cons)
                            else
                                buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons)
                            end
                        else
                            buildFunction(aiBrain, eng, v, closeToBuilder, relative, buildingTmpl, baseListData, reference, cons)
                        end
                    else
                        if PlatoonExists(aiBrain, self) then
                            WaitTicks(1)
                            self:PlatoonDisband()
                            return
                        end
                    end
                end
            end
        end

        -- wait in case we're still on a base
        if not eng.Dead then
            local count = 0
            while eng:IsUnitState('Attached') and count < 2 do
                WaitTicks(60)
                count = count + 1
            end
        end

        if not eng:IsUnitState('Building') then
            return self.ProcessBuildCommandRNG(eng, false)
        end
    end,

    SetupEngineerCallbacksRNG = function(eng)
        if eng and not eng.Dead and not eng.BuildDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitBuiltTrigger(eng.PlatoonHandle.EngineerBuildDoneRNG, eng, categories.ALLUNITS)
            eng.BuildDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.CaptureDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopCaptureTrigger(eng.PlatoonHandle.EngineerCaptureDoneRNG, eng)
            eng.CaptureDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.ReclaimDoneCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateUnitStopReclaimTrigger(eng.PlatoonHandle.EngineerReclaimDoneRNG, eng)
            eng.ReclaimDoneCallbackSet = true
        end
        if eng and not eng.Dead and not eng.FailedToBuildCallbackSet and eng.PlatoonHandle and PlatoonExists(eng:GetAIBrain(), eng.PlatoonHandle) then
            import('/lua/ScenarioTriggers.lua').CreateOnFailedToBuildTrigger(eng.PlatoonHandle.EngineerFailedToBuildRNG, eng)
            eng.FailedToBuildCallbackSet = true
        end
    end,

    EngineerBuildDoneRNG = function(unit, params)
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --LOG("*AI DEBUG: Build done " .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, true)
            unit.ProcessBuildDone = true
        end
    end,
    EngineerCaptureDoneRNG = function(unit, params)
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --LOG("*AI DEBUG: Capture done" .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
        end
    end,
    EngineerReclaimDoneRNG = function(unit, params)
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        --LOG("*AI DEBUG: Reclaim done" .. unit.Sync.id)
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, false)
        end
    end,
    EngineerFailedToBuildRNG = function(unit, params)
        if not unit.PlatoonHandle then return end
        if not unit.PlatoonHandle.PlanName == 'EngineerBuildAIRNG' then return end
        if unit.ProcessBuildDone and unit.ProcessBuild then
            KillThread(unit.ProcessBuild)
            unit.ProcessBuild = nil
        end
        if not unit.ProcessBuild then
            unit.ProcessBuild = unit:ForkThread(unit.PlatoonHandle.ProcessBuildCommandRNG, true)  --DUNCAN - changed to true
        end
    end,



    -------------------------------------------------------
    --   Function: ProcessBuildCommand
    --   Args:
    --       eng - the engineer that's gone through EngineerBuildAIRNG
    --   Description:
    --       Run after every build order is complete/fails.  Sets up the next
    --       build order in queue, and if the engineer has nothing left to do
    --       will return the engineer back to the army pool by disbanding the
    --       the platoon.  Support function for EngineerBuildAIRNG
    --   Returns:
    --       nil (tail calls into a behavior function)
    -------------------------------------------------------
    ProcessBuildCommandRNG = function(eng, removeLastBuild)
        --DUNCAN - Trying to stop commander leaving projects
        if (not eng) or eng.Dead or (not eng.PlatoonHandle) or eng.Combat or eng.Upgrading or eng.GoingHome then
            return
        end

        local aiBrain = eng.PlatoonHandle:GetBrain()
        if not aiBrain or eng.Dead or not eng.EngineerBuildQueue or RNGGETN(eng.EngineerBuildQueue) == 0 then
            if PlatoonExists(aiBrain, eng.PlatoonHandle) then
                --LOG("*AI DEBUG: Disbanding Engineer Platoon in ProcessBuildCommand top " .. eng.Sync.id)
                --if eng.CDRHome then --LOG('*AI DEBUG: Commander process build platoon disband...') end
                if not eng.AssistSet and not eng.AssistPlatoon and not eng.UnitBeingAssist then
                    --LOG('Disband engineer platoon start of process')
                    eng.PlatoonHandle:PlatoonDisband()
                end
            end
            if eng then eng.ProcessBuild = nil end
            return
        end

        -- it wasn't a failed build, so we just finished something
        if removeLastBuild then
            table.remove(eng.EngineerBuildQueue, 1)
        end

        eng.ProcessBuildDone = false
        IssueClearCommands({eng})
        local commandDone = false
        local PlatoonPos
        while not eng.Dead and not commandDone and RNGGETN(eng.EngineerBuildQueue) > 0  do
            local whatToBuild = eng.EngineerBuildQueue[1][1]
            local buildLocation = {eng.EngineerBuildQueue[1][2][1], 0, eng.EngineerBuildQueue[1][2][2]}
            if GetTerrainHeight(buildLocation[1], buildLocation[3]) > GetSurfaceHeight(buildLocation[1], buildLocation[3]) then
                --land
                buildLocation[2] = GetTerrainHeight(buildLocation[1], buildLocation[3])
            else
                --water
                buildLocation[2] = GetSurfaceHeight(buildLocation[1], buildLocation[3])
            end
            local buildRelative = eng.EngineerBuildQueue[1][3]
            if not eng.NotBuildingThread then
                eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
            end
            -- see if we can move there first
            --LOG('Check if we can move to location')
            --LOG('Unit is '..eng.UnitId)

            if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, buildLocation) then
                if not eng or eng.Dead or not eng.PlatoonHandle or not PlatoonExists(aiBrain, eng.PlatoonHandle) then
                    if eng then eng.ProcessBuild = nil end
                    return
                end
                --[[if AIUtils.IsMex(whatToBuild) and (not aiBrain:CanBuildStructureAt(whatToBuild, buildLocation)) then
                    LOG('Cant build at mass location')
                    LOG('*AI DEBUG: EngineerBuild AI ' ..eng.Sync.id)
                    LOG('Build location is '..repr(buildLocation))
                    return
                end]]
                aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                local engStuckCount = 0
                local Lastdist
                local dist
                while not eng.Dead do
                    PlatoonPos = eng:GetPosition()
                    dist = VDist2(PlatoonPos[1] or 0, PlatoonPos[3] or 0, buildLocation[1] or 0, buildLocation[3] or 0)
                    if dist < 12 then
                        break
                    end
                    if Lastdist ~= dist then
                        engStuckCount = 0
                        Lastdist = dist
                    else
                        engStuckCount = engStuckCount + 1
                        --LOG('* AI-RNG: * EngineerBuildAI: has no moved during move to build position look, adding one, current is '..engStuckCount)
                        if engStuckCount > 40 and not eng:IsUnitState('Building') then
                            --LOG('* AI-RNG: * EngineerBuildAI: Stuck while moving to build position. Stuck='..engStuckCount)
                            break
                        end
                    end
                    if (whatToBuild == 'ueb1103' or whatToBuild == 'uab1103' or whatToBuild == 'urb1103' or whatToBuild == 'xsb1103') then
                        if aiBrain:GetNumUnitsAroundPoint(categories.STRUCTURE * categories.MASSEXTRACTION, buildLocation, 1, 'Ally') > 0 then
                            --LOG('Extractor already present with 1 radius, return')
                            eng.PlatoonHandle:Stop()
                            return
                        end
                    end
                    if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                        if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), PlatoonPos, 10, 'Enemy') > 0 then
                            local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), PlatoonPos, 10, 'Enemy')
                            if enemyEngineer then
                                local enemyEngPos
                                for _, unit in enemyEngineer do
                                    if unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                                        enemyEngPos = unit:GetPosition()
                                        if VDist2Sq(PlatoonPos[1], PlatoonPos[3], enemyEngPos[1], enemyEngPos[3]) < 100 then
                                            IssueStop({eng})
                                            IssueClearCommands({eng})
                                            IssueReclaim({eng}, enemyEngineer[1])
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if eng.Upgrading or eng.Combat then
                        return
                    end
                    WaitTicks(7)
                end
                if not eng or eng.Dead or not eng.PlatoonHandle or not PlatoonExists(aiBrain, eng.PlatoonHandle) then
                    if eng then eng.ProcessBuild = nil end
                    return
                end
                -- cancel all commands, also the buildcommand for blocking mex to check for reclaim or capture
                eng.PlatoonHandle:Stop()
                -- check to see if we need to reclaim or capture...
                RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, buildLocation, 10)
                    -- check to see if we can repair
                AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, buildLocation)
                        -- otherwise, go ahead and build the next structure there
                --LOG('First marker location '..buildLocation[1]..':'..buildLocation[3])
                --aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                aiBrain:BuildStructure(eng, whatToBuild, {buildLocation[1], buildLocation[3], 0}, buildRelative)
                if (whatToBuild == 'ueb1103' or whatToBuild == 'uab1103' or whatToBuild == 'urb1103' or whatToBuild == 'xsb1103') and eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild then
                    --LOG('What to build was a mass extractor')
                    if EntityCategoryContains(categories.ENGINEER - categories.COMMAND, eng) then
                        local MexQueueBuild, MassMarkerTable = MABC.CanBuildOnMassEng2(aiBrain, buildLocation, 30)
                        if MexQueueBuild then
                            --LOG('We can build on a mass marker within 30')
                            --LOG(repr(MassMarkerTable))
                            for _, v in MassMarkerTable do
                                RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, v.MassSpot.position, 5)
                                AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, v.MassSpot.position)
                                aiBrain:BuildStructure(eng, whatToBuild, {v.MassSpot.position[1], v.MassSpot.position[3], 0}, buildRelative)
                                local newEntry = {whatToBuild, {v.MassSpot.position[1], v.MassSpot.position[3], 0}, buildRelative}
                                RNGINSERT(eng.EngineerBuildQueue, newEntry)
                            end
                        else
                            --LOG('Cant find mass within distance')
                        end
                    end
                end
                if not eng.NotBuildingThread then
                    eng.NotBuildingThread = eng:ForkThread(eng.PlatoonHandle.WatchForNotBuildingRNG)
                end
                --LOG('Build commandDone set true')
                commandDone = true
            else
                -- we can't move there, so remove it from our build queue
                table.remove(eng.EngineerBuildQueue, 1)
            end
            WaitTicks(2)
        end
        --LOG('EnginerBuildQueue : '..RNGGETN(eng.EngineerBuildQueue)..' Contents '..repr(eng.EngineerBuildQueue))
        if not eng.Dead and RNGGETN(eng.EngineerBuildQueue) <= 0 and eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild then
            --LOG('Starting RepeatBuild')
            local engpos = eng:GetPosition()
            if eng.PlatoonHandle.PlatoonData.Construction.RepeatBuild and eng.PlatoonHandle.PlanName then
                --LOG('Repeat Build is set for :'..eng.Sync.id)
                if eng.PlatoonHandle.PlatoonData.Construction.Type == 'Mass' then
                    eng.PlatoonHandle:EngineerBuildAIRNG()
                else
                    WARN('Invalid Construction Type or Distance, Expected : Mass, number')
                end
            end
        end
        -- final check for if we should disband
        if not eng or eng.Dead or RNGGETN(eng.EngineerBuildQueue) <= 0 then
            if eng.PlatoonHandle and PlatoonExists(aiBrain, eng.PlatoonHandle) then
                --LOG('buildqueue 0 disband for'..eng.UnitId)
                eng.PlatoonHandle:PlatoonDisband()
            end
            if eng then eng.ProcessBuild = nil end
            return
        end
        if eng then eng.ProcessBuild = nil end
    end,

    WatchForNotBuildingRNG = function(eng)
        WaitTicks(10)
        local aiBrain = eng:GetAIBrain()
        local engPos = eng:GetPosition()

        --DUNCAN - Trying to stop commander leaving projects, also added moving as well.
        while not eng.Dead and not eng.PlatoonHandle.UsingTransport and (eng.GoingHome or eng.ProcessBuild != nil
                  or eng.UnitBeingBuiltBehavior or not eng:IsIdleState()
                 ) do
            WaitTicks(30)

            if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy') > 0 then
                    local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy')
                    local enemyEngPos = enemyEngineer[1]:GetPosition()
                    if VDist2Sq(engPos[1], engPos[3], enemyEngPos[1], enemyEngPos[3]) < 100 then
                        IssueStop({eng})
                        IssueClearCommands({eng})
                        IssueReclaim({eng}, enemyEngineer[1])
                    end
                end
            end
        end

        eng.NotBuildingThread = nil
        if not eng.Dead and eng:IsIdleState() and RNGGETN(eng.EngineerBuildQueue) != 0 and eng.PlatoonHandle and not eng.WaitingForTransport then
            eng.PlatoonHandle.SetupEngineerCallbacksRNG(eng)
            if not eng.ProcessBuild then
                --LOG('Forking Process Build Command with table remove')
                eng.ProcessBuild = eng:ForkThread(eng.PlatoonHandle.ProcessBuildCommandRNG, true)
            end
        end
    end,

    MassRaidRNG = function(self)
        local aiBrain = self:GetBrain()
        --LOG('Platoon ID is : '..self:GetPlatoonUniqueName())
        local platLoc = GetPlatoonPosition(self)
        if not PlatoonExists(aiBrain, self) or not platLoc then
            return
        end

        -----------------------------------------------------------------------
        -- Platoon Data
        -----------------------------------------------------------------------
        -- Include mass markers that are under water
        local includeWater = self.PlatoonData.IncludeWater or false

        local waterOnly = self.PlatoonData.WaterOnly or false

        -- Minimum distance when looking for closest
        local avoidClosestRadius = self.PlatoonData.AvoidClosestRadius or 0

        -- if true, look to guard highest threat, otherwise,
        -- guard the lowest threat specified
        local bFindHighestThreat = self.PlatoonData.FindHighestThreat or false

        -- minimum threat to look for
        local minThreatThreshold = self.PlatoonData.MinThreatThreshold or -1
        -- maximum threat to look for
        local maxThreatThreshold = self.PlatoonData.MaxThreatThreshold  or 99999999

        -- Avoid bases (true or false)
        local bAvoidBases = self.PlatoonData.AvoidBases or false

        -- Radius around which to avoid the main base
        local avoidBasesRadius = self.PlatoonData.AvoidBasesRadius or 0

        -- Use Aggresive Moves Only
        local bAggroMove = self.PlatoonData.AggressiveMove or false

        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'

        local maxPathDistance = self.PlatoonData.MaxPathDistance or 200

        self.MassMarkerTable = self.planData.MassMarkerTable or false
        self.LoopCount = self.planData.LoopCount or 0

        -----------------------------------------------------------------------
        local markerLocations
        self.enemyRadius = 40
        local MaxPlatoonWeaponRange
        local scoutUnit = false
        local atkPri = {}
        local categoryList = {}
        local platoonThreat 
        local VDist2Sq = VDist2Sq
        local function VariableKite(platoon,unit,target)
            local function KiteDist(pos1,pos2,distance)
                local vec={}
                local dist=VDist3(pos1,pos2)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel = {}
                vel[1], vel[2], vel[3]=target:GetVelocity()
                --LOG('vel is '..repr(vel))
                --LOG(repr(pos1))
                --LOG(repr(pos2))
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            if target.Dead then return end
            if unit.Dead then return end
                
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=3
            if CheckRetreat(pos,tpos,target) then
                mod=8
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod)
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod)
            end
            if VDist3Sq(pos,dest)>6 then
                IssueMove({unit},dest)
                WaitTicks(20)
                return
            else
                WaitTicks(20)
                return
            end
        end

        AIAttackUtils.GetMostRestrictiveLayer(self)
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local stageExpansion = false
        local platoonUnits = GetPlatoonUnits(self)
        if platoonUnits > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if EntityCategoryContains(categories.SCOUT, v) then
                        self.ScoutPresent = true
                        self.scoutUnit = v
                    end
                    for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                        -- unit can have MaxWeaponRange entry from the last platoon
                        if not v.MaxWeaponRange or weapon.MaxRadius > v.MaxWeaponRange then
                            -- save the weaponrange 
                            v.MaxWeaponRange = weapon.MaxRadius * 0.9 -- maxrange minus 10%
                            -- save the weapon balistic arc, we need this later to check if terrain is blocking the weapon line of sight
                            if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                v.WeaponArc = 'low'
                            elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                v.WeaponArc = 'high'
                            else
                                v.WeaponArc = 'none'
                            end
                        end
                        if not MaxPlatoonWeaponRange or MaxPlatoonWeaponRange < v.MaxWeaponRange then
                            MaxPlatoonWeaponRange = v.MaxWeaponRange
                        end
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                    v.smartPos = {0,0,0}
                    if not v.MaxWeaponRange then
                        --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                    end
                end
            end
        end

        if self.PlatoonData.TargetSearchPriorities then
            --LOG('TargetSearch present for '..self.BuilderName)
            for k,v in self.PlatoonData.TargetSearchPriorities do
                RNGINSERT(atkPri, v)
            end
        else
            if self.PlatoonData.PrioritizedCategories then
                for k,v in self.PlatoonData.PrioritizedCategories do
                    RNGINSERT(atkPri, v)
                end
            end
        end
        if self.PlatoonData.PrioritizedCategories then
            for k,v in self.PlatoonData.PrioritizedCategories do
                RNGINSERT(categoryList, v)
            end
        end
        self:SetPrioritizedTargetList('Attack', categoryList)
        self.atkPri = atkPri

        if self.MovementLayer == 'Land' and not self.PlatoonData.EarlyRaid then
            local stageExpansion = RUtils.QueryExpansionTable(aiBrain, platLoc, math.min(BaseMilitaryArea, 250), self.MovementLayer, 10)
            if stageExpansion then
                --LOG('Stage Position key returned for '..stageExpansion.Key..' Name is '..stageExpansion.Expansion.Name)
                platLoc = GetPlatoonPosition(self) or nil
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platLoc, stageExpansion.Expansion.Position, 10 , maxPathDistance)
                if path then
                    --LOG('Found path to expansion, moving to position')
                    self:PlatoonMoveWithMicro(aiBrain, path, false)
                    aiBrain.BrainIntel.ExpansionWatchTable[stageExpansion.Key].TimeStamp = GetGameTimeSeconds()
                    --LOG('Arrived at expansion, set timestamp to '..aiBrain.BrainIntel.ExpansionWatchTable[stageExpansion.Key].TimeStamp)
                end
                platLoc = GetPlatoonPosition(self)
            end
        end

        if self.PlatoonData.FrigateRaid and aiBrain.EnemyIntel.FrigateRaid then
            markerLocations = aiBrain.EnemyIntel.FrigateRaidMarkers
        else
            markerLocations = RUtils.AIGetMassMarkerLocations(aiBrain, includeWater, waterOnly)
        end
        local bestMarker = false

        if not self.LastMarker then
            self.LastMarker = {nil,nil}
        end

        -- look for a random marker
        --[[Marker table examples for better understanding what is happening below 
        info: Marker Current{ Name="Mass7", Position={ 189.5, 24.240200042725, 319.5, type="VECTOR3" } }
        info: Marker Last{ { 374.5, 20.650400161743, 154.5, type="VECTOR3" } }
        ]] 

        local bestMarkerThreat = 0
        if not bFindHighestThreat then
            bestMarkerThreat = 99999999
        end

        local bestDistSq = 99999999
        -- find best threat at the closest distance
        for _,marker in markerLocations do
            local markerThreat
            local enemyThreat
            markerThreat = GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Economy')
            if self.MovementLayer == 'Water' then
                enemyThreat = GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings + 1, true, 'AntiSub')
            else
                enemyThreat = GetThreatAtPosition(aiBrain, marker.Position, aiBrain.BrainIntel.IMAPConfig.Rings + 1, true, 'AntiSurface')
            end
            --LOG('Best pre calculation marker threat is '..markerThreat..' at position'..repr(marker.Position))
            --LOG('Surface Threat at marker is '..enemyThreat..' at position'..repr(marker.Position))
            if enemyThreat > 0 and markerThreat then
                markerThreat = markerThreat / enemyThreat
            end
            local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])

            if markerThreat >= minThreatThreshold and markerThreat <= maxThreatThreshold then
                if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
                    if self.IsBetterThreat(bFindHighestThreat, markerThreat, bestMarkerThreat) then
                        bestDistSq = distSq
                        bestMarker = marker
                        bestMarkerThreat = markerThreat
                    elseif markerThreat == bestMarkerThreat then
                        if distSq < bestDistSq then
                            bestDistSq = distSq
                            bestMarker = marker
                            bestMarkerThreat = markerThreat
                        end
                    end
                end
            end
        end
        --[[
        if waterOnly then
            if bestMarker then
                LOG('Water based best marker is  '..repr(bestMarker))
                LOG('Best marker threat is '..bestMarkerThreat)
            else
                LOG('Water based no best marker')
            end
        end]]

        --LOG('* AI-RNG: Best Marker Selected is at position'..repr(bestMarker.Position))
        
        if bestMarker.Position == nil and GetGameTimeSeconds() > 600 and self.MovementLayer ~= 'Water' then
            --LOG('Best Marker position was nil and game time greater than 15 mins, switch to hunt ai')
            return self:SetAIPlanRNG('HuntAIPATHRNG')
        elseif bestMarker.Position == nil then
            
            
            if RNGGETN(aiBrain.BrainIntel.ExpansionWatchTable) > 0  and (not self.EarlyRaidSet) then
                for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
                    local distSq = VDist2Sq(v.Position[1], v.Position[3], platLoc[1], platLoc[3])
                    if distSq > (avoidClosestRadius * avoidClosestRadius) and AIAttackUtils.CanGraphToRNG(platLoc, v.Position, self.MovementLayer) then
                        if not v.PlatoonAssigned then
                            bestMarker = v
                            aiBrain.BrainIntel.ExpansionWatchTable[k].PlatoonAssigned = self
                            --LOG('Expansion Best marker selected is index '..k..' at '..repr(bestMarker.Position))
                            break
                        end
                    else
                        --LOG('Cant Graph to expansion marker location')
                    end
                    --LOG('Distance to marker '..k..' is '..VDist2(v.Position[1],v.Position[3],platLoc[1], platLoc[3]))
                end
            end
            if self.PlatoonData.EarlyRaid then
                self.EarlyRaidSet = true
            end
            if not bestMarker then
                --LOG('Best Marker position was nil, select random')
                if not self.MassMarkerTable then
                    self.MassMarkerTable = markerLocations
                else
                    --LOG('Found old marker table, using that')
                end
                if RNGGETN(self.MassMarkerTable) <= 2 then
                    self.LastMarker[1] = nil
                    self.LastMarker[2] = nil
                end
                local startX, startZ = aiBrain:GetArmyStartPos()

                table.sort(self.MassMarkerTable,function(a,b) return VDist2Sq(a.Position[1], a.Position[3],startX, startZ) / (VDist2Sq(a.Position[1], a.Position[3], platLoc[1], platLoc[3]) + RUtils.EdgeDistance(a.Position[1],a.Position[3],ScenarioInfo.size[1])) > VDist2Sq(b.Position[1], b.Position[3], startX, startZ) / (VDist2Sq(b.Position[1], b.Position[3], platLoc[1], platLoc[3]) + RUtils.EdgeDistance(b.Position[1],b.Position[3],ScenarioInfo.size[1])) end)
                --LOG('Sorted table '..repr(markerLocations))
                --LOG('Marker table is before loop is '..RNGGETN(self.MassMarkerTable))

                for k,marker in self.MassMarkerTable do
                    if RNGGETN(self.MassMarkerTable) <= 2 then
                        self.LastMarker[1] = nil
                        self.LastMarker[2] = nil
                        self.MassMarkerTable = false
                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                    end
                    local distSq = VDist2Sq(marker.Position[1], marker.Position[3], platLoc[1], platLoc[3])
                    if self:AvoidsBases(marker.Position, bAvoidBases, avoidBasesRadius) and distSq > (avoidClosestRadius * avoidClosestRadius) then
                        if self.LastMarker[1] and marker.Position[1] == self.LastMarker[1][1] and marker.Position[3] == self.LastMarker[1][3] then
                            continue
                        end
                        if self.LastMarker[2] and marker.Position[1] == self.LastMarker[2][1] and marker.Position[3] == self.LastMarker[2][3] then
                            continue
                        end

                        bestMarker = marker
                        --LOG('Delete Marker '..repr(marker))
                        self.MassMarkerTable[k] = nil
                        break
                    end
                end
                self.MassMarkerTable = aiBrain:RebuildTable(self.MassMarkerTable)
                --LOG('Marker table is after loop is '..RNGGETN(self.MassMarkerTable))
                --LOG('bestMarker is '..repr(bestMarker))
            end
        end

        local usedTransports = false

        if bestMarker then
            self.LastMarker[2] = self.LastMarker[1]
            self.LastMarker[1] = bestMarker.Position
            --LOG("MassRaid: Attacking " .. bestMarker.Name)
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestMarker.Position, 10 , maxPathDistance)
            local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, bestMarker.Position)
            IssueClearCommands(GetPlatoonUnits(self))
            if path then
                
                local position = GetPlatoonPosition(self)
                if not success or VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 512 then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true)
                elseif VDist2(position[1], position[3], bestMarker.Position[1], bestMarker.Position[3]) > 256 and (not self.PlatoonData.EarlyRaid) then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, false)
                end
                if not usedTransports then
                    self:PlatoonMoveWithMicro(aiBrain, path, self.PlatoonData.Avoid)
                end
            elseif (not path and reason == 'NoPath') then
                --LOG('MassRaid requesting transports')
                if not self.PlatoonData.EarlyRaid then
                    usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, bestMarker.Position, true)
                end
                --DUNCAN - if we need a transport and we cant get one the disband
                if not usedTransports then
                    --LOG('MASSRAID no transports')
                    if self.MassMarkerTable then
                        if self.LoopCount > 15 then
                            --LOG('Loop count greater than 15, return to base')
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        end
                        local data = {}
                        data.MassMarkerTable = self.MassMarkerTable
                        self.LoopCount = self.LoopCount + 1
                        data.LoopCount = self.LoopCount
                        --LOG('No path and no transports to location, setting table data and restarting')
                        return self:SetAIPlanRNG('MassRaidRNG', nil, data)
                    end
                    --LOG('No path and no transports to location, return to base')
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
                --LOG('Guardmarker found transports')
            else
                --LOG('Path error in MASSRAID')
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end

            if (not path or not success) and not usedTransports then
                --LOG('not path or not success or not usedTransports MASSRAID')
                return self:SetAIPlanRNG('ReturnToBaseAIRNG')
            end
            
            if aiBrain:CheckBlockingTerrain(GetPlatoonPosition(self), bestMarker.Position, 'none') then
                self:MoveToLocation(bestMarker.Position, false)
            else
                self:AggressiveMoveToLocation(bestMarker.Position)
            end

            -- wait till we get there
            local oldPlatPos = GetPlatoonPosition(self)
            local StuckCount = 0
            repeat
                WaitTicks(50)
                platLoc = GetPlatoonPosition(self)
                if VDist3(oldPlatPos, platLoc) < 1 then
                    StuckCount = StuckCount + 1
                else
                    StuckCount = 0
                end
                if StuckCount > 5 then
                    --LOG('MassRaidAI stuck count over 5, restarting')
                    return self:SetAIPlanRNG('MassRaidRNG')
                end
                oldPlatPos = platLoc
            until VDist2Sq(platLoc[1], platLoc[3], bestMarker.Position[1], bestMarker.Position[3]) < 64 or not PlatoonExists(aiBrain, self)

            -- we're there... wait here until we're done
            local numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            while numGround > 0 and PlatoonExists(aiBrain, self) do
                local target, acuInRange = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, GetPlatoonPosition(self), 'Attack', 20, (categories.LAND + categories.NAVAL + categories.STRUCTURE), self.atkPri, false)
                local attackSquad = self:GetSquadUnits('Attack')
                IssueClearCommands(attackSquad)
                while PlatoonExists(aiBrain, self) do
                    if target and not target.Dead then
                        local targetPosition = target:GetPosition()
                        local microCap = 50
                        for _, unit in attackSquad do
                            microCap = microCap - 1
                            if microCap <= 0 then break end
                            if unit.Dead then continue end
                            if not unit.MaxWeaponRange then
                                continue
                            end
                            IssueClearCommands({unit})
                            VariableKite(self,unit,target)
                        end
                    else
                        break
                    end
                WaitTicks(10)
                end
                WaitTicks(Random(40,80))
                --LOG('Still enemy stuff around marker position')
                numGround = GetNumUnitsAroundPoint(aiBrain, (categories.LAND + categories.NAVAL + categories.STRUCTURE), bestMarker.Position, 15, 'Enemy')
            end

            if not PlatoonExists(aiBrain, self) then
                return
            end
            --LOG('MassRaidAI restarting')
            self:Stop()
            self:MergeWithNearbyPlatoonsRNG('MassRaidRNG', 80, 25)
            self:SetPlatoonFormationOverride('NoFormation')
            return self:SetAIPlanRNG('MassRaidRNG')
        else
            -- no marker found, disband!
            --LOG('no marker found, disband MASSRAID')
            self:SetPlatoonFormationOverride('NoFormation')
            return self:SetAIPlanRNG('TruePlatoonRNG')
        end
    end,

    AttackForceAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()

        -- get units together
        if not self:GatherUnits() then
            return
        end

        -- Setup the formation based on platoon functionality

        local enemy = aiBrain:GetCurrentEnemy()

        local platoonUnits = GetPlatoonUnits(self)
        local numberOfUnitsInPlatoon = RNGGETN(platoonUnits)
        local oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon
        local stuckCount = 0

        self.PlatoonAttackForce = true
        -- formations have penalty for taking time to form up... not worth it here
        -- maybe worth it if we micro
        --self:SetPlatoonFormationOverride('GrowthFormation')
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)

        while PlatoonExists(aiBrain, self) do
            local pos = GetPlatoonPosition(self) -- update positions; prev position done at end of loop so not done first time

            -- if we can't get a position, then we must be dead
            if not pos then
                break
            end


            -- if we're using a transport, wait for a while
            if self.UsingTransport then
                WaitTicks(100)
                continue
            end

            -- pick out the enemy
            if aiBrain:GetCurrentEnemy() and aiBrain:GetCurrentEnemy().Result == "defeat" then
                aiBrain:PickEnemyLogicRNG()
            end

            -- merge with nearby platoons
            self:Stop()
            self:MergeWithNearbyPlatoonsRNG('AttackForceAIRNG', 20, 25)

            -- rebuild formation
            platoonUnits = GetPlatoonUnits(self)
            numberOfUnitsInPlatoon = RNGGETN(platoonUnits)
            -- if we have a different number of units in our platoon, regather
            if (oldNumberOfUnitsInPlatoon != numberOfUnitsInPlatoon) then
                self:StopAttack()
                self:SetPlatoonFormationOverride(PlatoonFormation)
            end
            oldNumberOfUnitsInPlatoon = numberOfUnitsInPlatoon

            -- deal with lost-puppy transports
            local strayTransports = {}
            for k,v in platoonUnits do
                if EntityCategoryContains(categories.TRANSPORTATION, v) then
                    RNGINSERT(strayTransports, v)
                end
            end
            if RNGGETN(strayTransports) > 0 then
                local dropPoint = pos
                dropPoint[1] = dropPoint[1] + Random(-3, 3)
                dropPoint[3] = dropPoint[3] + Random(-3, 3)
                IssueTransportUnload(strayTransports, dropPoint)
                WaitTicks(100)
                local strayTransports = {}
                for k,v in platoonUnits do
                    local parent = v:GetParent()
                    if parent and EntityCategoryContains(categories.TRANSPORTATION, parent) then
                        RNGINSERT(strayTransports, parent)
                        break
                    end
                end
                if RNGGETN(strayTransports) > 0 then
                    local MAIN = aiBrain.BuilderManagers.MAIN
                    if MAIN then
                        dropPoint = MAIN.Position
                        IssueTransportUnload(strayTransports, dropPoint)
                        WaitTicks(300)
                    end
                end
                self.UsingTransport = false
                AIUtils.ReturnTransportsToPool(strayTransports, true)
                platoonUnits = GetPlatoonUnits(self)
            end


            --Disband platoon if it's all air units, so they can be picked up by another platoon
            local mySurfaceThreat = AIAttackUtils.GetSurfaceThreatOfUnits(self)
            if mySurfaceThreat == 0 and AIAttackUtils.GetAirThreatOfUnits(self) > 0 then
                --LOG('* AI-RNG: AttackForceAIRNG surface threat low or air units present. Disbanding')
                self:PlatoonDisband()
                return
            end

            local cmdQ = {}
            -- fill cmdQ with current command queue for each unit
            for k,v in platoonUnits do
                if not v.Dead then
                    local unitCmdQ = v:GetCommandQueue()
                    for cmdIdx,cmdVal in unitCmdQ do
                        RNGINSERT(cmdQ, cmdVal)
                        break
                    end
                end
            end

            -- if we're on our final push through to the destination, and we find a unit close to our destination
            local closestTarget = self:FindClosestUnit('attack', 'enemy', true, categories.ALLUNITS)
            local nearDest = false
            local oldPathSize = RNGGETN(self.LastAttackDestination)
            if self.LastAttackDestination then
                nearDest = oldPathSize == 0 or VDist3(self.LastAttackDestination[oldPathSize], pos) < 20
            end

            -- if we're near our destination and we have a unit closeby to kill, kill it
            if RNGGETN(cmdQ) <= 1 and closestTarget and VDist3(closestTarget:GetPosition(), pos) < 20 and nearDest then
                self:StopAttack()
                if PlatoonFormation != 'No Formation' then
                    IssueFormAttack(platoonUnits, closestTarget, PlatoonFormation, 0)
                else
                    IssueAttack(platoonUnits, closestTarget)
                end
                cmdQ = {1}
            -- if we have nothing to do, try finding something to do
            elseif RNGGETN(cmdQ) == 0 then
                self:StopAttack()
                --LOG('* AI-RNG: AttackForceAIRNG Platoon Squad Attack Vector starting from main function')
                cmdQ = AIAttackUtils.AIPlatoonSquadAttackVectorRNG(aiBrain, self)
                stuckCount = 0
            -- if we've been stuck and unable to reach next marker? Ignore nearby stuff and pick another target
            elseif self.LastPosition and VDist2Sq(self.LastPosition[1], self.LastPosition[3], pos[1], pos[3]) < (self.PlatoonData.StuckDistance or 16) then
                stuckCount = stuckCount + 1
                --LOG('* AI-RNG: AttackForceAIRNG stuck count incremented, current is '..stuckCount)
                if stuckCount >= 3 then
                    self:StopAttack()
                    cmdQ = AIAttackUtils.AIPlatoonSquadAttackVectorRNG(aiBrain, self)
                    stuckCount = 0
                end
            else
                stuckCount = 0
            end

            self.LastPosition = pos

            if RNGGETN(cmdQ) == 0 then
                -- if we have a low threat value, then go and defend an engineer or a base
                if mySurfaceThreat < 4
                    and mySurfaceThreat > 0
                    and not self.PlatoonData.NeverGuard
                    and not (self.PlatoonData.NeverGuardEngineers and self.PlatoonData.NeverGuardBases)
                then
                    --LOG('* AI-RNG: AttackForceAIRNG has returned guard engineer')
                    return self:GuardEngineer(self.AttackForceAIRNG)
                end

                -- we have nothing to do, so find the nearest base and disband
                if not self.PlatoonData.NeverMerge then
                    --LOG('* AI-RNG: AttackForceAIRNG thinks it has nothing to do, return to base')
                    return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                end
                WaitTicks(50)
            else
                -- wait a little longer if we're stuck so that we have a better chance to move
                WaitSeconds(Random(5,11) + 2 * stuckCount)
            end
            WaitTicks(1)
        end
    end,

    PlatoonMoveWithMicro = function(self, aiBrain, path, avoid)
        -- I've tried to split out the platoon movement function as its getting too messy and hard to maintain

        local function VariableKite(platoon,unit,target)
            local function KiteDist(pos1,pos2,distance)
                local vec={}
                local dist=VDist3(pos1,pos2)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel = {}
                vel[1], vel[2], vel[3]=target:GetVelocity()
                --LOG('vel is '..repr(vel))
                --LOG(repr(pos1))
                --LOG(repr(pos2))
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            if target.Dead then return end
            if unit.Dead then return end
                
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=3
            if CheckRetreat(pos,tpos,target) then
                mod=8
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod)
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod)
            end
            if VDist3Sq(pos,dest)>6 then
                IssueMove({unit},dest)
                WaitTicks(20)
                return
            else
                WaitTicks(20)
                return
            end
        end

        local pathLength = RNGGETN(path)
        for i=1, pathLength - 1 do
            --LOG('* AI-RNG: * MassRaidRNG: moving to destination. i: '..i..' coords '..repr(path[i]))
            local platoonThreat = self:CalculatePlatoonThreat('AntiSurface', categories.ALLUNITS)
            if self.PlatoonData.AggressiveMove then
                self:AggressiveMoveToLocation(path[i])
            else
                self:MoveToLocation(path[i], false)
            end
            --[[if self.MovementLayer == 'Land' and (aiBrain.BrainIntel.SelfThreat.LandNow + aiBrain.BrainIntel.SelfThreat.AllyLandThreat) < aiBrain.EnemyIntel.EnemyThreatCurrent.Land then
                if platoonThreat < GetThreatAtPosition(aiBrain, GetPlatoonPosition(self), aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') then
                    --LOG('Threat too high, switching to trueplatoon')
                    return self:SetAIPlanRNG('TruePlatoonRNG')
                end
            end]]
            --LOG('* AI-RNG: * MassRaidRNG: moving to Waypoint')
            local PlatoonPosition
            local Lastdist
            local dist
            local Stuck = 0
            while PlatoonExists(aiBrain, self) do
                PlatoonPosition = GetPlatoonPosition(self) or nil
                if not PlatoonPosition then break end
                if self.scoutUnit and (not self.scoutUnit.Dead) then
                    IssueClearCommands({self.scoutUnit})
                    IssueMove({self.scoutUnit}, PlatoonPosition)
                end
                dist = VDist2Sq(path[i][1], path[i][3], PlatoonPosition[1], PlatoonPosition[3])
                -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                if dist < 400 then
                    -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                    self:Stop()
                    break
                end
                -- Do we move ?
                if Lastdist ~= dist then
                    Stuck = 0
                    Lastdist = dist
                -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                else
                    Stuck = Stuck + 1
                    if Stuck > 15 then
                        --LOG('* AI-RNG: * MassRaidRNG: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                        self:Stop()
                        break
                    end
                end
                local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, PlatoonPosition, self.enemyRadius, 'Enemy')
                if enemyUnitCount > 0 then
                    local attackSquad = self:GetSquadUnits('Attack')
                    -- local target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL)
                    local target, acuInRange, acuUnit = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, self, PlatoonPosition, 'Attack', self.enemyRadius, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL, self.atkPri, false)
                    if acuInRange then
                        target = false
                        --LOG('ACU is in close range, we could avoid or do some other stuff')
                        if platoonThreat < 25 then
                            local alternatePos = false
                            local mergePlatoon = false
                            local acuPos = acuUnit:GetPosition()
                            --LOG('Attempt to run away from acu')
                            --LOG('we are now '..VDist3(PlatoonPosition, acuUnit:GetPosition())..' from acu')
                            self:Stop()
                            self:MoveToLocation(RUtils.AvoidLocation(PlatoonPosition,acuPos,40), false)
                            WaitTicks(40)
                            PlatoonPosition = GetPlatoonPosition(self)
                            --LOG('after move wait we are now '..VDist3(PlatoonPosition, acuUnit:GetPosition())..' from acu')
                            local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, PlatoonPosition, 120, 'Enemy')
                            if massPoints then
                                --LOG('Try to run to masspoint')
                                local massPointPos
                                for _, v in massPoints do
                                    if not v.Dead then
                                        massPointPos = v:GetPosition()
                                        if VDist2Sq(massPointPos[1], massPointPos[2],PlatoonPosition[1], PlatoonPosition[3]) < VDist2Sq(massPointPos[1], massPointPos[2],acuPos[1], acuPos[3]) then
                                            --LOG('Found a masspoint to run to')
                                            alternatePos = massPointPos
                                        end
                                    end
                                end
                            end
                            if alternatePos then
                                --LOG('Moving to masspoint alternative at '..repr(alternatePos))
                                self:MoveToLocation(alternatePos, false)
                            else
                                --LOG('No close masspoint try to find platoon to merge with')
                                mergePlatoon, alternatePos = self:GetClosestPlatoonRNG('MassRaidRNG')
                                if alternatePos then
                                    self:MoveToLocation(alternatePos, false)
                                end
                            end
                            if alternatePos then
                                while PlatoonExists(aiBrain, self) do
                                    --LOG('Moving to alternate position')
                                    --LOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                    WaitTicks(10)
                                    if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                        --LOG('MergeWith Platoon position updated')
                                        alternatePos = GetPlatoonPosition(mergePlatoon)
                                    end
                                    self:MoveToLocation(alternatePos, false)
                                    PlatoonPosition = GetPlatoonPosition(self)
                                    dist = VDist2Sq(alternatePos[1], alternatePos[3], PlatoonPosition[1], PlatoonPosition[3])
                                    if dist < 225 then
                                        self:Stop()
                                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                            self:MergeWithNearbyPlatoonsRNG('MassRaidRNG', 60, 30)
                                        end
                                        --LOG('Arrived at either masspoint or friendly massraid')
                                        break
                                    end
                                    if Lastdist ~= dist then
                                        Stuck = 0
                                        Lastdist = dist
                                    else
                                        Stuck = Stuck + 1
                                        if Stuck > 15 then
                                            self:Stop()
                                            break
                                        end
                                    end
                                    WaitTicks(30)
                                    --LOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                end
                            end
                        end
                    end
                    if avoid then
                        if platoonThreat < GetThreatAtPosition(aiBrain, GetPlatoonPosition(self), aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') then
                            --LOG('Threat too high are we are in avoid mode')
                            IssueClearCommands(attackSquad)
                            local alternatePos = false
                            local mergePlatoon = false
                            if target and not target.Dead then
                                local unitPos = target:GetPosition() 
                                --LOG('Attempt to run away from unit')
                                --LOG('before run away we are  '..VDist3(PlatoonPosition, target:GetPosition())..' from enemy')
                                self:Stop()
                                self:MoveToLocation(RUtils.AvoidLocation(PlatoonPosition,unitPos,40), false)
                                WaitTicks(40)
                                PlatoonPosition = GetPlatoonPosition(self)
                                --LOG('we are now '..VDist3(PlatoonPosition, target:GetPosition())..' from enemy')
                                local massPoints = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, PlatoonPosition, 120, 'Enemy')
                                if massPoints then
                                    --LOG('Try to run to masspoint')
                                    local massPointPos
                                    for _, v in massPoints do
                                        if not v.Dead then
                                            massPointPos = v:GetPosition()
                                            if VDist2Sq(massPointPos[1], massPointPos[2],PlatoonPosition[1], PlatoonPosition[3]) < VDist2Sq(massPointPos[1], massPointPos[2],unitPos[1], unitPos[3]) then
                                                --LOG('Found a masspoint to run to')
                                                alternatePos = massPointPos
                                            end
                                        end
                                    end
                                end
                                if alternatePos then
                                    --LOG('Moving to masspoint alternative at '..repr(alternatePos))
                                    self:MoveToLocation(alternatePos, false)
                                else
                                    --LOG('No close masspoint try to find platoon to merge with')
                                    mergePlatoon, alternatePos = self:GetClosestPlatoonRNG('MassRaidRNG')
                                    if alternatePos then
                                        self:MoveToLocation(alternatePos, false)
                                    end
                                end
                                if alternatePos then
                                    while PlatoonExists(aiBrain, self) do
                                        --LOG('Moving to alternate position')
                                        --LOG('We are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                        WaitTicks(10)
                                        if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                            --LOG('MergeWith Platoon position updated')
                                            alternatePos = GetPlatoonPosition(mergePlatoon)
                                        end
                                        self:MoveToLocation(alternatePos, false)
                                        PlatoonPosition = GetPlatoonPosition(self)
                                        dist = VDist2Sq(alternatePos[1], alternatePos[3], PlatoonPosition[1], PlatoonPosition[3])
                                        if dist < 400 then
                                            self:Stop()
                                            if mergePlatoon and PlatoonExists(aiBrain, mergePlatoon) then
                                                self:MergeWithNearbyPlatoonsRNG('MassRaidRNG', 60, 30)
                                            end
                                            --LOG('Arrived at either masspoint or friendly massraid')
                                            break
                                        end
                                        if Lastdist ~= dist then
                                            Stuck = 0
                                            Lastdist = dist
                                        else
                                            Stuck = Stuck + 1
                                            if Stuck > 15 then
                                                self:Stop()
                                                break
                                            end
                                        end
                                        WaitTicks(30)
                                        --LOG('End of movement loop we are '..VDist3(PlatoonPosition, alternatePos)..' from alternate position')
                                    end
                                end
                            end
                        end
                    end
                    IssueClearCommands(attackSquad)
                    while PlatoonExists(aiBrain, self) do
                        if target and not target.Dead then
                            local targetPosition = target:GetPosition()
                            attackSquad = self:GetSquadUnits('Attack')
                            local microCap = 50
                            for _, unit in attackSquad do
                                microCap = microCap - 1
                                if microCap <= 0 then break end
                                if unit.Dead then continue end
                                if not unit.MaxWeaponRange then
                                    continue
                                end
                                IssueClearCommands({unit})
                                VariableKite(self,unit,target)
                            end
                        else
                            break
                        end
                    WaitTicks(10)
                    end
                end
                WaitTicks(15)
            end
        end
    end,

    ScoutFindNearbyPlatoonsRNG = function(self, radius)
        local aiBrain = self:GetBrain()
        if not aiBrain then return end
        local platPos = GetPlatoonPosition(self)
        local allyPlatPos = false
        if not platPos then
            return
        end
        local radiusSq = radius*radius
        AlliedPlatoons = aiBrain:GetPlatoonsList()
        local platRequiresScout = false
        for _,aPlat in AlliedPlatoons do
            if aPlat == self then continue end
            if aPlat.PlanName ~= 'MassRaidRNG' or aPlat.PlanName ~= 'HuntAIPATHRNG' or aPlat.PlanName ~= 'TruePlatoonRNG' or aPlat.PlanName ~= 'GuardMarkerRNG' then continue end
            if aPlat.UsingTransport then continue end
            if aPlat.ScoutPresent then continue end
            allyPlatPos = GetPlatoonPosition(aPlat)
            if not allyPlatPos or not PlatoonExists(aiBrain, aPlat) then
                allyPlatPos = false
                continue
            end
            if not aPlat.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayer(aPlat)
            end
            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
            if self.MovementLayer != aPlat.MovementLayer then
                continue
            end
            if  VDist2Sq(platPos[1], platPos[3], allyPlatPos[1], allyPlatPos[3]) <= radiusSq then
                if not AIAttackUtils.CanGraphToRNG(platPos, allyPlatPos, self.MovementLayer) then continue end
                --LOG("*AI DEBUG: Scout moving to allied platoon position")
                return true, aPlat
            end
        end
        --LOG('no platoons found that need scout')
        return false
    end,

    GetClosestPlatoonRNG = function(self, planName)
        local aiBrain = self:GetBrain()
        if not aiBrain then
            return
        end
        if self.UsingTransport then
            return
        end
        local platPos = GetPlatoonPosition(self)
        if not platPos then
            return
        end
        local closestPlatoon = false
        local closestDistance = 62,500
        local closestAPlatPos = false
        --LOG('Getting list of allied platoons close by')
        AlliedPlatoons = aiBrain:GetPlatoonsList()
        for _,aPlat in AlliedPlatoons do
            if aPlat.PlanName != planName then
                continue
            end
            if aPlat == self then
                continue
            end

            if aPlat.UsingTransport then
                continue
            end

            if aPlat.PlatoonFull then
                --LOG('Remote platoon is full, skip')
                continue
            end
            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayer(self)
            end
            if not aPlat.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayer(aPlat)
            end

            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
            if self.MovementLayer != aPlat.MovementLayer then
                continue
            end
            local aPlatPos = GetPlatoonPosition(aPlat)
            local aPlatDistance = VDist2Sq(platPos[1],platPos[3],aPlatPos[1],aPlatPos[3])
            if aPlatDistance < closestDistance then
                closestPlatoon = aPlat
                closestDistance = aPlatDistance
                closestAPlatPos = aPlatPos
            end
        end
        if closestPlatoon then
            --LOG('Found platoon checking if can graph')
            if AIAttackUtils.CanGraphToRNG(platPos,closestAPlatPos,self.MovementLayer) then
                --LOG('Can graph to platoon, returning platoon and platoon location')
                return closestPlatoon, closestAPlatPos
            end
        end
        --LOG('No platoon found within 250 units')
        return false, false
    end,

    MergeWithNearbyPlatoonsRNG = function(self, planName, radius, maxMergeNumber, ignoreBase)
        -- check to see we're not near an ally base
        local aiBrain = self:GetBrain()
        if not aiBrain then
            return
        end

        if self.UsingTransport then
            return
        end
        local platUnits = GetPlatoonUnits(self)
        local platCount = 0

        for _, u in platUnits do
            if not u.Dead then
                platCount = platCount + 1
            end
        end

        if (maxMergeNumber and platCount > maxMergeNumber) or platCount < 1 then
            return
        end 

        local platPos = GetPlatoonPosition(self)
        if not platPos then
            return
        end

        local radiusSq = radius*radius
        -- if we're too close to a base, forget it
        if not ignoreBase then
            if aiBrain.BuilderManagers then
                for baseName, base in aiBrain.BuilderManagers do
                    if VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3]) <= (2*radiusSq) then
                        --LOG('Platoon too close to base, not merge happening')
                        return
                    end
                end
            end
        end

        AlliedPlatoons = aiBrain:GetPlatoonsList()
        local bMergedPlatoons = false
        for _,aPlat in AlliedPlatoons do
            if aPlat.PlanName != planName then
                continue
            end
            if aPlat == self then
                continue
            end

            if self.PlatoonData.UnitType and self.PlatoonData.UnitType ~= aPlat.PlatoonData.UnitType then
                continue
            end

            if aPlat.UsingTransport then
                continue
            end

            if aPlat.PlatoonFull then
                --LOG('Remote platoon is full, skip')
                continue
            end

            local allyPlatPos = GetPlatoonPosition(aPlat)
            if not allyPlatPos or not PlatoonExists(aiBrain, aPlat) then
                continue
            end

            if not self.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayer(self)
            end
            if not aPlat.MovementLayer then
                AIAttackUtils.GetMostRestrictiveLayer(aPlat)
            end

            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
            if self.MovementLayer != aPlat.MovementLayer then
                continue
            end

            if  VDist2Sq(platPos[1], platPos[3], allyPlatPos[1], allyPlatPos[3]) <= radiusSq then
                local units = GetPlatoonUnits(aPlat)
                local validUnits = {}
                local bValidUnits = false
                for _,u in units do
                    if not u.Dead and not u:IsUnitState('Attached') then
                        RNGINSERT(validUnits, u)
                        bValidUnits = true
                    end
                end
                if not bValidUnits then
                    continue
                end
                --LOG("*AI DEBUG: Merging platoons " .. self.BuilderName .. ": (" .. platPos[1] .. ", " .. platPos[3] .. ") and " .. aPlat.BuilderName .. ": (" .. allyPlatPos[1] .. ", " .. allyPlatPos[3] .. ")")
                aiBrain:AssignUnitsToPlatoon(self, validUnits, 'Attack', 'GrowthFormation')
                bMergedPlatoons = true
            end
        end
        if bMergedPlatoons then
            self:StopAttack()
        end
        return bMergedPlatoons
    end,

    ReturnToBaseAIRNG = function(self, mainBase)

        local aiBrain = self:GetBrain()

        if not PlatoonExists(aiBrain, self) or not GetPlatoonPosition(self) then
            return
        end

        local bestBase = false
        local bestBaseName = ""
        local bestDistSq = 999999999
        local platPos = GetPlatoonPosition(self)
        AIAttackUtils.GetMostRestrictiveLayer(self)

        if not mainBase then
            for baseName, base in aiBrain.BuilderManagers do
                local distSq = VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3])

                if distSq < bestDistSq then
                    bestBase = base
                    bestBaseName = baseName
                    bestDistSq = distSq
                end
            end
        else
            bestBase = aiBrain.BuilderManagers['MAIN']
        end
        
        if bestBase then
            if self.MovementLayer == 'Air' then
                self:Stop()
                self:MoveToLocation(bestBase.Position, false)
                --LOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                while PlatoonExists(aiBrain, self) do
                    local currentPlatPos = self:GetPlatoonPosition()
                    --LOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3]))
                    --LOG('Air Unit Platoon Position is :'..repr(currentPlatPos))
                    local distSq = VDist2Sq(currentPlatPos[1], currentPlatPos[3], bestBase.Position[1], bestBase.Position[3])
                    if distSq < 6400 then
                        break
                    end
                    WaitTicks(15)
                end
            else
                local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), bestBase.Position, 10)
                IssueClearCommands(self)
                if path then
                    local pathLength = RNGGETN(path)
                    for i=1, pathLength-1 do
                        self:MoveToLocation(path[i], false)
                        local oldDistSq = 0
                        while PlatoonExists(aiBrain, self) do
                            platPos = GetPlatoonPosition(self)
                            local distSq = VDist2Sq(platPos[1], platPos[3], bestBase.Position[1], bestBase.Position[3])
                            if distSq < 400 then
                                self:PlatoonDisband()
                                return
                            end
                            -- if we haven't moved in 10 seconds... go back to attacking
                            if (distSq - oldDistSq) < 25 then
                                break
                            end
                            oldDistSq = distSq
                            WaitTicks(20)
                        end
                    end
                end
                self:MoveToLocation(bestBase.Position, false)
            end
        end
        -- return 
        self:PlatoonDisband()
    end,
    
    DistressResponseAIRNG = function(self)
        local aiBrain = self:GetBrain()
        while PlatoonExists(aiBrain, self) do
            if not self.UsingTransport then
                if aiBrain.BaseMonitor.AlertSounded or aiBrain.BaseMonitor.CDRDistress or aiBrain.BaseMonitor.PlatoonAlertSounded then
                    -- In the loop so they may be changed by other platoon things
                    local distressRange = self.PlatoonData.DistressRange or aiBrain.BaseMonitor.DefaultDistressRange
                    local reactionTime = self.PlatoonData.DistressReactionTime or aiBrain.BaseMonitor.PlatoonDefaultReactionTime
                    local threatThreshold = self.PlatoonData.ThreatSupport or 1
                    local platoonPos = GetPlatoonPosition(self)
                    if platoonPos and not self.DistressCall then
                        -- Find a distress location within the platoons range
                        local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(platoonPos, distressRange, threatThreshold)
                        local moveLocation

                        -- We found a location within our range! Activate!
                        if distressLocation then
                            --LOG('*AI DEBUG: ARMY '.. aiBrain:GetArmyIndex() ..': --- DISTRESS RESPONSE AI ACTIVATION ---')
                            --LOG('Distress response activated')
                            --LOG('PlatoonDistressTable'..repr(aiBrain.BaseMonitor.PlatoonDistressTable))
                            --LOG('BaseAlertTable'..repr(aiBrain.BaseMonitor.AlertsTable))
                            -- Backups old ai plan
                            local oldPlan = self:GetPlan()
                            if self.AiThread then
                                self.AIThread:Destroy()
                            end

                            -- Continue to position until the distress call wanes
                            repeat
                                moveLocation = distressLocation
                                self:Stop()
                                --LOG('Platoon responding to distress at location '..repr(distressLocation))
                                self:SetPlatoonFormationOverride('NoFormation')
                                local cmd = self:AggressiveMoveToLocation(distressLocation)
                                repeat
                                    WaitSeconds(reactionTime)
                                    if not PlatoonExists(aiBrain, self) then
                                        return
                                    end
                                until not self:IsCommandsActive(cmd) or GetThreatAtPosition(aiBrain, moveLocation, 0, true, 'Overall') <= threatThreshold
                                --LOG('Initial Distress Response Loop finished')

                                platoonPos = GetPlatoonPosition(self)
                                if platoonPos then
                                    -- Now that we have helped the first location, see if any other location needs the help
                                    distressLocation = aiBrain:BaseMonitorDistressLocationRNG(platoonPos, distressRange)
                                    if distressLocation then
                                        self:SetPlatoonFormationOverride('NoFormation')
                                        self:AggressiveMoveToLocation(distressLocation)
                                    end
                                end
                                WaitTicks(10)
                            -- If no more calls or we are at the location; break out of the function
                            until not distressLocation or (distressLocation[1] == moveLocation[1] and distressLocation[3] == moveLocation[3])

                            --LOG('*AI DEBUG: '..aiBrain.Name..' DISTRESS RESPONSE AI DEACTIVATION - oldPlan: '..oldPlan)
                            self:Stop()
                            self:SetAIPlanRNG(oldPlan)
                        end
                    end
                end
            end
            WaitTicks(110)
        end
    end,

    ExtractorCallForHelpAIRNG = function(self, aiBrain)
        local checkTime = self.PlatoonData.DistressCheckTime or 4
        local pos = GetPlatoonPosition(self)
        while PlatoonExists(aiBrain, self) and pos do
            if not self.DistressCall then
                local threat = GetThreatAtPosition(aiBrain, pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Land')
                --LOG('Threat at Extractor :'..threat)
                if threat and threat > 1 then
                    --LOG('*RNGAI Mass Extractor Platoon Calling for help with '..threat.. ' threat')
                    aiBrain:BaseMonitorPlatoonDistressRNG(self, threat)
                    self.DistressCall = true
                    aiBrain:AddScoutArea(pos)
                end
            end
            WaitSeconds(checkTime)
        end
    end,

    BaseManagersDistressAIRNG = function(self)
        local aiBrain = self:GetBrain()
        while PlatoonExists(aiBrain, self) do
            local distressRange = aiBrain.BaseMonitor.PoolDistressRange
            local reactionTime = aiBrain.BaseMonitor.PoolReactionTime

            local platoonUnits = GetPlatoonUnits(self)

            for locName, locData in aiBrain.BuilderManagers do
                if not locData.DistressCall then
                    local position = locData.EngineerManager.Location
                    local radius = locData.EngineerManager.Radius
                    local distressRange = locData.BaseSettings.DistressRange or aiBrain.BaseMonitor.PoolDistressRange
                    local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(position, distressRange, aiBrain.BaseMonitor.PoolDistressThreshold)

                    -- Distress !
                    if distressLocation then
                        --LOG('*AI DEBUG: ARMY '.. aiBrain:GetArmyIndex() ..': --- POOL DISTRESS RESPONSE ---')

                        -- Grab the units at the location
                        local group = self:GetPlatoonUnitsAroundPoint(categories.MOBILE - categories.ENGINEER - categories.TRANSPORTFOCUS - categories.SONAR - categories.EXPERIMENTAL, position, radius)

                        -- Move the group to the distress location and then back to the location of the base
                        IssueClearCommands(group)
                        IssueAggressiveMove(group, distressLocation)
                        IssueMove(group, position)

                        -- Set distress active for duration
                        locData.DistressCall = true
                        self:ForkThread(self.UnlockBaseManagerDistressLocation, locData)
                    end
                end
            end
            WaitSeconds(aiBrain.BaseMonitor.PoolReactionTime)
        end
    end,

    NavalHuntAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local cmd = false
        local platoonUnits = GetPlatoonUnits(self)
        local PlatoonFormation = self.PlatoonData.UseFormation or 'NoFormation'
        self:SetPlatoonFormationOverride(PlatoonFormation)
        local atkPri = { 'MOBILE NAVAL', 'STRUCTURE ANTINAVY', 'STRUCTURE NAVAL', 'COMMAND', 'EXPERIMENTAL', 'STRUCTURE STRATEGIC EXPERIMENTAL', 'ARTILLERY EXPERIMENTAL', 'STRUCTURE ARTILLERY TECH3', 'STRUCTURE NUKE TECH3', 'STRUCTURE ANTIMISSILE SILO',
                            'STRUCTURE DEFENSE DIRECTFIRE', 'TECH3 MASSFABRICATION', 'TECH3 ENERGYPRODUCTION', 'STRUCTURE STRATEGIC', 'STRUCTURE DEFENSE', 'STRUCTURE', 'MOBILE', 'SPECIALLOWPRI', 'ALLUNITS' }
        local atkPriTable = {}
        for k,v in atkPri do
            RNGINSERT(atkPriTable, ParseEntityCategory(v))
        end
        self:SetPrioritizedTargetList('Attack', atkPriTable)
        local maxRadius = 6000
        for k,v in platoonUnits do
            if v.Dead then
                continue
            end
            if v:GetCurrentLayer() == 'Sub' then
                continue
            end
            if v:TestCommandCaps('RULEUCC_Dive') and v:GetUnitId() != 'uas0401' then
                IssueDive({v})
            end
        end
        WaitTicks(10)
        local distanceToTarget = 9999999999
        local blockCounter = 0
        local targetPosition = false
        while PlatoonExists(aiBrain, self) do
            target = RUtils.AIFindBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri, false)
            if target then
                targetPosition = target:GetPosition()
                self:Stop()
                cmd = self:AggressiveMoveToLocation(targetPosition)
            end
            WaitTicks(10)
            if (not cmd or not self:IsCommandsActive(cmd)) then
                target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.WALL)
                if target then
                    targetPosition = target:GetPosition()
                    self:Stop()
                    cmd = self:AggressiveMoveToLocation(targetPosition)
                else
                    local scoutPath = {}
                    scoutPath = AIUtils.AIGetSortedNavalLocations(self:GetBrain())
                    for k, v in scoutPath do
                        self:Patrol(v)
                    end
                end
            end
            WaitTicks(120)
            local targetDistance = VDist3Sq(targetPosition, GetPlatoonPosition(self))
            if targetDistance < distanceToTarget then
                distanceToTarget = targetDistance
            elseif targetDistance == distanceToTarget then
                --LOG('NavalHuntAI distance to attack position hasnt changed')
                blockCounter = blockCounter + 1
            end
            if blockCounter > 3 then
                if target then
                    --LOG('NavalHuntAI is stuck or attack something that is terrainblocked')
                    self:Stop()
                    self:AttackTarget(target)
                    distanceToTarget = 9999999999
                end
            end
            self:Stop()
        end
    end,

    SACUAttackAIRNG = function(self)
        -- SACU Attack Platoon
        AIAttackUtils.GetMostRestrictiveLayer(self)
        local platoonUnits = GetPlatoonUnits(self)

        if platoonUnits and PlatoonStrength > 0 then
            for k, v in platoonUnits do
                if not v.Dead then
                    if IsDestroyed(v) then
                        WARN('Unit is not Dead but DESTROYED')
                    end
                    if v:BeenDestroyed() then
                        WARN('Unit is not Dead but DESTROYED')
                    end
                    if v:TestToggleCaps('RULEUTC_StealthToggle') then
                        v:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if v:TestToggleCaps('RULEUTC_CloakToggle') then
                        v:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                    if EntityCategoryContains(categories.EXPERIMENTAL, v) then
                        ExperimentalInPlatoon = true
                    end
                    -- prevent units from reclaiming while attack moving
                    v:RemoveCommandCap('RULEUCC_Reclaim')
                    v:RemoveCommandCap('RULEUCC_Repair')
                end
            end
        end
        
        local MoveToCategories = {}
        if self.PlatoonData.MoveToCategories then
            for k,v in self.PlatoonData.MoveToCategories do
                RNGINSERT(MoveToCategories, v )
            end
        else
            --LOG('* RNGAI: * SACUATTACKAIRNG: MoveToCategories missing in platoon '..self.BuilderName)
        end
        local WeaponTargetCategories = {}
        if self.PlatoonData.WeaponTargetCategories then
            for k,v in self.PlatoonData.WeaponTargetCategories do
                RNGINSERT(WeaponTargetCategories, v )
            end
        elseif self.PlatoonData.MoveToCategories then
            WeaponTargetCategories = MoveToCategories
        end
        self:SetPrioritizedTargetList('Attack', WeaponTargetCategories)
        local aiBrain = self:GetBrain()
        local bAggroMove = self.PlatoonData.AggressiveMove
        local maxRadius = self.PlatoonData.SearchRadius
        local platoonPos
        local requestTransport = self.PlatoonData.RequestTransport
        while PlatoonExists(aiBrain, self) do
            --LOG('* AI-RNG: * HuntAIPATH:: Check for target')
            if aiBrain.TacticalMonitor.TacticalSACUMode then
                --stuff
            else
                local target = self:FindClosestUnit('Attack', 'Enemy', true, categories.ALLUNITS - categories.AIR - categories.SCOUT - categories.WALL)
                if target then
                    --LOG('* AI-RNG: * HuntAIPATH:: Target Found')
                    local targetPosition = target:GetPosition()
                    local attackUnits =  self:GetSquadUnits('Attack')
                    local guardUnits = self:GetSquadUnits('Guard')
                    if guardUnits then
                        local guardedUnit = 1
                        if attackUnitCount > 0 then
                            while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                                guardedUnit = guardedUnit + 1
                                WaitTicks(3)
                                if guardedUnit > attackUnitCount then
                                    guardedUnit = false
                                    break
                                end
                            end
                        else
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        end
                        IssueClearCommands(guardUnits)
                        if not guardedUnit then
                            return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                        else
                            IssueGuard(guardUnits, attackUnits[guardedUnit])
                        end
                    end
                    --LOG('* AI-RNG: * SACUAIPATH: Performing Path Check')
                    --LOG('Details :'..' Movement Layer :'..self.MovementLayer..' Platoon Position :'..repr(GetPlatoonPosition(self))..' Target Position :'..repr(targetPosition))
                    local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), targetPosition, 10 , maxPathDistance)
                    local success, bestGoalPos = AIAttackUtils.CheckPlatoonPathingEx(self, targetPosition)
                    IssueClearCommands(GetPlatoonUnits(self))
                    if path then
                        --LOG('* AI-RNG: * HuntAIPATH: Path found')
                        local position = GetPlatoonPosition(self)
                        local usedTransports = false
                        if not success or VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 512 then
                            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                        elseif VDist2(position[1], position[3], targetPosition[1], targetPosition[3]) > 256 then
                            usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, false)
                        end
                        if not usedTransports then
                            for i=1, RNGGETN(path) do
                                local PlatoonPosition
                                if guardUnits then
                                    local guardedUnit = 1
                                    if attackUnitCount > 0 then
                                        while attackUnits[guardedUnit].Dead or attackUnits[guardedUnit]:BeenDestroyed() do
                                            guardedUnit = guardedUnit + 1
                                            WaitTicks(3)
                                            if guardedUnit > attackUnitCount then
                                                guardedUnit = false
                                                break
                                            end
                                        end
                                    else
                                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                                    end
                                    IssueClearCommands(guardUnits)
                                    if not guardedUnit then
                                        return self:SetAIPlanRNG('ReturnToBaseAIRNG')
                                    else
                                        IssueGuard(guardUnits, attackUnits[guardedUnit])
                                    end
                                end
                                --LOG('* AI-RNG: * SACUATTACKAIRNG:: moving to destination. i: '..i..' coords '..repr(path[i]))
                                if bAggroMove and attackUnits then
                                    self:AggressiveMoveToLocation(path[i], 'Attack')
                                elseif attackUnits then
                                    self:MoveToLocation(path[i], false, 'Attack')
                                end
                                --LOG('* AI-RNG: * SACUATTACKAIRNG:: moving to Waypoint')
                                local Lastdist
                                local dist
                                local Stuck = 0
                                local retreatCount = 2
                                while PlatoonExists(aiBrain, self) do
                                    SquadPosition = self:GetSquadPosition('Attack') or nil
                                    if not SquadPosition then break end
                                    dist = VDist2Sq(path[i][1], path[i][3], SquadPosition[1], SquadPosition[3])
                                    -- are we closer then 15 units from the next marker ? Then break and move to the next marker
                                    --LOG('* AI-RNG: * SACUATTACKAIRNG: Distance to path node'..dist)
                                    if dist < 400 then
                                        -- If we don't stop the movement here, then we have heavy traffic on this Map marker with blocking units
                                        self:Stop()
                                        break
                                    end
                                    if retreatCount < 5 then
                                        local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER, SquadPosition, self.enemyRadius, 'Enemy')
                                        --LOG('* AI-RNG: * SACUATTACKAIRNG: EnemyCount :'..enemyUnitCount)
                                        if enemyUnitCount > 2 and i > 2 then
                                            --LOG('* AI-RNG: * SACUATTACKAIRNG: Enemy Units Detected, retreating..')
                                            --LOG('* AI-RNG: * SACUATTACKAIRNG: Retreation Position :'..repr(path[i - retreatCount]))
                                            self:Stop()
                                            self:MoveToLocation(path[i - retreatCount], false, 'Attack')
                                            --LOG('* AI-RNG: * SACUATTACKAIRNG: Retreat Command Given')
                                            retreatCount = retreatCount + 1
                                            WaitTicks(50)
                                            self:Stop()
                                            break
                                        elseif enemyUnitCount > 2 and i <= 2 then
                                            --LOG('* AI-RNG: * SACUATTACKAIRNG: Not enough path nodes : increasing retreat count')
                                            retreatCount = retreatCount + 1
                                            self:Stop()
                                            break
                                        end
                                    end
                                    -- Do we move ?
                                    if Lastdist ~= dist then
                                        Stuck = 0
                                        Lastdist = dist
                                    -- No, we are not moving, wait 100 ticks then break and use the next weaypoint
                                    else
                                        Stuck = Stuck + 1
                                        if Stuck > 15 then
                                            --LOG('* AI-RNG: * SACUATTACKAIRNG: Stucked while moving to Waypoint. Stuck='..Stuck..' - '..repr(path[i]))
                                            self:Stop()
                                            break
                                        end
                                    end
                                    if not target then
                                        --LOG('* AI-RNG: * SACUATTACKAIRNG: Lost target while moving to Waypoint. '..repr(path[i]))
                                        self:Stop()
                                        break
                                    end
                                    --LOG('* AI-RNG: * SACUATTACKAIRNG: End of movement loop, wait 10 ticks at :'..GetGameTimeSeconds())
                                    WaitTicks(15)
                                end
                                --LOG('* AI-RNG: * SACUATTACKAIRNG: Ending Loop at :'..GetGameTimeSeconds())
                            end
                        end
                    elseif (not path and reason == 'NoPath') then
                        --LOG('* AI-RNG: * SACUATTACKAIRNG: NoPath reason from path')
                        --LOG('Guardmarker requesting transports')
                        local usedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheckRNG(aiBrain, self, targetPosition, true)
                        --DUNCAN - if we need a transport and we cant get one the disband
                        if not usedTransports then
                            --LOG('Guardmarker no transports')
                            self:PlatoonDisband()
                            return
                        end
                        --LOG('Guardmarker found transports')
                    else
                        --LOG('* AI-RNG: * SACUATTACKAIRNG: No Path found, no reason')
                        self:PlatoonDisband()
                        return
                    end

                    if (not path or not success) and not usedTransports then
                        self:PlatoonDisband()
                        return
                    end
                end
            --LOG('* AI-RNG: * SACUATTACKAIRNG: No target, waiting 5 seconds')
            WaitTicks(50)
            end
            WaitTicks(1)
        end
    end,

    GuardArtillerySquadRNG = function(self, aiBrain, target)
        while target and not target.Dead do
            local artillerySquad = self:GetSquadUnits('Artillery')
            local attackUnits = self:GetSquadUnits('Attack')
            local artillerySquadPosition = self:GetSquadPosition('Artillery') or nil
            if RNGGETN(artillerySquad) > 0 and RNGGETN(attackUnits) > 0 then
                IssueClearCommands(attackUnits)
                IssueMove(attackUnits, artillerySquadPosition)
                WaitTicks(2)
                IssueGuard(attackUnits, artillerySquadPosition)
                WaitTicks(100)
                if RNGGETN(artillerySquad) < 1 then
                    break
                end
            else
                return
            end
        end
    end,

    EngineerAssistAIRNG = function(self)
        self:ForkThread(self.AssistBodyRNG)
        local aiBrain = self:GetBrain()
        WaitSeconds(self.PlatoonData.Assist.Time or 60)
        if not PlatoonExists(aiBrain, self) then
            return
        end
        WaitTicks(1)
        -- stop the platoon from endless assisting
        self:Stop()
        WaitTicks(1)
        self:PlatoonDisband()
    end,

    AssistBodyRNG = function(self)
        local platoonUnits = GetPlatoonUnits(self)
        local eng = platoonUnits[1]
        eng.AssistPlatoon = self
        local aiBrain = self:GetBrain()
        local assistData = self.PlatoonData.Assist
        local platoonPos = self:GetPlatoonPosition()
        local assistee = false
        local assistingBool = false
        WaitTicks(5)
        if not PlatoonExists(aiBrain, self) then
            return
        end
        if not eng.Dead then
            local guardedUnit = eng:GetGuardedUnit()
            if guardedUnit and not guardedUnit.Dead then
                if eng.AssistSet and assistData.PermanentAssist then
                    return
                end
                eng.AssistSet = false
                if guardedUnit:IsUnitState('Building') or guardedUnit:IsUnitState('Upgrading') then
                    return
                end
            end
        end
        self:Stop()
        if assistData then
            local assistRange = assistData.AssistRange or 80
            -- Check for units being built
            if assistData.BeingBuiltCategories then
                local unitsBuilding = aiBrain:GetListOfUnits(categories.CONSTRUCTION, false)
                for catNum, buildeeCat in assistData.BeingBuiltCategories do
                    local buildCat = ParseEntityCategory(buildeeCat)
                    for unitNum, unit in unitsBuilding do
                        if not unit.Dead and (unit:IsUnitState('Building') or unit:IsUnitState('Upgrading')) then
                            local buildingUnit = unit.UnitBeingBuilt
                            if buildingUnit and not buildingUnit.Dead and EntityCategoryContains(buildCat, buildingUnit) then
                                local unitPos = unit:GetPosition()
                                if unitPos and platoonPos and VDist2(platoonPos[1], platoonPos[3], unitPos[1], unitPos[3]) < assistRange then
                                    assistee = unit
                                    break
                                end
                            end
                        end
                    end
                    if assistee then
                        break
                    end
                end
            end
            -- Check for builders
            if not assistee and assistData.BuilderCategories then
                for catNum, buildCat in assistData.BuilderCategories do
                    local unitsBuilding = aiBrain:GetListOfUnits(ParseEntityCategory(buildCat), false)
                    for unitNum, unit in unitsBuilding do
                        if not unit.Dead and unit:IsUnitState('Building') then
                            local unitPos = unit:GetPosition()
                            if unitPos and platoonPos and VDist2(platoonPos[1], platoonPos[3], unitPos[1], unitPos[3]) < assistRange then
                                assistee = unit
                                break
                            end
                        end
                    end
                end
            end
            -- If the unit to be assisted is a factory, assist whatever it is assisting or is assisting it
            -- Makes sure all factories have someone helping out to load balance better
            if assistee and not assistee.Dead and EntityCategoryContains(categories.FACTORY, assistee) then
                local guardee = assistee:GetGuardedUnit()
                if guardee and not guardee.Dead and EntityCategoryContains(categories.FACTORY, guardee) then
                    local factories = AIUtils.AIReturnAssistingFactories(guardee)
                    RNGINSERT(factories, assistee)
                    AIUtils.AIEngineersAssistFactories(aiBrain, platoonUnits, factories)
                    assistingBool = true
                elseif RNGGETN(assistee:GetGuards()) > 0 then
                    local factories = AIUtils.AIReturnAssistingFactories(assistee)
                    RNGINSERT(factories, assistee)
                    AIUtils.AIEngineersAssistFactories(aiBrain, platoonUnits, factories)
                    assistingBool = true
                end
            end
        end
        if assistee and not assistee.Dead then
            if not assistingBool then
                eng.AssistSet = true
                IssueGuard(platoonUnits, assistee)
            end
        elseif not assistee then
            if eng.BuilderManagerData then
                local emLoc = eng.BuilderManagerData.EngineerManager.Location
                local dist = assistData.AssistRange or 80
                if VDist3(eng:GetPosition(), emLoc) > dist then
                    self:MoveToLocation(emLoc, false)
                    WaitSeconds(9)
                end
            end
            --LOG('Assistee Not found for AssisteeType'..ToString(assistData.AssisteeType)..' with BeingBuiltCategories'..repr(assistData.BeingBuiltCategories))
            WaitSeconds(1)
        end
    end,

    ManagerEngineerAssistAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local eng = GetPlatoonUnits(self)[1]
        self:EconAssistBodyRNG()
        WaitTicks(10)
        if eng.Upgrading or eng.Combat then
            --LOG('eng.Upgrading is True at start of assist function')
        end
        -- do we assist until the building is finished ?
        if self.PlatoonData.Assist.AssistUntilFinished then
            local guardedUnit
            if eng.UnitBeingAssist then
                guardedUnit = eng.UnitBeingAssist
            else 
                guardedUnit = eng:GetGuardedUnit()
            end
            -- loop as long as we are not dead and not idle
            while eng and not eng.Dead and PlatoonExists(aiBrain, self) and not eng:IsIdleState() do
                if not guardedUnit or guardedUnit.Dead or guardedUnit:BeenDestroyed() then
                    break
                end
                -- stop if our target is finished
                if guardedUnit:GetFractionComplete() == 1 and not guardedUnit:IsUnitState('Upgrading') then
                    --LOG('* ManagerEngineerAssistAI: Engineer Builder ['..self.BuilderName..'] - ['..self.PlatoonData.Assist.AssisteeType..'] - Target unit ['..guardedUnit:GetBlueprint().BlueprintId..'] ('..guardedUnit:GetBlueprint().Description..') is finished')
                    break
                end
                -- wait 1.5 seconds until we loop again
                if eng.Upgrading or eng.Combat then
                    --LOG('eng.Upgrading is True inside Assist function for assistuntilfinished')
                end
                WaitTicks(30)
            end
        else
            if eng.Upgrading or eng.Combat then
                --LOG('eng.Upgrading is True inside Assist function for assist time')
            end
            WaitSeconds(self.PlatoonData.Assist.Time or 60)
        end
        if not PlatoonExists(aiBrain, self) then
            return
        end
        self.AssistPlatoon = nil
        eng.UnitBeingAssist = nil
        self:Stop()
        if eng.Upgrading then
            --LOG('eng.Upgrading is True')
        end
        self:PlatoonDisband()
    end,

    EconAssistBodyRNG = function(self)
        local aiBrain = self:GetBrain()
        local eng = GetPlatoonUnits(self)[1]
        if not eng or eng:IsUnitState('Building') or eng:IsUnitState('Upgrading') or eng:IsUnitState("Enhancing") then
           return
        end
        local assistData = self.PlatoonData.Assist
        if not assistData.AssistLocation then
            WARN('*AI WARNING: Builder '..repr(self.BuilderName)..' is missing AssistLocation')
            return
        end
        if not assistData.AssisteeType then
            WARN('*AI WARNING: Builder '..repr(self.BuilderName)..' is missing AssisteeType')
            return
        end
        eng.AssistPlatoon = self
        local assistee = false
        local assistRange = assistData.AssistRange or 80
        local platoonPos = self:GetPlatoonPosition()
        local beingBuilt = assistData.BeingBuiltCategories or { categories.ALLUNITS }
        local assisteeCat = assistData.AssisteeCategory or categories.ALLUNITS
        if type(assisteeCat) == 'string' then
            assisteeCat = ParseEntityCategory(assisteeCat)
        end

        -- loop through different categories we are looking for
        for _,category in beingBuilt do
            -- Track all valid units in the assist list so we can load balance for builders
            local assistList = RUtils.GetAssisteesRNG(aiBrain, assistData.AssistLocation, assistData.AssisteeType, category, assisteeCat)
            if RNGGETN(assistList) > 0 then
                -- only have one unit in the list; assist it
                local low = false
                local bestUnit = false
                for k,v in assistList do
                    --DUNCAN - check unit is inside assist range 
                    local unitPos = v:GetPosition()
                    local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                    local NumAssist = RNGGETN(UnitAssist:GetGuards())
                    local dist = VDist2(platoonPos[1], platoonPos[3], unitPos[1], unitPos[3])
                    -- Find the closest unit to assist
                    if assistData.AssistClosestUnit then
                        if (not low or dist < low) and NumAssist < 20 and dist < assistRange then
                            low = dist
                            bestUnit = v
                        end
                    -- Find the unit with the least number of assisters; assist it
                    else
                        if (not low or NumAssist < low) and NumAssist < 20 and dist < assistRange then
                            low = NumAssist
                            bestUnit = v
                        end
                    end
                end
                assistee = bestUnit
                break
            end
        end
        -- assist unit
        if assistee  then
            self:Stop()
            eng.AssistSet = true
            eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
            --LOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
            IssueGuard({eng}, eng.UnitBeingAssist)
        else
            self.AssistPlatoon = nil
            eng.UnitBeingAssist = nil
            if eng.Upgrading then
                --LOG('eng.Upgrading is True')
            end
            -- stop the platoon from endless assisting
            self:PlatoonDisband()
        end
    end,

    FinishStructureAIRNG = function(self)
        local aiBrain = self:GetBrain()

        if not self.PlatoonData or not self.PlatoonData.Assist then
            WARN('* AI-RNG: FinishStructureAIRNG missing data' )
            self:PlatoonDisband()
            return
        end
        local assistData = self.PlatoonData.Assist
        local eng = self:GetPlatoonUnits()[1]
        local engineerManager = aiBrain.BuilderManagers[assistData.AssistLocation].EngineerManager
        if not engineerManager then
            WARN('* AI-RNG: FinishStructureAIRNG cant find engineer manager' )
            self:PlatoonDisband()
            return
        end
        local unfinishedUnits = aiBrain:GetUnitsAroundPoint(assistData.BeingBuiltCategories, engineerManager.Location, engineerManager.Radius, 'Ally')
        for k,v in unfinishedUnits do
            local FractionComplete = v:GetFractionComplete()
            if FractionComplete < 1 and RNGGETN(v:GetGuards()) < 1 then
                self:Stop()
                if not v.Dead and not v:BeenDestroyed() then
                    IssueRepair(self:GetPlatoonUnits(), v)
                end
                break
            end
        end
        local count = 0
        repeat
            coroutine.yield(20)
            if not aiBrain:PlatoonExists(self) then
                return
            end
            count = count + 1
            if eng:IsIdleState() then break end
        until count >= 30
        self:PlatoonDisband()
    end,

    SetAIPlanRNG = function(self, plan, currentPlan, planData)
        if not self[plan] then return end
        if self.AIThread then
            self.AIThread:Destroy()
        end
        self.PlanName = plan
        self.OldPlan = currentPlan
        self.planData = planData
        self:ForkAIThread(self[plan])
    end,

    -- For Debugging
    --[[PlatoonDisband = function(self)
        local aiBrain = self:GetBrain()
        if not aiBrain.RNG then
            return RNGAIPlatoon.PlatoonDisband(self)
        end
        WARN('* AI-RNG: PlatoonDisband: PlanName '..repr(self.PlanName)..'  -  BuilderName: '..repr(self.BuilderName)..'.' )
        if not self.PlanName or not self.BuilderName then
            WARN('* AI-RNG: PlatoonDisband: PlatoonData = '..repr(self.PlatoonData))
        end
        local FuncData = debug.getinfo(2)
        if FuncData.name and FuncData.name ~= "" then
            WARN('* AI-RNG: PlatoonDisband: Called from '..FuncData.name..'.')
        else
            WARN('* AI-RNG: PlatoonDisband: Called from '..FuncData.source..' - line: '..FuncData.currentline.. '  -  (Offset AI-RNG: ['..(FuncData.currentline - 6543)..'])')
        end
        if aiBrain:PlatoonExists(self) then
            RNGAIPlatoon.PlatoonDisband(self)
        end
    end,]]


    PlatoonMergeRNG = function(self)
        --LOG('Platoon Merge Started')
        local aiBrain = self:GetBrain()
        local destinationPlan = self.PlatoonData.PlatoonPlan
        local location = self.PlatoonData.Location
        --LOG('Location Type is '..location)
        --LOG('at position '..repr(aiBrain.BuilderManagers[location].Position))
        --LOG('Destiantion Plan is '..destinationPlan)
        if destinationPlan == 'EngineerAssistManagerRNG' then
            --LOG('Have been requested to create EngineerAssistManager platoon')
        end
        if not destinationPlan then
            return
        end
        local mergedPlatoon
        local units = GetPlatoonUnits(self)
        --LOG('Number of units are '..RNGGETN(units))
        local platoonList = aiBrain:GetPlatoonsList()
        for k, platoon in platoonList do
            if platoon:GetPlan() == destinationPlan and platoon.Location == location then
                --LOG('Setting mergedPlatoon to platoon')
                mergedPlatoon = platoon
                break
            end
        end
        if not mergedPlatoon then
            --LOG('Platoon Merge is creating platoon for '..destinationPlan..' at location '..repr(aiBrain.BuilderManagers[location].Position))
            mergedPlatoon = aiBrain:MakePlatoon(destinationPlan..'Platoon'..location, destinationPlan)
            mergedPlatoon.PlanName = destinationPlan
            mergedPlatoon.BuilderName = destinationPlan..'Platoon'..location
            mergedPlatoon.Location = location
            mergedPlatoon.CenterPosition = aiBrain.BuilderManagers[location].Position
        end
        --LOG('Platoon Merge is assigning units to platoon')
        aiBrain:AssignUnitsToPlatoon(mergedPlatoon, units, 'attack', 'none')
        self:PlatoonDisbandNoAssign()
    end,

    TMLAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits
        local enemyShield = 0
        local targetHealth
        local targetPosition = {}
        local atkPri = {
            categories.MASSEXTRACTION * categories.STRUCTURE * ( categories.TECH2 + categories.TECH3 ),
            categories.COMMAND,
            categories.STRUCTURE * categories.ENERGYPRODUCTION * ( categories.TECH2 + categories.TECH3 ),
            categories.MOBILE * categories.LAND * categories.EXPERIMENTAL,
            categories.STRUCTURE * categories.DEFENSE * ( categories.TECH2 + categories.TECH3 ),
            categories.MOBILE * categories.NAVAL * ( categories.TECH2 + categories.TECH3 ),
            categories.STRUCTURE * categories.FACTORY * ( categories.TECH2 + categories.TECH3 ),
            categories.STRUCTURE * categories.RADAR * (categories.TECH2 + categories.TECH3)
        }
        --LOG('Starting TML function')
        --LOG('TML Center Point'..repr(self.CenterPosition))
        while PlatoonExists(aiBrain, self) do
            platoonUnits = GetPlatoonUnits(self)
            local readyTmlLaunchers
            local readyTmlLauncherCount = 0
            local inRangeTmlLaunchers = {}
            local target = false
            WaitTicks(50)
            --LOG('Checking Through TML Platoon units and set automode')
            for k, tml in platoonUnits do
                -- Disband if dead launchers. Will reform platoon on next PFM cycle
                if not tml or tml.Dead or tml:BeenDestroyed() then
                    self:PlatoonDisbandNoAssign()
                    return
                end
                tml:SetAutoMode(true)
                IssueClearCommands({tml})
            end
            --LOG('Checking for target')
            while not target do
                local missileCount = 0
                local totalMissileCount = 0
                local enemyTmdCount = 0
                local enemyShieldHealth = 0
                local ecoCaution = false 
                readyTmlLaunchers = {}
                WaitTicks(50)
                platoonUnits = GetPlatoonUnits(self)
                --LOG('Target Find cycle start')
                --LOG('Number of units in platoon '..RNGGETN(platoonUnits))
                if aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 1.1 and GetEconomyStored(aiBrain, 'MASS') < 500 then
                    ecoCaution = true
                else
                    ecoCaution = false
                end
                for k, tml in platoonUnits do
                    if not tml or tml.Dead or tml:BeenDestroyed() then
                        self:PlatoonDisbandNoAssign()
                        return
                    else
                        missileCount = tml:GetTacticalSiloAmmoCount()
                        if missileCount > 0 then
                            totalMissileCount = totalMissileCount + missileCount
                            RNGINSERT(readyTmlLaunchers, tml)
                        end
                    end
                    if missileCount > 1 and ecoCaution then
                        tml:SetAutoMode(false)
                    else
                        tml:SetAutoMode(true)
                    end
                end
                readyTmlLauncherCount = RNGGETN(readyTmlLaunchers)
                --LOG('Ready TML Launchers is '..readyTmlLauncherCount)
                if readyTmlLauncherCount < 1 then
                    WaitTicks(50)
                    continue
                end
                -- TML range is 256, try 230 to account for TML placement around CenterPosition
                local targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS, self.CenterPosition, 235, 'Enemy')
                for _, v in atkPri do
                    for num, unit in targetUnits do
                        if not unit.Dead and EntityCategoryContains(v, unit) and self:CanAttackTarget('attack', unit) then
                            -- 6000 damage for TML
                            if EntityCategoryContains(categories.COMMAND, unit) then
                                local armorHealth = unit:GetHealth()
                                local shieldHealth
                                if unit.MyShield then
                                    shieldHealth = unit.MyShield:GetHealth()
                                else
                                    shieldHealth = 0
                                end
                                targetHealth = armorHealth + shieldHealth
                            else
                                targetHealth = unit:GetHealth()
                            end
                            
                            --LOG('Target Health is '..targetHealth)
                            local missilesRequired = math.ceil(targetHealth / 6000)
                            local shieldMissilesRequired = 0
                            --LOG('Missiles Required = '..missilesRequired)
                            --LOG('Total Missiles '..totalMissileCount)
                            if (totalMissileCount >= missilesRequired and not EntityCategoryContains(categories.COMMAND, unit)) or (readyTmlLauncherCount >= missilesRequired) then
                                target = unit
                                targetPosition = target:GetPosition()
                                --enemyTMD = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH2, targetPosition, 25, 'Enemy')
                                enemyTmdCount = AIAttackUtils.AIFindNumberOfUnitsBetweenPointsRNG( aiBrain, self.CenterPosition, targetPosition, categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH2, 30, 'Enemy')
                                enemyShield = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE * categories.DEFENSE * categories.SHIELD, targetPosition, 25, 'Enemy')
                                if RNGGETN(enemyShield) > 0 then
                                    local enemyShieldHealth = 0
                                    --LOG('There are '..RNGGETN(enemyShield)..'shields')
                                    for k, shield in enemyShield do
                                        if not shield or shield.Dead or not shield.MyShield then continue end
                                        enemyShieldHealth = enemyShieldHealth + shield.MyShield:GetHealth()
                                    end
                                    shieldMissilesRequired = math.ceil(enemyShieldHealth / 6000)
                                end

                                --LOG('Enemy Unit has '..enemyTmdCount.. 'TMD along path')
                                --LOG('Enemy Unit has '..RNGGETN(enemyShield).. 'Shields around it with a total health of '..enemyShieldHealth)
                                --LOG('Missiles Required for Shield Penetration '..shieldMissilesRequired)

                                if enemyTmdCount >= readyTmlLauncherCount then
                                    --LOG('Target is too protected')
                                    --Set flag for more TML or ping attack position with air/land
                                    target = false
                                    continue
                                else
                                    --LOG('Target does not have enough defense')
                                    for k, tml in readyTmlLaunchers do
                                        local missileCount = tml:GetTacticalSiloAmmoCount()
                                        --LOG('Missile Count in Launcher is '..missileCount)
                                        local tmlMaxRange = __blueprints[tml.UnitId].Weapon[1].MaxRadius
                                        --LOG('TML Max Range is '..tmlMaxRange)
                                        local tmlPosition = tml:GetPosition()
                                        if missileCount > 0 and VDist2Sq(tmlPosition[1], tmlPosition[3], targetPosition[1], targetPosition[3]) < tmlMaxRange * tmlMaxRange then
                                            if (missileCount >= missilesRequired) and (enemyTmdCount < 1) and (shieldMissilesRequired < 1) and missilesRequired == 1 then
                                                --LOG('Only 1 missile required')
                                                RNGINSERT(inRangeTmlLaunchers, tml)
                                                break
                                            else
                                                RNGINSERT(inRangeTmlLaunchers, tml)
                                                local readyTML = RNGGETN(inRangeTmlLaunchers)
                                                if (readyTML >= missilesRequired) and (readyTML > enemyTmdCount + shieldMissilesRequired) then
                                                    --LOG('inRangeTmlLaunchers table number is enough for kill')
                                                    break
                                                end
                                            end
                                        end
                                    end
                                    --LOG('Have Target and number of in range ready launchers is '..RNGGETN(inRangeTmlLaunchers))
                                    break
                                end
                            else
                                --LOG('Not Enough Missiles Available')
                                target = false
                                continue
                            end
                            WaitTicks(1)
                        end
                    end
                    if target then
                        --LOG('We have target and can fire, breaking loop')
                        break
                    end
                end
            end
            if RNGGETN(inRangeTmlLaunchers) > 0 then
                --LOG('Launching Tactical Missile')
                if EntityCategoryContains(categories.MOBILE, target) then
                    local firePos = RUtils.LeadTargetRNG(self.CenterPosition, target, 15, 256)
                    if firePos then
                        IssueTactical(inRangeTmlLaunchers, firePos)
                    else
                        --LOG('LeadTarget Returned False')
                    end
                else
                    IssueTactical(inRangeTmlLaunchers, target)
                end

            end
            WaitTicks(30)
            if not PlatoonExists(aiBrain, self) then
                return
            end
        end
    end,

    ExperimentalAIHubRNG = function(self)

        local behaviors = import('/lua/ai/AIBehaviors.lua')

        local experimental = GetPlatoonUnits(self)[1]
        if not experimental then
            return
        end
        local ID = experimental.UnitId
        --LOG('Starting experimental behaviour...' .. ID)
        if ID == 'uel0401' then
            --LOG('FATBOY Behavior')
            return behaviors.FatBoyBehaviorRNG(self)
        elseif ID == 'uaa0310' then
            --LOG('CZAR Behavior')
            return behaviors.CzarBehaviorRNG(self)
        elseif ID == 'xsa0402' then
            --LOG('Exp Bomber Behavior')
            return behaviors.AhwassaBehaviorRNG(self)
        elseif ID == 'ura0401' then
            --LOG('Exp Gunship Behavior')
            return behaviors.TickBehavior(self)
        elseif ID == 'url0401' then
            return behaviors.ScathisBehaviorSorian(self)
        end
        --LOG('Standard Behemoth')
        return behaviors.BehemothBehaviorRNG(self, ID)
    end,

    SatelliteAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local data = self.PlatoonData
        local atkPri = {}
        local atkPriTable = {}
        if data.PrioritizedCategories then
            for k,v in data.PrioritizedCategories do
                RNGINSERT(atkPri, v)
                RNGINSERT(atkPriTable, v)
            end
        end
        RNGINSERT(atkPri, categories.ALLUNITS)
        RNGINSERT(atkPriTable, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Attack', atkPriTable)

        local maxRadius = data.SearchRadius or 50
        local oldTarget = false
        local target = false
       --('Novax AI starting')
        
        while PlatoonExists(aiBrain, self) do
            self:MergeWithNearbyPlatoonsSorian('SatelliteAIRNG', 50, true)
            target = AIUtils.AIFindUndefendedBrainTargetInRangeRNG(aiBrain, self, 'Attack', maxRadius, atkPri)
            local targetRotation = 0
            if target and target != oldTarget and not target.Dead then
                -- Pondering over if getting the target position would be useful for calling in air strike on target if shielded.
                --local targetpos = target:GetPosition()
                local originalHealth = target:GetHealth()
                self:Stop()
                self:AttackTarget(target)
                while (target and not target.Dead) or targetRotation < 6 do
                    --LOG('Novax Target Rotation is '..targetRotation)
                    targetRotation = targetRotation + 1
                    WaitTicks(100)
                    if target.Dead then
                        break
                    end
                end
                if target and not target.Dead then
                    local currentHealth = target:GetHealth()
                    --LOG('Target is not dead at end of loop with health '..currentHealth)
                    if currentHealth == originalHealth then
                        --LOG('Enemy Unit Health no change, setting to old target')
                        oldTarget = target
                    end
                end
            end
            WaitTicks(100)
            self:Stop()
            --LOG('End of Satellite loop')
        end
    end,

    TransferAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local moveToLocation = false
        if self.PlatoonData.MoveToLocationType == 'ActiveExpansion' then
            moveToLocation = aiBrain.BrainIntel.ActiveExpansion
        else
            moveToLocation = self.PlatoonData.MoveToLocationType
        end
        --LOG('* AI-RNG: * TransferAIRNG: Location ('..moveToLocation..')')
        if not aiBrain.BuilderManagers[moveToLocation] then
            --LOG('* AI-RNG: * TransferAIRNG: Location ('..moveToLocation..') has no BuilderManager!')
            self:PlatoonDisband()
            return
        end
        local eng = GetPlatoonUnits(self)[1]
        if eng and not eng.Dead and eng.BuilderManagerData.EngineerManager then
            --LOG('* AI-RNG: * TransferAIRNG: Moving transfer-units to - ' .. moveToLocation)
            if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, aiBrain.BuilderManagers[moveToLocation].Position) then
                --LOG('* AI-RNG: * TransferAIRNG: '..repr(self.BuilderName))
                eng.BuilderManagerData.EngineerManager:RemoveUnit(eng)
                --LOG('* AI-RNG: * TransferAIRNG: AddUnit units to - BuilderManagers: '..moveToLocation..' - ' .. aiBrain.BuilderManagers[moveToLocation].EngineerManager:GetNumCategoryUnits('Engineers', categories.ALLUNITS) )
                aiBrain.BuilderManagers[moveToLocation].EngineerManager:AddUnit(eng, true)
                -- Move the unit to the desired base after transfering BuilderManagers to the new LocationType
            end
        end
        if PlatoonExists(aiBrain, self) then
            self:PlatoonDisband()
        end
    end,

    NUKEAIRNG = function(self)
        --LOG('NukeAIRNG starting')
        local aiBrain = self:GetBrain()
        local missileCount
        local unit
        local readySmlLaunchers
        local readySmlLauncherCount
        WaitTicks(50)
        --LOG('NukeAIRNG initial wait complete')
        local platoonUnits = GetPlatoonUnits(self)
        for _, sml in platoonUnits do
            if not sml or sml.Dead or sml:BeenDestroyed() then
                self:PlatoonDisbandNoAssign()
                return
            end
            sml:SetAutoMode(true)
            IssueClearCommands({sml})
        end
        while PlatoonExists(aiBrain, self) do
            --LOG('NukeAIRNG main loop beginning')
            readySmlLaunchers = {}
            readySmlLauncherCount = 0
            WaitTicks(50)
            platoonUnits = GetPlatoonUnits(self)
            for _, sml in platoonUnits do
                if not sml or sml.Dead or sml:BeenDestroyed() then
                    self:PlatoonDisbandNoAssign()
                    return
                end
                sml:SetAutoMode(true)
                IssueClearCommands({sml})
                missileCount = sml:GetNukeSiloAmmoCount() or 0
                --LOG('NukeAIRNG : SML has '..missileCount..' missiles')
                if missileCount > 0 then
                    readySmlLauncherCount = readySmlLauncherCount + 1
                    RNGINSERT(readySmlLaunchers, sml)
                end
            end
            --LOG('NukeAIRNG : readySmlLauncherCount '..readySmlLauncherCount)
            if readySmlLauncherCount < 1 then
                WaitTicks(100)
                continue
            end
            local nukePos
            nukePos = import('/lua/ai/aibehaviors.lua').GetHighestThreatClusterLocationRNG(aiBrain, self)
            if nukePos then
                for _, launcher in readySmlLaunchers do
                    IssueNuke({launcher}, nukePos)
                    --LOG('NukeAIRNG : Launching Single Nuke')
                    WaitTicks(120)
                    IssueClearCommands({launcher})
                    break
                end
            else
                --LOG('NukeAIRNG : No available targets or nukePos is null')
            end
            WaitTicks(10)
        end
    end,

    ArtilleryAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local target = false
        --LOG('Initialize atkPri table')
        local atkPri = { categories.STRUCTURE * categories.STRATEGIC,
                         categories.STRUCTURE * categories.ENERGYPRODUCTION,
                         categories.COMMAND,
                         categories.STRUCTURE * categories.FACTORY,
                         categories.EXPERIMENTAL * categories.LAND,
                         categories.STRUCTURE * categories.SHIELD,
                         categories.STRUCTURE * categories.DEFENSE,
                         categories.ALLUNITS,
                        }
        local atkPriTable = {}
        --LOG('Adding Target Priorities')
        for k,v in atkPri do
            RNGINSERT(atkPriTable, v)
        end
        --LOG('Setting artillery priorities')
        self:SetPrioritizedTargetList('artillery', atkPriTable)

        -- Set priorities on the unit so if the target has died it will reprioritize before the platoon does
        local unit = false
        for k,v in self:GetPlatoonUnits() do
            if not v.Dead then
                unit = v
                break
            end
        end
        if not unit then
            return
        end
        --LOG('Set unit priorities')
        unit:SetTargetPriorities(atkPriTable)
        local weapon = ALLBPS[unit.UnitId].Weapon[1]
        local maxRadius = weapon.MaxRadius
        --LOG('Starting Platoon Loop')

        while aiBrain:PlatoonExists(self) do
            local targetRotation = 0
            if not target then
                target = aiBrain:CheckDirectorTargetAvailable(false, false)
            end
            if not target then
                --LOG('No Director Target, checking for normal target')
                target = self:FindPrioritizedUnit('artillery', 'Enemy', true, self:GetPlatoonPosition(), maxRadius)
            end
            if target and not target.Dead then
                self:Stop()
                self:AttackTarget(target)
                while (target and not target.Dead) do
                    --LOG('Arty Target Rotation is '..targetRotation)
                    targetRotation = targetRotation + 1
                    WaitTicks(200)
                    if target.Dead or (targetRotation > 6) then
                        --LOG('Target Dead ending loop')
                        break
                    end
                end
            end
            target = false
            WaitTicks(100)
        end
    end,

    EngineerAssistManagerRNG = function(self)

        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local platoonUnits
        local platoonCount = 0
        local locationType = self.PlatoonData.Location or 'MAIN'
        local engineerRadius = aiBrain.BuilderManagers[locationType].EngineerManager.Radius
        local managerPosition = aiBrain.BuilderManagers[locationType].Position
        local totalBuildRate = 0
        --LOG('engineerRadius '..engineerRadius)
        --LOG('managerPosition '..repr(managerPosition))
        local platoonMaximum = 0
        self.Active = false
        
        --[[
            Buildrates :
            T1 = 5
            T2 = 12.5
            T3 = 30
            SACU = 56
            SACU + eng = 98
        ]]
        --[[for _, eng in platoonUnits do
            if not eng or eng.Dead or eng:BeenDestroyed() then
                self:PlatoonDisbandNoAssign()
                return
            end
        end]]
        local ExtractorCostSpec = {
            TECH1 = ALLBPS['ueb1103'].Economy.BuildCostMass,
            TECH2 = ALLBPS['ueb1202'].Economy.BuildCostMass,
            TECH3 = ALLBPS['ueb1302'].Economy.BuildCostMass,
        }

        while aiBrain:PlatoonExists(self) do
            --LOG('aiBrain.EngineerAssistManagerEngineerCount '..aiBrain.EngineerAssistManagerEngineerCount)
            local platoonUnits = GetPlatoonUnits(self)
            local totalBuildRate = 0
            local platoonCount = RNGGETN(platoonUnits)

            --LOG('Start of loop platoon count '..platoonCount)
            
            for _, eng in platoonUnits do
                if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                    if aiBrain.EngineerAssistManagerBuildPower > aiBrain.EngineerAssistManagerBuildPowerRequired then
                        --LOG('Moving engineer back to armypool')
                        self:EngineerAssistRemoveRNG(aiBrain, eng)
                        platoonCount = platoonCount - 1
                    else
                        totalBuildRate = totalBuildRate + ALLBPS[eng.UnitId].Economy.BuildRate
                        --if eng:IsIdleState() then
                        --    eng:SetCustomName('In Assist Manager but idle')
                        --end
                    end
                end
            end
            aiBrain.EngineerAssistManagerBuildPower = totalBuildRate
            aiBrain.EngineerAssistManagerEngineerCount = platoonCount
            --LOG('EngineerAssistPlatoon total build rate is '..totalBuildRate)
            --LOG('aiBrain.EngineerAssistManagerEngineerCount '..aiBrain.EngineerAssistManagerEngineerCount)
            --LOG('aiBrain.EngineerAssistManagerBuildPower '..aiBrain.EngineerAssistManagerBuildPower)
            --LOG('aiBrain.EngineerAssistManagerBuildPowerRequired '..aiBrain.EngineerAssistManagerBuildPowerRequired)

            --[[local unitTypeAssist = {}
            local priorityNum = 0
            for k, v in aiBrain.EngineerAssistManagerPriorityTable do
                local priorityUnitAlreadyAssist = false
                for l, b in unitTypeAssist do
                    if k == b then
                        priorityUnitAlreadyAssist = true
                    end
                end
                if priorityUnitAlreadyAssist then
                    --LOG('priorityUnit already in unitTypePaused, skipping')
                    continue
                end
                if v > priorityNum then
                    priorityNum = v
                    priorityUnit = k
                end
            end]]
            local priorityUnit = 'MASSEXTRACTION'
            
            if priorityUnit == 'MASSEXTRACTION' then
                local unitsUpgrading = GetUnitsAroundPoint(aiBrain, categories.MASSEXTRACTION, managerPosition, engineerRadius, 'Ally')
                local low = false
                local bestUnit = false
                if unitsUpgrading then
                    local numBuilding = 0
                    for _, unit in unitsUpgrading do
                        if not unit.Dead and not unit:BeenDestroyed() and unit:IsUnitState('Upgrading') and unit:GetAIBrain():GetArmyIndex() == armyIndex then
                            --LOG('Upgrading Extractor Found')
                            numBuilding = numBuilding + 1
                            local unitPos = unit:GetPosition()
                            local NumAssist = RNGGETN(unit:GetGuards())
                            local dist = VDist2(managerPosition[1], managerPosition[3], unitPos[1], unitPos[3])
                            if (not low or dist < low) and NumAssist < 20 and dist < engineerRadius then
                                low = dist
                                bestUnit = unit
                                --LOG('EngineerAssistManager has best unit')
                            end
                        end
                    end
                    if bestUnit then
                        --LOG('Best unit is true looking through platoon units')
                        --LOG('Number of platoon units is '..RNGGETN(platoonUnits))
                        for _, eng in platoonUnits do
                            if eng and (not eng.Dead) and (not eng:BeenDestroyed()) then
                                if not eng.UnitBeingAssist then
                                    eng.UnitBeingAssist = bestUnit
                                    --LOG('Engineer Assist issuing guard')
                                    IssueGuard({eng}, eng.UnitBeingAssist)
                                    --eng:SetCustomName('Ive been ordered to guard')
                                    WaitTicks(1)
                                    --LOG('For assist wait thread for engineer')
                                    self:ForkThread(self.EngineerAssistThreadRNG, aiBrain, eng, bestUnit)
                                end
                            end
                        end
                    else
                        --LOG('No best unit found')
                    end
                end
            end
            WaitTicks(50)
            if aiBrain.EngineerAssistManagerBuildPower <= 0 then
                --LOG('No Engineers in platoon, disbanding')
                WaitTicks(5)
                self:PlatoonDisband()
                return
            end
        end
    end,

    EngineerAssistThreadRNG = function(self, aiBrain, eng, unitToAssist)
        WaitTicks(math.random(1, 20))
        while eng and not eng.Dead and aiBrain:PlatoonExists(self) and not eng:IsIdleState() and eng.UnitBeingAssist do
            --eng:SetCustomName('I am assisting')
            WaitTicks(1)
            if not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                --eng:SetCustomName('assist function break due to no UnitBeingAssist')
                eng.UnitBeingAssist = nil
                break
            end
            if aiBrain.EngineerAssistManagerBuildPower > aiBrain.EngineerAssistManagerBuildPowerRequired then
                --eng:SetCustomName('Got asked to remove myself due to build power')
                self:EngineerAssistRemoveRNG(aiBrain, eng)
            end
            if not aiBrain.EngineerAssistManagerActive then
                --eng:SetCustomName('Got asked to remove myself due to assist manager being false')
                self:EngineerAssistRemoveRNG(aiBrain, eng)
            end
            --LOG('I am assisting with aiBrain.EngineerAssistManagerBuildPower > aiBrain.EngineerAssistManagerBuildPowerRequired being true :'..aiBrain.EngineerAssistManagerBuildPower..' > ' ..aiBrain.EngineerAssistManagerBuildPowerRequired)
            WaitTicks(50)
        end
        eng.UnitBeingAssist = nil
    end,

    EngineerAssistRemoveRNG = function(self, aiBrain, eng)
        -- Removes an engineer from a platoon without disbanding it.
        if not eng.Dead then
            --eng:SetCustomName('I am being removed')
            eng.PlatoonHandle = nil
            eng.AssistSet = nil
            eng.AssistPlatoon = nil
            eng.UnitBeingBuilt = nil
            eng.ReclaimInProgress = nil
            eng.CaptureInProgress = nil
            eng.UnitBeingAssist = nil
            if eng:IsPaused() then
                eng:SetPaused( false )
            end
            aiBrain.EngineerAssistManagerBuildPower = aiBrain.EngineerAssistManagerBuildPower - ALLBPS[eng.UnitId].Economy.BuildRate
            if eng.BuilderManagerData.EngineerManager then
                --eng:SetCustomName('Running TaskFinished')
                eng.BuilderManagerData.EngineerManager:TaskFinished(eng)
            else
                --eng:SetCustomName('I was being removed but I had no engineer manager')
            end
            --eng:SetCustomName('Issuing stop command after TaskFinished')
            IssueStop({eng})
            IssueClearCommands({eng})
            --eng:SetCustomName('I was being removed and I performed my stop commands')
            --eng:SetCustomName('about to be reassigned to pool')
            aiBrain:AssignUnitsToPlatoon('ArmyPool', {eng}, 'Unassigned', 'NoFormation')
            --eng:SetCustomName('have been reassigned, about to wait')
            WaitTicks(3)
            --eng:SetCustomName('finished waiting')
            --LOG('Removed Engineer From Assist Platoon. We now have '..RNGGETN(GetPlatoonUnits(self)))
        end
    end,

    ReclaimStructuresRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local data = self.PlatoonData
        local radius = aiBrain:PBMGetLocationRadius(data.Location)
        local counter = 0
        local reclaimcat
        local reclaimables
        local unitPos
        local reclaimunit
        local distance
        local allIdle
        local reclaimCount = 0
        local reclaimMax = data.ReclaimMax or 1
        while aiBrain:PlatoonExists(self) do
            if reclaimCount >= reclaimMax then
                self:PlatoonDisband()
                return
            end
            unitPos = self:GetPlatoonPosition()
            reclaimunit = false
            distance = false
            for num,cat in data.Reclaim do
                reclaimables = aiBrain:GetListOfUnits(cat, false)
                for k,v in reclaimables do
                    local vPos = v:GetPosition()
                    if not v.Dead and (not reclaimunit or VDist3Sq(unitPos, vPos) < distance) and unitPos and not v:IsUnitState('Upgrading') and VDist3Sq(aiBrain.BuilderManagers[data.Location].FactoryManager.Location, vPos) < (radius * radius) then
                        reclaimunit = v
                        distance = VDist3Sq(unitPos, vPos)
                    end
                end
                if reclaimunit then break end
            end
            if reclaimunit and not reclaimunit.Dead then
                counter = 0
                -- Set ReclaimInProgress to prevent repairing (see RepairAI)
                reclaimunit.ReclaimInProgress = true
                reclaimCount = reclaimCount + 1
                IssueReclaim(self:GetPlatoonUnits(), reclaimunit)
                repeat
                    WaitTicks(30)
                    if not aiBrain:PlatoonExists(self) then
                        return
                    end
                    if reclaimunit and not reclaimunit.ReclaimInProgress then
                        reclaimunit.ReclaimInProgress = true
                    end
                    allIdle = true
                    for k,v in self:GetPlatoonUnits() do
                        if not v.Dead and not v:IsIdleState() then
                            allIdle = false
                            break
                        end
                    end
                until allIdle
            elseif not reclaimunit or counter >= 5 then
                self:PlatoonDisband()
                return
            else
                counter = counter + 1
                WaitSeconds(5)
            end
        end
    end,

    MexBuildAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local platoonUnits = GetPlatoonUnits(self)
        local cons = self.PlatoonData.Construction
        local buildingTmpl, buildingTmplFile, baseTmpl, baseTmplFile, baseTmplDefault
        local eng=platoonUnits[1]
        local VDist2Sq = VDist2Sq
        self:Stop()
        if not eng or eng.Dead then
            WaitTicks(1)
            self:PlatoonDisband()
            return
        end
        if not eng.EngineerBuildQueue then
            eng.EngineerBuildQueue={}
        end
        local factionIndex = aiBrain:GetFactionIndex()
        buildingTmplFile = import(cons.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
        buildingTmpl = buildingTmplFile[(cons.BuildingTemplate or 'BuildingTemplates')][factionIndex]

        --LOG("*AI DEBUG: Setting up Callbacks for " .. eng.Sync.id)
        --self.SetupEngineerCallbacksRNG(eng)
        local whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
        -- wait in case we're still on a base
        if not eng.Dead then
            local count = 0
            while eng:IsUnitState('Attached') and count < 2 do
                WaitTicks(60)
                count = count + 1
            end
        end
        --eng:SetCustomName('MexBuild Platoon Checking for expansion mex')
        --LOG('MexBuild Platoon Checking for expansion mex')
        while not aiBrain.expansionMex do WaitSeconds(2) end
        --eng:SetCustomName('MexBuild Platoon has found aiBrain.expansionMex')
        local markerTable=table.copy(aiBrain.expansionMex)
        if eng.Dead then self:PlatoonDisband() end
        while PlatoonExists(aiBrain, self) and eng and not eng.Dead do
            local platoonPos=self:GetPlatoonPosition()
            table.sort(markerTable,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],platoonPos[1],platoonPos[3])/VDist3Sq(aiBrain.emanager.enemy.Position,a.Position)/a.priority/a.priority<VDist2Sq(b.Position[1],b.Position[3],platoonPos[1],platoonPos[3])/VDist3Sq(aiBrain.emanager.enemy.Position,b.Position)/b.priority/b.priority end)
            local currentmexpos=nil
            local curindex=nil
            for i,v in markerTable do
                if aiBrain:CanBuildStructureAt('ueb1103', v.Position) then
                    currentmexpos=v.Position
                    curindex=i
                    --LOG('We can build at mex, breaking loop '..repr(currentmexpos))
                    break
                end
            end
            if not currentmexpos then self:PlatoonDisband() end
            --LOG('currentmexpos has data')
            if not AIUtils.EngineerMoveWithSafePathCHP(aiBrain, eng, currentmexpos, whatToBuild) then
                table.remove(markerTable,curindex) 
                --LOG('No path to currentmexpos')
                --eng:SetCustomName('MexBuild Platoon has no path to aiBrain.currentmexpos, removing and moving to next')
                continue 
            end
            local firstmex=currentmexpos
            local initialized=nil
            --LOG('Firstmex '..repr(firstmex))
            for _=0,3,1 do
                if not currentmexpos then break end
                local bool,markers=MABC.CanBuildOnMassEng2(aiBrain, currentmexpos, 30)
                if bool then
                    --LOG('We can build on a mass marker within 30')
                    --local massMarker = RUtils.GetClosestMassMarkerToPos(aiBrain, waypointPath)
                    --LOG('Mass Marker'..repr(markers))
                    --LOG('Attempting second mass marker')
                    for _,massMarker in markers do
                    RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, massMarker.Position, 5)
                    AIUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, massMarker.Position)
                    --eng:SetCustomName('MexBuild Platoon attempting to build in for loop')
                    --LOG('MexBuild Platoon Checking for expansion mex')
                    aiBrain:BuildStructure(eng, whatToBuild, {massMarker.Position[1], massMarker.Position[3], 0}, false)
                    local newEntry = {whatToBuild, {massMarker.Position[1], massMarker.Position[3], 0}, false,Position=massMarker.Position}
                    RNGINSERT(eng.EngineerBuildQueue, newEntry)
                    currentmexpos=massMarker.Position
                    end
                else
                    --LOG('No markers reported')
                    break
                end
            end
            while not eng.Dead and 0<RNGGETN(eng:GetCommandQueue()) or eng:IsUnitState('Building') or eng:IsUnitState("Moving") do
                if eng:IsUnitState("Moving") and not initialized and VDist3Sq(self:GetPlatoonPosition(),firstmex)<12*12 then
                    IssueClearCommands({eng})
                    for _,v in eng.EngineerBuildQueue do
                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, v.Position, 5)
                        AIUtils.EngineerTryRepair(aiBrain, eng, v[1], v.Position)
                        --eng:SetCustomName('MexBuild Platoon attempting to build in while loop')
                        --LOG('MexBuild Platoon Checking for expansion mex')
                        aiBrain:BuildStructure(eng, v[1],v[2],v[3])
                    end
                    initialized=true
                end
                WaitTicks(20)
            end
            --eng:SetCustomName('Reset EngineerBuildQueue')
            --LOG('Reset EngineerBuildQueue')
            eng.EngineerBuildQueue={}
            IssueClearCommands({eng})
            WaitTicks(20)
        end
    end,

    TruePlatoonRNG = function(self)
        local VDist2Sq = VDist2Sq
        local function GetWeightedHealthRatio(unit)--health % including shields
            if unit.MyShield then
                return (unit.MyShield:GetHealth()+unit:GetHealth())/(unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
            else
                return unit:GetHealthPercent()
            end
        end
        local function GetTrueHealth(unit,total)--health+shieldhealth
            if total then
                if unit.MyShield then
                    return (unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
                else
                    return unit:GetMaxHealth()
                end
            else
                if unit.MyShield then
                    return (unit.MyShield:GetHealth()+unit:GetHealth())
                else
                    return unit:GetHealth()
                end
            end
        end
        local function crossp(vec1,vec2,n)--cross product
            local z = vec2[3] + n * (vec2[1] - vec1[1])
            local y = vec2[2] - n * (vec2[2] - vec1[2])
            local x = vec2[1] - n * (vec2[3] - vec1[3])
            return {x,y,z}
        end
        local function midpoint(vec1,vec2,ratio)--midpoint,sort of- put 0.5 for halfway, higher or lower to get closer or further from the destination
            local vec3={}
            for z,v in vec1 do
                if type(v)=='number' then 
                    vec3[z]=vec2[z]*(ratio)+v*(1-ratio)
                end
            end
            return vec3
        end
        local function spreadmove(unitgroup,location)--spreadmove! almost formation move, but not!
            local num=RNGGETN(unitgroup)
            local sum={0,0,0}
            for i,v in unitgroup do
                if not v or v.Dead then
                    continue
                end
                local pos = v:GetPosition()
                for k,v in sum do
                    sum[k]=sum[k] + pos[k]/num
                end
            end
            num=math.min(num,30)
            local dist=VDist3(sum,location)
            local loc1=crossp(sum,location,-num/dist)
            local loc2=crossp(sum,location,num/dist)
            for i,v in unitgroup do
                IssueMove({v},midpoint(v:GetPosition(),midpoint(loc1,loc2,i/num)),(dist-math.random(3))/dist)
            end
        end
        local function UnitInitialize(self)--do the unit initialization stuff!
            local platoon=self
            local platoonUnits=self:GetPlatoonUnits()
            local platoonthreat=0
            local platoonhealth=0
            local platoonhealthtotal=0
            local categoryList = {   
                categories.EXPERIMENTAL * categories.LAND,
                categories.ENGINEER,
                categories.MASSEXTRACTION,
                categories.MOBILE * categories.LAND,
                categories.ENERGYPRODUCTION,
                categories.ENERGYSTORAGE,
                categories.STRUCTURE * categories.DEFENSE,
                categories.STRUCTURE,
                categories.ALLUNITS,
            }
            self:SetPrioritizedTargetList('Attack', categoryList)
            for _,v in platoonUnits do
                if not v.Dead then
                    if EntityCategoryContains(categories.SCOUT, v) then
                        self.ScoutPresent = true
                    end
                    platoonhealth=platoonhealth+GetTrueHealth(v)
                    platoonhealthtotal=platoonhealthtotal+GetTrueHealth(v,true)
                    local mult=1
                    if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                        mult=0.3
                    end
                    local bp = __blueprints[v.UnitId].Defense
                    --LOG(repr(__blueprints[v.UnitId].Defense))
                    if bp.SurfaceThreatLevel ~= nil then
                        platoonthreat = platoonthreat + bp.SurfaceThreatLevel*GetWeightedHealthRatio(v)*mult
                    end
                    if (v.Sync.Regen>0) or not v.chpinitialized then
                        v.chpinitialized=true
                        if EntityCategoryContains(categories.ARTILLERY * categories.TECH3,v) then
                            v.Role='Artillery'
                        elseif EntityCategoryContains(categories.EXPERIMENTAL,v) then
                            v.Role='Experimental'
                        elseif EntityCategoryContains(categories.SILO,v) then
                            v.Role='Silo'
                        elseif EntityCategoryContains(categories.xsl0202 + categories.xel0305 + categories.xrl0305,v) then
                            v.Role='Heavy'
                        elseif EntityCategoryContains((categories.SNIPER + categories.INDIRECTFIRE) * categories.LAND + categories.ual0201 + categories.drl0204 + categories.del0204,v) then
                            v.Role='Sniper'
                            if EntityCategoryContains(categories.ual0201,v) then
                                v.GlassCannon=true
                            end
                        elseif EntityCategoryContains(categories.SCOUT,v) then
                            v.Role='Scout'
                        elseif EntityCategoryContains(categories.ANTIAIR,v) then
                            v.Role='AA'
                        elseif EntityCategoryContains(categories.DIRECTFIRE,v) then
                            v.Role='Bruiser'
                        elseif EntityCategoryContains(categories.SHIELD,v) then
                            v.Role='Shield'
                        end
                        for _, weapon in ALLBPS[v.UnitId].Weapon or {} do
                            if not (weapon.RangeCategory == 'UWRC_DirectFire') then continue end
                            if not v.MaxWeaponRange or v.MaxRadius > v.MaxWeaponRange then
                                v.MaxWeaponRange = weapon.MaxRadius * 0.9
                                if weapon.BallisticArc == 'RULEUBA_LowArc' then
                                    v.WeaponArc = 'low'
                                elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                                    v.WeaponArc = 'high'
                                else
                                    v.WeaponArc = 'none'
                                end
                            end
                        end
                        if v:TestToggleCaps('RULEUTC_StealthToggle') then
                            v:SetScriptBit('RULEUTC_StealthToggle', false)
                        end
                        if v:TestToggleCaps('RULEUTC_CloakToggle') then
                            v:SetScriptBit('RULEUTC_CloakToggle', false)
                        end
                        v:RemoveCommandCap('RULEUCC_Reclaim')
                        v:RemoveCommandCap('RULEUCC_Repair')
                        if not v.MaxWeaponRange then
                            --WARN('Scanning: unit ['..repr(v.UnitId)..'] has no MaxWeaponRange - '..repr(self.BuilderName))
                            continue
                        end
                        if not platoon.MaxWeaponRange or v.MaxWeaponRange>platoon.MaxWeaponRange then
                            platoon.MaxWeaponRange=v.MaxWeaponRange
                        end
                    end
                end
            end
            if not self.MaxWeaponRange then 
                self.MaxWeaponRange=30
            end
            for _,v in platoonUnits do
                if not v.MaxWeaponRange then
                    v.MaxWeaponRange=self.MaxWeaponRange
                end
            end
            self.Pos=self:GetPlatoonPosition()
            self.Threat=platoonthreat
            self.health=platoonhealth
            self.mhealth=platoonhealthtotal
            self.rhealth=platoonhealth/platoonhealthtotal
        end
        local function SimpleTarget(self,aiBrain,guardee)--find enemies in a range and attack them- lots of complicated stuff here
            local function ViableTargetCheck(unit)
                if unit.Dead or not unit then return false end
                if self.MovementLayer=='Amphibious' then
                    if AIAttackUtils.CanGraphToRNG(self.Pos,unit:GetPosition(),self.MovementLayer) then
                        return true
                    end
                else
                    local targetpos=unit:GetPosition()
                    if GetTerrainHeight(targetpos[1],targetpos[3])<GetSurfaceHeight(targetpos[1],targetpos[3]) then
                        return false
                    else
                        if AIAttackUtils.CanGraphToRNG(self.Pos,targetpos,self.MovementLayer) then
                            return true
                        end
                    end
                end
            end
            local platoon=self
            local id=platoon.chpdata.id
            --LOG('chpdata.id '..repr(id))
            local position=platoon.Pos
            if guardee and not guardee.Dead then
                position=guardee:GetPosition()
            end
            platoon.target=nil
            if self.PlatoonData.Defensive and VDist2Sq(position[1], position[3], platoon.base[1], platoon.base[3]) < 14400 then
                --LOG('Defensive Posture Targets')
                platoon.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL, platoon.base, 120, 'Enemy')
            else
                platoon.targetcandidates=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE - categories.WALL, position, self.MaxWeaponRange+40, 'Enemy')
            end
            for i,unit in platoon.targetcandidates do
                if not ViableTargetCheck(unit) then table.remove(platoon.targetcandidates,i) continue end
                if not unit.chppriority then unit.chppriority={} unit.chpdistance={} end
                if not unit.dangerupdate or GetGameTimeSeconds()-unit.dangerupdate>10 then
                    unit.chpdanger=math.max(10,RUtils.GrabPosDangerRNG(aiBrain,unit:GetPosition(),30).enemy)
                    unit.dangerupdate=GetGameTimeSeconds()
                end
                if not unit.chpvalue then unit.chpvalue=ALLBPS[unit.UnitId].Economy.BuildCostMass/GetTrueHealth(unit) end
                unit.chpworth=unit.chpvalue/GetTrueHealth(unit)
                unit.chpdistance[id]=VDist3(position,unit:GetPosition())
                unit.chppriority[id]=unit.chpworth/math.max(30,unit.chpdistance[id])/unit.chpdanger
            end
            if RNGGETN(platoon.targetcandidates)<1 then 
                platoon.target=nil 
                return false
            else
                table.sort(platoon.targetcandidates, function(a,b) return a.chppriority[id]>b.chppriority[id] end)
                platoon.target=platoon.targetcandidates[1]
                return true
            end
        end
        local function SimpleEarlyPatrol(self,aiBrain)--basic raid function
            local mex=RUtils.AIGetMassMarkerLocations(aiBrain, false)
            local raidlocs={}
            local platoon=self
            for _,v in mex do
                if v.Position[1] <= 8 or v.Position[1] >= ScenarioInfo.size[1] - 8 or v.Position[3] <= 8 or v.Position[3] >= ScenarioInfo.size[2] - 8 then
                    -- mass marker is too close to border, skip it.
                    continue
                end
                if GetSurfaceHeight(v.Position[1],v.Position[3])>GetTerrainHeight(v.Position[1],v.Position[3]) then
                    continue
                end
                --LOG('self.pos '..repr(self.Pos))
                --LOG('v.Position '..repr(v.Position))
                if not v.Position then continue end
                if VDist2Sq(v.Position[1],v.Position[3],platoon.Pos[1],platoon.Pos[3])<150*150 then
                    continue
                end
                if not AIAttackUtils.CanGraphToRNG(self.Pos,v.Position,self.MovementLayer) then
                    continue
                end
                if RUtils.GrabPosEconRNG(aiBrain,v.Position,50).ally>0 then
                    continue
                end
                RNGINSERT(raidlocs,v)
            end
            table.sort(raidlocs,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],platoon.Pos[1],platoon.Pos[3])*VDist2Sq(k1.Position[1],k1.Position[3],platoon.home[1],platoon.home[3])/VDist2Sq(k1.Position[1],k1.Position[3],platoon.base[1],platoon.base[3])<VDist2Sq(k2.Position[1],k2.Position[3],platoon.Pos[1],platoon.Pos[3])*VDist2Sq(k2.Position[1],k2.Position[3],platoon.home[1],platoon.home[3])/VDist2Sq(k2.Position[1],k2.Position[3],platoon.base[1],platoon.base[3]) end)
            platoon.dest=raidlocs[1].Position
            --LOG('platoon.Pos '..repr(platoon.Pos))
            --LOG('platoon.dest '..repr(platoon.dest))
            if platoon.dest and platoon.Pos then
                platoon.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoon.Pos, platoon.dest, 0, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
            end
            if platoon.path then
                platoon.navigating=true
                return true
            else
                return false
            end
        end
        local function SimpleRetreat(self,aiBrain)--basic retreat function
            local threat=RUtils.GrabPosDangerRNG(aiBrain,self:GetPlatoonPosition(),self.MaxWeaponRange+25)
            --LOG('Simple Retreat Threat Stats '..repr(threat))
            if threat.ally*1.1<threat.enemy then
                self.retreat=true
                return true
            else
                self.retreat=false
                return false
            end
        end
        local function SimpleDoRetreat(self,aiBrain)--basic "choose path and then start retreating" function
            local location = false
            local RangeList = {
                [1] = 30,
                [1] = 64,
                [2] = 128,
                [2] = 192,
                [3] = 256,
            }
            for _, range in RangeList do
                local retreatUnits = GetUnitsAroundPoint(aiBrain, (categories.MASSEXTRACTION + categories.ENGINEER), self.Pos, range, 'Ally')
                if retreatUnits then
                    for _, unit in retreatUnits do
                        local unitPos = unit:GetPosition()
                        if AIAttackUtils.CanGraphToRNG(self.Pos,unitPos,self.MovementLayer) then
                            location = unitPos
                            --LOG('Retreat Position found for mex or engineer')
                            break
                        end
                    end
                end
                if location then
                    break
                end
            end
            if (not location) then
                location = self.home
                --LOG('No retreat location found, retreat to home')
            end
            if self.path and VDist3Sq(self.path[RNGGETN(self.path)],location)<400 then return end
            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, location, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
        end
        local function VariableKite(self,unit,target)--basic kiting function.. complicated as heck
            local function KiteDist(pos1,pos2,distance,healthmod)
                local vec={}
                local dist=VDist3(pos1,pos2)
                distance=distance*(1-healthmod)
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    vec[i]=k+distance/dist*(pos1[i]-k)
                end
                return vec
            end
            local function CheckRetreat(pos1,pos2,target)
                local vel={}
                vel[1],vel[2],vel[3]=target:GetVelocity()
                local dotp=0
                for i,k in pos2 do
                    if type(k)~='number' then continue end
                    dotp=dotp+(pos1[i]-k)*vel[i]
                end
                return dotp<0
            end
            local function GetRoleMod(unit)
                local healthmod=20
                if unit.Role=='Heavy' or unit.Role=='Bruiser' then
                    healthmod=50
                end
                local ratio=GetWeightedHealthRatio(unit)
                healthmod=healthmod*ratio*ratio
                return healthmod/100
            end
            local pos=unit:GetPosition()
            local tpos=target:GetPosition()
            local dest
            local mod=0
            local healthmod=GetRoleMod(unit)
            local strafemod=3
            if CheckRetreat(pos,tpos,target) then
                mod=5
            end
            if unit.Role=='Heavy' or unit.Role=='Bruiser' or unit.GlassCannon then
                strafemod=7
            end
            if unit.MaxWeaponRange then
                dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,3)-mod,healthmod)
                dest=crossp(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
            else
                dest=KiteDist(pos,tpos,self.MaxWeaponRange+5-math.random(1,3)-mod,healthmod)
                dest=crossp(pos,dest,strafemod/VDist3(pos,dest)*(1-2*math.random(0,1)))
            end
            if VDist3Sq(pos,dest)>6 then
                IssueClearCommands({unit})
                IssueMove({unit},dest)
                return
            else
                return
            end
        end
        local function SimpleCombat(self,aiBrain)--fight stuff nearby
            local units=self:GetPlatoonUnits()
            for k,unit in self.targetcandidates do
                if not unit or unit.Dead or not unit.chpworth then LOG('Unit with no chpworth is '..unit.UnitId) table.remove(self.targetcandidates,k) end
            end
            local target
            local closestTarget = 9999999
            for _,v in units do
                if v and not v.Dead then
                    local unitPos = v:GetPosition()
                    for l, m in self.targetcandidates do
                        if m and not m.Dead then
                            local tmpDistance = VDist3Sq(unitPos,m:GetPosition())*m.chpworth
                            if tmpDistance < closestTarget then
                                target = m
                                closestTarget = tmpDistance
                            end
                        end
                    end
                    if target then
                        if VDist3Sq(unitPos,target:GetPosition())>(v.MaxWeaponRange+20)*(v.MaxWeaponRange+20) then
                            IssueClearCommands({v}) 
                            IssueMove({v},target:GetPosition())
                            continue
                        end
                        VariableKite(self,v,target)
                    end
                end
            end
        end
        local function SimplePriority(self,aiBrain)--use the aibrain priority table to do things
            local VDist2Sq = VDist2Sq
            local RNGMAX = math.max
            if (not aiBrain.prioritypoints) or RNGGETN(aiBrain.prioritypoints)==0 then
                return false
            end
            local pointHighest = 0
            local point = false
            for _, v in aiBrain.prioritypoints do
                local tempPoint = v.priority/(RNGMAX(VDist2Sq(self.Pos[1],self.Pos[3],v.Position[1],v.Position[3]),30*30)+(v.danger or 0))
                if tempPoint > pointHighest then
                    pointHighest = tempPoint
                    point = v
                end
            end
            if point then
                --LOG('point pos '..repr(point.Position)..' with a priority of '..point.priority)
            else
                --LOG('No priority found')
                return false
            end
            if VDist2Sq(point.Position[1],point.Position[3],self.Pos[1],self.Pos[3])<(self.MaxWeaponRange+20)*(self.MaxWeaponRange+20) then return false end
            if not self.combat and not self.retreat then
                if point.type then
                    --LOG('switching to state '..point.type)
                end
                if point.type=='push' then
                    --SwitchState(platoon,'push')
                    self.dest=point.Position
                elseif point.type=='raid' then
                    if self.raid then
                        if self.path and VDist3Sq(self.path[RNGGETN(self.path)],point.Position)>400 then
                            self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
                            --LOG('platoon.path distance(should be greater than 400) between last path node and point.position is return true'..VDist3Sq(self.path[RNGGETN(self.path)],point.Position))
                            return true
                        end
                    end
                    self.rdest=point.Position
                    self.raidunit=point.unit
                    self.dest=point.Position
                    self.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, self.Pos, self.rdest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
                    self.navigating=true
                    self.raid=true
                    --SwitchState(self,'raid')
                    
                    for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
                        --LOG('expansionwatchtable position '..repr(v.Position)..' vs platoon dest '..repr(platoon.dest))
                        if self.dest == v.Position and (not aiBrain.BrainIntel.ExpansionWatchTable[k].PlatoonAssigned) then
                            --LOG('Set platoon at expansionwatchtable at position '..repr(self.dest))
                            aiBrain.BrainIntel.ExpansionWatchTable[k].PlatoonAssigned = self
                            break
                        end
                    end
                    --LOG('Simple Priority is moving to '..repr(self.dest))
                    return true
                elseif point.type=='garrison' then
                    --SwitchState(platoon,'garrison')
                    self.dest=point.Position
                elseif point.type=='guard' then
                    --SwitchState(platoon,'guard')
                    self.guard=point.unit
                elseif point.type=='acuhelp' then
                    --SwitchState(platoon,'acuhelp')
                    self.guard=point.unit
                end
            end
        end
        local function DistancePredict(target,time)--predict where a unit is going to be in x time
            local vel={}
            vel[1],vel[2],vel[3]=target:GetVelocity()
            local pos=target:GetPosition()
            local dest={}
            for k,v in vel do
                dest[k]=pos[k]+v*time
            end
            return dest
        end
        local function AggressivelyCircle(self,unit,location,radius)--circle around something
            local dist=VDist3(unit:GetPosition(),location)
            local dest=crossp(unit:GetPosition(),location,radius/dist)
            if AIAttackUtils.CanGraphToRNG(unit:GetPosition(),dest,self.MovementLayer) then
                IssueClearCommands({unit})
                IssueMove({unit},dest)
            else
                IssueClearCommands({unit})
                IssueMove({unit},location)
            end
        end
        local function SimpleGuard(self,aiBrain,unit)--supposed to help guard things- not sure if it works
            local platoon=self
            
            if SimpleTarget(self,aiBrain,unit) then
                SimpleCombat(self,aiBrain)
            elseif VDist3Sq(platoon.Pos,unit:GetPosition())>80*80 then
                platoon.dest=unit:GetPosition()
                platoon.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoon.Pos, platoon.dest, 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
                platoon.navigating=true
            else
                local pos=DistancePredict(unit,5)
                for _,v in self:GetPlatoonUnits() do
                    if v.Dead or not v then continue end
                    AggressivelyCircle(self,v,pos,20)
                end
            end
        end
        UnitInitialize(self)
        self:Stop()
        
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local target
        local targetmex
        local targetacu
        local targeteng
        local targetpd
        local platoonUnits = GetPlatoonUnits(self)
        local friendlyThreat=0
        local enemyThreat=0
        AIAttackUtils.GetMostRestrictiveLayer(self)
        self:ForkThread(self.HighlightTruePlatoon)
        self:ForkThread(self.OptimalTargetingRNG)
        self:ForkThread(self.PathNavigationRNG)
        self.chpdata = {name = 'CHPTruePlatoon',id=platoonUnits[1].Sync.id}
        local platoon=self
        local LocationType = self.PlatoonData.LocationType or 'MAIN'
        local homepos = aiBrain.BuilderManagers[LocationType].Position
        platoon.home=homepos
        platoon.base=homepos
        platoon.evaluationpoints = {}
        platoon.friendlyThreats = {}
        platoon.enemyThreats = {}
        platoon.threats = {}
        local pathTimeout = 0
        while PlatoonExists(aiBrain, self) do
            platoonUnits = GetPlatoonUnits(self)
            local platoonNum=RNGGETN(platoonUnits)
            if platoonNum < 20 then
                if self:CHPMergePlatoon(30) then
                    UnitInitialize(self)
                end
            end
            if platoon.navigating then 
                while platoon.navigating do 
                    if ScenarioInfo.Options.AIDebugDisplay == 'displayOn' then
                        DrawCircle(platoon:GetPlatoonPosition(),5,'FFbb00FF')
                    end
                    WaitTicks(2) 
                end 
            end
            local spread=0
            local snum=0
            platoon.clumpmode=false
            if platoon.clumpmode then--this is for clumping- it works well sometimes, bad other times. formation substitute. doesn't work that great recently- need to fix sometime
                for _,v in platoonUnits do
                    if not v or v.Dead then continue end
                    local unitPos = v:GetPosition()
                    if VDist3Sq(unitPos,platoon.Pos)>v.MaxWeaponRange/5*v.MaxWeaponRange/5+platoonNum*platoonNum then
                        IssueClearCommands({v})
                        IssueMove({v},RUtils.LerpyRotate(unitPos,platoon.Pos,{VDist3(unitPos,platoon.Pos),v.MaxWeaponRange/6}))
                        spread=spread+VDist3Sq(unitPos,platoon.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                        snum=snum+1
                    end
                end
                if spread>4 then--how much delay are we going to wait to fix?
                    WaitTicks(math.ceil(math.sqrt(spread/platoonNum+10)))
                end
            end
            --LOG('trueplatoon distance from base is '..VDist2Sq(platoon.Pos[1], platoon.Pos[3], platoon.base[1], platoon.base[3]))
            if SimpleRetreat(self,aiBrain) then--retreat if we feel like it
                SimpleDoRetreat(self,aiBrain)
            elseif VDist2Sq(platoon.Pos[1], platoon.Pos[3], platoon.base[1], platoon.base[3]) > 10000 and SimplePriority(self,aiBrain) then--do priority stuff next
                --LOG('SimplePriority being used')
            elseif SimpleTarget(self,aiBrain) then--do combat stuff
                --LOG('SimpleTarget being used')
                SimpleCombat(self,aiBrain)
                WaitTicks(10)
            elseif SimpleEarlyPatrol(self,aiBrain) then--do raid stuff
            else
                --LOG('Nothing to target, setting path timeout')
                pathTimeout = pathTimeout + 1
                --SimpleGuard(self,aiBrain)--guard stuff with nearest mex
            end
            if not PlatoonExists(aiBrain, self) then
                return
            end
            if pathTimeout > 10 then return self:SetAIPlanRNG('HuntAIPATHRNG') end
            WaitTicks(15)
        end
    end,
    PathNavigationRNG = function(self)
        local function ExitConditions(self,aiBrain)
            if not self.path then
                return true
            end
            if VDist3Sq(self.path[RNGGETN(self.path)],self.Pos)<20*20 then
                return true
            end
            if self.navigating then
                local enemies=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE, self.Pos, self.MaxWeaponRange+40, 'Enemy')
                if enemies and RNGGETN(enemies)>0 then
                    for _,enemy in enemies do
                        if enemy and not enemy.Dead and AIAttackUtils.CanGraphToRNG(self.Pos,enemy:GetPosition(),self.MovementLayer) then
                            local dist=VDist3Sq(enemy:GetPosition(),self.Pos)
                            if self.raid or self.guard then
                                if dist<1225 then
                                    --LOG('Exit Path Navigation for raid')
                                    return true
                                end
                            else
                                if dist<math.max(self.MaxWeaponRange*self.MaxWeaponRange*3,625) then
                                    --LOG('Exit Path Navigation')
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
        local function crossp(vec1,vec2,n)
            local z = vec2[3] + n * (vec2[1] - vec1[1])
            local y = vec2[2] - n * (vec2[2] - vec1[2])
            local x = vec2[1] - n * (vec2[3] - vec1[3])
            return {x,y,z}
        end
        local function midpoint(vec1,vec2,ratio)
            local vec3={}
            for z,v in vec1 do
                if type(v)=='number' then 
                    vec3[z]=vec2[z]*(ratio)+v*(1-ratio)
                end
            end
            return vec3
        end
        local function spreadmove(unitgroup,location)
            local num=RNGGETN(unitgroup)
            if num==0 then return end
            local sum={0,0,0}
            for i,v in unitgroup do
                if not v or v.Dead then
                    continue
                end
                local pos = v:GetPosition()
                for k,v in sum do
                    sum[k]=sum[k] + pos[k]/num
                end
            end
            local loc1=crossp(sum,location,-num/VDist3(sum,location))
            local loc2=crossp(sum,location,num/VDist3(sum,location))
            for i,v in unitgroup do
                IssueMove({v},midpoint(loc1,loc2,i/num))
            end
        end
        function GetAngleCCW(base, direction)
            local newbase={x=base[1],y=base[2],z=base[3]}
            local newdir={x=direction[1],y=direction[2],z=direction[3]}
            local bn = Utils.NormalizeVector(newbase)
            local dn = Utils.NormalizeVector(newdir)
        
            -- compute the orthogonal vector to determine if we need to take the inverse
            local ort = { bn[3], 0, -bn[1] }
        
            -- compute the radians, correct it accordingly
            local rads = math.acos(bn[1] * dn[1] + bn[3] * dn[3])
            if ort[1] * dn[1] + ort[3] * dn[3] < 0 then
                rads = 2 * math.pi - rads
            end
        
            -- convert to degrees
            return (180 / math.pi) * rads
        end
        if self.rttaken then return end
        local aiBrain = self:GetBrain()
        local armyIndex = aiBrain:GetArmyIndex()
        local platoonUnits = GetPlatoonUnits(self)
        local platoon=self
        platoon.rttaken=true
        local enemyunits=nil
        local pathmaxdist=0
        local lastfinalpoint=nil
        local lastfinaldist=0
        while not platoon.dead and PlatoonExists(aiBrain, self) do
            platoon.Pos=platoon:GetPlatoonPosition()
            if ExitConditions(self,aiBrain) then
                platoon.navigating=false
                platoon.path=false
                WaitTicks(20)
                continue
            end
            local nodenum=RNGGETN(platoon.path)
            if not (platoon.path[nodenum]==lastfinalpoint) and nodenum > 1 then
                pathmaxdist=0
                for i,v in platoon.path do
                    if not v then continue end
                    if not type(i)=='number' then continue end
                    if i==nodenum then continue end
                    --totaldist=totaldist+platoon.path[i+1].nodedist
                    pathmaxdist=math.max(VDist3Sq(v,platoon.path[i+1]),pathmaxdist)
                end
                lastfinalpoint=platoon.path[nodenum]
                lastfinaldist=VDist3Sq(platoon.path[nodenum],platoon.path[nodenum-1])
            end
            if platoon.path[nodenum-1] and VDist3Sq(platoon.path[nodenum],platoon.path[nodenum-1])>lastfinaldist*3 then
                if AIAttackUtils.CanGraphToRNG(self.Pos,platoon.path[nodenum],self.MovementLayer) then
                    platoon.path=AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, platoon.Pos, platoon.path[nodenum], 1, 150,ScenarioInfo.size[1]*ScenarioInfo.size[2])
                    WaitTicks(10)
                    continue
                end
            end
            if (platoon.dest and not AIAttackUtils.CanGraphToRNG(self.Pos,platoon.dest,self.MovementLayer)) or (platoon.path and GetTerrainHeight(platoon.path[nodenum][1],platoon.path[nodenum][3])<GetSurfaceHeight(platoon.path[nodenum][1],platoon.path[nodenum][3])) then
                platoon.navigating=false
                platoon.path=nil
                WaitTicks(20)
                continue
            end
            platoon.Pos=self:GetPlatoonPosition() 
            platoonUnits = GetPlatoonUnits(self)
            local platoonNum=RNGGETN(platoonUnits)
            if platoonNum < 20 then
                self:CHPMergePlatoon(30)
            end
            local spread=0
            local snum=0
            if GetTerrainHeight(platoon.Pos[1],platoon.Pos[3])<platoon.Pos[2]+3 then
                for _,v in platoonUnits do
                    if not v or v.Dead then continue end
                    local unitPos = v:GetPosition()
                    if VDist2Sq(unitPos[1],unitPos[3],platoon.Pos[1],platoon.Pos[3])>platoon.MaxWeaponRange*platoon.MaxWeaponRange+900 then
                        local vec={}
                        vec[1],vec[2],vec[3]=v:GetVelocity()
                        if VDist3Sq({0,0,0},vec)<1 then
                            IssueClearCommands({v})
                            IssueMove({v},platoon.base)
                            aiBrain:AssignUnitsToPlatoon('ArmyPool', {v}, 'Unassigned', 'NoFormation')
                            continue
                        end
                    end
                    if VDist2Sq(unitPos[1],unitPos[3],platoon.Pos[1],platoon.Pos[3])>v.MaxWeaponRange/3*v.MaxWeaponRange/3+platoonNum*platoonNum then
                        --spread=spread+VDist3Sq(v:GetPosition(),platoon.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                        --snum=snum+1
                        ---[[
                        if platoon.dest then
                            IssueClearCommands({v})
                            if v.Sniper then
                                IssueMove({v},RUtils.lerpy(platoon.Pos,platoon.dest,{VDist3(platoon.dest,platoon.Pos),v.MaxWeaponRange/7+math.sqrt(platoonNum)}))
                            else
                                IssueMove({v},RUtils.lerpy(platoon.Pos,platoon.dest,{VDist3(platoon.dest,platoon.Pos),v.MaxWeaponRange/4+math.sqrt(platoonNum)}))
                            end
                            spread=spread+VDist3Sq(unitPos,platoon.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                            snum=snum+1
                        else
                            IssueClearCommands({v})
                            if v.Sniper or v.Support then
                                IssueMove({v},RUtils.lerpy(platoon.Pos,platoon.home,{VDist3(platoon.home,platoon.Pos),v.MaxWeaponRange/7+math.sqrt(platoonNum)}))
                            else
                                IssueMove({v},RUtils.lerpy(platoon.Pos,platoon.home,{VDist3(platoon.home,platoon.Pos),v.MaxWeaponRange/4+math.sqrt(platoonNum)}))
                            end
                            spread=spread+VDist3Sq(unitPos,platoon.Pos)/v.MaxWeaponRange/v.MaxWeaponRange
                            snum=snum+1
                        end--]]
                    end
                end
            end
            if spread>5 then
                WaitTicks(math.ceil(math.sqrt(spread+10)*5))
            end
            platoonUnits = GetPlatoonUnits(self)
            local supportsquad={}
            local scouts={}
            local aa={}
            for _,v in platoonUnits do
                if v and not v.Dead then
                    if v.Role=='Artillery' or v.Role=='Silo' or v.Role=='Sniper' or v.Role=='Shield' then
                        RNGINSERT(supportsquad,v)
                    elseif v.Role=='Scout' then
                        RNGINSERT(scouts,v)
                    elseif v.Role=='AA' then
                        RNGINSERT(aa,v)
                    end
                end
            end
            platoon.Pos=self:GetPlatoonPosition() 
            self:Stop()
            if platoon.path then
                nodenum=RNGGETN(platoon.path)
                if nodenum>=3 then
                    --LOG('platoon.path[3] '..repr(platoon.path[3]))
                    platoon.dest={platoon.path[3][1]+math.random(-4,4),platoon.path[3][2],platoon.path[3][3]+math.random(-4,4)}
                    self:MoveToLocation(platoon.dest,false)
                    IssueClearCommands(supportsquad)
                    spreadmove(supportsquad,midpoint(platoon.path[1],platoon.path[2],0.2))
                    spreadmove(scouts,midpoint(platoon.path[1],platoon.path[2],0.15))
                    spreadmove(aa,midpoint(platoon.path[1],platoon.path[2],0.1))
                else
                    platoon.dest={platoon.path[nodenum][1]+math.random(-4,4),platoon.path[nodenum][2],platoon.path[nodenum][3]+math.random(-4,4)}
                    self:MoveToLocation(platoon.dest,false)
                end
                for i,v in platoon.path do
                    if not platoon.Pos then break end
                    if (not v) then continue end
                    if not type(i)=='number' or type(v)=='number' then continue end
                    if i==nodenum then continue end
                    if VDist2Sq(v[1],v[3],platoon.Pos[1],platoon.Pos[3])<1089 then
                        table.remove(platoon.path,i)
                    end
                end
            end
            if not PlatoonExists(aiBrain, self) then
                return
            end
            WaitTicks(20)
        end
    end,

    CHPMergePlatoon = function(self,radius)
        local aiBrain = self:GetBrain()
        local VDist3Sq = VDist3Sq
        if not self.chpdata then self.chpdata={} end
        self.chpdata.merging=true
        WaitTicks(3)
        --local other
        local best = radius*radius
        local ps1 = table.copy(aiBrain:GetPlatoonsList())
        local ps = {}
        local platoonPos = self:GetPlatoonPosition()
        local platoonUnits = self:GetPlatoonUnits()
        local platoonCount = RNGGETN(platoonUnits)
        if platoonCount<1 or platoonCount>30 then return end
        for i, p in ps1 do
            if not p or p==self or not aiBrain:PlatoonExists(p) or not p.chpdata.name or not p.chpdata.name==self.chpdata.name or VDist3Sq(platoonPos,p:GetPlatoonPosition())>best or RNGGETN(p:GetPlatoonUnits())>30 then  
                --LOG('merge table removed '..repr(i)..' merge table now holds '..repr(RNGGETN(ps)))
            else
                RNGINSERT(ps,p)
            end
        end
        if RNGGETN(ps)<1 then 
            WaitSeconds(3)
            self.chpdata.merging=false
            return 
        elseif RNGGETN(ps)==1 then
            if ps[1].chpdata and self then
                -- actually merge
                if platoonCount<RNGGETN(ps[1]:GetPlatoonUnits()) then
                    self.chpdata.merging=false
                    return
                else
                    local units = ps[1]:GetPlatoonUnits()
                    --LOG('ps=1 merging '..repr(ps[1].chpdata)..'into '..repr(self.chpdata))
                    local validUnits = {}
                    local bValidUnits = false
                    for _,u in units do
                        if not u.Dead and not u:IsUnitState('Attached') then
                            RNGINSERT(validUnits, u)
                            bValidUnits = true
                        end
                    end
                    if not bValidUnits or RNGGETN(validUnits)<1 then
                        return
                    end
                    aiBrain:AssignUnitsToPlatoon(self,validUnits,'Attack','NoFormation')
                    self.chpdata.merging=false
                    ps[1]:PlatoonDisbandNoAssign()
                    return true
                end
            end
        else
            table.sort(ps,function(a,b) return VDist3Sq(a:GetPlatoonPosition(),platoonPos)<VDist3Sq(b:GetPlatoonPosition(),platoonPos) end)
            for _,other in ps do
                if other and self then
                    -- actually merge
                    if platoonCount<RNGGETN(other:GetPlatoonUnits()) then
                        continue
                    else
                        local units = other:GetPlatoonUnits()
                        --LOG('ps>1 merging '..repr(other.chpdata)..'into '..repr(self.chpdata))
                        local validUnits = {}
                        local bValidUnits = false
                        for _,u in units do
                            if not u.Dead and not u:IsUnitState('Attached') then
                                RNGINSERT(validUnits, u)
                                bValidUnits = true
                            end
                        end
                        if not bValidUnits or RNGGETN(validUnits)<1 then
                            continue
                        end
                        aiBrain:AssignUnitsToPlatoon(self,validUnits,'Attack','NoFormation')
                        self.chpdata.merging=false
                        other:PlatoonDisbandNoAssign()
                        return true
                    end
                end
            end
            self.chpdata.merging=false
        end
    end,


}