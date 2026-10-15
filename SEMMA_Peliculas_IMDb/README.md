# Aplicación de la metodología SEMMA — Top 1000 IMDb

Análisis de películas del conjunto Top 1000 IMDb siguiendo la metodología SEMMA (Sample, Explore, Modify, Model, Assess), con una regresión Ridge para predecir la calificación IMDb.

## Contenido

- `semma_imdb.py` — script completo (Sample → Explore → Modify → Model → Assess)
- `Top_1000_IMDB.xlsx` — dataset original (1000 películas)
- `Reporte_SEMMA_Peliculas_IMDb.docx` — reporte final
- `fig1`–`fig4` — gráficas generadas por el script
- `tabla_*.csv` — tablas de resultados de cada fase

## Resultados

- MAE = 0.160
- RMSE = 0.201
- R² = 0.367

## Uso

```bash
pip install pandas numpy matplotlib scikit-learn openpyxl
python semma_imdb.py
```

## Fuente de datos

Inductiveanks. (2020). *Top 1000 IMDb Movies Dataset*. Kaggle. https://www.kaggle.com/datasets/inductiveanks/top-1000-imdb-movies-dataset
