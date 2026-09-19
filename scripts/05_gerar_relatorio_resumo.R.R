## ---- Comparação entre projeção de 2026 e histórico de 2025 ----

historico_2025 <- dados %>%
  filter(
    tipo == "venda",
    data_dt >= as.Date("2025-12-15"),
    data_dt <= as.Date("2026-01-07"),
    data_dt != as.Date("2025-12-25")
  ) %>%
  mutate(
    periodo_fim_ano = case_when(
      month(data_dt) == 12 &
        day(data_dt) %in% 15:24 ~
        "Antes do Natal",
      
      month(data_dt) == 12 &
        day(data_dt) %in% 26:31 ~
        "Entre Natal e Ano Novo",
      
      month(data_dt) == 1 &
        day(data_dt) %in% 1:7 ~
        "Ano Novo e primeiros dias",
      
      TRUE ~ NA_character_
    )
  ) %>%
  filter(
    !is.na(periodo_fim_ano)
  ) %>%
  group_by(periodo_fim_ano) %>%
  summarise(
    faturamento_2025 = sum(
      valor,
      na.rm = TRUE
    ),
    .groups = "drop"
  )

comparacao_2026_2025 <- resumo_projecao %>%
  select(
    periodo_fim_ano,
    faturamento_projetado
  ) %>%
  left_join(
    historico_2025,
    by = "periodo_fim_ano"
  ) %>%
  mutate(
    diferenca_reais =
      faturamento_projetado - faturamento_2025,
    
    variacao_percentual =
      ifelse(
        faturamento_2025 > 0,
        (
          diferenca_reais /
            faturamento_2025
        ) * 100,
        NA_real_
      ),
    
    resultado = case_when(
      variacao_percentual > 0 ~
        "Projeção de 2026 acima de 2025",
      
      variacao_percentual < 0 ~
        "Projeção de 2026 abaixo de 2025",
      
      TRUE ~
        "Projeção de 2026 igual a 2025"
    )
  )

total_2025 <- sum(
  historico_2025$faturamento_2025,
  na.rm = TRUE
)

total_projetado_2026 <- sum(
  resumo_projecao$faturamento_projetado,
  na.rm = TRUE
)

diferenca_total <- total_projetado_2026 - total_2025

variacao_total <- ifelse(
  total_2025 > 0,
  (diferenca_total / total_2025) * 100,
  NA_real_
)

cat(
  "Total histórico de 2025:",
  formato_reais(total_2025),
  "\n"
)

cat(
  "Total projetado para 2026:",
  formato_reais(total_projetado_2026),
  "\n"
)

cat(
  "Diferença:",
  formato_reais(diferenca_total),
  "\n"
)

cat(
  "Variação percentual:",
  round(variacao_total, 2),
  "%\n"
)