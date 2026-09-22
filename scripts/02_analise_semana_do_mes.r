# 1. Pacotes

pacotes <- c(
  "dplyr",
  "ggplot2",
  "lubridate",
  "readr",
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
library(tidyr)


# 2. Caminhos

arquivo_dados <- "data/processed/vendas_diarias_indice.csv"

pasta_tabelas <- "outputs/tables"
pasta_graficos <- "outputs/figures"

dir.create(
  pasta_tabelas,
  recursive = TRUE,
  showWarnings = FALSE
)

dir.create(
  pasta_graficos,
  recursive = TRUE,
  showWarnings = FALSE
)

if (!file.exists(arquivo_dados)) {
  stop(
    paste0(
      "Base pública não encontrada em: ",
      arquivo_dados,
      "\n\n",
      "Execute primeiro: python scripts/01_anonimizar_por_indice.py"
    )
  )
}

classificar_semana_mes <- function(dia) {
  case_when(
    dia <= 7 ~ "1a semana (dias 1-7)",
    dia <= 14 ~ "2a semana (dias 8-14)",
    dia <= 21 ~ "3a semana (dias 15-21)",
    TRUE ~ "4a/5a semana (dias 22-31)"
  )
}

classificar_marco_mes <- function(dia) {
  case_when(
    dia <= 5 ~ "Inicio do mes",
    dia >= 8 & dia <= 14 ~ "Perto do dia 12",
    dia == 15 ~ "Quinzena (dia 15)",
    TRUE ~ "Outros dias"
  )
}

ordem_semana <- c(
  "1a semana (dias 1-7)",
  "2a semana (dias 8-14)",
  "3a semana (dias 15-21)",
  "4a/5a semana (dias 22-31)"
)

ordem_marco <- c(
  "Inicio do mes",
  "Outros dias",
  "Perto do dia 12",
  "Quinzena (dia 15)"
)

dados <- read_csv(
  arquivo_dados,
  show_col_types = FALSE
) %>%
  mutate(
    data_dt = ymd(data),
    dia_mes = day(data_dt),
    mes = month(data_dt),
    ano = year(data_dt),
    semana_mes = factor(
      classificar_semana_mes(dia_mes),
      levels = ordem_semana
    ),
    marco_do_mes = factor(
      classificar_marco_mes(dia_mes),
      levels = ordem_marco
    )
  )

colunas_necessarias <- c(
  "data",
  "indice_vendas_efetivadas",
  "indice_vendas_com_pendente"
)

colunas_ausentes <- setdiff(
  colunas_necessarias,
  names(dados)
)

if (length(colunas_ausentes) > 0) {
  stop(
    paste0(
      "A base pública não possui estas colunas: ",
      paste(colunas_ausentes, collapse = ", ")
    )
  )
}

cenarios <- dados %>%
  select(
    data_dt,
    dia_mes,
    mes,
    ano,
    semana_mes,
    marco_do_mes,
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

resumo_semana <- cenarios %>%
  group_by(cenario, semana_mes) %>%
  summarise(
    indice_medio = mean(
      indice_vendas,
      na.rm = TRUE
    ),
    dias_no_periodo = n(),
    .groups = "drop"
  )

resumo_marco <- cenarios %>%
  group_by(cenario, marco_do_mes) %>%
  summarise(
    indice_medio = mean(
      indice_vendas,
      na.rm = TRUE
    ),
    dias_no_periodo = n(),
    .groups = "drop"
  )

resumo_dia_numero <- cenarios %>%
  group_by(cenario, dia_mes) %>%
  summarise(
    indice_medio = mean(
      indice_vendas,
      na.rm = TRUE
    ),
    ocorrencias = n(),
    .groups = "drop"
  )

resumo_mes <- cenarios %>%
  group_by(cenario, ano, mes) %>%
  summarise(
    indice_medio = mean(
      indice_vendas,
      na.rm = TRUE
    ),
    .groups = "drop"
  ) %>%
  mutate(
    ano_mes = make_date(
      ano,
      mes,
      1
    )
  )

write_csv(
  resumo_semana,
  file.path(
    pasta_tabelas,
    "indice_por_semana_do_mes.csv"
  )
)

write_csv(
  resumo_marco,
  file.path(
    pasta_tabelas,
    "indice_por_marco_do_mes.csv"
  )
)

write_csv(
  resumo_dia_numero,
  file.path(
    pasta_tabelas,
    "indice_por_dia_numero.csv"
  )
)

write_csv(
  resumo_mes,
  file.path(
    pasta_tabelas,
    "indice_por_mes.csv"
  )
)

grafico_semana <- ggplot(
  resumo_semana,
  aes(
    x = semana_mes,
    y = indice_medio,
    fill = cenario
  )
) +
  geom_col(
    position = position_dodge(width = 0.8),
    width = 0.7
  ) +
  geom_text(
    aes(
      label = round(indice_medio, 1)
    ),
    position = position_dodge(width = 0.8),
    vjust = -0.35,
    size = 3.5,
    fontface = "bold"
  ) +
  geom_hline(
    yintercept = 100,
    linetype = "dashed",
    color = "gray45"
  ) +
  labs(
    title = "Índice médio de vendas por semana do mês",
    subtitle = "Base 100 = média diária do período",
    x = "Semana do mês",
    y = "Índice de vendas",
    fill = "Cenário"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.x = element_text(
      angle = 15,
      hjust = 1
    ),
    plot.title = element_text(
      face = "bold"
    )
  )

grafico_marco <- ggplot(
  resumo_marco,
  aes(
    x = marco_do_mes,
    y = indice_medio,
    fill = cenario
  )
) +
  geom_col(
    position = position_dodge(width = 0.8),
    width = 0.7
  ) +
  geom_text(
    aes(
      label = round(indice_medio, 1)
    ),
    position = position_dodge(width = 0.8),
    vjust = -0.35,
    size = 3.5,
    fontface = "bold"
  ) +
  geom_hline(
    yintercept = 100,
    linetype = "dashed",
    color = "gray45"
  ) +
  labs(
    title = "Índice médio de vendas por marco do mês",
    subtitle = "Base 100 = média diária do período",
    x = "Marco do mês",
    y = "Índice de vendas",
    fill = "Cenário"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.x = element_text(
      angle = 15,
      hjust = 1
    ),
    plot.title = element_text(
      face = "bold"
    )
  )

grafico_dia <- ggplot(
  resumo_dia_numero,
  aes(
    x = dia_mes,
    y = indice_medio,
    fill = cenario
  )
) +
  geom_col(
    position = position_dodge(width = 0.8),
    width = 0.7
  ) +
  geom_hline(
    yintercept = 100,
    linetype = "dashed",
    color = "gray45"
  ) +
  scale_x_continuous(
    breaks = 1:31
  ) +
  labs(
    title = "Índice médio de vendas por dia do mês",
    subtitle = "Base 100 = média diária do período",
    x = "Dia do mês",
    y = "Índice de vendas",
    fill = "Cenário"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    plot.title = element_text(
      face = "bold"
    )
  )

grafico_mes <- ggplot(
  resumo_mes,
  aes(
    x = ano_mes,
    y = indice_medio,
    color = cenario,
    group = cenario
  )
) +
  geom_hline(
    yintercept = 100,
    linetype = "dashed",
    color = "gray45"
  ) +
  geom_line(
    linewidth = 1.1
  ) +
  geom_point(
    size = 3
  ) +
  geom_text(
    aes(
      label = round(indice_medio, 0)
    ),
    vjust = -0.8,
    size = 3,
    fontface = "bold",
    show.legend = FALSE
  ) +
  scale_x_date(
    date_breaks = "1 month",
    date_labels = "%b/%Y"
  ) +
  labs(
    title = "Tendência mensal do índice de vendas",
    subtitle = "Base 100 = média diária do período",
    x = "Mês",
    y = "Índice médio de vendas",
    color = "Cenário"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.x = element_text(
      angle = 45,
      hjust = 1
    ),
    plot.title = element_text(
      face = "bold"
    )
  )

print(grafico_semana)
print(grafico_marco)
print(grafico_dia)
print(grafico_mes)

ggsave(
  file.path(
    pasta_graficos,
    "indice_por_semana_do_mes.png"
  ),
  grafico_semana,
  width = 12,
  height = 7,
  dpi = 180
)

ggsave(
  file.path(
    pasta_graficos,
    "indice_por_marco_do_mes.png"
  ),
  grafico_marco,
  width = 12,
  height = 7,
  dpi = 180
)

ggsave(
  file.path(
    pasta_graficos,
    "indice_por_dia_do_mes.png"
  ),
  grafico_dia,
  width = 16,
  height = 8,
  dpi = 180
)

ggsave(
  file.path(
    pasta_graficos,
    "indice_por_mes.png"
  ),
  grafico_mes,
  width = 14,
  height = 8,
  dpi = 180
)

cat("\nAnálise por semana e marcos do mês concluída.\n")
cat("Tabelas salvas em: ", pasta_tabelas, "\n", sep = "")
cat("Gráficos salvos em: ", pasta_graficos, "\n", sep = "")