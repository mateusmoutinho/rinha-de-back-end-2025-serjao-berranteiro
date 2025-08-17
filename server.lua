DEFAULT_URL  ="http://localhost:8001"
FALLBACK_URL ="http://localhost:8002"
set_server.max_queue = 10000 
set_server.max_request = 10000
set_server.function_timeout = 100

local function get_summary(database_path,from,to)
   local files = dtw.list_files(database_path)
   local result ={
      totalRequests=0,
      totalAmount=0,
   }

   -- Set default values for filtering
   local from_seconds = 0
   local from_nanoseconds = 0
   local to_seconds = math.huge
   local to_nanoseconds = math.huge
   
   -- If from is provided, use its values
   if from then
      from_seconds = from.seconds 
      from_nanoseconds = from.nanoseconds
   end
   
   -- If to is provided, use its values
   if to then
      to_seconds = to.seconds
      to_nanoseconds = to.nanoseconds
   end
   for i=1,#files do
      local element = files[i]
      local element_seconds_str = string.sub(element,1,10)
      local element_seconds = tonumber(element_seconds_str)
      local element_nano_seconds_str = string.sub(element,12,21)
      local element_nano_seconds = tonumber(element_nano_seconds_str)
      
      -- Check if the file timestamp is within the range
      local is_after_from = (element_seconds > from_seconds) or 
                           (element_seconds == from_seconds and element_nano_seconds >= from_nanoseconds)
      local is_before_to = (element_seconds < to_seconds) or 
                          (element_seconds == to_seconds and element_nano_seconds <= to_nanoseconds)
      
      if is_after_from and is_before_to then
         result.totalRequests = result.totalRequests + 1
         -- Read the amount from the file and add to total
         local amount_str = dtw.load_file(database_path .. "/" .. element)
         local amount = tonumber(amount_str) or 0
         result.totalAmount = result.totalAmount + amount
      end
   end 
   return result
end


-- Define your request handler

function api_handler(request)
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
     absolute_time.seconds = absolute_time.seconds +  (60 * 60 * 3)
     entries.requestedAt = dtw.convert_absolute_time_to_string(absolute_time)
     local requisition = luabear.fetch({
        url = decided_url.."/payments",
        method = "POST",
        body = entries
     })    
     if requisition.status_code == 200 then

      local str_miliseconds = string.format("%03d", absolute_time.miliseconds)
      local path = decided_path.."/"..absolute_time.seconds.."_"..str_miliseconds.."_"..dtw.get_pid()
         dtw.write_file(path,tostring(entries.amount))
         return "",200
      end
      return "",requisition.status_code
      
   end
   if request.route == "/payments-summary" then
      local from_str = request.params["from"]
      local from_time_struct = nil 
      if from_str then 
         from_time_struct = dtw.get_absolute_time_from_string(from_str)
      end
      local to_str = request.params["to"]
      local to_time_struct = nil
      if to_str then
         to_time_struct = dtw.get_absolute_time_from_string(to_str)
      end
      local default_sumary = get_summary("./data/default", from_time_struct, to_time_struct)
      local fallback_sumary = get_summary("./data/fallback", from_time_struct, to_time_struct)

      local result =  {
          default = default_sumary,
         fallback= fallback_sumary
      }
      return result

   end

   return "AQUI TEM CORAGEM1"
end
local start_here = argv.flags_exist({ "start" })
if start_here then 
   serjao.server(9999, api_handler)
end 

return api_handler