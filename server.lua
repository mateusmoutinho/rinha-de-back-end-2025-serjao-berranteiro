DEFAULT_URL  ="http://localhost:8001"
FALLBACK_URL ="http://localhost:8002"


set_server.max_queue = 1000
set_server.max_request = 100000
set_server.function_timeout = 1
set_server.client_timeout = 100

-- Function to validate payment schema
local function validate_payment_schema(entries)
   -- Check if entries is a table
   if type(entries) ~= "table" then
      return false, "Request body must be a valid JSON object"
   end
   
   -- Check required fields
   if not entries.correlationId then
      return false, "Missing required field: correlationId"
   end
   
   if type(entries.correlationId) ~= "string" then
      return false, "correlationId must be a string"
   end
   
   if not entries.amount then
      return false, "Missing required field: amount"
   end
   
   if type(entries.amount) ~= "number" then
      return false, "amount must be a number"
   end
   
   -- Add other validations as needed
   -- For example:
   -- if not entries.description or type(entries.description) ~= "string" then
   --    return false, "description must be a valid string"
   -- end
   
   return true, nil
end
local function write_ensuring(path,content)
   while true do 

      dtw.write_file(path,content)
      local content_read = dtw.load_file(path)
      if content_read == content then
         return true
      end 
   end 

end 
function load_ensuring(path)

   while true do 
      local content = dtw.load_file(path)
      if content then
         return content
      end 
   end 
   
end
-- Handle payments route
local function handle_payments(request)
   local entries = request.read_json_body(4000)
   
   -- Validate schema
   local is_valid, error_message = validate_payment_schema(entries)
   if not is_valid then
      return serjao.send_text(error_message, 400)  -- Bad Request
   end
   
   -- Check if correlationId already exists
   local locker = dtw.newLocker()
   local correlation_path = "./data/" .. entries.correlationId
   
   -- Lock before checking to prevent race conditions
   locker.lock(correlation_path)
   
   if dtw.isdir(correlation_path) then
      locker.unlock(correlation_path)
      return serjao.send_text(" ", 500 )
   end 
   -- Create directory explicitly before writing to it
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
            write_ensuring(correlation_path .. "/seconds", tostring(absolute_time.seconds))
            write_ensuring(correlation_path .. "/milliseconds", tostring(absolute_time.milliseconds))
            write_ensuring(correlation_path .. "/payment_processor", "1")  -- 1 for default
            write_ensuring(correlation_path .. "/amount", tostring(entries.amount))
            
            locker.unlock(correlation_path)
            return serjao.send_text(" ", 200)
         end
         
         -- Try fallback only if DEFAULT failed
         local fallback_requisition = luabear.fetch({
            url = FALLBACK_URL.."/payments",
            method = "POST",
            body = entries
         })
         print("fall back status code of requisition: " .. fallback_requisition.status_code)
         if fallback_requisition.status_code == 200 then
            write_ensuring(correlation_path .. "/seconds", tostring(absolute_time.seconds))
            write_ensuring(correlation_path .. "/milliseconds", tostring(absolute_time.milliseconds))
            write_ensuring(correlation_path .. "/payment_processor", "2")  -- 2 for fallback
            write_ensuring(correlation_path .. "/amount", tostring(entries.amount))
                  
            locker.unlock(correlation_path)
            return serjao.send_text(" ", 200)
         end
   -- If both processors failed, remove the directory we created
   locker.unlock(correlation_path)

   return serjao.send_text(" ", 422)
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
      
      local processor =load_ensuring(processor_file)
      local seconds = tonumber(load_ensuring(correlation_path .. "/seconds"))
      local milliseconds = tonumber(load_ensuring(correlation_path .. "/milliseconds"))
      local amount = tonumber(load_ensuring(correlation_path .. "/amount")) or 0
      
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
   end

   return "AQUI TEM CORAGEM1"
end

serjao.server(9999, api_handler)