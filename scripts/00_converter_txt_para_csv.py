from pathlib import Path
import csv
import re


# 1. CAMINHOS DO PROJETO

RAIZ_PROJETO = Path(__file__).resolve().parents[1]

PASTA_PRIVADA = RAIZ_PROJETO / "data" / "private"

ARQUIVO_ENTRADA = PASTA_PRIVADA / "movimentos_caixa.TXT"
ARQUIVO_SAIDA = PASTA_PRIVADA / "vendas_caixa.csv"

PASTA_PRIVADA.mkdir(
    parents=True,
    exist_ok=True
)

print("\n========== CONVERSOR TXT PARA CSV ==========")
print(f"Pasta privada: {PASTA_PRIVADA}")
print(f"Arquivo de entrada: {ARQUIVO_ENTRADA}")
print(f"Arquivo de saída: {ARQUIVO_SAIDA}")

if not ARQUIVO_ENTRADA.exists():
    raise FileNotFoundError(
        f"\nArquivo TXT não encontrado: {ARQUIVO_ENTRADA}\n"
        "Confira se o nome do arquivo é movimentos_caixa.TXT "
        "e se ele está dentro de data/private/."
    )


# 2. PADRÕES DO ARQUIVO TXT

PADRAO_DIA = re.compile(
    r"^Dia:\s*(?P<data>\d{2}/\d{2}/\d{2})\s*$"
)

PADRAO_MOVIMENTO = re.compile(
    r"^(?P<hora>\d{2}:\d{2})\s+"
    r"(?P<historico>.+?)\s+"
    r"(?P<sinal>[+-])\s+"
    r"(?P<valor>\d{1,3}(?:\.\d{3})*,\d{2}|\d+,\d{2}|\d+\.\d{2})\s*$"
)

# 3. FUNÇÕES AUXILIARES

def converter_valor(valor_texto, sinal):
    """
    Converte valor brasileiro em número decimal.

    Exemplos:
    14,10      -> 14.10
    1.234,56   -> 1234.56
    14.10      -> 14.10

    O sinal + ou - vem em uma coluna própria do TXT.
    """

    valor_texto = valor_texto.strip()

    if "," in valor_texto:
        valor = float(
            valor_texto
            .replace(".", "")
            .replace(",", ".")
        )
    else:
        valor = float(valor_texto)

    if sinal == "-":
        return -valor

    return valor


def classificar_tipo(historico):
    """
    Classifica cada movimento pelo texto do histórico.
    A ordem importa: venda pendente deve ser identificada
    antes de venda normal.
    """

    texto = str(historico).strip().lower()

    if "saldo anterior" in texto:
        return "saldo_anterior"

    if "pend" in texto and "venda" in texto:
        return "venda_pendente"

    if "troco" in texto:
        return "troco"

    if "fechamento" in texto:
        return "fechamento"

    if "devolu" in texto:
        return "devolucao"

    if "venda" in texto:
        return "venda"

    return "outro"


# 4. CONVERSÃO TXT -> CSV

data_atual = None

linhas_lidas = 0
linhas_convertidas = 0
linhas_sem_data = 0
linhas_ignoradas = 0

exemplos_ignorados = []

with open(
    ARQUIVO_ENTRADA,
    "r",
    encoding="utf-8",
    errors="replace"
) as entrada, open(
    ARQUIVO_SAIDA,
    "w",
    newline="",
    encoding="utf-8-sig"
) as saida:

    escritor = csv.DictWriter(
        saida,
        fieldnames=[
            "data",
            "hora",
            "historico",
            "tipo",
            "valor"
        ]
    )

    escritor.writeheader()

    for linha in entrada:
        linhas_lidas += 1
        linha = linha.strip()

        if not linha:
            continue

        resultado_dia = PADRAO_DIA.match(linha)

        if resultado_dia:
            data_atual = resultado_dia.group("data")
            continue

        resultado_movimento = PADRAO_MOVIMENTO.match(linha)

        if not resultado_movimento:
            linhas_ignoradas += 1

            if len(exemplos_ignorados) < 8:
                exemplos_ignorados.append(linha)

            continue

        if data_atual is None:
            linhas_sem_data += 1
            continue

        registro = resultado_movimento.groupdict()

        historico = registro["historico"].strip()
        tipo = classificar_tipo(historico)
        valor = converter_valor(
            registro["valor"],
            registro["sinal"]
        )

        escritor.writerow(
            {
                "data": data_atual,
                "hora": registro["hora"],
                "historico": historico,
                "tipo": tipo,
                "valor": valor
            }
        )

        linhas_convertidas += 1
# 5. RESULTADO FINAL
print("\n========== CONVERSÃO CONCLUÍDA ==========")
print(f"Linhas lidas: {linhas_lidas}")
print(f"Movimentos convertidos: {linhas_convertidas}")
print(f"Movimentos sem data: {linhas_sem_data}")
print(f"Linhas ignoradas: {linhas_ignoradas}")
print(f"CSV privado criado em:\n{ARQUIVO_SAIDA}")

if exemplos_ignorados:
    print("\nExemplos de linhas ignoradas:")
    for exemplo in exemplos_ignorados:
        print(f"- {exemplo}")

print("\nPróxima etapa:")
print("python scripts/01_anonimizar_base.py")

print("\nIMPORTANTE:")
print("Não publique a pasta data/private/ no GitHub.")