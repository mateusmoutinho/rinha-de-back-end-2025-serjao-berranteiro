
set_server.max_queue = 10000 
set_server.max_request = 10000
set_server.function_timeout = 100
set_server.single_process = true


-- Define your request handler
local function firmware_handler(request)
    relative_load("server.lua")
   return api_handler(request)
end

serjao.server(9999, firmware_handler)
