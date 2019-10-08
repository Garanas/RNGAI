function GreaterThanEconStorageRatio(aiBrain, mStorageRatio, eStorageRatio)
    local econ = AIUtils.AIGetEconomyNumbers(aiBrain)
    -- If a paragon is present and we not stall mass or energy, return true
    if aiBrain.HasParagon and econ.MassStorageRatio >= 0.01 and econ.EnergyStorageRatio >= 0.01 then
        return true
    elseif econ.MassStorageRatio >= mStorageRatio and econ.EnergyStorageRatio >= eStorageRatio then
        return true
    end
    return false
end

function GreaterThanEconTrend(aiBrain, MassTrend, EnergyTrend)
    local econ = AIUtils.AIGetEconomyNumbers(aiBrain)
    -- If a paragon is present and we have at least a neutral m+e trend, return true
    LOG('Current Econ Trends M E: ', econ.MassTrend, econ.EnergyTrend)
    if aiBrain.HasParagon and econ.MassTrend >= 0 and econ.EnergyTrend >= 0 then
        return true
    elseif econ.MassTrend >= MassTrend and econ.EnergyTrend >= EnergyTrend then
        return true
    end
    return false
end

function GreaterThanEconIncome(aiBrain, MassIncome, EnergyIncome)
    -- If a paragon is present, return true
    if aiBrain.HasParagon then
        return true
    end
    local econ = AIUtils.AIGetEconomyNumbers(aiBrain)
    if (econ.MassIncome >= MassIncome and econ.EnergyIncome >= EnergyIncome) then
        return true
    end
    return false
end

##############################################################################################################
# function: GreaterThanEconEfficiencyOverTime = BuildCondition	doc = "Please work function docs."
# 
# parameter 0: string	aiBrain		= "default_brain"				doc = "docs for param1"
# parameter 1: int	MassEfficiency	= 1             doc = "docs for param1"
# parameter 2: int	EnergyEfficiency	= 1             doc = "param2 docs"
#
##############################################################################################################
function GreaterThanEconEfficiencyOverTime(aiBrain, MassEfficiency, EnergyEfficiency)
    local econ = AIUtils.AIGetEconomyNumbers(aiBrain)
    if (econ.MassEfficiencyOverTime >= MassEfficiency and econ.EnergyEfficiencyOverTime >= EnergyEfficiency) then
        LOG('EfficiencyOverTime, Mass : Energy', econ.MassEfficiencyOverTime, econ.EnergyEfficiencyOverTime)
        return true
    end
    return false
end

