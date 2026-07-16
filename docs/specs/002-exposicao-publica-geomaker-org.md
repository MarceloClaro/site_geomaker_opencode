# Especificação 002 — Exposição pública do Geomaker via geomaker.org

Status: em implementação  
Versão-alvo: 2.0.0  
Fonte de verdade: este documento e seus testes de aceitação

## Objetivo

Permitir que qualquer pessoa na internet acesse o Museu Geomaker instalado no WSL usando o domínio `geomaker.org`, sem exigir IP fixo ou configuração manual de roteador.

## Arquitetura

```
Internet → geomaker.org → Cloudflare CDN → cloudflared tunnel → localhost:8080 → Nginx → site estático
                                                                        → localhost:8081 → TouchTerrain
```

A exposição pública usa **Cloudflare Tunnel** (`cloudflared`) por três motivos:

1. **Sem porta aberta** — o túnel é iniciado de dentro do WSL para o Cloudflare, sem exigir port forwarding no roteador ou firewall do Windows.
2. **IP dinâmico** — funciona mesmo que o IP público mude, pois a conexão é sempre originada do WSL.
3. **SSL gratuito** — Cloudflare emite e renova o certificado automaticamente.

## Requisitos funcionais

- **RF-09 — Túnel Cloudflare:** o script `wsl/expor-publicamente.sh` deve instalar o `cloudflared`, autenticar com Cloudflare e criar um túnel que exponha `localhost:8080` na internet.
- **RF-10 — Nome de domínio:** o túnel deve ser roteado para `geomaker.org` (DNS gerenciado pelo Cloudflare). Caso o domínio ainda não esteja registrado, o script deve aceitar um subdomínio `*.trycloudflare.com` temporário para testes.
- **RF-11 — TouchTerrain remoto:** o laboratório deve apontar para o TouchTerrain via túnel separado (porta 8081) quando acessado remotamente, ou manter `localhost:8081` quando acessado localmente.
- **RF-12 — Status integrado:** `wsl/status.sh` deve reportar se o túnel público está ativo e qual URL pública está sendo usada.
- **RF-13 — Parar túnel:** `wsl/stop.sh` deve encerrar o túneo junto com os demais serviços.

## Requisitos não funcionais

- **RNF-06 — Segurança:** o túnel não deve expor portas além de 8080 e 8081; a autenticação do Cloudflare deve ser feita via token, nunca via senha.
- **RNF-07 — Latência:** o túnel adiciona latência de borda CDN (~50-200ms), aceitável para um site estático.
- **RNF-08 — Custo zero:** a solução deve usar o plano gratuito do Cloudflare (sem custo de banda ou túnel).

## Critérios de aceitação

| ID | Dado | Quando | Então | Teste |
|---|---|---|---|---|
| CA-08 | O script expor-publicamente.sh | É executado sem argumentos | Exibe ajuda com as opções disponíveis | `npm run test:wsl` |
| CA-09 | O script com flag `--tunnel` | cloudflared não está instalado | Instala cloudflared, cria túnel e exibe a URL pública | teste manual WSL |
| CA-10 | O script com flag `--quick-tunnel` | Tudo instalado | Cria túnel temporário trycloudflare.com e exibe URL | `npm run test:wsl` + verificação de sintaxe |
| CA-11 | status.sh | Túnel ativo | Reporta "Túnel público: ativo — https://geomaker.org" | teste manual WSL |
| CA-12 | status.sh | Túnel inativo | Reporta "Túnel público: inativo" | `npm run test:wsl` |
| CA-13 | assets/config.js | Acessado remotamente | touchTerrainBaseUrl aponta para túnel do TouchTerrain | validação de lógica no teste |
| CA-14 | O pacote-fonte | `npm test` é executado | Testes existentes + novos terminam sem falhas | `npm test` |

## Fora de escopo

- Registrar o domínio `geomaker.org` — é responsabilidade do mantenedor.
- Configurar o Cloudflare DNS além do túnel (e-mail, MX, etc.).
- Balanceamento de carga ou múltiplas réplicas do site.
- Expor o TouchTerrain com segurança (autenticação); o túnel é para testes controlados.
- ngrok, serveo ou outros serviços de túnel que não sejam Cloudflare.
