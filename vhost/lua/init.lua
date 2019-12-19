#!/usr/local/bin/lua
whitelistConfig=require "whitelistConfig"
local cjson = require "cjson"
local file = io.open("/usr/local/nginx/conf/vhost/lua/whitelistCustomizeConfig.json", "r");
local json_text = file:read("*a");
file:close();
local whitelistCustomizeConfig={}
if json_text~=nil
then
        whitelistCustomizeConfig = cjson.decode(json_text)
end
ngx.log(ngx.INFO,"whitelistConfig---:", cjson.encode(whitelistConfig))
ngx.shared.whitelist_zone:flush_all()
ngx.shared.whitelist_zone:flush_expired(0)
for i, row in ipairs(whitelistConfig) do
        ngx.log(ngx.INFO,cjson.encode(row))
        if row.project_type=="4" then
                ngx.log(ngx.INFO,"row.host=",row.host,"---row.type=",row.type,"---row.location=",row.location,"---row.project_type=",row.project_type,"---data: ", cjson.encode(row.data))
                local succ, err, forcible = ngx.shared.whitelist_zone:set(row.host..":"..row.location..":"..row.type..":"..row.project_type,cjson.encode(row.data));
                if not succ then
                        ngx.log(ngx.ERR,"err=",err)
                end
        else
                local dataGroupTableJson=ngx.shared.whitelist_zone:get(row.host..":"..row.location..":"..row.type..":"..row.project_type);
                if dataGroupTableJson ==nil then
                        local data_group_table={}
                        data_group_table[row.group_code]=row.data
                        ngx.log(ngx.INFO,"row.host=",row.host,"---row.type=",row.type,"---row.location=",row.location,"---row.project_type=",row.project_type,"---data_group_table: ", cjson.encode(data_group_table))
                        local succ, err, forcible =     ngx.shared.whitelist_zone:set(row.host..":"..row.location..":"..row.type..":"..row.project_type,cjson.encode(data_group_table));
                        if not succ then
                                ngx.log(ngx.ERR,"err=",err)
                        end
                else
                        local data_group_table=cjson.decode(dataGroupTableJson)
                        data_group_table[row.group_code]=row.data
                        ngx.log(ngx.INFO,"row.host=",row.host,"---row.type=",row.type,"---row.location=",row.location,"---row.project_type=",row.project_type,"---data_group_table: ", cjson.encode(data_group_table))
                        local succ, err, forcible =     ngx.shared.whitelist_zone:set(row.host..":"..row.location..":"..row.type..":"..row.project_type,cjson.encode(data_group_table));
                        if not succ then
                                ngx.log(ngx.ERR,"err=",err)
                        end

                end

        end
end
ngx.log(ngx.INFO,"whitelistConfig_customize---:", cjson.encode(whitelistCustomizeConfig))
ngx.shared.whitelist_customize:flush_all()
ngx.shared.whitelist_customize:flush_expired(0)
for i, row in ipairs(whitelistCustomizeConfig) do
        ngx.log(ngx.INFO,"whitelistCustomizeConfig row.host=",row.task_info.host,"---row.group_code=",row.task_info.group_code,"---row.location=",row.task_info.location,"---row: ", cjson.encode(row))
        local succ, err, forcible =  ngx.shared.whitelist_customize:set(row.task_info.host..":"..row.task_info.location..":"..row.task_info.project_type,cjson.encode(row));
        if not succ then
                ngx.log(ngx.ERR,"err=",err)
        end
end
