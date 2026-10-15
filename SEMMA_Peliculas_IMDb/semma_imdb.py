"""
Aplicacion de la metodologia SEMMA
Analisis de peliculas del conjunto Top 1000 IMDb
Replica del flujo: Sample -> Explore -> Modify -> Model -> Assess
"""
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from sklearn.model_selection import train_test_split
from sklearn.linear_model import Ridge
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

plt.rcParams["figure.dpi"] = 110

# ---------------------------------------------------------------------
# 0. Carga de datos
# ---------------------------------------------------------------------
df = pd.read_excel("Top_1000_IMDB.xlsx")
df.columns = ["Idx","Movie Name","Year of Release","Watch Time","Movie Rating",
              "Metascore of movie","Gross","Votes","Description"]

print("Registros originales:", len(df))

# ---------------------------------------------------------------------
# 1. SAMPLE (Muestreo)
# ---------------------------------------------------------------------
target = "Movie Rating"
features = ["Year of Release","Watch Time","Metascore of movie","Gross","Votes"]

# Limpieza minima para poder castear
# Votes trae comas (formato "27,77,378")
df["Votes"] = (df["Votes"].astype(str).str.replace(",", "", regex=False)
               .str.replace("'", "", regex=False))
df["Votes"] = pd.to_numeric(df["Votes"], errors="coerce")
df["Gross"] = pd.to_numeric(df["Gross"], errors="coerce")
# Year trae algunos valores con prefijo de clasificacion IMDb (p.ej. "I 2019")
# se extrae el año de 4 digitos
df["Year of Release"] = (df["Year of Release"].astype(str)
                          .str.extract(r"(\d{4})")[0])
df["Year of Release"] = pd.to_numeric(df["Year of Release"], errors="coerce")

X = df[features].copy()
y = df[target].copy()

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.20, random_state=42
)

print(f"Entrenamiento: {len(X_train)} ({len(X_train)/len(df):.0%})")
print(f"Prueba:        {len(X_test)} ({len(X_test)/len(df):.0%})")

tabla_sample = pd.DataFrame({
    "Elemento": ["Registros analizados","Variable objetivo","Entrenamiento","Prueba","Criterio de seleccion"],
    "Resultado": [f"{len(df):,} peliculas","Calificacion IMDb",
                  f"{len(X_train)} peliculas (80%)", f"{len(X_test)} peliculas (20%)",
                  "Muestreo aleatorio simple"]
})
print(tabla_sample)

# ---------------------------------------------------------------------
# 2. EXPLORE (Exploracion)
# ---------------------------------------------------------------------
faltantes = X.isna().sum()
tabla_explore = pd.DataFrame({
    "Variable": ["Año","Duracion (min)","Calificacion IMDb","Metascore","Recaudacion (MUSD)","Votos"],
    "Tipo": ["Numerica"]*6,
    "Valores faltantes": [faltantes["Year of Release"], faltantes["Watch Time"], y.isna().sum(),
                           faltantes["Metascore of movie"], faltantes["Gross"], faltantes["Votes"]],
    "Interpretacion": ["Año de estreno","Tiempo de reproduccion","Variable a predecir",
                        "Evaluacion de criticos","Ingresos brutos","Popularidad de la pelicula"]
})
print(tabla_explore)

# Grafico 1: distribucion de la calificacion IMDb
fig, ax = plt.subplots(figsize=(7,4.5))
ax.hist(y, bins=15, color="#1f77b4", edgecolor="white")
ax.set_title("Distribucion de la calificacion IMDb")
ax.set_xlabel("Calificacion")
ax.set_ylabel("Numero de peliculas")
fig.tight_layout()
fig.savefig("fig1_distribucion_calificacion.png")
plt.close(fig)

# ---------------------------------------------------------------------
# 3. MODIFY (Modificacion)
# ---------------------------------------------------------------------
# Imputacion con la mediana de TRAIN unicamente
medianas_train = X_train[["Metascore of movie","Gross"]].median()
X_train = X_train.fillna(medianas_train)
X_test  = X_test.fillna(medianas_train)

