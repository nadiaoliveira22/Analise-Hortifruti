from pathlib import Path
import csv
import re

RAIZ_PROJETO = Path(__file__).resolve().parents[1]
PASTA_PRIVADA = RAIZ_PROJETO / "data" / "private"

ARQUIVO_ENTRADA = PASTA_PRIVADA / "movimentos_caixa.TXT"
ARQUIVO_SAIDA = PASTA_PRIVADA / "vendas_caixa.csv"

PASTA_PRIVADA.mkdir(parents=True, exist_ok=True)

print("\n========== CONVERSOR TXT PARA CSV ==========")
print(f"Arquivo de entrada: {ARQUIVO_ENTRADA}")
print(f"Arquivo de saída: {ARQUIVO_SAIDA}")

if not ARQUIVO_ENTRADA.exists():
    raise FileNotFoundError(
        f"Arquivo TXT não encontrado: {ARQUIVO_ENTRADA}\n"
        "Confira o nome e a localização do arquivo."
    )

PADRAO_DIA = re.compile(
    r"^Dia:\s*(?P<data>\d{2}/\d{2}/\d{2})\s*$"
)

PADRAO_MOVIMENTO = re.compile(
    r"^(?P<hora>\d{2}:\d{2})\s+"
    r"(?P<historico>.+?)\s+"
    r"(?P<sinal>[+-])\s+"
    r"(?P<valor>\d{1,3}(?:\.\d{3})*,\d{2}|\d+,\d{2}|\d+\.\d{2})\s*$"
)


def converter_valor(valor_texto, sinal):
    valor_texto = valor_texto.strip()

    if "," in valor_texto:
        valor = float(
            valor_texto
            .replace(".", "")
            .replace(",", ".")
        )
    else:
        valor = float(valor_texto)

    return -valor if sinal == "-" else valor


def classificar_tipo(historico):
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


data_atual = None
linhas_lidas = 0
movimentos_convertidos = 0
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
        fieldnames=["data", "hora", "historico", "tipo", "valor"]
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

            if len(exemplos_ignorados) < 5:
                exemplos_ignorados.append(linha)

            continue

        if data_atual is None:
            continue

        registro = resultado_movimento.groupdict()
        historico = registro["historico"].strip()

        escritor.writerow(
            {
                "data": data_atual,
                "hora": registro["hora"],
                "historico": historico,
                "tipo": classificar_tipo(historico),
                "valor": converter_valor(
                    registro["valor"],
                    registro["sinal"]
                )
            }
        )

        movimentos_convertidos += 1

print("\n========== CONVERSÃO CONCLUÍDA ==========")
print(f"Linhas lidas: {linhas_lidas}")
print(f"Movimentos convertidos: {movimentos_convertidos}")
print(f"Linhas ignoradas: {linhas_ignoradas}")
print(f"CSV privado criado em: {ARQUIVO_SAIDA}")

if exemplos_ignorados:
    print("\nExemplos de linhas ignoradas:")
    for exemplo in exemplos_ignorados:
        print(f"- {exemplo}")

print("\nPróxima etapa:")
print("python scripts/01_anonimizar_por_indice.py")
print("\nNão publique data/private/ no GitHub.")

#python scripts/00_converter_txt_para_csv.py