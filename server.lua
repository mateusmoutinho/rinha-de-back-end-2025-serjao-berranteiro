DEFAULT_URL  ="http://localhost:8001"
FALLBACK_URL ="http://localhost:8002"

local function get_summary(database_path,from,to)
   local files = dtw.list_files(database_path)
   local result ={
      totalRequests=0,
      totalAmount=0,
   }
   for i=1,#files do
      local file = files[i]
      local file_start = string.sub(file,1,10)
      local files_start_number = tonumber(file_start)
      local file_end = string.sub(file,12,21)
      local file_end_number = tonumber(file_end)
   end 
end


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
      local absolute_time = dtw.get_absolute_time()
     entries.requestedAt = dtw.convert_absolute_time_to_string(absolute_time)
     local requisition = luabear.fetch({
        url = decided_url.."/payments",
        method = "POST",
        body = entries
     })    
     if requisition.status_code == 200 then
        local path = decided_path.."/"..absolute_time.seconds.."_"..absolute_time.nanoseconds
        dtw.write_file(path,tostring(entries.amount))
         return "",200
      end
      return "",requisition.status_code
      
   end
   if request.route == "/payments-summary" then
      local start_str = request.params["from"]
      local start_time = nil 
      if start_str then 
         start_time = dtw.get_absolute_time_from_string(start_str)
      end
      local end_str = request.params["to"]
      local end_time = nil
      if end_str then
         end_time = dtw.get_absolute_time_from_string(end_str)
      end
      local default_summary = get_summary("./data/default", start_time, end_time)
   end

   return "AQUI TEM CORAGEM"
end

serjao.server(9999, api_handler)
