## analise_feriados_e_pendentes.R
##
## Analisa feriados, tipos de dia, Natal e Ano Novo.
##
## O gráfico de feriados compara:
##   - faturamento real no feriado;
##   - média de dias normais do mesmo dia da semana.
##
## Os arquivos são salvos em:
##   outputs feriado/graficos
##   outputs feriado/tabelas

## ---- 1. Pacotes ----

pacotes <- c(
  "dplyr",
  "ggplot2",
  "lubridate",
  "readr",
  "scales",
  "tidyr"
)

for (pacote in pacotes) {
  if (!requireNamespace(pacote, quietly = TRUE)) {
    install.packages(pacote)
  }
}

library(dplyr)
library(ggplot2)
library(lubridate)
library(readr)
library(scales)
library(tidyr)

## ---- 2. Configurações ----

arquivo_dados <- "vendas_caixa.csv"
data_natal_fechado <- as.Date("2025-12-25")
pasta_saida <- "outputs feriado"
pasta_graficos <- file.path(pasta_saida, "graficos")
pasta_tabelas <- file.path(pasta_saida, "tabelas")

dir.create(pasta_graficos, recursive = TRUE, showWarnings = FALSE)
dir.create(pasta_tabelas, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(arquivo_dados)) {
  stop(
    "O arquivo vendas_caixa.csv não foi encontrado na pasta: ",
    getwd()
  )
}

## ---- 3. Funções visuais ----

formato_reais <- function(x) {
  dollar(
    x,
    prefix = "R$ ",
    big.mark = ".",
    decimal.mark = ",",
    accuracy = 0.01
  )
}

cores_cenario <- c(
  "Efetivado" = "#9CC4D1",
  "Efetivado + Pendente" = "#080887"
)

tema_apresentacao <- theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(
      size = 18,
      face = "bold",
      margin = margin(bottom = 8)
    ),
    plot.subtitle = element_text(
      size = 13,
      margin = margin(bottom = 18)
    ),
    axis.title = element_text(
      size = 13,
      face = "bold"
    ),
    axis.text.x = element_text(
      angle = 20,
      hjust = 1,
      size = 11
    ),
    axis.text.y = element_text(size = 11),
    legend.position = "top",
    legend.title = element_text(
      size = 12,
      face = "bold"
    ),
    legend.text = element_text(size = 12),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    plot.margin = margin(15, 20, 20, 20)
  )

## ---- 4. Carregar dados ----

dados <- read_csv(
  arquivo_dados,
  locale = locale(decimal_mark = "."),
  col_types = cols(
    data = col_character(),
    hora = col_character(),
    historico = col_character(),
    tipo = col_character(),
    valor = col_double()
  )
) %>%
  mutate(data_dt = dmy(data))

## ---- 5. Criar cenários ----

movimentos_efetivado <- dados %>%
  filter(tipo == "venda") %>%
  mutate(cenario = "Efetivado")

movimentos_com_pendente <- dados %>%
  filter(tipo %in% c("venda", "venda_pendente")) %>%
  mutate(cenario = "Efetivado + Pendente")

movimentos_geral <- bind_rows(
  movimentos_efetivado,
  movimentos_com_pendente
) %>%
  mutate(
    cenario = factor(
      cenario,
      levels = c(
        "Efetivado",
        "Efetivado + Pendente"
      )
    )
  )

## ---- 6. Faturamento diário ----

resumo_dia <- movimentos_geral %>%
  group_by(cenario, data_dt) %>%
  summarise(
    faturamento = sum(valor, na.rm = TRUE),
    qtd_registros = n(),
    .groups = "drop"
  )

## ---- 7. Feriados nacionais ----

feriados_nacionais <- as_date(c(
  "2025-01-01",
  "2025-03-03",
  "2025-03-04",
  "2025-04-18",
  "2025-04-21",
  "2025-05-01",
  "2025-06-19",
  "2025-09-07",
  "2025-10-12",
  "2025-11-02",
  "2025-11-15",
  "2025-11-20",
  "2025-12-25",
  "2026-01-01",
  "2026-02-16",
  "2026-02-17",
  "2026-04-03",
  "2026-04-21",
  "2026-05-01",
  "2026-06-04",
  "2026-09-07"
))

