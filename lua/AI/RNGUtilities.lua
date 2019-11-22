local AIUtils = import('/lua/ai/AIUtilities.lua')

function ReclaimRNGAIThread(platoon, self, aiBrain)
    -- Caution this is extremely barebones and probably will break stuff or reclaim stuff it shouldn't
    LOG('Start Reclaim Function')
    IssueClearCommands({self})
    local locationType = self.PlatoonData.LocationType
    local initialRange = 40
    local furtherestReclaim = nil
    local closestReclaim = nil
    local closestDistance = 10000
    local furtherestDistance = 0
    local createTick = GetGameTick()

    self.BadReclaimables = self.BadReclaimables or {}

    while aiBrain:PlatoonExists(platoon) and self and not self.Dead do
        local engPos = self:GetPosition()
        local x1 = engPos[1] - initialRange
        local x2 = engPos[1] + initialRange
        local z1 = engPos[3] - initialRange
        local z2 = engPos[3] + initialRange
        local rect = Rect(x1, z1, x2, z2)
        local reclaimRect = GetReclaimablesInRect(rect)

        if not engPos then
            WaitTicks(1)
            return
        end

        local reclaim = {}
        local needEnergy = aiBrain:GetEconomyStoredRatio('ENERGY') < 0.5
        LOG('Going through reclaim table')
        if reclaimRect and table.getn( reclaimRect ) > 0 then
            for k,v in reclaimRect do
                --LOG(repr(v))
                if not IsProp(v) or self.BadReclaimables[v] then continue end
                if not needEnergy or v.MaxEnergyReclaim then
                    if not self.BadReclaimables[v] then
                        local rpos = v:GetCachePosition()
                        local distance = VDist2(engPos[1], engPos[3], rpos[1], rpos[3])
                        if distance < closestDistance then
                            closestReclaim = rpos
                            closestDistance = distance
                        end
                        if distance > furtherestDistance then -- and distance < closestDistance + 20
                            furtherestReclaim = rpos
                            furtherestDistance = distance
                        end
                    end
                end
            end
        end
        if self.Dead then 
            return
        end
        LOG('Closest Distance is : '..closestDistance..'Furtherest Distance is :'..furtherestDistance)
        -- Clear Commands first
        IssueClearCommands({self})
        LOG('Attempting move to closest reclaim')
        StartMoveDestination(self, closestReclaim)
        LOG('Closest reclaim is '..closestReclaim[1]..' '..closestReclaim[3])
        local brokenDistance = closestDistance / 6
        LOG('One 6th of distance is '..brokenDistance)
        local moveWait = 0
        while VDist2(engPos[1], engPos[3], closestReclaim[1], closestReclaim[3]) > brokenDistance do
            LOG('Waiting for engineer to get close, current distance : '..VDist2(engPos[1], engPos[3], closestReclaim[1], closestReclaim[3])..'closestDistance'..closestDistance)
            WaitSeconds(2)
            moveWait = moveWait + 1
            engPos = self:GetPosition()
            if moveWait == 10 then
                break
            end
        end
        LOG('Attempting agressive move to furtherest reclaim')
        -- Clear Commands first
        IssueClearCommands({self})
        IssueAggressiveMove({self}, furtherestReclaim)
        local reclaiming = not self:IsIdleState()
        local max_time = platoon.PlatoonData.ReclaimTime
        while reclaiming do
            LOG('Engineer is reclaiming')
            WaitSeconds(max_time)
           if self:IsIdleState() or (max_time and (GetGameTick() - createTick)*10 > max_time) then
                LOG('Engineer no longer reclaiming')
                reclaiming = false
            end
        end
        local basePosition = aiBrain.BuilderManagers['MAIN'].Position
        LOG('Base Location is : '..basePosition[1]..' '..basePosition[3])
        local location = AIUtils.RandomLocation(basePosition[1],basePosition[3])
        LOG('Random Location is :'..location[1]..' '..location[3])
        IssueClearCommands({self})
        StartMoveDestination(self, location)
        WaitSeconds(5)
    end
end

function StartMoveDestination(self,destination)
    local NowPosition = self:GetPosition()
    local x, z, y = unpack(self:GetPosition())
    local count = 0
    IssueClearCommands({self})
    while x == NowPosition[1] and y == NowPosition[3] and count < 20 do
        count = count + 1
        IssueClearCommands({self})
        IssueMove( {self}, destination )
        WaitTicks(10)
    end
