#!/usr/local/bin/lua

appVersion=ngx.req.get_headers()["x-appVersion"]
h5Version=ngx.req.get_headers()["x-h5-grayscale-version"]
webVersion=ngx.req.get_headers()["x-web-grayscale-version"]
secWebSocketProtocol=ngx.req.get_headers()["Sec-WebSocket-Protocol"]
organize=ngx.var.cookie_organize
muid=ngx.var.cookie_muid
uid=ngx.var.cookie_uid


location=ngx.var.lct
if location == nil then
    ngx.log(ngx.ERR, "please set lct arg")
    return
end

appVersionTableJson=ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."x-appVersion:1")
h5VersionTableJson= ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."x-h5-grayscale-version:1")
webVersionTableJson= ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."x-web-grayscale-version:1")
secWebSocketProtocolTableJson= ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."Sec-WebSocket-Protocol:1")

ngx.log(ngx.INFO,"host=",ngx.var.host,"---appVersionTableJson=",appVersionTableJson,"---h5VersionTableJson=",h5VersionTableJson,"---webVersionTableJson=",webVersionTableJson,"---secWebSocketProtocolTableJson=",secWebSocketProtocolTableJson,"---appVersion=",appVersion,"---h5Version=",h5Version,"---webVersion=",webVersion,"---secWebSocketProtocol=",secWebSocketProtocol)


uidTableJson= ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."uid:1")
muidTableJson=ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."muid:1")
organizeTableJson=ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."organize:1")
ngx.log(ngx.INFO,"host=",ngx.var.host,"---uidTableJson=",uidTableJson,"---muidTableJson=",muidTableJson,"---organizeTableJson=",organizeTableJson,"---uid=",uid,"---muid=",muid,"---organize=",organize)

-- 从内存中获取自定义的值
findResultTableJson=ngx.shared.whitelist_customize:get(ngx.var.host..":"..location..":1")
ngx.log(ngx.INFO,"host=",ngx.var.host,"---location=",location,"---findResultTableJson=", findResultTableJson)

function versionCheck(target,sources,cjson)
    local grayscaleVersion
    for key, val in pairs(sources) do
        ngx.log(ngx.INFO, location.." sources  key=",key,"---","val=",cjson.encode(val))
        if val ~= nil then
            for key1, val1 in pairs(val) do
                ngx.log(ngx.INFO, location.." val  key1=",key1,"---","val1=",val1,"---target=",target)
                if val1==target
                then
                    grayscaleVersion=location.."_"..key
                    break
                end
            end

        end
    end
    return grayscaleVersion
end

