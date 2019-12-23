local username = ""
local passsword = ""

local server = require "resty.websocket.server"

local wsocket, err = server:new{
    timeout = 5000, --TODO:配置超时时间
    max_playload_len = 65535
}

if not wsocket then
    ngx.log(ngx.ERR, "failed to new websocket: ", err)
    return ngx.exit(444)
end

wsocket:send_text("connecting to the port 23 ... \n")

local webtelnet = dofile ("webtelnet.lua")
--NOTE: 不会根据package.path进行搜索，而是根据相对路径搜索，而此处的应该是相对此nginx进程的相对路径(openresty根目录)
if not webtelnet.connect() then
    ngx.log(ngx.ERR, "failed to connect port 23")
    wsocket:send_text("failed to connect telnet！\n")
    wsocket:send_close()
    return ngx.exit(444)
end

wsocket:send_text("connect success.\n")

-- local welcome
-- while true do
    local auto_out = webtelnet.input() --NOTE: 这一段是自动登录，就算不需要，也不能注释这一行
--     if auto_out ~= "" then
--         if string.find(auto_out, "ogin:") then
--             auto_out = webtelnet.input(username .. "\r\n")
--         end
--         if string.find(auto_out, "assword:") then
--             welcome = webtelnet.input(passsword .. "\r\n")
--             break
--         end
--     end
-- end

-- wsocket:send_text(welcome)

-- local tellog = require "tellog"
local skip = true
while true do
    local data, typ, err = wsocket:recv_frame()
    if wsocket.fatal then
        ngx.log(ngx.ERR, "failed to receive frame: ", err)
        return ngx.exit(444)
    end

    local bytes, err, etype = true

    if not data then
        etype, bytes, err = "ping", wsocket:send_ping()
    elseif typ == "close" then
        webtelnet.close()
        break
    elseif typ == "ping" then
        etype, bytes, err = "pong" wsocket:send_pong()
    elseif typ == "pong" then
        ngx.log(ngx.INFO, "client ponged")
    elseif typ == "text" then
        local res, restart = webtelnet.input(data)
        if restart then
            break
        end

        -- if skip then
        --     res = res .. tellog.getAll()
        --     skip = nil
        -- else
        --     tellog.addLog(res)
        -- end

        --NOTE: 如果websocket是纯转发，那么这里就需要注释掉，如果是堆积发送，那么不需要注释
        -- res = string.gsub(res, data, "", 1)

        etype, bytes, err = "text", wsocket:send_text(res)
    end

    if not bytes then
        ngx.log(ngx.ERR, "failed to send " .. etype, err)
        return ngx.exit(444)
    end
end

wsocket:send_close()
