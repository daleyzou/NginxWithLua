# NginxWithLua
 利用 lua-nginx-module 模块在nginx上开发，实现灰度转发的功能
 
 #### 参考资料
 [idea+openresty+lua开发环境搭建](https://www.cnblogs.com/HushAsy/articles/10302148.html)
 
 [OpenResty最佳实践](https://moonbingbing.gitbooks.io/openresty-best-practices/lua/re.html)
 
 [灰度发布基于cookie分流](https://vther.github.io/nginx-dark-launch/)
 
 #### 从请求中获取值
 
 ```
 -- 从请求中获取请求头为 Sec-WebSocket-Protocol 的值
 secWebSocketProtocol=ngx.req.get_headers()["Sec-WebSocket-Protocol"]
 
 -- 从 cookie 中获取uid对应的值
 uid=ngx.var.cookie_uid
 
 -- 获取我们在 nginx 中定义的变量
 -- set $lct "initialD";
 location=ngx.var.lct
 
 -- 从请求头中获取来源 ip
 ip=headers["X-REAL-IP"] or headers["X_FORWARDED_FOR"] or ngx.var.remote_addr
 ```
 
 #### 说明
 
 
 #### 推送到 nginx 中的 json 配置数据
 
 ```
 [
   {
     "rules": {
       "rule_name": {
         "rule": [
           {
             "type": "cookie",
             "key": "test",
             "value": "",
             "multi_val": [
               "1"
             ],
             "match_type_v": "whitelist",
             "relative": "must"
           }
         ],
         "should_match_num": 0,
         "relative": "must"
       },
       "should_match_num": 0
     },
     "task_info": {
       "host": "storage.test.com",
       "group_code": "1572094195",
       "location": "test",
       "project_type": "1"
     }
   }
 ]
 ```
 
 #### test.conf 文件的内容
 
 ```
 upstream test_default {
     server 172.16.1.1:20440;
 	server 172.16.1.2:20440;
 }
 server{
     listen 80;
     server_name storage.test.com;
 
     charset   utf-8;
     location / {
         index  index.html index.htm;
         proxy_redirect off ;
         proxy_set_header Host $host;
         proxy_set_header X-Real-IP $remote_addr;
         proxy_set_header REMOTE-HOST $remote_addr;
         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
         client_max_body_size 500m;
         client_body_buffer_size 256k;
         proxy_connect_timeout 300;
         proxy_send_timeout 300;
         proxy_read_timeout 600;
         proxy_buffer_size 256k;
         proxy_buffers 4 256k;
         proxy_busy_buffers_size 256k;
         proxy_temp_file_write_size 256k;
         proxy_next_upstream error timeout invalid_header http_500 http_503 http_404;
         proxy_max_temp_file_size 128m;
         set $lct "test";
         set_by_lua_file $cur_ups conf/vhost/lua/grayscaleControl.lua;
         proxy_pass $scheme://$cur_ups;
         proxy_http_version 1.1;
         proxy_set_header Upgrade $http_upgrade;
         proxy_set_header Connection "Upgrade";
     }
 
 
 
 
     access_log logs/test_access.log  json;
     error_log logs/test_error.log info;
 }
 ```
 
 
 #### 用户配置的HTTP规则生效流程
 1. 用户配置拦截的条件
 1. 根据条件生成规则的json数据
 2. 一个项目有一个json规则数据，将项目的json数据放入列表
 3. 将列表数据以json的方式写出到文件，文件名为 whitelistCustomizeConfig.json
 4. 将文件推送到nginx下
 5. 重启nginx，此时会重新加载json规则数据到 nginx 内存中
 
 #### nginx 重启流程
 1. lua_shared_dict whitelist_customize 64m（在 nginx 中开辟一个空间，用于加载拦截请求的规则）
 2. init_worker_by_lua_file conf/vhost/lua/init.lua (执行 lua 脚本，读取whitelistCustomizeConfig.json 文件，将规则数据按照项目保存到 whitelist_customize 字典中，字典中的 key 是 “域名 + 项目名”， 字典中的 value 是用户配置的 json 规则数据)
 
 #### 浏览器发起请求进行拦截的过程
 1. 根据请求获取域名和项目名
 1. 从 nginx 内存中获取规则，即根据 key="域名+项目名" ，获取 map 中的值
 1. 执行 lua 脚本，根据从内存中获取的规则进行判断，将请求转发到正常节点的 upstream 或者是 灰度节点的 upstream
 ![http规则示意图](https://raw.githubusercontent.com/daleyzou/Image/master/img/http%E8%A7%84%E5%88%99%E7%A4%BA%E6%84%8F%E5%9B%BE.png)
 
 
 

 
