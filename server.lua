DEFAULT_URL  ="http://localhost:8001"
FALLBACK_URL = "http://localhost:8001"

-- Define your request handler
local function api_handler(request)
  -- Process the request here
   if request.route == "/payments" then 
     local entries = request.read_json_body(400)
     local url = ""

   end 


end

serjao.server(3000, 5000, api_handler)