## ---- 8. Classificar os dias ----

resumo_dia <- resumo_dia %>%
  mutate(
    dia_semana_num = wday(data_dt, week_start = 1),
    fim_de_semana = dia_semana_num %in% c(6, 7),
    eh_feriado = data_dt %in% feriados_nacionais,
    vespera_feriado = (
      data_dt + days(1)
    ) %in% feriados_nacionais,
    pos_feriado = (
      data_dt - days(1)
    ) %in% feriados_nacionais,
    classificacao = case_when(
      eh_feriado ~ "Feriado nacional",
      vespera_feriado ~ "Véspera de feriado",
      pos_feriado ~ "Dia seguinte ao feriado",
      fim_de_semana ~ "Fim de semana sem feriado",
      TRUE ~ "Dia útil comum"
    ),
    classificacao = factor(
      classificacao,
      levels = c(
        "Feriado nacional",
        "Véspera de feriado",
        "Dia seguinte ao feriado",
        "Fim de semana sem feriado",
        "Dia útil comum"
      )
    )
  )

## ---- 9. Resumo por tipo de dia ----

resumo_classificacao <- resumo_dia %>%
  group_by(cenario, classificacao) %>%
  summarise(
    faturamento_medio = mean(faturamento),
    faturamento_total = sum(faturamento),
    dias_no_periodo = n(),
    .groups = "drop"
  )

## ---- 10. Média de dias normais equivalentes ----
## Exclui feriados, vésperas e dias seguintes a feriados.
## A média é calculada separadamente por dia da semana.

media_por_dia_semana <- resumo_dia %>%
  filter(
    !eh_feriado,
    !vespera_feriado,
    !pos_feriado
  ) %>%
  group_by(
    cenario,
    dia_semana_num
  ) %>%
  summarise(
    faturamento_medio_normal = mean(
      faturamento,
      na.rm = TRUE
    ),
    .groups = "drop"
  )

## ---- 11. Comparação feriado x dia normal equivalente ----

comparativo_feriados <- resumo_dia %>%
  filter(eh_feriado) %>%
  left_join(
    media_por_dia_semana,
    by = c(
      "cenario",
      "dia_semana_num"
    )
  ) %>%
  mutate(
    diferenca = faturamento -
      faturamento_medio_normal,
    diferenca_percentual = (
      faturamento /
        faturamento_medio_normal - 1
    ) * 100
  ) %>%
  select(
    cenario,
    data_dt,
    faturamento,
    faturamento_medio_normal,
    diferenca,
    diferenca_percentual
  ) %>%
  arrange(cenario, data_dt)

comparativo_grafico <- comparativo_feriados %>%
  filter(cenario == "Efetivado") %>%
  select(
    data_dt,
    faturamento,
    faturamento_medio_normal
  ) %>%
  pivot_longer(
    cols = c(
      faturamento,
      faturamento_medio_normal
    ),
    names_to = "tipo_valor",
    values_to = "valor"
  ) %>%
  mutate(
    tipo_valor = recode(
      tipo_valor,
      faturamento = "Feriado",
      faturamento_medio_normal =
        "Média do mesmo dia da semana"
    )
  )

## ---- 12. Resumo de Natal e Ano Novo ----

