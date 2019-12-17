local username = "root"
local passsword = "Kilo25070View03653"

local server = require "resty.websocket.server"

local wsocket, err = server:new{
    timeout = 5000, --TODO:配置超时时间
    max_playload_len = 65535
}

if not wsocket then
    ngx.log(ngx.ERR, "failed to new websocket: ", err)
    return ngx.exit(444)
end

local webtelnet = dofile ("lualib/webtelnet.lua")
--NOTE: 不会根据package.path进行搜索，而是根据相对路径搜索，而此处的应该是相对openresty的解释器的相对路径(openresty根目录)
webtelnet.connect()
while true do
    local auto_out = webtelnet.input()
    if auto_out ~= "" then
        if string.find(auto_out, "ogin:") then
            auto_out = webtelnet.input(username)
        end
        if string.find(auto_out, "assword:") then
            auto_out = webtelnet.input(passsword)
            break
        end
    end
end

local function ascii_str(res)
    local byte_s = ""
    for i = 1, #res do
        local b = string.byte(string.sub(res, i, i))
        if b < 127 then
            byte_s = byte_s .. b .. "-"
        end
    end
    return byte_s
end

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

        local ascii = ascii_str(tostring(res))
        etype, bytes, err = "text", wsocket:send_text("from nginx:" ..  tostring(ascii) .. "\n")
    end

    if not bytes then
        ngx.log(ngx.ERR, "failed to send " .. etype, err)
        return ngx.exit(444)
    end
end

wsocket:send_close()
