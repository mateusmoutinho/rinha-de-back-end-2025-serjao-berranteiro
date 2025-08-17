
set_server.max_queue = 1 
set_server.max_request = 10000
set_server.function_timeout = 1
set_server.client_timeout = 100
--set_server.single_process = true


-- Define your request handler
local function firmware_handler(request)
    local api_handler = require("server")
   return api_handler(request)
end

serjao.server(9999, firmware_handler)
