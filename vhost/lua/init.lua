#!/usr/local/bin/lua
local cjson = require "cjson"
local file = io.open("/usr/local/nginx/conf/vhost/lua/whitelistCustomizeConfig.json", "r");
local json_text = file:read("*a");
file:close();
local whitelistCustomizeConfig={}
if json_text~=nil
then
        whitelistCustomizeConfig = cjson.decode(json_text)
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