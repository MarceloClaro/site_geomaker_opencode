# 3D Terrain Paper Model

Details are explained in this [blogpost](https://petervojtek.github.io/diy/2015/04/18/3d-paper-model-of-polana-volcano.html)
(hoje acessível apenas via [Wayback Machine](https://web.archive.org/web/20201004070138/https://petervojtek.github.io/diy/2015/04/18/3d-paper-model-of-polana-volcano.html), ver `reversa-analysis/`).

---

## ⚠️ Este script original não funciona mais (API descontinuada)

O script `3d-paper-model.rb` nesta pasta depende da API MapQuest Open Elevation, que
está **descontinuada desde 2022** (o domínio `open.mapquestapi.com` não resolve mais).
Rodá-lo como está vai falhar na primeira chamada de rede.

## ✅ Use a versão modernizada e pronta para execução: [`modernized/`](./modernized/)

A pasta [`modernized/`](./modernized/) contém uma versão totalmente funcional, testada
e **pronta para execução hoje**, com:

- API de elevação gratuita e sem chave (Open-Meteo), no lugar da MapQuest morta;
- Capacidade de gerar modelos para **qualquer localização do planeta** (busca por nome
  de lugar via geocoding, ou coordenadas explícitas) — não apenas Poľana;
- 28 testes automatizados, `Gemfile`/`Rakefile`/`Dockerfile`, `LICENSE` e um script
  único de verificação de ambiente (`bin/setup`).

```bash
cd modernized
./bin/setup                    # prepara e valida o ambiente em um comando
ruby 3d-paper-model.rb --help  # ve todas as opcoes disponiveis
```

Ver [`modernized/README.md`](./modernized/README.md) (quickstart e histórico da
migração) e [`modernized/CHANGELOG-v2.md`](./modernized/CHANGELOG-v2.md) (parametrização
genérica de localização, estilo [TouchTerrain](https://touchterrain.geol.iastate.edu/)).

## 📚 Documentação de engenharia reversa

A pasta [`reversa-analysis/`](./reversa-analysis/) contém a análise completa do sistema
legado (inventário, algoritmos, regras de negócio, arquitetura, especificações
executáveis e revisão crítica), produzida por um pipeline de engenharia reversa
multi-agente antes de qualquer modificação de código.
