preciso que configure  o seguinte cenario, tenho um serviço que vai rodar com:
```bash
 vibescript health_checker.lua
 ```
em paralelo, duas instancias de servidores  com 
```bash
 vibescript server.lua --start 3000 --end 3100
 vibescript server.lua --start 3101 --end 3200
 ```
 o vibescript pode ser instalado nativamente no alpine com:
```bash
curl -L https://github.com/OUIsolutions/VibeScript/releases/download/0.32.0/vibescript.out -o vibescript.out && sudo cp vibescript.out /usr/bin/vibescript
```
baseado nisso edite o docker-compose.yaml e crie as docker files nescesárias para o projeto.