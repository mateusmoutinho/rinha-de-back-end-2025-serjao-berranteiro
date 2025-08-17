local server = clpr.add_action({
    name="server",
    callback=function ()
        relative_load("server.lua")
    end
})
clpr.add_main(function ()


    dtw.remove_any("data")
    clpr.start_action(server)
    local required_files = {
        {
            url ="https://raw.githubusercontent.com/zanfranceschi/rinha-de-backend-2025/refs/heads/main/payment-processor/init.sql",
            file="init.sql"
        },
        {
            url="https://raw.githubusercontent.com/zanfranceschi/rinha-de-backend-2025/refs/heads/main/payment-processor/docker-compose.yml",
            file="payments.yaml"
        },
        {url="https://raw.githubusercontent.com/zanfranceschi/rinha-de-backend-2025/refs/heads/main/rinha-test/rinha.js",
        file="rinha.js"
        },
        {url="https://raw.githubusercontent.com/zanfranceschi/rinha-de-backend-2025/refs/heads/main/rinha-test/requests.js",
        file="requests.js"
        },
    }   
    for i=1,#required_files do
        local current = required_files[i]
        if not dtw.isfile(current.file) then
            print("Downloading "..current.url.." to "..current.file)
            local cmd = string.format("curl -L %s -o %s", current.url, current.file)
            os.execute(cmd)
        end
    end

    os.execute("docker compose -f payments.yaml down -v")
    os.execute("docker compose -f payments.yaml up -d")
    os.execute("sleep 5") -- Wait for the server to be fully up
    os.execute("k6 run -e MAX_REQUESTS=1 rinha.js")
end)
