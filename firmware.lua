
set_server.max_queue = 10000 
set_server.max_request = 10000
set_server.function_timeout = 100



-- Define your request handler
local function firmware_handler(request)
   local api_hanlder = require("server")
   return api_hanlder(request)
end

serjao.server(9999, firmware_handler)
