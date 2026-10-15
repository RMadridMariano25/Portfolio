"""Genera las figuras del análisis exploratorio (fase 3 de CRISP-DM).

Uso, desde la raíz del proyecto:
    python scripts/generar_figuras.py
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd

RAIZ = Path(__file__).resolve().parent.parent
DATOS = RAIZ / "data" / "Top_1000_IMD.xlsx"
FIGURAS = RAIZ / "figures"
FIGURAS.mkdir(exist_ok=True)

ROJO = "#B71C3C"

df = pd.read_excel(DATOS)

# Histograma de la calificación
plt.figure(figsize=(6, 4))
plt.hist(df["Movie Rating"], bins=15, color=ROJO, edgecolor="white")
plt.title("Distribución de Movie Rating")
plt.xlabel("Movie Rating")
plt.ylabel("Frecuencia")
plt.tight_layout()
plt.savefig(FIGURAS / "hist_rating.png", dpi=150)
plt.close()

# Metascore vs calificación
plt.figure(figsize=(6, 4))
plt.scatter(df["Metascore of movie"], df["Movie Rating"], alpha=0.4, color=ROJO, s=15)
plt.title("Metascore vs Movie Rating")
plt.xlabel("Metascore")
plt.ylabel("Movie Rating")
plt.tight_layout()
plt.savefig(FIGURAS / "scatter_metascore.png", dpi=150)
plt.close()

print("Figuras guardadas en", FIGURAS)
