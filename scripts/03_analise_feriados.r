pacotes <- c("dplyr", "ggplot2", "lubridate", "readr", "tidyr")

for (pacote in pacotes) {
  if (!requireNamespace(pacote, quietly = TRUE)) {
    install.packages(pacote)
  }
}

library(dplyr)
library(ggplot2)
library(lubridate)
library(readr)
library(tidyr)

arquivo_dados <- "data/processed/vendas_diarias_indice.csv"
pasta_tabelas <- "outputs/tables"
pasta_graficos <- "outputs/figures"

dir.create(pasta_tabelas, recursive = TRUE, showWarnings = FALSE)
dir.create(pasta_graficos, recursive = TRUE, showWarnings = FALSE)

# Calendário demonstrativo.
# Ajuste as datas para que coincidam com a base anonimizada, se desejar.
feriados_exemplo <- as.Date(c(
  "2026-01-01",
  "2026-02-16",
  "2026-04-21",
  "2026-05-01",
  "2026-09-07",
  "2026-11-20",
  "2026-12-25"
))

ordem_tipos <- c(
  "Feriado",
  "Vespera de feriado",
  "Dia seguinte ao feriado",
  "Fim de semana",
  "Dia util comum"
)

dados <- read_csv(arquivo_dados, show_col_types = FALSE) %>%
  mutate(
    data_dt = ymd(data),
    dia_semana_num = wday(data_dt, week_start = 1),
    fim_de_semana = dia_semana_num %in% c(6, 7),
    eh_feriado = data_dt %in% feriados_exemplo,
    vespera_feriado = data_dt %in% (feriados_exemplo - days(1)),
    pos_feriado = data_dt %in% (feriados_exemplo + days(1)),
    classificacao = case_when(
      eh_feriado ~ "Feriado",
      vespera_feriado ~ "Vespera de feriado",
      pos_feriado ~ "Dia seguinte ao feriado",
      fim_de_semana ~ "Fim de semana",
      TRUE ~ "Dia util comum"
    ),
    classificacao = factor(classificacao, levels = ordem_tipos)
  )

cenarios <- dados %>%
  select(
    data_dt,
    dia_semana_num,
    classificacao,
    indice_vendas_efetivadas,
    indice_vendas_com_pendente
  ) %>%
  pivot_longer(
    cols = c(
      indice_vendas_efetivadas,
      indice_vendas_com_pendente
    ),
    names_to = "cenario",
    values_to = "indice_vendas"
  ) %>%
  mutate(
    cenario = recode(
      cenario,
      indice_vendas_efetivadas = "Efetivado",
      indice_vendas_com_pendente = "Efetivado + Pendente"
    )
  )

resumo_tipo_dia <- cenarios %>%
  group_by(cenario, classificacao) %>%
  summarise(
    indice_medio = mean(indice_vendas, na.rm = TRUE),
    dias_no_periodo = n(),
    .groups = "drop"
  )

comparativo_feriados <- cenarios %>%
  filter(data_dt %in% feriados_exemplo) %>%
  left_join(
    cenarios %>%
      filter(classificacao == "Dia util comum") %>%
      group_by(cenario, dia_semana_num) %>%
      summarise(indice_medio_normal = mean(indice_vendas), .groups = "drop"),
    by = c("cenario", "dia_semana_num")
  ) %>%
  mutate(
    diferenca_indice = indice_vendas - indice_medio_normal
  ) %>%
  select(
    cenario,
    data_dt,
    indice_feriado = indice_vendas,
    indice_medio_normal,
    diferenca_indice
  )

write_csv(resumo_tipo_dia, file.path(pasta_tabelas, "indice_por_tipo_de_dia.csv"))
write_csv(comparativo_feriados, file.path(pasta_tabelas, "comparativo_feriados_indice.csv"))

grafico_tipo_dia <- ggplot(
  resumo_tipo_dia,
  aes(x = classificacao, y = indice_medio, fill = cenario)
) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(
    aes(label = round(indice_medio, 1)),
    position = position_dodge(width = 0.8),
    vjust = -0.35,
    size = 3.2,
    fontface = "bold"
  ) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray45") +
  labs(
    title = "Índice médio de vendas por tipo de dia",
    subtitle = "Base 100 = média diária do período",
    x = "Classificação do dia",
    y = "Índice de vendas",
    fill = "Cenário"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

grafico_feriados <- ggplot(
  comparativo_feriados,
  aes(x = factor(data_dt), y = indice_feriado)
) +
  geom_col(fill = "navy", width = 0.55) +
  geom_point(
    aes(y = indice_medio_normal),
    color = "steelblue",
    size = 3
  ) +
  geom_segment(
    aes(
      xend = factor(data_dt),
      y = indice_feriado,
      yend = indice_medio_normal
    ),
    color = "gray50",
    linetype = "dashed"
  ) +
  geom_hline(yintercept = 100, linetype = "dotted", color = "gray45") +
  labs(
    title = "Índice no feriado versus média do mesmo dia da semana",
    subtitle = "Barras: índice no feriado | Pontos: índice médio dos dias úteis equivalentes",
    x = "Data anonimizada",
    y = "Índice de vendas"
  ) +
  facet_wrap(~ cenario) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(pasta_graficos, "indice_por_tipo_de_dia.png"), grafico_tipo_dia, width = 14, height = 8, dpi = 150)
ggsave(file.path(pasta_graficos, "indice_feriado_vs_media.png"), grafico_feriados, width = 15, height = 8, dpi = 150)

cat("Análise de calendário e feriados concluída.\n")