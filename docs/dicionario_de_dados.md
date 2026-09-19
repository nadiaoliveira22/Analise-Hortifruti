# Dicionário de dados

## Base pública: `vendas_diarias_anonimizadas.csv`

| Coluna | Descrição |
|---|---|
| `data` | Data anonimizada e deslocada em formato `AAAA-MM-DD` |
| `faturamento_efetivado` | Faturamento diário de vendas efetivadas, com valores transformados por fator constante |
| `faturamento_pendente` | Valor diário de vendas pendentes, também transformado |
| `qtd_vendas_efetivadas` | Quantidade agregada e reduzida de vendas efetivadas do dia |
| `qtd_vendas_pendentes` | Quantidade agregada e reduzida de vendas pendentes do dia |

## Regras de anonimização

- Dados agregados por dia.
- Remoção de hora, histórico, cliente, pedido e qualquer identificador direto.
- Deslocamento fixo de datas.
- Transformação proporcional dos valores financeiros.
- Redução de precisão nas quantidades de pedidos.