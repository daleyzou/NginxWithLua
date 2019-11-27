
flowControl = {}


--flowControl.flowCountorTable = {}

local function getNowFlowCountor(grayTaskId)
--    local flowCountor = flowControl.flowCountorTable["grayFlowControl:" .. grayTaskId]
    local flowCountor = ngx.shared.whitelist_customize:get("grayFlowControl:" .. grayTaskId)
    if flowCountor ~= nil then
        flowCountor = flowCountor + 1;
    else
        flowCountor = 1
    end

--    flowControl.flowCountorTable["grayFlowControl:" .. grayTaskId] = flowCountor
    ngx.shared.whitelist_customize:set("grayFlowControl:" .. grayTaskId, flowCountor)
    return flowCountor
end

function flowControl.isGrayFlow(grayTaskId, flowLimitRate)
--    if flowControlEnabled == false then
--        return false
--    end

    local requestCountor = getNowFlowCountor(grayTaskId)

--    print(requestCountor)

    if requestCountor % 100 <= flowLimitRate then
        return true
    else
        return false
    end
end

return flowControl