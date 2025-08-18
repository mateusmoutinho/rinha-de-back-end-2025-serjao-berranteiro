DEFAULT_URL  ="http://payment-processor-default:8080"
FALLBACK_URL ="http://payment-processor-fallback:8080"


set_server.max_queue = 1000
set_server.max_request = 10000
set_server.function_timeout = 3
set_server.client_timeout = 100
set_server.signle_process = true
-- Handle payments route
local function handle_payments(request)
   local entries = request.read_json_body(4000)
   
   -- Check if correlationId already exists
   local locker = dtw.newLocker()
   local correlation_path = "./data/" .. entries.correlationId
   
   -- Lock before checking to prevent race conditions
   locker.lock(correlation_path)
   
   if dtw.isdir(correlation_path) then
      locker.unlock(correlation_path)
      return serjao.send_text(" ", 500 )
   end 
      local chosed_url = nil
      local url_chosed = dtw.load_file("url.txt")

      
      if url_chosed == "0" then
         locker.unlock(correlation_path)
         return serjao.send_text(" ", 422) -- Both processors are down
      elseif url_chosed == "1" then
         chosed_url = DEFAULT_URL
      elseif url_chosed == "2" then
         chosed_url = FALLBACK_URL
      else
         error("Invalid url_chosed value: " .. tostring(url_chosed))
      end
   -- Create directory explicitly before writing to it
      local absolute_time = dtw.get_absolute_time()
      absolute_time.seconds = absolute_time.seconds +  ((60 * 60) * 3)
      absolute_time.milliseconds = absolute_time.milliseconds or 0
      entries.requestedAt = dtw.convert_absolute_time_to_string(absolute_time)
      local requisition = luabear.fetch({
         url = chosed_url.."/payments",
         method = "POST",
         body = entries
      })    
      if requisition.status_code == 200 then
         dtw.write_file(correlation_path .. "/seconds", tostring(absolute_time.seconds))
         dtw.write_file(correlation_path .. "/milliseconds", tostring(absolute_time.milliseconds))
         dtw.write_file(correlation_path .. "/payment_processor",url_chosed)  -- 1 for default
         dtw.write_file(correlation_path .. "/amount", tostring(entries.amount))
         
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
   
      local processor =dtw.load_file(processor_file)
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
   end

   return "AQUI TEM CORAGEM1"
end

local start_server = clpr.add_action({
    name = "start_server",
    callback = function(args)
        serjao.server(args.port, api_handler)
    end
})

clpr.add_main(function ()
   local start =  argv.get_flag_arg_by_index({ "start" },1)
   local start_num = tonumber(start)
   if not start_num or start_num < 1 or start_num > 65535 then
      print("Invalid port number. Please provide a port between 1 and 65535.")
      return
   end
   local end_port = argv.get_flag_arg_by_index({ "end" },1)
   local end_num = tonumber(end_port)
   if not end_num or end_num < 1 or end_num > 65535 then
      print("Invalid port number. Please provide a port between 1 and 65535.")
      return
   end
   
   local all ={}
   
   for port = start_num, end_num do
      all[#all+1] = clpr.start_action(start_server, {port = port})
   end
   while true do end 
end)