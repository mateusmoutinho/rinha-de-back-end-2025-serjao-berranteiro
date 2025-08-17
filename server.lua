DEFAULT_URL  ="http://localhost:8001"
FALLBACK_URL = "http://localhost:8001"

-- Define your request handler
local function api_handler(request)
  -- Process the request here
   if request.route == "/payments" then 
     local entries = request.read_json_body(400)
     local decided = dtw.load_file("url.txt")
     local decided_url = DEFAULT_URL
     local decided_path = "./data/default"
     if decided == "2" then 
        decided_url = FALLBACK_URL
        decided_path = "./data/fallback"
     end
     
     local requisition = luabear.fetch({
        url = decided_url.."/payments",
        method = "POST",
        body = entries
     })
     if requisition.status == 200 then
        local absolute_time = dtw.get_absolute_time()
        local path = decided_path.."/"..absolute_time.seconds.."_"..absolute_time.nanoseconds
        dtw.write_file(path,tostring(entries.amount))
     end

   end 

   return "AQUI TEM CORAGEM"
end

serjao.server(3000, 5000, api_handler)
