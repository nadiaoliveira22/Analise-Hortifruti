## analise_semana_do_mes_completo.R
##
## Analisa em qual semana do mes a loja mais vende, se ha relacao com
## o dia 12/quinzena/inicio de mes, e mostra o faturamento por mes.
##
## Este script calcula TUDO em dois cenarios, lado a lado:
##   - "Efetivado"            -> apenas vendas ja concluidas (Venda cli#0 e Venda balcao)
##   - "Efetivado + Pendente" -> inclui tambem "Pend Venda balcao"
##
## Assim voce pode comparar os dois sem precisar rodar dois scripts.
## Todos os graficos usam tons de azul (claro = Efetivado, escuro = com Pendente).
##
## Antes de rodar:
## 1. Gere o CSV com: python converter_txt_para_csv.py
## 2. Coloque "vendas_caixa.csv" na mesma pasta deste script
## 3. Session > Set Working Directory > To Source File Location
## 4. Clique em "Source" (Ctrl+Shift+S)

## ---- 1. Pacotes ----

pacotes <- c("dplyr", "ggplot2", "lubridate", "readr", "scales", "tidyr")

for (p in pacotes) {
  if (!requireNamespace(p, quietly = TRUE)) {
    install.packages(p)
  }
}

library(dplyr)
library(ggplot2)
library(lubridate)
library(readr)
library(scales)
library(tidyr)
library(gt)


## ---- 2. Funcao auxiliar para formatar reais e paleta de cores ----

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
  "Efetivado" = "lightblue3",
  "Efetivado + Pendente" = "navy"
)


## ---- 3. Carregar dados ----

dados <- read_csv(
  "vendas_caixa.csv",
  locale = locale(decimal_mark = "."),
  col_types = cols(
    data = col_character(),
    hora = col_character(),
    historico = col_character(),
    tipo = col_character(),
    valor = col_double()
  )
)

dados <- dados %>%
  mutate(data_dt = dmy(data))


## ---- 4. Separar os dois cenarios ----

movimentos_efetivado <- dados %>%
  filter(tipo == "venda") %>%
  mutate(cenario = "Efetivado")

movimentos_com_pendente <- dados %>%
  filter(tipo %in% c("venda", "venda_pendente")) %>%
  mutate(cenario = "Efetivado + Pendente")

movimentos_geral <- bind_rows(movimentos_efetivado, movimentos_com_pendente) %>%
  mutate(
    cenario = factor(
      cenario,
      levels = c("Efetivado", "Efetivado + Pendente")
    )
  )

cat("Registros so efetivado:", nrow(movimentos_efetivado), "\n")
cat("Registros efetivado + pendente:", nrow(movimentos_com_pendente), "\n")
cat("Periodo:", as.character(min(dados$data_dt)),
    "a", as.character(max(dados$data_dt)), "\n\n")


## ---- 5. Faturamento por dia, nos dois cenarios ----

resumo_dia <- movimentos_geral %>%
  group_by(cenario, data_dt) %>%
  summarise(
    faturamento = sum(valor, na.rm = TRUE),
    qtd_registros = n(),
    .groups = "drop"
  ) %>%
  mutate(
    dia_mes = day(data_dt),
    ano_mes = floor_date(data_dt, "month")
  )


## ---- 6. Classificar em semana do mes ----

resumo_dia <- resumo_dia %>%
  mutate(
    semana_mes = case_when(
      dia_mes <= 7  ~ "1a semana (dias 1-7)",
      dia_mes <= 14 ~ "2a semana (dias 8-14)",
      dia_mes <= 21 ~ "3a semana (dias 15-21)",
      TRUE          ~ "4a/5a semana (dias 22-31)"
    ),
    semana_mes = factor(
      semana_mes,
      levels = c(
        "1a semana (dias 1-7)",
        "2a semana (dias 8-14)",
        "3a semana (dias 15-21)",
        "4a/5a semana (dias 22-31)"
      )
    )
  )


## ---- 7. Resumo por semana do mes, nos dois cenarios ----
## Usamos faturamento medio POR DIA, pois as semanas nao tem o mesmo
## numero de dias no periodo analisado.

resumo_semana <- resumo_dia %>%
  group_by(cenario, semana_mes) %>%
  summarise(
    faturamento_total = sum(faturamento),
    dias_no_periodo = n(),
    faturamento_medio_dia = faturamento_total / dias_no_periodo,
    .groups = "drop"
  ) %>%
  arrange(cenario, semana_mes)