function forwardByWhitelist()
    local cjson = require "cjson"
    if  appVersion ~=nil and appVersionTableJson~=nil
    then
        appVersionTable=cjson.decode(appVersionTableJson)
        grayscaleVersion=versionCheck(appVersion,appVersionTable,cjson)
        if grayscaleVersion ~=nil
        then
            ngx.log(ngx.INFO, " app upsteam:"..grayscaleVersion.." success")
            return grayscaleVersion
        end
    end

    --h5流量控制
    if  h5Version ~=nil and h5VersionTableJson~=nil
    then
        h5VersionTable=cjson.decode(h5VersionTableJson)
        grayscaleVersion=versionCheck(h5Version,h5VersionTable,cjson)
        if grayscaleVersion ~=nil
        then
            ngx.log(ngx.INFO, " h5 upsteam:"..grayscaleVersion.." success")
            return grayscaleVersion
        end
    end

    --web流量控制
    if  webVersion ~=nil and webVersionTableJson~=nil
    then
        webVersionTable=cjson.decode(webVersionTableJson)
        grayscaleVersion=versionCheck(webVersion,webVersionTable,cjson)
        if grayscaleVersion ~=nil
        then
            ngx.log(ngx.INFO, " web upsteam:"..grayscaleVersion.." success")
            return grayscaleVersion
        end
    end


    --长连接流量控制
    if  secWebSocketProtocol ~=nil and secWebSocketProtocolTableJson~=nil
    then
        secWebSocketProtocolTable=cjson.decode(secWebSocketProtocolTableJson)
        grayscaleVersion=versionCheck(secWebSocketProtocol,secWebSocketProtocolTable,cjson)
        if grayscaleVersion ~=nil
        then
            ngx.log(ngx.INFO, " ws upsteam:"..grayscaleVersion.." success")
            return grayscaleVersion
        end
    end

    --uid流量控制
    if  uid ~=nil and uidTableJson~=nil
    then
        uidTable=cjson.decode(uidTableJson)
        grayscaleVersion=versionCheck(uid,uidTable,cjson)
        if grayscaleVersion ~=nil
        then
            ngx.log(ngx.INFO, " uid upsteam:"..grayscaleVersion.." success")
            return grayscaleVersion
        end
    end

    --muid流量控制
    if  muid ~=nil and muidTableJson~=nil
    then
        muidTable=cjson.decode(muidTableJson)
        grayscaleVersion=versionCheck(muid,muidTable,cjson)
        if grayscaleVersion ~=nil
        then
            ngx.log(ngx.INFO, " muid upsteam:"..grayscaleVersion.." success")
            return grayscaleVersion
        end
    end


    --muid流量控制
    if  organize ~=nil and organizeTableJson~=nil
    then
        organizeTable=cjson.decode(organizeTableJson)
        grayscaleVersion=versionCheck(organize,organizeTable,cjson)
        if grayscaleVersion ~=nil
        then
            ngx.log(ngx.INFO, " organize upsteam:"..grayscaleVersion.." success")
            return grayscaleVersion
        end
    end

    ngx.log(ngx.INFO, " no grayscale !run "..location.."_default")
    return location.."_default"
end

function forwardByCustomize()
    local cjson = require "cjson"
    local grayEnabled = false
    if findResultTableJson ~= nil then
        local findResultTable = cjson.decode(findResultTableJson)
        if findResultTable.flow_rate ~= nil and findResultTable.flow_rate.before_of_rules then
            local fc = require "flowControl"
            grayEnabled = fc.isGrayFlow(findResultTable.task_info.group_code, findResultTable.flow_rate.percentage)
            if grayEnabled and findResultTable.rules ~= nil then
                local cr = require "customizeRules"
                grayEnabled = cr.applyCustomizeRules(findResultTable,cjson)
            end
        end

        if findResultTable.flow_rate ~= nil and (not findResultTable.flow_rate.before_of_rules) then
            if findResultTable.rules ~= nil then
                local cr = require "customizeRules"
                grayEnabled = cr.applyCustomizeRules(findResultTable,cjson)
            else
                grayEnabled = true
            end

            if grayEnabled then
                local fc = require "flowControl"
                grayEnabled = fc.isGrayFlow(findResultTable.task_info.group_code, findResultTable.flow_rate.percentage)
            end
        end

        if findResultTable.flow_rate == nil then
            if findResultTable.rules ~= nil then
                local cr = require "customizeRules"
                grayEnabled = cr.applyCustomizeRules(findResultTable,cjson)
            else
                grayEnabled = false
            end
        end

        if grayEnabled then
            ngx.log(ngx.INFO, " is customize rule !run "..location .. "_" .. findResultTable.task_info.group_code)
            return location .. "_" .. findResultTable.task_info.group_code
        else
            ngx.log(ngx.INFO, " no customize grayscale !run "..location.."_default")
            return location .. "_default"
        end
    end
    ngx.log(ngx.INFO, " no customize grayscale !run "..location.."_default")
    return location .. "_default"
end

-- 匹配转发
docheck=function()
    local result = forwardByWhitelist()
    if result == location.."_default" then
        result = forwardByCustomize()
    end
    return result
end
local status, message = pcall(docheck)
if status then
    return message
else
    return location.."_default"
end




