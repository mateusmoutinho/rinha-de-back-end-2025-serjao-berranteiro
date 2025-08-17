DEFAULT_URL  ="http://localhost:8001"
FALLBACK_URL ="http://localhost:8002"


set_server.max_queue = 1000
set_server.max_request = 1000
set_server.function_timeout = 100
set_server.client_timeout = 100


-- Handle payments route
local function handle_payments(request)
   local entries = request.read_json_body(400)
   
   -- Check request limit first
   local counter_locker = dtw.newLocker()
   local counter_path = "./data/request_counter"
   counter_locker.lock(counter_path)
   
   -- Read current count
   local current_count = 0
   if dtw.isfile(counter_path) then
      current_count = tonumber(dtw.load_file(counter_path)) or 0
   end
   
   -- Check if we've reached the limit
   if current_count >= 1000 then
      counter_locker.unlock(counter_path)
      return "Request limit reached", 503  -- Service Unavailable
   end
   
   -- Check if correlationId already exists
   local locker = dtw.newLocker()

   local correlation_path = "./data/" .. entries.correlationId
   locker.lock(correlation_path)

   if dtw.isdir(correlation_path) then
      locker.unlock(correlation_path)
      counter_locker.unlock(counter_path)
      return "", 422  -- Unprocessable Entity - duplicate correlationId
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
   print("Default processor response code: " .. requisition.read_body())
   if requisition.status_code == 200 then
   
      dtw.write_file(correlation_path .. "/seconds", tostring(absolute_time.seconds))
      dtw.write_file(correlation_path .. "/milliseconds", tostring(absolute_time.milliseconds))
      dtw.write_file(correlation_path .. "/payment_processor", "1")  -- 1 for default
      dtw.write_file(correlation_path .. "/amount", tostring(entries.amount))
      
      -- Increment counter only on success
      dtw.write_file(counter_path, tostring(current_count + 1))
      
      locker.unlock(correlation_path)
      counter_locker.unlock(counter_path)
      return "", 200  -- IMPORTANTE: Retornar aqui para evitar continuar
   end
   
   -- Só tenta fallback se o DEFAULT falhou
   local fallback_requisition = luabear.fetch({
      url = FALLBACK_URL.."/payments",
      method = "POST",
      body = entries
   })
   print("Fallback processor response code: " .. fallback_requisition.read_body())
   if fallback_requisition.status_code == 200 then
      dtw.write_file(correlation_path .. "/seconds", tostring(absolute_time.seconds))
      dtw.write_file(correlation_path .. "/milliseconds", tostring(absolute_time.milliseconds))
      dtw.write_file(correlation_path .. "/payment_processor", "2")  -- 2 for fallback
      dtw.write_file(correlation_path .. "/amount", tostring(entries.amount))
      
      -- Increment counter only on success
      dtw.write_file(counter_path, tostring(current_count + 1))
      
      locker.unlock(correlation_path)
      counter_locker.unlock(counter_path)
      return " ", 200  -- IMPORTANTE: Retornar aqui também
   end

   locker.unlock(correlation_path)
   counter_locker.unlock(counter_path)
   return " ", 500
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
   local all_correlations = dtw.list_dirs("./data")
   local default_total = {totalRequests = 0, totalAmount = 0}
   local fallback_total = {totalRequests = 0, totalAmount = 0}
   
   for i=1,#all_correlations do
      local correlation_id = all_correlations[i]
      local correlation_path = "./data/" .. correlation_id
      local processor_file = correlation_path .. "/payment_processor"
      
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
   elseif request.route == "/reset-counter" then
      -- Optional: Add a route to reset the counter for testing
      local counter_locker = dtw.newLocker()
      local counter_path = "./data/request_counter"
      counter_locker.lock(counter_path)
      dtw.write_file(counter_path, "0")
      counter_locker.unlock(counter_path)
      return {message = "Counter reset", count = 0}
   elseif request.route == "/get-counter" then
      -- Optional: Get current counter value
      local count = 0
      if dtw.isfile("./data/request_counter") then
         count = tonumber(dtw.load_file("./data/request_counter")) or 0
      end
      return {current_count = count, limit = 200}
   end

   return "AQUI TEM CORAGEM1"
end

serjao.server(9999, api_handler)