end
-- Get the military operational areas of the map. Credit to Uveso, this is based on his zones but a little more for small map sizes.
function GetMOARadii(bool)
    -- Military area is slightly less than half the map size (10x10map) or maximal 200.
    local BaseMilitaryArea = math.max( ScenarioInfo.size[1]-50, ScenarioInfo.size[2]-50 ) / 2.2
    BaseMilitaryArea = math.max( 180, BaseMilitaryArea )
    -- DMZ is half the map. Mainly used for air formers
    local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
    -- Restricted Area is half the BaseMilitaryArea. That's a little less than 1/4 of a 10x10 map
    local BaseRestrictedArea = BaseMilitaryArea / 2
    -- Make sure the Restricted Area is not smaller than 50 or greater than 100
    BaseRestrictedArea = math.max( 50, BaseRestrictedArea )
    BaseRestrictedArea = math.min( 100, BaseRestrictedArea )
    -- The rest of the map is enemy area
    local BaseEnemyArea = math.max( ScenarioInfo.size[1], ScenarioInfo.size[2] ) * 1.5
    -- "bool" is only true if called from "AIBuilders/Mobile Land.lua", so we only print this once.
    if bool then
        LOG('* RNGAI: BaseRestrictedArea= '..math.floor( BaseRestrictedArea * 0.01953125 ) ..' Km - ('..BaseRestrictedArea..' units)' )
        LOG('* RNGAI: BaseMilitaryArea= '..math.floor( BaseMilitaryArea * 0.01953125 )..' Km - ('..BaseMilitaryArea..' units)' )
        LOG('* RNGAI: BaseDMZArea= '..math.floor( BaseDMZArea * 0.01953125 )..' Km - ('..BaseDMZArea..' units)' )
        LOG('* RNGAI: BaseEnemyArea= '..math.floor( BaseEnemyArea * 0.01953125 )..' Km - ('..BaseEnemyArea..' units)' )
    end
    return BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea
end

function AirScoutPatrolRNGAIThread(self, aiBrain)
    
    local scout = self:GetPlatoonUnits()[1]
    if not scout then
        return
    end

    -- build scoutlocations if not already done.
    if not aiBrain.InterestList then
        aiBrain:BuildScoutLocations()
    end

    --If we have Stealth (are cybran), then turn on our Stealth
    if scout:TestToggleCaps('RULEUTC_CloakToggle') then
        scout:EnableUnitIntel('Toggle', 'Cloak')
    end

    while not scout.Dead do
        local targetArea = false
        local highPri = false

        local mustScoutArea, mustScoutIndex = aiBrain:GetUntaggedMustScoutArea()
        local unknownThreats = aiBrain:GetThreatsAroundPosition(scout:GetPosition(), 16, true, 'Unknown')

        --1) If we have any "must scout" (manually added) locations that have not been scouted yet, then scout them
        if mustScoutArea then
            mustScoutArea.TaggedBy = scout
            targetArea = mustScoutArea.Position

        --2) Scout "unknown threat" areas with a threat higher than 25
        elseif table.getn(unknownThreats) > 0 and unknownThreats[1][3] > 25 then
            aiBrain:AddScoutArea({unknownThreats[1][1], 0, unknownThreats[1][2]})

        --3) Scout high priority locations
        elseif aiBrain.IntelData.AirHiPriScouts < aiBrain.NumOpponents and aiBrain.IntelData.AirLowPriScouts < 1
        and table.getn(aiBrain.InterestList.HighPriority) > 0 then
            aiBrain.IntelData.AirHiPriScouts = aiBrain.IntelData.AirHiPriScouts + 1

            highPri = true

            targetData = aiBrain.InterestList.HighPriority[1]
            targetData.LastScouted = GetGameTimeSeconds()
            targetArea = targetData.Position

            aiBrain:SortScoutingAreas(aiBrain.InterestList.HighPriority)

        --4) Every time we scout NumOpponents number of high priority locations, scout a low priority location
        elseif aiBrain.IntelData.AirLowPriScouts < 1 and table.getn(aiBrain.InterestList.LowPriority) > 0 then
            aiBrain.IntelData.AirHiPriScouts = 0
            aiBrain.IntelData.AirLowPriScouts = aiBrain.IntelData.AirLowPriScouts + 1

            targetData = aiBrain.InterestList.LowPriority[1]
            targetData.LastScouted = GetGameTimeSeconds()
            targetArea = targetData.Position

            aiBrain:SortScoutingAreas(aiBrain.InterestList.LowPriority)
        else
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

                WaitSeconds(5)
            end
        else
            WaitSeconds(1)
        end
        WaitTicks(1)
    end
