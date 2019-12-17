local addr = "192.168.2.123"
local port = 23

local sock
local function con_socket()
    if sock then
        ngx.log(nx.ERR, "already connect telnet")
        return
    end

    sock = ngx.socket.tcp()
    local ok, err = sock:connect(addr, port)
    if not ok then
        ngx.log(ngx.ERR, "failed to connect telnet")
        return
    end
    sock:settimeout(50)
end

local co = coroutine.create(function()
    while true do
        local result = ""
        local input
        while true do
            local res = sock:receiveany(1024) 
            --NOTE: 如若是用sock:receive(number)，那么必定会等到读到了指定长度的数据才会返回/或者连接断开。
            --NOTE: 用receiveany则会读取最长不超过指定长度的数据。
            if not res then
                input = coroutine.yield(result)
                break
            end

            result = result .. res
        end

        if input then
            sock:send(input .. "\r\n")
        end

        if input == "exit" then
            sock:close()
            sock = nil
            return
        end
    end
end)

return {
    connect = function()
        con_socket()
    end,
    input = function(cmd)
        local ok, output = coroutine.resume(co, cmd)
        if ok and output then
            return output
        end

        ngx.log(ngx.ERR, "telnet connect has been dead")
        return nil, true
    end,
    close = function()
        sock:close()
    end
}
