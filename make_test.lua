dtw.remove_any("data")
dtw.remove_any("debug")
local required_files = {
    {
        url ="https://raw.githubusercontent.com/zanfranceschi/rinha-de-backend-2025/refs/heads/main/payment-processor/init.sql",
        file="init.sql"
    },
    {
        url="https://raw.githubusercontent.com/zanfranceschi/rinha-de-backend-2025/refs/heads/main/payment-processor/docker-compose.yml",
        file="payments.yaml"
    },
    {
        url="https://raw.githubusercontent.com/zanfranceschi/rinha-de-backend-2025/refs/heads/main/rinha-test/rinha.js",
        file="rinha.js"
    },
    {
        url="https://raw.githubusercontent.com/zanfranceschi/rinha-de-backend-2025/refs/heads/main/rinha-test/requests.js",
        file="requests.js"
    },
    {
        url = "https://github.com/OUIsolutions/VibeScript/releases/download/0.32.0/alpine_with_get_addr_info.out",
        file="vibescript.out"
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

os.execute("chmod +x vibescript.out")

os.execute("docker compose -f payments.yaml down -v")
os.execute("docker compose -f payments.yaml up -d")
os.execute("sleep 20") -- Wait for the server to be fully up


-- Start new docker-compose scenario first
os.execute("docker compose -f docker-compose.yaml down -v")
os.execute("docker compose -f docker-compose.yaml build ") 
os.execute("docker compose -f docker-compose.yaml up -d")
os.execute("sleep 20") -- Wait for the new services to be fully up
while true do end

os.execute("k6 run rinha.js")
os.execute("docker compose -f payments.yaml down -v")
os.execute("docker compose -f docker-compose.yaml down -v")
