DEFAULT_URL  ="http://localhost:8001"
FALLBACK_URL ="http://localhost:8002"
-- Define an action
-- Define an action
local get_status = clpr.add_action({
    name = "get_status",

    callback = function(args)
    error("aaa")

        local result = luabear.fetch({
            url=args.url.."/payments/service-health"
        })
        return result.read_body_json()
    end
})

clpr.add_main(function ()
        while true do

            local default_status = clpr.start_action(get_status, {url=DEFAULT_URL})
            local fallback_status = clpr.start_action(get_status, {url=FALLBACK_URL})
            default_status.wait(10000, function() os.execute("sleep 0.1") end)
            fallback_status.wait(1000, function() os.execute("sleep 0.1") end)
            local response_default = default_status.get_result()
            local response_fallback = fallback_status.get_result()
            if not response_default or not response_fallback then
                print("Error fetching service health")
                dtw.write_file("url.txt","0")
                return
            end
            if response_default.failing == false then 
                print("chose the default payment processor")
                dtw.write_file("url.txt","1")
            else if response_fallback.failing == false then
                print("chose the fallback payment processor") 
                dtw.write_file("url.txt","2")
            else
                print("both payment processors are down, not using")
                dtw.write_file("url.txt","0")
            end

        end 
    end 
end)
