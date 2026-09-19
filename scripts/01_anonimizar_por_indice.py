from pathlib import Path
import pandas as pd

RAIZ_PROJETO = Path(__file__).resolve().parents[1]

ARQUIVO_ORIGINAL = (
    RAIZ_PROJETO
    / "data"
    / "private"
    / "vendas_caixa.csv"
)

ARQUIVO_SAIDA = (
    RAIZ_PROJETO
    / "data"
    / "processed"
    / "vendas_diarias_indice.csv"
)

# Mantém a sequência dos dias, mas desloca o calendário real.
# Escolha um valor fixo e mantenha-o para todos os outputs públicos.
DESLOCAMENTO_DIAS = 365

if not ARQUIVO_ORIGINAL.exists():
    raise FileNotFoundError(
        f"Arquivo privado não encontrado: {ARQUIVO_ORIGINAL}\n"
        "Execute primeiro o script 00_converter_txt_para_csv.py."
    )

ARQUIVO_SAIDA.parent.mkdir(parents=True, exist_ok=True)

dados = pd.read_csv(ARQUIVO_ORIGINAL, encoding="utf-8-sig")

colunas_necessarias = {"data", "tipo", "valor"}
colunas_ausentes = colunas_necessarias - set(dados.columns)

if colunas_ausentes:
    raise ValueError(
        f"Colunas ausentes no CSV privado: {colunas_ausentes}"
    )

dados["data_dt"] = pd.to_datetime(
    dados["data"],
    format="%d/%m/%y",
    errors="coerce"
)

dados["valor"] = pd.to_numeric(dados["valor"], errors="coerce")

dados = dados.dropna(subset=["data_dt", "valor"])

vendas = dados[
    dados["tipo"].isin(["venda", "venda_pendente"])
].copy()

if vendas.empty:
    tipos_encontrados = dados["tipo"].value_counts().to_dict()
    raise ValueError(
        "Nenhuma venda ou venda pendente foi encontrada.\n"
        f"Tipos encontrados: {tipos_encontrados}"
    )

vendas["valor_efetivado"] = vendas["valor"].where(
    vendas["tipo"].eq("venda"),
    0
)

vendas["valor_pendente"] = vendas["valor"].where(
    vendas["tipo"].eq("venda_pendente"),
    0
)

base_diaria = (
    vendas.groupby("data_dt", as_index=False)
    .agg(
        faturamento_efetivado=("valor_efetivado", "sum"),
        faturamento_pendente=("valor_pendente", "sum"),
    )
)

base_diaria["faturamento_com_pendente"] = (
    base_diaria["faturamento_efetivado"]
    + base_diaria["faturamento_pendente"]
)

media_efetivado = base_diaria["faturamento_efetivado"].mean()
media_com_pendente = base_diaria["faturamento_com_pendente"].mean()

base_diaria["indice_vendas_efetivadas"] = (
    base_diaria["faturamento_efetivado"]
    / media_efetivado
    * 100
).round(1)

base_diaria["indice_vendas_com_pendente"] = (
    base_diaria["faturamento_com_pendente"]
    / media_com_pendente
    * 100
).round(1)

# A data é deslocada. Não há valores financeiros ou quantidades no arquivo público.
base_diaria["data"] = (
    base_diaria["data_dt"] + pd.Timedelta(days=DESLOCAMENTO_DIAS)
).dt.strftime("%Y-%m-%d")

base_publica = base_diaria[
    [
        "data",
        "indice_vendas_efetivadas",
        "indice_vendas_com_pendente",
    ]
]

base_publica.to_csv(
    ARQUIVO_SAIDA,
    index=False,
    encoding="utf-8"
)

print("\n========== ANONIMIZAÇÃO CONCLUÍDA ==========")
print(f"Base pública criada em: {ARQUIVO_SAIDA}")
print(f"Quantidade de dias analisados: {len(base_publica)}")
print("Colunas públicas:")
print(", ".join(base_publica.columns))
print("\nA base pública contém apenas índices relativos de vendas.")
print("Não publique data/private/ no GitHub.")

#python scripts/00_converter_txt_para_csv.py