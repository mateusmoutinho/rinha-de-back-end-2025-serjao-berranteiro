DEFAULT_URL  ="http://localhost:8001"
FALLBACK_URL ="http://localhost:8002"
-- Define an action
-- Define an action
local get_status = clpr.add_action({
    name = "get_status",
    callback = function(args)
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

            if response_default.failing == false then 
            dtw.write_file("url.txt","1")
        
            else if response_fallback.failing == false then 
            dtw.write_file("url.txt","2")
            else
                dtw.write_file("url.txt","0")
            end

        end 
    end 
end)
