location=ngx.var.lct

local customizeRules = {}

local function isTableEmpty(t)
    return t == nil or next(t) == nil
end

-- regular, whitelist, blacklist, expression, script
-- match with regular
local function matchWithRegular(sources,field)
    -- judge by regular
    if sources.value~=nil
    then
        local from, to, err = ngx.re.find(field, sources.value, "jo")
        if from then
            if from==1 and string.len(field)==to then
                ngx.log(ngx.INFO,"match ok host=",ngx.var.host,"---location=",location,"---key=", sources.key,"--value=",sources.value,"--field=",field)
                return true
            end
        else
            if err then
                ngx.log(ngx.ERR,"host=",ngx.var.host,"---location=",location,"---key=",sources.key,"--err=",err)
            end
            return false
        end
        return false
    end
    return false
end

-- match with whitelist
local function matchWithWhitelist(sources,field)
    -- judge by value
    if sources.value~=nil and sources.value~=""
    then
        if sources.value==field
        then
            ngx.log(ngx.INFO, "value ok "..location.." sources  key=",sources.key,"---","val=",sources.value)
            return true
        end
        return false
    end
    -- judge by multi_val
    local multiValTable=sources.multi_val
    if not isTableEmpty(multiValTable)
    then
        for key, val in pairs(multiValTable) do
            ngx.log(ngx.INFO, "multi in pairs "..location.." sources  key=",key,"---","val=",val,"--field=",field)
            if val==field
            then
                ngx.log(ngx.INFO, "multi ok "..location.." sources  key=",key,"---","val=",val)
                return true
            end
        end
        return false
    end
    return false
end

-- match with expression
local function matchWithExpression(sources,field)
    --    =：支持字符串、数字、Boolean 和 Char 的比较。
    --    !=：支持字符串、数字、Boolean 和 Char 的比较。
    --    >：支持数字的比较。
    --    >=：支持数字的比较。
    --    <：支持数字的比较。
    --    <=：支持数字的比较
    local expression=sources.value
    if expression~=nil
    then
        local n = tonumber(field);
        if n then
            -- n就是得到数字
            -- 修改 expression 中的字符，使其符合 lua 规范 [!= to ~=][&& to and][|| to or][value to n]
            expression=(string.gsub(expression, "!=", "~="))
            expression=(string.gsub(expression, "&&", " and "))
            expression=(string.gsub(expression, "||", " or "))
            expression=(string.gsub(expression, "value", n))
            expression = "return  "..expression
            ngx.log(ngx.INFO,"expression="..expression)
            local resultFunction=loadstring(expression)
            local expressionResult=resultFunction()
            ngx.log(ngx.INFO,"result="..tostring(expressionResult))
            return expressionResult
        else
            -- 转数字失败,不是数字, 这时n == nil
            return false
        end
    end
    return false
end

-- match with mod
local function matchWithMod(sources,field)
    local expression=sources.value
    if expression~=nil
    then
        local value=0
        local n = tonumber(field);
        if n then
            -- field is number
            value=n
        else
            -- field is not number,通过哈希（Hash）算法将非数字转化为数字
            mmh2 = require "murmurhash2"
            value = mmh2(field)
        end
        expression=(string.gsub(expression, "value", value))
        expression = "return  "..expression
        ngx.log(ngx.INFO,"matchWithMod expression="..expression)
        local resultFunction=loadstring(expression)
        local expressionResult=resultFunction()
        ngx.log(ngx.INFO,"matchWithMod result="..tostring(expressionResult))
        return expressionResult
    end
    return false
end

local function compareSourcesWithField(sources,field)
    ngx.log(ngx.INFO, "compareSourcesWithField "..location.." sources  key=",sources.key,"---","val=",sources.value,"---field=",field)
    -- match with whitelist
    if sources.match_type_v=="whitelist" then
        return matchWithWhitelist(sources,field)
    end
    -- match with regular
    if sources.match_type_v=="regular" then
        return matchWithRegular(sources,field)
    end
    -- match with expression
    if sources.match_type_v=="expression" then
        return matchWithExpression(sources,field)
    end
    -- match with mod
    if sources.match_type_v=="mod" then
        return matchWithMod(sources,field)
    end
    return false;
end

local function judgeByCookie(sources)
    local ck = require "cookie"
    local cookie, err = ck:new()
    if not cookie then
        ngx.log(ngx.ERR, "host=",ngx.var.host,"---location=",location,"---err",err)
        return false
    end
    local cookie = cookie:new()
    local all_cookie,err = cookie:get_all()
    if not all_cookie then
        ngx.log(ngx.ERR, "host=",ngx.var.host,"---location=",location,"---err",err)
        return false
    end
    -- judge by key
    if sources.key~=nil and sources.key~=""
    then
        -- get single cookie
        local field, err = cookie:get(sources.key)
        if not field then
            ngx.log(ngx.ERR, "judgeByCookie host=",ngx.var.host,"---location=",location,"---err",err)
            return false
        end
        return compareSourcesWithField(sources,field)
    end
    return false
