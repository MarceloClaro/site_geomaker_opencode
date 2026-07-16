# Museu Geomaker — instalação local no WSL do Windows

Este ZIP contém o site, a Terra Antiga em português, o código do TouchTerrain_for_CAGEO e os instaladores necessários. Nginx serve o museu em `http://localhost:8080` e Gunicorn executa o TouchTerrain em `http://localhost:8081`.

## 1. Instalar o WSL

No PowerShell do Windows, como administrador:

```powershell
wsl --install -d Ubuntu
```

Reinicie o Windows se solicitado e conclua a criação do usuário Ubuntu.

## 2. Extrair o pacote dentro do WSL

No terminal Ubuntu/WSL, troque o caminho abaixo pelo local real do ZIP no Windows:

```bash
mkdir -p ~/geomaker-instalador
cd ~/geomaker-instalador
unzip /mnt/c/Users/SEU_USUARIO/Downloads/Geomaker_site.zip
```

É melhor extrair em `~/geomaker-instalador` que executar diretamente em `/mnt/c`, pois o sistema de arquivos Linux é mais rápido para Python e GDAL.

## 3. Instalar tudo

Dentro da pasta que contém `index.html`:

```bash
bash wsl/setup.sh
```

O instalador prepara automaticamente Nginx, Python, ambiente virtual, GDAL, Flask, Gunicorn, Earth Engine e o TouchTerrain empacotado. Os arquivos finais ficam em `/opt/geomaker`.

## 4. Autorizar o Earth Engine

Esta é a única etapa que não pode ser automatizada, porque o Google exige a confirmação da pessoa responsável pela conta. Antes, crie ou escolha um projeto Google Cloud, habilite a Earth Engine API e registre o projeto para uso comercial ou não comercial. O comando solicitará o ID desse projeto:

```bash
bash /opt/geomaker/installer/autenticar-earthengine.sh
```

Abra o endereço exibido, entre com a conta Google autorizada e conclua o vínculo. Depois acesse:

- Museu: http://localhost:8080
- Laboratório: http://localhost:8080/laboratorio.html
- TouchTerrain direto: http://localhost:8081

Uma chave do Google Maps é opcional. Para configurá-la sem mostrá-la nos logs:

```bash
bash /opt/geomaker/installer/configurar-google-maps.sh
```

## Comandos de operação

```bash
bash /opt/geomaker/installer/status.sh
bash /opt/geomaker/installer/start.sh
bash /opt/geomaker/installer/stop.sh
```

## 5. Expor o site na internet (opcional)

O pacote inclui o script `wsl/expor-publicamente.sh` que cria um **Cloudflare Tunnel** — um túnel seguro que dispensa IP fixo, port forwarding ou configuração de roteador. Qualquer pessoa na internet acessa o site em `https://geomaker.org`.

### Opção A — Túnel temporário (teste rápido, sem domínio)

```bash
bash wsl/expor-publicamente.sh install
bash wsl/expor-publicamente.sh quick-tunnel
```

O comando exibirá uma URL do tipo `https://qualquer-coisa.trycloudflare.com`. Compartilhe essa URL para testes.

### Opção B — Túnel permanente com domínio próprio

1. Registre `geomaker.org` e gerencie o DNS pelo Cloudflare.
2. Crie um token de API no Cloudflare com permissão "Cloudflare Tunnel — Edit".
3. Salve o token em `~/.cloudflare/token`:

   ```bash
   mkdir -p ~/.cloudflare
   nano ~/.cloudflare/token
   chmod 600 ~/.cloudflare/token
   ```

4. Configure o túnel:

   ```bash
   bash wsl/expor-publicamente.sh tunnel geomaker.org
   ```

O túnel será ativado como serviço systemd (ou background) automaticamente.

### Monitoramento

```bash
bash /opt/geomaker/installer/status.sh
```

A saída incluirá o status do túneo público.

Para receber uma versão mais nova do site:

```bash
bash /opt/geomaker/installer/receber-site.sh /mnt/c/caminho/novo-site.zip
```

Para processar no modo standalone um JSON baixado pelo Preparador CAGEO:

```bash
bash /opt/geomaker/installer/criar-modelo.sh ~/Downloads/geomaker-crateus.json
```

Os modelos e relatórios serão gravados em `/opt/geomaker/data/exports`.

O pacote também traz um pequeno GeoTIFF demonstrativo, que não consulta o Earth Engine. Ele serve para confirmar a geração local de uma malha STL:

```bash
bash /opt/geomaker/installer/criar-modelo.sh /opt/geomaker/installer/samples/exemplo-local.json
```

## Observações

- O site e a Terra Antiga funcionam totalmente locais depois da instalação.
- O programa TouchTerrain roda localmente, mas a obtenção de um DEM online ainda usa o Google Earth Engine.
- Para trabalhar sem Earth Engine, use no modo standalone um arquivo GeoTIFF local em `importedDEM`.
- Os visualizadores do Sketchfab, o catálogo Tainacan e as análises por Gemini ou Grok continuam dependendo dos respectivos serviços externos quando forem usados.
- Modelos grandes podem consumir bastante memória e levar vários minutos.
- O instalador não inclui PHP porque este site não precisa dele.
