# Processo SDD e TDD

O projeto usa **Spec-Driven Development (SDD)** para definir o comportamento antes da implementação e **Test-Driven Development (TDD)** para transformar cada critério verificável em teste automatizado.

## Ciclo de mudança

1. Criar ou atualizar uma especificação em `docs/specs/`.
2. Acrescentar um critério de aceitação com identificador estável.
3. Escrever primeiro o teste que representa o comportamento desejado e confirmar que ele falha pelo motivo esperado.
4. Implementar a menor alteração que faz o teste passar.
5. Refatorar preservando o resultado de `npm test`.
6. Atualizar a matriz da especificação e a documentação do usuário.

## Suítes

- `npm run test:site`: comportamento das nove páginas, links, recursos, Tainacan, Geólogo Digital, Terra Antiga e Preparador CAGEO.
- `npm run test:wsl`: estrutura do pacote, sintaxe dos scripts, portas locais, credenciais, revisão do fork e amostra GeoTIFF.
- `npm test`: porta de qualidade completa; deve ser executada antes de gerar o ZIP.

Os casos que dependem do WSL real, de `sudo` ou de consentimento OAuth permanecem identificados como testes manuais ou de integração na especificação. Eles não devem ser simulados como se fossem testes completos.
