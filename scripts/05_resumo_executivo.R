pacotes <- c("dplyr", "readr")

for (pacote in pacotes) {
  if (!requireNamespace(pacote, quietly = TRUE)) {
    install.packages(pacote)
  }
}

library(dplyr)
library(readr)

pasta_tabelas <- "outputs/tables"

semana <- read_csv(
  file.path(pasta_tabelas, "indice_por_semana_do_mes.csv"),
  show_col_types = FALSE
)

marco <- read_csv(
  file.path(pasta_tabelas, "indice_por_marco_do_mes.csv"),
  show_col_types = FALSE
)

melhor_semana <- semana %>%
  filter(cenario == "Efetivado") %>%
  slice_max(indice_medio, n = 1, with_ties = FALSE)

melhor_marco <- marco %>%
  filter(cenario == "Efetivado") %>%
  slice_max(indice_medio, n = 1, with_ties = FALSE)

cat("\n\nMelhor semana do mês:")
cat("\n- ", melhor_semana$semana_mes, sep = "")
cat("\n- Índice médio: ", round(melhor_semana$indice_medio, 1), sep = "")
cat("\n- Base 100 = média diária do período")

cat("\n\nMelhor marco do mês:")
cat("\n- ", melhor_marco$marco_do_mes, sep = "")
cat("\n- Índice médio: ", round(melhor_marco$indice_medio, 1), sep = "")

cat("\n\nArquivos criados:")
cat("\n- outputs/tables/")
cat("\n- outputs/figures/")
cat("\n\nOs outputs públicos usam índices relativos e não expõem valores financeiros reais.\n")