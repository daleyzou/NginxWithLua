#!/usr/local/bin/lua

uid=ngx.var.cookie_uid
headers=ngx.req.get_headers()
-- 从请求头中获取来源 ip
ip=headers["X-REAL-IP"] or headers["X_FORWARDED_FOR"] or ngx.var.remote_addr
organize=ngx.var.cookie_organize
muid=ngx.var.cookie_muid
-- 获取我们在 nginx 中定义的变量
-- set $lct "initialD";
location=ngx.var.lct
sr=ngx.var.sr
if location == nil then
    ngx.log(ngx.ERR, "please set lct arg")
    return
end
if sr == nil then
    ngx.log(ngx.ERR, "please set sr arg")
    return
end
uidTableJson=ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."uid:4")
muidTableJson=ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."muid:4")
ipTableJson= ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."ip:4")
organizeTableJson=ngx.shared.whitelist_zone:get(ngx.var.host..":"..location..":".."organize:4")
ngx.log(ngx.INFO,"host=",ngx.var.host,"---location=",location,"---uidTableJson=",uidTableJson,"---muidTableJson=",muidTableJson,"---ipTableJson=",ipTableJson,"---organizeTableJson=",organizeTableJson,"---uid=",uid,"---muid=",muid,"---ip=",ip,"---organize=",organize)

-- 从内存中获取自定义的值
webCustomizeResultTableJson=ngx.shared.whitelist_customize:get(ngx.var.host..":"..location..":4")
ngx.log(ngx.INFO,"host=",ngx.var.host,"---location=",location,"---webCustomizeResultTableJson=", webCustomizeResultTableJson)

function checkWhitelist(target,sources)
    if sources ==nil
    then
        return false
    end
    for key, val in pairs(sources) do
        if val==target
        then
            return true
        end
    end
    return false
end

--begin customize
function forwardByCustomize()
    local cjson = require "cjson"
    local grayEnabled = false
    if webCustomizeResultTableJson ~= nil then
        local findResultTable = cjson.decode(webCustomizeResultTableJson)
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

        return grayEnabled
    end
    return false
end
--end customize

docheck=function()
    --   No original whitelist logic, start custom logic
    local webCustomizeStatus = forwardByCustomize()
    if webCustomizeStatus
    then
        if sr=="false" then
            ngx.log(ngx.INFO,"Satisfy grayscale exec @"..location.."_grayscale")
            ngx.exec("@"..location.."_grayscale")
            return
        else
            ngx.log(ngx.INFO,"Satisfy grayscale exec @sr_"..location.."_grayscale")
            ngx.exec("@sr_"..location.."_grayscale")
            return
        end
    end

    if sr=="false" then
        ngx.log(ngx.INFO,"exec @"..location.."_default")
        ngx.exec("@"..location.."_default")
        return
    elseif sr=="true" then
        ngx.log(ngx.INFO,"exec @sr_"..location.."_default")
        ngx.exec("@sr_"..location.."_default")
        return
    end
end

docheck()
