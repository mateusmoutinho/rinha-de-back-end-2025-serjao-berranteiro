DEFAULT_URL  ="http://payment-processor-default:8080"
FALLBACK_URL ="http://payment-processor-fallback:8080"
-- Define an action
-- Define an action
local get_status = clpr.add_action({
    name = "get_status",
    callback = function(args)
        local result = luabear.fetch({
            url=args.url.."/payments/service-health"
        })
        local result =  result.read_body_json()
        return result
    end
})

clpr.add_main(function ()
        while true do
            local default_status = clpr.start_action(get_status, {url=DEFAULT_URL})
            local fallback_status = clpr.start_action(get_status, {url=FALLBACK_URL})
            os.execute("sleep 5") -- Wait for the services to respond

           
            local response_default = default_status.get_result()
            local response_fallback = fallback_status.get_result()
            print(response_default)
            print(response_fallback)
            if not response_default or not response_fallback then
                print("Error fetching service health")
                dtw.write_file("url.txt","1")
                goto continue
            end
            if response_default.failing == false then 
                print("chose the default payment processor")
                dtw.write_file("url.txt","1")
            else if response_fallback.failing == false then
                print("chose the fallback payment processor") 
                dtw.write_file("url.txt","2")
            else
                print("both payment processors are down, not using")
                dtw.write_file("url.txt","1")
            end
            

        end 
        ::continue::
    end 
end)
