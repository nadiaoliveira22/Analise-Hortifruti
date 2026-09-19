from pathlib import Path
import pandas as pd

ARQUIVO_ORIGINAL = Path("data/private/vendas_caixa.csv")
ARQUIVO_SAIDA = Path("data/processed/vendas_diarias_anonimizadas.csv")

# Altere apenas se quiser usar outro deslocamento/fator.
# Use sempre os mesmos valores para preservar a consistência entre tabelas e gráficos.
DESLOCAMENTO_DIAS = 365
FATOR_ESCALA = 0.93

if not ARQUIVO_ORIGINAL.exists():
    raise FileNotFoundError(
        f"Arquivo original não encontrado: {ARQUIVO_ORIGINAL}. "
        "Coloque sua base privada nessa pasta antes de executar o script."
    )

ARQUIVO_SAIDA.parent.mkdir(parents=True, exist_ok=True)

dados = pd.read_csv(ARQUIVO_ORIGINAL)

colunas_necessarias = {"data", "tipo", "valor"}
colunas_ausentes = colunas_necessarias - set(dados.columns)

if colunas_ausentes:
    raise ValueError(
        f"A base original não possui estas colunas: {colunas_ausentes}"
    )

dados["data_dt"] = pd.to_datetime(
    dados["data"],
    format="%d/%m/%y",
    errors="coerce"
)

dados["valor"] = pd.to_numeric(dados["valor"], errors="coerce")

dados = dados.dropna(subset=["data_dt", "valor"])

# Mantém apenas movimentos que interessam para a análise.
vendas = dados[dados["tipo"].isin(["venda", "venda_pendente"])].copy()

vendas["valor_efetivado"] = vendas["valor"].where(
    vendas["tipo"].eq("venda"),
    0
)

vendas["valor_pendente"] = vendas["valor"].where(
    vendas["tipo"].eq("venda_pendente"),
    0
)

vendas["qtd_vendas_efetivadas"] = vendas["tipo"].eq("venda").astype(int)
vendas["qtd_vendas_pendentes"] = vendas["tipo"].eq("venda_pendente").astype(int)

base_publica = (
    vendas.groupby("data_dt", as_index=False)
    .agg(
        faturamento_efetivado=("valor_efetivado", "sum"),
        faturamento_pendente=("valor_pendente", "sum"),
        qtd_vendas_efetivadas=("qtd_vendas_efetivadas", "sum"),
        qtd_vendas_pendentes=("qtd_vendas_pendentes", "sum"),
    )
)

# Remove a data real e substitui por uma data deslocada.
base_publica["data"] = (
    base_publica["data_dt"] + pd.Timedelta(days=DESLOCAMENTO_DIAS)
).dt.strftime("%Y-%m-%d")

# Aplica fator constante: preserva tendências e relações, mas não valores reais.
base_publica["faturamento_efetivado"] = (
    base_publica["faturamento_efetivado"] * FATOR_ESCALA
).round(0)

base_publica["faturamento_pendente"] = (
    base_publica["faturamento_pendente"] * FATOR_ESCALA
).round(0)

# Reduz a precisão da contagem para não expor o volume exato da operação.
base_publica["qtd_vendas_efetivadas"] = (
    (base_publica["qtd_vendas_efetivadas"] / 2)
    .round()
    .astype(int)
)

base_publica["qtd_vendas_pendentes"] = (
    (base_publica["qtd_vendas_pendentes"] / 2)
    .round()
    .astype(int)
)

base_publica = base_publica[
    [
        "data",
        "faturamento_efetivado",
        "faturamento_pendente",
        "qtd_vendas_efetivadas",
        "qtd_vendas_pendentes",
    ]
]

base_publica.to_csv(
    ARQUIVO_SAIDA,
    index=False,
    encoding="utf-8"
)

print(f"Base anonimizada criada em: {ARQUIVO_SAIDA}")
print(f"Quantidade de dias analisados: {len(base_publica)}")
print("Atenção: não publique o conteúdo da pasta data/private/.")
