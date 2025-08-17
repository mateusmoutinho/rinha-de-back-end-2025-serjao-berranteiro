DEFAULT_URL  ="http://localhost:8001"
FALLBACK_URL ="http://localhost:8002"


set_server.max_queue = 1 
set_server.max_request = 10
set_server.function_timeout = 1
set_server.client_timeout = 100


local function get_summary(database_path,from,to)
   local correlations = dtw.list_files(database_path)
   local result ={
      totalRequests=0,
      totalAmount=0,
   }

   -- Set default values for filtering
   local from_seconds = 0
   local from_milliseconds = 0
   local to_seconds = math.huge
   local to_milliseconds = math.huge
   
   -- If from is provided, use its values
   if from then
      from_seconds = from.seconds 
      from_milliseconds = from.milliseconds
   end
   
   -- If to is provided, use its values
   if to then
      to_seconds = to.seconds
      to_milliseconds = to.milliseconds
   end
   
   for i=1,#correlations do
      local correlation_id = correlations[i]
      local correlation_path = database_path .. "/" .. correlation_id
      
      -- Read the timestamp files
      local seconds_file = correlation_path .. "/seconds"
      local milliseconds_file = correlation_path .. "/milliseconds"
      local amount_file = correlation_path .. "/amount"
      
      if dtw.isfile(seconds_file) and dtw.isfile(milliseconds_file) then
         local element_seconds = tonumber(dtw.load_file(seconds_file))
         local element_milliseconds = tonumber(dtw.load_file(milliseconds_file))
         
         -- Check if the file timestamp is within the range
         local is_after_from = (element_seconds > from_seconds) or 
                              (element_seconds == from_seconds and element_milliseconds >= from_milliseconds)
         local is_before_to = (element_seconds < to_seconds) or 
                             (element_seconds == to_seconds and element_milliseconds <= to_milliseconds)
         
         if is_after_from and is_before_to then
            result.totalRequests = result.totalRequests + 1
            -- Read the amount from the file and add to total
            if dtw.isfile(amount_file) then
               local amount_str = dtw.load_file(amount_file)
               local amount = tonumber(amount_str) or 0
               result.totalAmount = result.totalAmount + amount
            end
         end
      end
   end 
   return result
end



-- Handle payments route
local function handle_payments(request)
   local entries = request.read_json_body(400)
   
   -- Check if correlationId already exists
   if entries.correlationId then
      local correlation_path = "./data/" .. entries.correlationId
      if dtw.isdir(correlation_path) then
         return "", 422  -- Unprocessable Entity - duplicate correlationId
      end
   end
   
   local absolute_time = dtw.get_absolute_time()
   absolute_time.seconds = absolute_time.seconds +  ((60 * 60) * 3)
   absolute_time.milliseconds = absolute_time.milliseconds or 0
   entries.requestedAt = dtw.convert_absolute_time_to_string(absolute_time)
   
   local requisition = luabear.fetch({
      url = DEFAULT_URL.."/payments",
      method = "POST",
      body = entries
   })    
   
   if requisition.status_code == 200 then
      -- Create directory structure for correlationId
      local correlation_path = "./data/" .. entries.correlationId
      dtw.write_file(correlation_path .. "/seconds", tostring(absolute_time.seconds))
      dtw.write_file(correlation_path .. "/milliseconds", tostring(absolute_time.milliseconds))
      dtw.write_file(correlation_path .. "/payment_processor", "1")  -- 1 for default
      dtw.write_file(correlation_path .. "/amount", tostring(entries.amount))
      return "",200
   else
       local fallback_requisition = luabear.fetch({
          url = FALLBACK_URL.."/payments",
          method = "POST",
          body = entries
       })
       if fallback_requisition.status_code == 200 then
          -- Create directory structure for correlationId
          local correlation_path = "./data/" .. entries.correlationId
          dtw.write_file(correlation_path .. "/seconds", tostring(absolute_time.seconds))
          dtw.write_file(correlation_path .. "/milliseconds", tostring(absolute_time.milliseconds))
          dtw.write_file(correlation_path .. "/payment_processor", "2")  -- 2 for fallback
          dtw.write_file(correlation_path .. "/amount", tostring(entries.amount))
          return "",200
       end 
   end
   return "",500
end

-- Handle payments summary route
local function handle_payments_summary(request)
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
   
   -- Get all correlations and filter by payment_processor
   local all_correlations = dtw.list_files("./data")
   local default_total = {totalRequests = 0, totalAmount = 0}
   local fallback_total = {totalRequests = 0, totalAmount = 0}
   
   for i=1,#all_correlations do
      local correlation_id = all_correlations[i]
      local correlation_path = "./data/" .. correlation_id
      local processor_file = correlation_path .. "/payment_processor"
      
      if dtw.isfile(processor_file) then
         local processor = dtw.load_file(processor_file)
         local seconds = tonumber(dtw.load_file(correlation_path .. "/seconds"))
         local milliseconds = tonumber(dtw.load_file(correlation_path .. "/milliseconds"))
         local amount = tonumber(dtw.load_file(correlation_path .. "/amount")) or 0
         
         -- Apply time filtering
         local is_after_from = true
         local is_before_to = true
         
         if from_time_struct then
            is_after_from = (seconds > from_time_struct.seconds) or 
                           (seconds == from_time_struct.seconds and milliseconds >= from_time_struct.milliseconds)
         end
         
         if to_time_struct then
            is_before_to = (seconds < to_time_struct.seconds) or 
                          (seconds == to_time_struct.seconds and milliseconds <= to_time_struct.milliseconds)
         end
         
         if is_after_from and is_before_to then
            if processor == "1" then  -- default
               default_total.totalRequests = default_total.totalRequests + 1
               default_total.totalAmount = default_total.totalAmount + amount
            elseif processor == "2" then  -- fallback
               fallback_total.totalRequests = fallback_total.totalRequests + 1
               fallback_total.totalAmount = fallback_total.totalAmount + amount
            end
         end
      end
   end

   local result =  {
       default = default_total,
      fallback= fallback_total
   }
   return result
end

-- Define your request handler
function api_handler(request)
   -- Process the request here
   if request.route == "/payments" then
      return handle_payments(request)
   elseif request.route == "/payments-summary" then
      return handle_payments_summary(request)
   end

   return "AQUI TEM CORAGEM1"
end

serjao.server(9999, api_handler)