end

function EngineerTryReclaimCaptureArea(aiBrain, eng, pos)
    if not pos then
        return false
    end
    local Reclaiming = false
    -- Check if enemy units are at location
    local checkUnits = aiBrain:GetUnitsAroundPoint( (categories.STRUCTURE + categories.MOBILE) - categories.AIR, pos, 10, 'Enemy')
    -- reclaim units near our building place.
    if checkUnits and table.getn(checkUnits) > 0 then
        for num, unit in checkUnits do
            if unit.Dead or unit:BeenDestroyed() then
                continue
            end
            if not IsEnemy( aiBrain:GetArmyIndex(), unit:GetAIBrain():GetArmyIndex() ) then
                continue
            end
            if unit:IsCapturable() and not EntityCategoryContains(categories.TECH1 - categories.STRUCTURE, unit) then 
                LOG('Unit no is capturable and not category engineer')
                -- if we can capture the unit/building then do so
                unit.CaptureInProgress = true
                IssueCapture({eng}, unit)
            else
                -- if we can't capture then reclaim
                unit.ReclaimInProgress = true
                IssueReclaim({eng}, unit)
            end
        end
        Reclaiming = true
    end
    -- reclaim rocks etc or we can't build mexes or hydros
    local Reclaimables = GetReclaimablesInRect(Rect(pos[1], pos[3], pos[1], pos[3]))
    if Reclaimables and table.getn( Reclaimables ) > 0 then
        for k,v in Reclaimables do
            if v.MaxMassReclaim and v.MaxMassReclaim > 0 or v.MaxEnergyReclaim and v.MaxEnergyReclaim > 0 then
                IssueReclaim({eng}, v)
            end
        end
    end
    return Reclaiming
end

function EngineerMoveWithSafePath(aiBrain, unit, destination)
    if not destination then
        return false
    end
    local pos = unit:GetPosition()
    -- don't check a path if we are in build range
    if VDist2(pos[1], pos[3], destination[1], destination[3]) < 14 then
        return true
    end
    local result, bestPos = unit:CanPathTo(destination)
    local bUsedTransports = false
    -- Increase check to 300 for transports
    if not result or VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 300 * 300
    and unit.PlatoonHandle and not EntityCategoryContains(categories.COMMAND, unit) then
        -- If we can't path to our destination, we need, rather than want, transports
        local needTransports = not result
        if VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 300 * 300 then
            needTransports = true
        end

        -- Skip the last move... we want to return and do a build
        bUsedTransports = AIAttackUtils.SendPlatoonWithTransportsNoCheck(aiBrain, unit.PlatoonHandle, destination, needTransports, true, false)

        if bUsedTransports then
            return true
        elseif VDist2Sq(pos[1], pos[3], destination[1], destination[3]) > 512 * 512 then
            -- If over 512 and no transports dont try and walk!
            return false
        end
    end

    -- If we're here, we haven't used transports and we can path to the destination
    if result then
        local path, reason = AIAttackUtils.PlatoonGenerateSafePathTo(aiBrain, 'Amphibious', pos, destination)
        if path then
            local pathSize = table.getn(path)
            -- Move to way points (but not to destination... leave that for the final command)
            for widx, waypointPath in path do
                if pathSize ~= widx then
                    IssueMove({unit}, waypointPath)
                end
            end
        end
        -- If there wasn't a *safe* path (but dest was pathable), then the last move would have been to go there directly
        -- so don't bother... the build/capture/reclaim command will take care of that after we return
        return true
    end
    return false
end

function EngineerTryRepair(aiBrain, eng, whatToBuild, pos)
    if not pos then
        return false
    end

    local structureCat = ParseEntityCategory(whatToBuild)
    local checkUnits = aiBrain:GetUnitsAroundPoint(structureCat, pos, 1, 'Ally')
    if checkUnits and table.getn(checkUnits) > 0 then
        for num, unit in checkUnits do
            IssueRepair({eng}, unit)
        end
        return true
    end

    return false
end