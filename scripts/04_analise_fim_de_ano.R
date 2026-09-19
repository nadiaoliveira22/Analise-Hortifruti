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

classificar_periodo_sazonal <- function(data_dt) {
  mes <- month(data_dt)
  dia <- day(data_dt)
  
  case_when(
    mes == 12 & dia >= 15 & dia <= 24 ~ "Sazonal A\n15/12 a 24/12",
    mes == 12 & dia >= 26 & dia <= 31 ~ "Sazonal B\n26/12 a 31/12",
    mes == 1 & dia >= 1 & dia <= 7 ~ "Sazonal C\n01/01 a 07/01",
    TRUE ~ NA_character_
  )
}

dados <- read_csv(arquivo_dados, show_col_types = FALSE) %>%
  mutate(
    data_dt = ymd(data),
    periodo_sazonal = classificar_periodo_sazonal(data_dt),
    dia_semana = wday(data_dt, label = TRUE, abbr = FALSE, week_start = 1)
  )

cenarios <- dados %>%
  filter(!is.na(periodo_sazonal)) %>%
  select(
    data_dt,
    periodo_sazonal,
    dia_semana,
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

if (nrow(cenarios) == 0) {
  stop(
    paste0(
      "Não há datas do período sazonal na base anonimizada. ",
      "Isso pode ocorrer por causa do deslocamento de datas."
    )
  )
}

resumo_sazonal <- cenarios %>%
  group_by(cenario, periodo_sazonal) %>%
  summarise(
    indice_medio = mean(indice_vendas, na.rm = TRUE),
    indice_acumulado = sum(indice_vendas, na.rm = TRUE),
    dias_analisados = n(),
    maior_indice_diario = max(indice_vendas, na.rm = TRUE),
    .groups = "drop"
  )

write_csv(resumo_sazonal, file.path(pasta_tabelas, "indice_periodos_sazonais.csv"))
write_csv(cenarios, file.path(pasta_tabelas, "indice_diario_periodos_sazonais.csv"))

grafico_periodo <- ggplot(
  resumo_sazonal,
  aes(x = periodo_sazonal, y = indice_medio, fill = cenario)
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
    title = "Índice médio nos períodos sazonais de fim de ano",
    subtitle = "Base 100 = média diária do período completo",
    x = "Período sazonal",
    y = "Índice médio de vendas",
    fill = "Cenário"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

grafico_diario <- ggplot(
  cenarios,
  aes(x = data_dt, y = indice_vendas, color = cenario, group = cenario)
) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray45") +
  geom_line(linewidth = 1) +
  geom_point(size = 2.5) +
  scale_x_date(date_labels = "%d/%m") +
  labs(
    title = "Índice diário nos períodos sazonais",
    subtitle = "Base 100 = média diária do período completo",
    x = "Data anonimizada",
    y = "Índice de vendas",
    color = "Cenário"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(file.path(pasta_graficos, "indice_periodos_sazonais.png"), grafico_periodo, width = 14, height = 8, dpi = 150)
ggsave(file.path(pasta_graficos, "indice_diario_periodos_sazonais.png"), grafico_diario, width = 16, height = 8, dpi = 150)

# Projeção relativa: calcula a média histórica por período e dia da semana.
ano_projecao <- max(year(dados$data_dt), na.rm = TRUE) + 1
data_inicio <- as.Date(paste0(ano_projecao, "-12-15"))
data_fim <- as.Date(paste0(ano_projecao + 1, "-01-07"))
data_fechado <- as.Date(paste0(ano_projecao, "-12-25"))

medias_historicas <- cenarios %>%
  group_by(cenario, periodo_sazonal, dia_semana) %>%
  summarise(
    indice_medio = mean(indice_vendas, na.rm = TRUE),
    .groups = "drop"
  )

media_periodo <- cenarios %>%
  group_by(cenario, periodo_sazonal) %>%
  summarise(
    indice_periodo = mean(indice_vendas, na.rm = TRUE),
    .groups = "drop"
  )

datas_projecao <- tibble(
  data_dt = seq(data_inicio, data_fim, by = "day")
) %>%
  filter(data_dt != data_fechado) %>%
  mutate(
    periodo_sazonal = classificar_periodo_sazonal(data_dt),
    dia_semana = wday(data_dt, label = TRUE, abbr = FALSE, week_start = 1)
  ) %>%
  filter(!is.na(periodo_sazonal))

projecao <- datas_projecao %>%
  crossing(cenario = c("Efetivado", "Efetivado + Pendente")) %>%
  left_join(
    medias_historicas,
    by = c("cenario", "periodo_sazonal", "dia_semana")
  ) %>%
  left_join(
    media_periodo,
    by = c("cenario", "periodo_sazonal")
  ) %>%
  mutate(
    indice_projetado = coalesce(indice_medio, indice_periodo),
    metodo = if_else(
      is.na(indice_medio),
      "Média do período",
      "Média por período e dia da semana"
    )
  ) %>%
  select(data_dt, periodo_sazonal, dia_semana, cenario, indice_projetado, metodo)

write_csv(projecao, file.path(pasta_tabelas, "projecao_indice_sazonal.csv"))

grafico_projecao <- ggplot(
  projecao,
  aes(x = data_dt, y = indice_projetado, fill = cenario)
) +
  geom_hline(yintercept = 100, linetype = "dashed", color = "gray45") +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_x_date(date_labels = "%d/%m") +
  labs(
    title = "Projeção de índice de vendas para período sazonal",
    subtitle = "Base 100 = média diária do período | Projeção relativa",
    x = "Data anonimizada",
    y = "Índice projetado de vendas",
    fill = "Cenário"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 60, hjust = 1))

ggsave(file.path(pasta_graficos, "projecao_indice_sazonal.png"), grafico_projecao, width = 18, height = 9, dpi = 150)

cat("Análise sazonal e projeção relativa concluídas.\n")