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
    }
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
os.execute("vibescript server.lua &")
os.execute("k6 run rinha.js")