# Grafico 2: Metascore vs calificacion (con datos ya imputados en train)
fig, ax = plt.subplots(figsize=(7,4.5))
ax.scatter(X_train["Metascore of movie"], y_train, alpha=0.45, color="#2ca58d", edgecolor="none")
ax.set_title("Relacion entre Metascore y calificacion IMDb")
ax.set_xlabel("Metascore")
ax.set_ylabel("Calificacion IMDb")
fig.tight_layout()
fig.savefig("fig2_metascore_vs_calificacion.png")
plt.close(fig)

# Estandarizacion (ajustada solo con train)
scaler = StandardScaler()
X_train_sc = scaler.fit_transform(X_train)
X_test_sc  = scaler.transform(X_test)

tabla_modify = pd.DataFrame({
    "Transformacion": ["Conversion numerica","Tratamiento de faltantes","Escalamiento","Variables textuales"],
    "Aplicacion": ["Año, Recaudacion y Votos","Mediana en Metascore y Recaudacion",
                   "Estandarizacion de las cinco variables predictoras",
                   "No se incluyeron por no ser necesarias para el objetivo"]
})
print(tabla_modify)

# ---------------------------------------------------------------------
# 4. MODEL (Modelado)
# ---------------------------------------------------------------------
modelo = Ridge(alpha=1.0, random_state=42)
modelo.fit(X_train_sc, y_train)

nombres_es = {"Year of Release":"Año","Watch Time":"Duracion (min)",
              "Metascore of movie":"Metascore","Gross":"Recaudacion (MUSD)","Votes":"Votos"}
coef = pd.Series(modelo.coef_, index=features).rename(index=nombres_es).sort_values(key=abs, ascending=False)
tabla_model = coef.rename("Coeficiente estandarizado").reset_index().rename(columns={"index":"Variable"})
print(tabla_model)

# Grafico 3: efecto estimado de las variables
fig, ax = plt.subplots(figsize=(7,4.5))
coef_sorted = coef.sort_values()
colors = ["#d62728" if v < 0 else "#1f77b4" for v in coef_sorted]
ax.barh(coef_sorted.index, coef_sorted.values, color=colors)
ax.set_title("Efecto estimado de las variables")
ax.set_xlabel("Coeficiente estandarizado")
ax.axvline(0, color="black", linewidth=0.8)
fig.tight_layout()
fig.savefig("fig3_efecto_variables.png")
plt.close(fig)

# ---------------------------------------------------------------------
# 5. ASSESS (Evaluacion)
# ---------------------------------------------------------------------
y_pred = modelo.predict(X_test_sc)

mae  = mean_absolute_error(y_test, y_pred)
rmse = np.sqrt(mean_squared_error(y_test, y_pred))
r2   = r2_score(y_test, y_pred)

tabla_assess = pd.DataFrame({
    "Metrica": ["MAE","RMSE","R2"],
    "Resultado": [round(mae,3), round(rmse,3), round(r2,3)],
    "Interpretacion": ["Error promedio absoluto, en puntos de calificacion",
                        "Penaliza mas los errores grandes",
                        f"Variacion explicada: {r2*100:.1f}%"]
})
print(tabla_assess)

# Grafico 4: prediccion vs valor observado
fig, ax = plt.subplots(figsize=(7,5.5))
ax.scatter(y_test, y_pred, alpha=0.6, color="#9467bd", edgecolor="none")
lims = [min(y_test.min(), y_pred.min()), max(y_test.max(), y_pred.max())]
ax.plot(lims, lims, "--", color="#d62728")
ax.set_title("Prediccion frente a valor observado (prueba)")
ax.set_xlabel("Calificacion observada")
ax.set_ylabel("Calificacion predicha")
fig.tight_layout()
fig.savefig("fig4_prediccion_vs_observado.png")
plt.close(fig)

# ---------------------------------------------------------------------
# Guardar resultados para el reporte
# ---------------------------------------------------------------------
tabla_sample.to_csv("tabla_sample.csv", index=False)
tabla_explore.to_csv("tabla_explore.csv", index=False)
tabla_modify.to_csv("tabla_modify.csv", index=False)
tabla_model.to_csv("tabla_model.csv", index=False)
tabla_assess.to_csv("tabla_assess.csv", index=False)

print("\n--- RESULTADOS FINALES ---")
print(f"MAE  = {mae:.3f}")
print(f"RMSE = {rmse:.3f}")
print(f"R2   = {r2:.3f}")
print("\nCoeficientes:")
print(coef.round(3))