cat("---- Faturamento medio por dia, por semana do mes ----\n")
print(resumo_semana)


## ---- 8. Faturamento medio por dia especifico do mes (1 a 31) ----

resumo_por_dia_numero <- resumo_dia %>%
  group_by(cenario, dia_mes) %>%
  summarise(
    faturamento_medio = mean(faturamento),
    ocorrencias = n(),
    .groups = "drop"
  ) %>%
  arrange(cenario, dia_mes)

cat("\n---- Faturamento medio por dia do mes (1 a 31) ----\n")
print(resumo_por_dia_numero, n = 62)

tabela_semana_apresentacao <- resumo_semana %>%
  mutate(
    cenario = recode(
      cenario,
      "Efetivado" = "Vendas efetivadas",
      "Efetivado + Pendente" = "Vendas efetivadas + pendentes"
    ),
    semana_mes = as.character(semana_mes)
  ) %>%
  select(
    Cenario = cenario,
    `Semana do mês` = semana_mes,
    `Faturamento total` = faturamento_total,
    `Dias analisados` = dias_no_periodo,
    `Média por dia` = faturamento_medio_dia
  ) %>%
  gt() %>%
  tab_header(
    title = "Faturamento por semana do mês",
    subtitle = "Comparação entre vendas efetivadas e vendas pendentes"
  ) %>%
  fmt_currency(
    columns = c(
      `Faturamento total`,
      `Média por dia`
    ),
    currency = "BRL",
    decimals = 2,
    use_seps = TRUE
  ) %>%
  fmt_number(
    columns = `Dias analisados`,
    decimals = 0,
    use_seps = TRUE
  ) %>%
  cols_align(
    align = "center",
    columns = everything()
  ) %>%
  tab_options(
    table.font.size = px(14),
    heading.title.font.size = px(20),
    heading.subtitle.font.size = px(14),
    table.border.top.style = "solid",
    table.border.bottom.style = "solid"
  )

tabela_semana_apresentacao

gtsave(
  tabela_semana_apresentacao,
  "tabela_faturamento_semana.html"
)



## ---- 9. Destacar marcos do mes (dia 12, quinzena, inicio) ----

resumo_dia <- resumo_dia %>%
  mutate(
    marco_do_mes = case_when(
      dia_mes %in% 10:14 ~ "Perto do dia 12",
      dia_mes %in% 1:5   ~ "Inicio do mes",
      dia_mes %in% 15:16 ~ "Quinzena (dia 15)",
      TRUE               ~ "Outros dias"
    )
  )

resumo_marco <- resumo_dia %>%
  group_by(cenario, marco_do_mes) %>%
  summarise(
    faturamento_medio_dia = mean(faturamento),
    dias_no_periodo = n(),
    .groups = "drop"
  ) %>%
  arrange(cenario, desc(faturamento_medio_dia))

cat("\n---- Faturamento medio por marco do mes ----\n")
print(resumo_marco)


## ---- 10. Faturamento por mes, nos dois cenarios ----

resumo_mes <- resumo_dia %>%
  group_by(cenario, ano_mes) %>%
  summarise(
    faturamento = sum(faturamento),
    qtd_registros = sum(qtd_registros),
    .groups = "drop"
  ) %>%
  arrange(cenario, ano_mes)

cat("\n---- Faturamento por mes ----\n")
print(resumo_mes, n = 40)


## ---- 11. Grafico 1: faturamento medio por semana do mes ----

grafico_semana <- ggplot(
  resumo_semana,
  aes(x = semana_mes, y = faturamento_medio_dia, fill = cenario)
) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(
    aes(label = formato_reais(faturamento_medio_dia)),
    position = position_dodge(width = 0.8),
    vjust = -0.5,
    size = 3.8,
    fontface = "bold"
  ) +
  scale_y_continuous(
    labels = formato_reais,
    expand = expansion(mult = c(0, 0.15))
  ) +
  scale_fill_manual(values = cores_cenario) +
  labs(
    title = "Faturamento medio por dia, segundo a semana do mes",
    subtitle = "Comparando vendas efetivadas com vendas efetivadas + pendentes",
    x = "Semana do mes",
    y = "Faturamento medio por dia (R$)",
    fill = "Cenario"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "top")