resumo_fim_ano <- resumo_dia %>%
  filter(data_dt != data_natal_fechado) %>%
  mutate(
    periodo = case_when(
      month(data_dt) == 12 &
        day(data_dt) %in% 15:24 ~
        "Antes do Natal\n15/12 a 24/12",
      month(data_dt) == 12 &
        day(data_dt) %in% 26:31 ~
        "Entre Natal e Ano Novo\n26/12 a 31/12",
      month(data_dt) == 1 &
        day(data_dt) %in% 1:7 ~
        "Ano Novo e primeiros dias\n01/01 a 07/01",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(periodo))

## ---- 13. Completar datas de fim de ano ----

periodo_datas <- tibble(
  data_dt = seq(
    as.Date("2025-12-15"),
    as.Date("2026-01-07"),
    by = "day"
  )
) %>%
  filter(data_dt != data_natal_fechado)

cenarios <- tibble(
  cenario = factor(
    c(
      "Efetivado",
      "Efetivado + Pendente"
    ),
    levels = c(
      "Efetivado",
      "Efetivado + Pendente"
    )
  )
)

base_completa <- crossing(
  cenario = cenarios$cenario,
  data_dt = periodo_datas$data_dt
)

resumo_fim_ano_completo <- base_completa %>%
  left_join(
    resumo_fim_ano %>%
      select(
        cenario,
        data_dt,
        faturamento,
        qtd_registros
      ),
    by = c(
      "cenario",
      "data_dt"
    )
  ) %>%
  mutate(
    faturamento = replace_na(
      faturamento,
      0
    ),
    qtd_registros = replace_na(
      qtd_registros,
      0
    ),
    periodo = case_when(
      month(data_dt) == 12 &
        day(data_dt) %in% 15:24 ~
        "Antes do Natal\n15/12 a 24/12",
      month(data_dt) == 12 &
        day(data_dt) %in% 26:31 ~
        "Entre Natal e Ano Novo\n26/12 a 31/12",
      month(data_dt) == 1 &
        day(data_dt) %in% 1:7 ~
        "Ano Novo e primeiros dias\n01/01 a 07/01",
      TRUE ~ NA_character_
    ),
    periodo = factor(
      periodo,
      levels = c(
        "Antes do Natal\n15/12 a 24/12",
        "Entre Natal e Ano Novo\n26/12 a 31/12",
        "Ano Novo e primeiros dias\n01/01 a 07/01"
      )
    )
  ) %>%
  filter(!is.na(periodo))

tabela_fim_ano <- resumo_fim_ano_completo %>%
  group_by(cenario, periodo) %>%
  summarise(
    faturamento_total = sum(faturamento),
    faturamento_medio_dia = mean(faturamento),
    menor_venda_diaria = min(faturamento),
    maior_venda_diaria = max(faturamento),
    dias_analisados = n(),
    dias_com_registro = sum(qtd_registros > 0),
    .groups = "drop"
  )

## ---- 14. Gráfico: tipo de dia ----

grafico_classificacao <- ggplot(
  resumo_classificacao,
  aes(
    x = classificacao,
    y = faturamento_medio,
    fill = cenario
  )
) +
  geom_col(
    position = position_dodge(width = 0.85),
    width = 0.68
  ) +
  geom_text(
    aes(
      label = formato_reais(faturamento_medio)
    ),
    position = position_dodge(width = 0.85),
    vjust = -0.45,
    size = 3,
    fontface = "bold",
    color = "black",
    show.legend = FALSE
  ) +
  scale_y_continuous(
    labels = formato_reais,
    expand = expansion(mult = c(0, 0.40))
  ) +
  scale_fill_manual(values = cores_cenario) +
  labs(
    title = "Faturamento médio por tipo de dia",
    subtitle = "Comparação entre vendas efetivadas e pendentes",
    x = NULL,
    y = "Faturamento médio (R$)",
    fill = "Cenário"
  ) +
  tema_apresentacao

print(grafico_classificacao)

ggsave(
  filename = file.path(
    pasta_graficos,
    "faturamento_por_tipo_de_dia.png"
  ),
  plot = grafico_classificacao,
  width = 14,
  height = 8,
  dpi = 150
)

## ---- 15. Gráfico: feriado x média equivalente ----

grafico_comparativo <- ggplot(
  comparativo_grafico,
  aes(
    x = as.character(data_dt),
    y = valor,
    fill = tipo_valor
  )
) +
  geom_col(
    position = position_dodge(width = 0.85),
    width = 0.68
  ) +
  geom_text(
    aes(
      label = formato_reais(valor)
    ),
    position = position_dodge(width = 0.85),
    vjust = -0.45,
    size = 2.7,
    fontface = "bold",
    color = "black",
    show.legend = FALSE
  ) +
  scale_y_continuous(
    labels = formato_reais,
    expand = expansion(mult = c(0, 0.40))
  ) +
  scale_fill_manual(
    values = c(
      "Feriado" = "#080887",
      "Média do mesmo dia da semana" = "#9CC4D1"
    )
  ) +
  labs(
    title = "Faturamento no feriado versus média do mesmo dia da semana",
    subtitle = "Comparação entre feriados e dias normais equivalentes",
    x = "Data do feriado",
    y = "Faturamento (R$)",
    fill = NULL
  ) +
  tema_apresentacao +
  theme(
    axis.text.x = element_text(
      angle = 45,
      hjust = 1,
      size = 10
    )
  )

print(grafico_comparativo)

ggsave(
  filename = file.path(
    pasta_graficos,
    "faturamento_feriado_vs_media.png"
  ),
  plot = grafico_comparativo,
  width = 15,
  height = 8,
  dpi = 150
)

## ---- 16. Gráfico: média por período ----

grafico_periodos_fim_ano <- ggplot(
  tabela_fim_ano,
  aes(
    x = periodo,
    y = faturamento_medio_dia,
    fill = cenario
  )
) +
  geom_col(
    position = position_dodge(width = 0.85),
    width = 0.68
  ) +
  geom_text(
    aes(
      label = formato_reais(faturamento_medio_dia)
    ),
    position = position_dodge(width = 0.85),
    vjust = -0.45,
    size = 3,
    fontface = "bold",
    color = "black",
    show.legend = FALSE
  ) +
  scale_y_continuous(
    labels = formato_reais,
    expand = expansion(mult = c(0, 0.40))
  ) +
  scale_fill_manual(values = cores_cenario) +
  labs(
    title = "Faturamento médio nos períodos de Natal e Ano Novo",
    subtitle = "Comparação entre 15/12 e 07/01",
    x = NULL,
    y = "Faturamento médio por dia (R$)",
    fill = "Cenário"
  ) +
  tema_apresentacao

print(grafico_periodos_fim_ano)

ggsave(
  filename = file.path(
    pasta_graficos,
    "faturamento_medio_periodos_fim_ano.png"
  ),
  plot = grafico_periodos_fim_ano,
  width = 14,
  height = 8,
  dpi = 150
)

## ---- 17. Gráfico: total por período ----

grafico_total_fim_ano <- ggplot(
  tabela_fim_ano,
  aes(
    x = periodo,
    y = faturamento_total,
    fill = cenario
  )
) +
  geom_col(
    position = position_dodge(width = 0.85),
    width = 0.68
  ) +
  geom_text(
    aes(
      label = formato_reais(faturamento_total)
    ),
    position = position_dodge(width = 0.85),
    vjust = -0.45,
    size = 3.2,
    fontface = "bold",
    color = "black",
    show.legend = FALSE
  ) +
  scale_y_continuous(
    labels = formato_reais,
    expand = expansion(mult = c(0, 0.40))
  ) +
  scale_fill_manual(values = cores_cenario) +
  labs(
    title = "Faturamento total nos períodos de Natal e Ano Novo",
    subtitle = "Comparação entre 15/12 e 07/01",
    x = NULL,
    y = "Faturamento total (R$)",
    fill = "Cenário"
  ) +
  tema_apresentacao

print(grafico_total_fim_ano)

ggsave(
  filename = file.path(
    pasta_graficos,
    "faturamento_total_periodos_fim_ano.png"
  ),
  plot = grafico_total_fim_ano,
  width = 14,
  height = 8,
  dpi = 150
)

## ---- 18. Salvar tabelas ----

write_csv(
  resumo_classificacao,
  file.path(
    pasta_tabelas,
    "resumo_por_tipo_de_dia.csv"
  )
)

write_csv(
  detalhe_feriados <- resumo_dia %>%
    filter(
      eh_feriado,
      data_dt != data_natal_fechado
    ) %>%
    select(
      cenario,
      data_dt,
      faturamento,
      qtd_registros
    ) %>%
    arrange(cenario, data_dt),
  file.path(
    pasta_tabelas,
    "detalhe_faturamento_feriados.csv"
  )
)

write_csv(
  comparativo_feriados,
  file.path(
    pasta_tabelas,
    "comparativo_feriados_vs_normal.csv"
  )
)

write_csv(
  tabela_fim_ano,
  file.path(
    pasta_tabelas,
    "tabela_detalhada_natal_ano_novo.csv"
  )
)

cat("\nAnálise concluída.\n")
cat("Gráficos salvos em: ", pasta_graficos, "\n")
cat("Tabelas salvas em: ", pasta_tabelas, "\n")