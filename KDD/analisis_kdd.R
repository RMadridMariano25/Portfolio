# KDD aplicado al Top 1000 de IMDb
# Árbol de decisión para clasificar películas con calificación >= 8.0
#
# Correr desde la raíz del repositorio:
#   Rscript analisis_kdd.R

library(readxl)
library(dplyr)
library(stringr)
library(rpart)
library(rpart.plot)
library(caret)

# 1 y 2. Selección e integración ---------------------------------------
# La primera columna del Excel no tiene nombre (es un índice), por eso
# se pide a readxl que renombre sin avisar.
df <- read_excel("data/Top_1000_IMD.xlsx", .name_repair = "unique_quiet")

df_integrado <- df %>%
  select(`Year of Release`, `Watch Time`, `Metascore of movie`,
         Gross, Votes, `Movie Rating`)

# 3. Limpieza ------------------------------------------------------------
# Votes viene como texto con comas al estilo indio ("27,77,378").
# Gross y Year of Release ya son numéricos en este archivo; el as.character()
# evita que stringr falle y deja el código funcionando si cambia el formato.
df_limpio <- df_integrado %>%
  mutate(Votes = as.numeric(str_replace_all(Votes, ",", ""))) %>%
  mutate(Gross = as.numeric(str_replace_all(as.character(Gross), "[^0-9.]", ""))) %>%
  mutate(`Year of Release` = as.numeric(
    str_extract(as.character(`Year of Release`), "[0-9]{4}"))) %>%
  na.omit()   # quedan 756 de las 1000 películas

# 4. Transformación ------------------------------------------------------
df_transformado <- df_limpio %>%
  mutate(Clase_Maestra = as.factor(ifelse(`Movie Rating` >= 8.0, 1, 0))) %>%
  select(-`Movie Rating`)   # se quita para que el modelo no vea la respuesta

# 5. Minería de datos ----------------------------------------------------
set.seed(42)
index      <- sample(1:nrow(df_transformado), 0.8 * nrow(df_transformado))
train_data <- df_transformado[index, ]
test_data  <- df_transformado[-index, ]

modelo_arbol <- rpart(Clase_Maestra ~ .,
                      data    = train_data,
                      method  = "class",
                      control = rpart.control(maxdepth = 3))

# 6. Evaluación ----------------------------------------------------------
predicciones      <- predict(modelo_arbol, test_data, type = "class")
matriz_evaluacion <- confusionMatrix(predicciones, test_data$Clase_Maestra,
                                     positive = "1")

cat("--- Resultados de evaluación ---\n")
print(matriz_evaluacion$table)
cat("\nAccuracy:", round(matriz_evaluacion$overall["Accuracy"], 4), "\n")
cat("Sensibilidad:", round(matriz_evaluacion$byClass["Sensitivity"], 4), "\n")
cat("Especificidad:", round(matriz_evaluacion$byClass["Specificity"], 4), "\n")

cat("\n--- Importancia de las variables ---\n")
print(modelo_arbol$variable.importance)

# 7. Presentación del conocimiento ---------------------------------------
dir.create("images", showWarnings = FALSE)

graficar_arbol <- function() {
  rpart.plot(modelo_arbol,
             main = "Árbol de Decisión: Factores de Éxito en Películas",
             type = 3,
             extra = 104,
             fallen.leaves = TRUE,
             shadow.col = "gray")
}

png("images/arbol_decision.png", width = 1400, height = 900, res = 150)
graficar_arbol()
dev.off()

graficar_arbol()   # también en pantalla
