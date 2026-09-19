## projecao_fim_ano.R
##
## Projeção de faturamento para Natal e Ano Novo.
## Período projetado: 15/12/2026 a 07/01/2027.
## O dia 25/12/2026 é excluído porque a loja não abre.

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
data_inicio <- as.Date("2026-12-15")
data_fim <- as.Date("2027-01-07")
data_fechado <- as.Date("2026-12-25")

pasta_saida <- "outputs"
pasta_tabelas <- file.path(pasta_saida, "tabelas")
pasta_graficos <- file.path(pasta_saida, "graficos")

## ---- 3. Pastas e validações ----

if (!file.exists(arquivo_dados)) {
  stop(
    "O arquivo ", arquivo_dados,
    " não foi encontrado na pasta: ",
    getwd()
  )
}

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

## ---- 4. Funções auxiliares ----

formato_reais <- function(x) {
  dollar(
    x,
    prefix = "R$ ",
    big.mark = ".",
    decimal.mark = ",",
    accuracy = 0.01
  )
}

classificar_periodo <- function(data_dt) {
  mes <- month(data_dt)
  dia <- day(data_dt)
  
  case_when(
    mes == 12 & dia %in% 15:24 ~
      "Antes do Natal",
    
    mes == 12 & dia %in% 26:31 ~
      "Entre Natal e Ano Novo",
    
    mes == 1 & dia %in% 1:7 ~
      "Ano Novo e primeiros dias",
    
    TRUE ~ NA_character_
  )
}

## ---- 5. Carregar dados ----

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
  mutate(
    data_dt = dmy(data)
  )

## ---- 6. Preparar histórico ----

historico <- dados %>%
  filter(tipo == "venda") %>%
  group_by(data_dt) %>%
  summarise(
    faturamento = sum(valor, na.rm = TRUE),
    qtd_registros = n(),
    .groups = "drop"
  ) %>%
  mutate(
    periodo_fim_ano = classificar_periodo(data_dt),
    dia_semana = wday(
      data_dt,
      label = TRUE,
      abbr = FALSE,
      week_start = 1
    )
  ) %>%
  filter(!is.na(periodo_fim_ano))

## ---- 7. Calcular médias históricas ----

medias_historicas <- historico %>%
  group_by(periodo_fim_ano, dia_semana) %>%
  summarise(
    media_faturamento = mean(
      faturamento,
      na.rm = TRUE
    ),
    desvio_faturamento = sd(
      faturamento,
      na.rm = TRUE
    ),
    quantidade_dias = n(),
    .groups = "drop"
  )

## ---- 8. Criar datas futuras ----

datas_projecao <- tibble(
  data_dt = seq(
    data_inicio,
    data_fim,
    by = "day"
  )
) %>%
  filter(
    data_dt != data_fechado
  ) %>%
  mutate(
    periodo_fim_ano = classificar_periodo(data_dt),
    dia_semana = wday(
      data_dt,
      label = TRUE,
      abbr = FALSE,
      week_start = 1
    )
  ) %>%
  filter(!is.na(periodo_fim_ano))

## ---- 9. Fazer projeção ----

projecao <- datas_projecao %>%
  left_join(
    medias_historicas,
    by = c("periodo_fim_ano", "dia_semana")
  ) %>%
  mutate(
    cenario = "Projeção",
    desvio_faturamento = coalesce(
      desvio_faturamento,
      0
    ),
    limite_inferior = pmax(
      media_faturamento - desvio_faturamento,
      0
    ),
    limite_superior = media_faturamento +
      desvio_faturamento
  )

## ---- 10. Verificações ----

cat("\nQuantidade de datas projetadas:\n")
print(nrow(projecao))

cat("\nPrimeira e última data:\n")
print(range(projecao$data_dt))

cat("\nQuantidade por período:\n")
print(count(projecao, periodo_fim_ano))

cat("\nDatas sem média histórica:\n")
print(
  projecao %>%
    filter(is.na(media_faturamento)) %>%
    select(data_dt, periodo_fim_ano, dia_semana)
)

## ---- 11. Salvar tabelas ----

write_csv(
  projecao,
  file.path(
    pasta_tabelas,
    "projecao_diaria_natal_ano_novo_2026.csv"
  )
)

resumo_projecao <- projecao %>%
  group_by(periodo_fim_ano) %>%
  summarise(
    faturamento_projetado = sum(
      media_faturamento,
      na.rm = TRUE
    ),
    media_diaria_projetada = mean(
      media_faturamento,
      na.rm = TRUE
    ),
    dias_projetados = n(),
    .groups = "drop"
  )

print(resumo_projecao)

write_csv(
  resumo_projecao,
  file.path(
    pasta_tabelas,
    "resumo_projecao_natal_ano_novo_2026.csv"
  )
)

## ---- 12. Preparar gráfico ----

projecao_grafico <- projecao %>%
  filter(
    !is.na(media_faturamento),
    data_dt != data_fechado
  ) %>%
  arrange(data_dt)

quebras_datas <- projecao_grafico$data_dt

## ---- 13. Criar gráfico ----

grafico_projecao <- ggplot(
  projecao_grafico,
  aes(
    x = data_dt,
    y = media_faturamento
  )
) +
  geom_col(
    fill = "steelblue",
    width = 0.8
  ) +
  geom_label(
    aes(
      label = formato_reais(media_faturamento)
    ),
    vjust = -0.35,
    hjust = 0.5,
    size = 2.5,
    fontface = "bold",
    fill = "white",
    color = "black",
    label.size = 0.2,
    label.padding = unit(
      0.12,
      "lines"
    ),
    na.rm = TRUE
  ) +
  scale_x_date(
    limits = c(
      data_inicio - days(1),
      data_fim + days(1)
    ),
    breaks = quebras_datas,
    date_labels = "%d/%m",
    expand = c(0.01, 0.01)
  ) +
  scale_y_continuous(
    labels = formato_reais,
    expand = expansion(
      mult = c(0, 0.35)
    )
  ) +
  labs(
    title = "Projeção de faturamento para Natal e Ano Novo",
    subtitle = "De 15/12/2026 a 07/01/2027, sem o dia 25/12",
    x = "Data",
    y = "Faturamento projetado"
  ) +
  theme_minimal(
    base_size = 12
  ) +
  theme(
    axis.text.x = element_text(
      angle = 60,
      hjust = 1,
      vjust = 1,
      size = 9
    ),
    plot.margin = margin(
      10,
      20,
      30,
      10
    )
  )

print(grafico_projecao)

## ---- 14. Salvar gráfico ----

ggsave(
  filename = file.path(
    pasta_graficos,
    "projecao_natal_ano_novo_2026.png"
  ),
  plot = grafico_projecao,
  width = 18,
  height = 9,
  dpi = 150
)

cat("\nProjeção concluída.\n")
cat("Tabelas salvas em: ", pasta_tabelas, "\n")
cat("Gráfico salvo em: ", pasta_graficos, "\n")