print(grafico_semana)

ggsave(
  "faturamento_por_semana_do_mes.png",
  plot = grafico_semana,
  width = 11,
  height = 7,
  dpi = 150
)


## ---- 12. Grafico 2: faturamento medio por dia especifico (1 a 31) ----

grafico_dia_numero <- ggplot(
  resumo_por_dia_numero,
  aes(x = dia_mes, y = faturamento_medio, fill = cenario)
) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  scale_x_continuous(breaks = 1:31) +
  scale_y_continuous(
    labels = formato_reais,
    expand = expansion(mult = c(0, 0.15))
  ) +
  scale_fill_manual(values = cores_cenario) +
  labs(
    title = "Faturamento medio por dia do mes",
    subtitle = "Comparando vendas efetivadas com vendas efetivadas + pendentes",
    x = "Dia do mes",
    y = "Faturamento medio (R$)",
    fill = "Cenario"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    axis.text.x = element_text(angle = 90, vjust = 0.5),
    legend.position = "top"
  )

print(grafico_dia_numero)

ggsave(
  "faturamento_por_dia_do_mes.png",
  plot = grafico_dia_numero,
  width = 15,
  height = 8,
  dpi = 150
)


## ---- 13. Grafico 3: faturamento por mes ----

grafico_mes <- ggplot(
  resumo_mes,
  aes(x = ano_mes, y = faturamento, fill = cenario)
) +
  geom_col(position = position_dodge(width = 20), width = 18) +
  scale_x_date(
    date_labels = "%b/%Y",
    date_breaks = "1 month"
  ) +
  scale_y_continuous(
    labels = formato_reais,
    expand = expansion(mult = c(0, 0.15))
  ) +
  scale_fill_manual(values = cores_cenario) +
  labs(
    title = "Faturamento por mes",
    subtitle = "Comparando vendas efetivadas com vendas efetivadas + pendentes",
    x = "Mes",
    y = "Faturamento (R$)",
    fill = "Cenario"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "top"
  )

print(grafico_mes)

ggsave(
  "faturamento_por_mes.png",
  plot = grafico_mes,
  width = 13,
  height = 7,
  dpi = 150
)


## ---- 14. Grafico 4: marcos do mes (dia 12 / quinzena / inicio) ----

grafico_marco <- ggplot(
  resumo_marco,
  aes(x = marco_do_mes, y = faturamento_medio_dia, fill = cenario)
) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(
    aes(label = formato_reais(faturamento_medio_dia)),
    position = position_dodge(width = 0.8),
    vjust = -0.5,
    size = 3.8,
    fontface = "bold"
  ) +
  scale_y_continuous(
    labels = formato_reais,
    expand = expansion(mult = c(0, 0.15))
  ) +
  scale_fill_manual(values = cores_cenario) +
  labs(
    title = "Faturamento medio por marco do mes",
    subtitle = "Comparando vendas efetivadas com vendas efetivadas + pendentes",
    x = NULL,
    y = "Faturamento medio por dia (R$)",
    fill = "Cenario"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    axis.text.x = element_text(angle = 15, hjust = 1),
    legend.position = "top"
  )

print(grafico_marco)

ggsave(
  "faturamento_por_marco_do_mes.png",
  plot = grafico_marco,
  width = 11,
  height = 7,
  dpi = 150
)


## ---- 15. Salvar tabelas em CSV ----

write_csv(resumo_semana, "resumo_semana_do_mes.csv")
write_csv(resumo_por_dia_numero, "resumo_por_dia_numero.csv")
write_csv(resumo_marco, "resumo_marco_do_mes.csv")
write_csv(resumo_mes, "resumo_por_mes.csv")

cat("\nAnalise concluida.\n")
cat("Graficos salvos:\n")
cat(" - faturamento_por_semana_do_mes.png\n")
cat(" - faturamento_por_dia_do_mes.png\n")
cat(" - faturamento_por_mes.png\n")
cat(" - faturamento_por_marco_do_mes.png\n")
cat("Tabelas salvas:\n")
cat(" - resumo_semana_do_mes.csv\n")
cat(" - resumo_por_dia_numero.csv\n")
cat(" - resumo_marco_do_mes.csv\n")
cat(" - resumo_por_mes.csv\n")