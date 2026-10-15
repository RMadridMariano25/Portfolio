# CRISP-DM aplicado al Top 1000 de películas de IMDb

Proyecto de la Licenciatura en Ingeniería en Ciencia de Datos (Universidad Veracruzana). Aplica las seis fases de la metodología CRISP-DM a un dataset con las 1000 películas mejor calificadas en IMDb.

## Contenido

```
data/       Top_1000_IMD.xlsx (dataset original)
reports/    Reportes en Word
figures/    Gráficos del análisis exploratorio
scripts/    Código para regenerar las figuras
```

Reportes:

- `CRISP-DM_Top1000_Movies.docx`: las seis fases aplicadas al dataset, con análisis exploratorio y propuesta de modelado por clustering.
- `CRISP-DM_Arbol_de_decision.docx`: versión con un árbol de decisión que clasifica las películas según su calificación.

## Sobre el dataset

1000 registros y 8 variables útiles: nombre, año de estreno, duración, calificación en IMDb, Metascore, recaudación (Gross), votos y descripción. Hay valores faltantes en Metascore (15.5%) y Gross (16.2%), y la columna Votes viene como texto con comas, así que se limpia antes de modelar.

## Resultados del análisis exploratorio

- La calificación media es 7.97, con mínimo de 7.6 y máximo de 9.3.
- La duración media es de 124 minutos.
- La correlación con la calificación es de 0.27 para la duración y de 0.26 para el Metascore.

## Cómo reproducir las figuras

```bash
pip install -r requirements.txt
python scripts/generar_figuras.py
```

## Referencias

- Chaves Cole, V. (2023). La metodología CRISP-DM en ciencia de datos. Parte I Trabajo Final-Modelado Analítico de Decisiones. https://rpubs.com/mavaleriacc/1075094
- Espinosa-Zúñiga, J. J. (2020). Aplicación de metodología CRISP-DM para segmentación geográfica de una base de datos pública. *Ingeniería, investigación y tecnología, 21*(1), e00008. https://doi.org/10.22201/fi.25940732e.2020.21n1.008
- R Core Team (2024). *R: A language and environment for statistical computing*. R Foundation for Statistical Computing. https://www.R-project.org/
