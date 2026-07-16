# Instalador WSL do Museu Geomaker

Esta pasta provisiona o site e o laboratório topográfico em Ubuntu/WSL.

- `setup.sh`: instala dependências e configura Nginx + TouchTerrain.
- `start.sh`, `stop.sh` e `status.sh`: controlam os serviços.
- `autenticar-earthengine.sh`: associa uma conta e um projeto Google Cloud.
- `configurar-google-maps.sh`: grava uma chave opcional fora do site público.
- `receber-site.sh`: recebe futuramente um novo ZIP do museu.
- `criar-modelo.sh`: processa uma configuração JSON no modo standalone.
- `samples/`: exemplo GeoTIFF para teste inteiramente local.
- `vendor/TouchTerrain_for_CAGEO/`: código-fonte incluído do fork CAGEO.

Comece pelo roteiro `../INICIAR_NO_WSL.md`.