end

-- judge with request param
local function judgeByRequestParam(sources, cjson)
    local getParems = ngx.req.get_uri_args()
    if isTableEmpty(getParems) then
        ngx.log(ngx.ERR, "judgeByRequestParam host=",ngx.var.host,"getParems is nil")
        return false
    end
    local field=getParems[sources.key]
    if not field then
        ngx.log(ngx.ERR, "judgeByRequestParam method=GET host=",ngx.var.host,"---location=",location,"---all field=",cjson.encode(getParems))
        return false
    end
    return compareSourcesWithField(sources,field)
end

-- judge with request param
local function judgeByHeader(sources,cjson)
    local headers = ngx.req.get_headers()
    if headers==nil then
        ngx.log(ngx.ERR, "judgeByHeader host=",ngx.var.host,"headers is nil")
        return false
    end
    local field=headers[sources.key]
    if not field then
        ngx.log(ngx.ERR, "judgeByHeader field=nil host=",ngx.var.host,"---location=",location,"---all field",cjson.encode(headers))
        return false
    end
    return compareSourcesWithField(sources,field)
end

local function judgeByURI(sources,cjson)
    local uri = ngx.var.uri
    if not uri then
        ngx.log(ngx.ERR, "judgeByURI field=nil host=",ngx.var.host,"---location=",location,"---all field=",uri)
        return false
    end
    return compareSourcesWithField(sources,uri)
end

local function statusCheck(sources,cjson)
    if sources.type=="cookie"
    then
        return judgeByCookie(sources)
    end

    if sources.type=="requestParam"
    then
        return judgeByRequestParam(sources,cjson)
    end
    if sources.type=="header"
    then
        return judgeByHeader(sources,cjson)
    end
    if sources.type=="URI"
    then
        local test=judgeByURI(sources,cjson)
        ngx.log(ngx.INFO, "judgeByURI Return",test)
        return test
    end
    return false
end

local function checkRule(rule)
    local cjson = require "cjson"
    local result = true
    if  rule~=nil
    then
        local shouldNum=tonumber(rule.should_match_num)
        local countshould=0
        for i, row in ipairs(rule.rule) do
            local relation=row.relative
            if relation~="should" or countshould<shouldNum then
                local status=statusCheck(row,cjson)
                if "must"==relation and not status then
                    ngx.log(ngx.INFO, "checkRule relation=must and status=false ---data="..cjson.encode(row))
                    result=false
                    break
                end
                if "should"==relation and status then
                    countshould=countshould+1
                end
            end
        end
        if countshould<shouldNum then
            ngx.log(ngx.INFO, "checkRule countshould<shouldNum ,return false")
            return false
        end
        if result then
            ngx.log(ngx.INFO, "checkRule return true")
            return true
        end
    end

    return false
end

function customizeRules.applyCustomizeRules(findResultTable,cjson)
    local shouldNum = tonumber(findResultTable.rules.should_match_num)
    local countshould = 0
    ngx.log(ngx.ERR, "data = " .. cjson.encode(findResultTable.rules))
    local result=true
    for i, row in pairs(findResultTable.rules) do
        ngx.log(ngx.ERR, " i=  " .. i)
        if i ~= "should_match_num" then
            ngx.log(ngx.ERR, "into if i=  " .. i)
            -- 如果should 个数已经满足要求，就停止判断should
            local relation = row.relative
            if relation ~= "should" or countshould < shouldNum then
                ngx.log(ngx.ERR, "in rules:" .. cjson.encode(row))
                local status = checkRule(row)
                if "must" == relation and not status then
                    ngx.log(ngx.ERR, findResultTable.task_info.host .. ":" .. findResultTable.task_info.location .. " docheck relation=must and status=false and rule_name= " .. i .. " ---data=" .. cjson.encode(row))
                    result = false
                    break
                end
                if "should" == relation and status then
                    countshould = countshould + 1
                end
            end
        end
    end
    if countshould < shouldNum then
        ngx.log(ngx.ERR, " countshould<shouldNum, run  " .. location .. "_default")
        return false
    end
    if result then
        ngx.log(ngx.ERR, "Satisfy grayscale, run " .. location .. "_" .. findResultTable.task_info.group_code)
        return true
    end
end

return customizeRules