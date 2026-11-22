# =============================================================================
# 01_identificar_seleccionados.R
# RSL: IA generativa, pensamiento crítico y rendimiento académico en
#      educación superior
#
# Qué hace este script:
#   Toma los registros que pasaron el cribado (archivo de recribado) y los
#   localiza en las exportaciones originales de ScienceDirect (.ris) y
#   Google Scholar (.csv), para recuperar todos sus datos en crudo.
#   Cruce, en este orden:
#     1. DOI (del Excel o de la fuente).
#     2. Título normalizado idéntico.
#     3. Título recortado: Google Scholar corta títulos con "…"; se acepta si
#        un título contiene al otro (mínimo 30 caracteres).
#     4. Título casi idéntico (distancia de edición <= 10 %) y mismo año.
#
# Entradas: data/raw/cribado/recribado_criterios_2026.xlsx (hoja 1)
#           data/raw/sciencedirect/*.ris
#           data/raw/google_scholar/*.csv
# Salidas : data/processed/seleccionados_texto_completo.csv  (1 fila por registro)
#           data/processed/seleccionados_sciencedirect.ris   (entradas originales)
#           data/processed/seleccionados_google_scholar.csv  (filas originales)
#           data/processed/seleccionados_sin_coincidencia.csv (si hay)
#
# Paquetes: dplyr, readr, stringr, readxl, purrr, here, stringi
# =============================================================================

library(dplyr)
library(readr)
library(stringr)
library(readxl)
library(purrr)
library(here)

# -----------------------------------------------------------------------------
# 0. Configuración
# -----------------------------------------------------------------------------
archivo_cribado  <- here("data", "raw", "cribado", "recribado_criterios_2026.xlsx")
carpeta_sd       <- here("data", "raw", "sciencedirect")
carpeta_gs       <- here("data", "raw", "google_scholar")
carpeta_salida   <- here("data", "processed")
dir.create(carpeta_salida, recursive = TRUE, showWarnings = FALSE)

# Decisiones del cribado que NO pasan a texto completo
decisiones_excluidas <- c("Excluir - evidencia suficiente")

# -----------------------------------------------------------------------------
# 1. Funciones auxiliares
# -----------------------------------------------------------------------------
limpiar_doi <- function(x) {
  d <- str_extract(x, "10\\.\\d{4,9}/[^\\s\"<>]+")
  d <- str_remove(d, "[\\.,;\\)\\]]+$")
  d <- str_remove(d, "[?#].*$")
  tolower(d)
}

normalizar_titulo <- function(x) {
  x <- stringi::stri_trans_general(ifelse(is.na(x), "", x), "Latin-ASCII")
  x <- str_replace_all(tolower(x), "…|\\.\\.\\.", " ")
  x <- str_replace_all(x, "[^a-z0-9]+", " ")
  str_squish(x)
}

vacio <- function(x) is.na(x) | str_trim(x) == ""
primero <- function(...) {                     # primer valor no vacío
  v <- list(...)
  out <- v[[1]]
  for (w in v[-1]) out <- ifelse(vacio(out), w, out)
  out
}

leer_ris <- function(archivo) {
  lineas <- readLines(archivo, warn = FALSE, encoding = "UTF-8")
  lineas <- sub("^﻿", "", lineas)
  inicio <- which(str_detect(lineas, "^TY  - "))
  fin    <- which(str_detect(lineas, "^ER  - ?"))
  map2_dfr(inicio, fin, function(a, b) {
    bloque <- lineas[a:b]
    campo <- function(tag) {
      v <- str_remove(bloque[str_detect(bloque, paste0("^", tag, "  - "))], "^.{6}")
      if (length(v)) paste(str_trim(v), collapse = "; ") else NA_character_
    }
    tibble(
      titulo = campo("T1"), autores = campo("AU"), revista = campo("JO"),
      anio = campo("PY"), volumen = campo("VL"), numero = campo("IS"),
      pagina_inicio = campo("SP"), pagina_fin = campo("EP"),
      doi_original = campo("DO"), url = campo("UR"), resumen = campo("AB"),
      palabras_clave = campo("KW"), issn = campo("SN"),
      archivo = basename(archivo), ris = paste(bloque, collapse = "\n")
    )
  })
}

# -----------------------------------------------------------------------------
# 2. Lectura
# -----------------------------------------------------------------------------
cribado <- read_excel(archivo_cribado, sheet = 1, col_types = "text")
names(cribado) <- c("id_registro", "titulo_cribado", "anio_cribado", "fuente_cribado",
                    "decision", "justificacion", "estado_anterior",
                    "texto_completo_anterior", "url_o_doi", "tipo_resultado")
cribado <- cribado |> filter(!vacio(id_registro))

seleccionados <- cribado |>
  filter(!decision %in% decisiones_excluidas) |>
  mutate(doi_cribado = limpiar_doi(url_o_doi),
         tnorm = normalizar_titulo(titulo_cribado))

sd <- map_dfr(list.files(carpeta_sd, "\\.ris$", full.names = TRUE, ignore.case = TRUE), leer_ris) |>
  mutate(id_fuente = sprintf("SD-%04d", row_number()),
         doi = limpiar_doi(doi_original),
         tnorm = normalizar_titulo(titulo))

gs <- map_dfr(list.files(carpeta_gs, "\\.csv$", full.names = TRUE, ignore.case = TRUE),
              function(f) read_csv(f, col_types = cols(.default = "c"), show_col_types = FALSE) |>
                mutate(archivo = basename(f))) |>
  mutate(id_fuente = sprintf("GS-%04d", row_number()),
         doi = limpiar_doi(DOI),
         tnorm = normalizar_titulo(Title))

cat("Cribado:", nrow(cribado), "| seleccionados:", nrow(seleccionados),
    "| ScienceDirect:", nrow(sd), "| Google Scholar:", nrow(gs), "\n")

# -----------------------------------------------------------------------------
# 3. Cruce de cada seleccionado con una fuente
# -----------------------------------------------------------------------------
buscar <- function(doi, tnorm, anio, fuente) {
  sin <- list(pos = NA_integer_, metodo = "no_encontrado")
  if (!is.na(doi)) {
    k <- which(fuente$doi == doi)
    if (length(k)) return(list(pos = k[1], metodo = "doi"))
  }
  if (nchar(tnorm) == 0) return(sin)
  k <- which(fuente$tnorm == tnorm)
  if (length(k)) return(list(pos = k[1], metodo = "titulo_exacto"))
  k <- which(nchar(fuente$tnorm) >= 30 & nchar(tnorm) >= 30 &
               (str_detect(tnorm, fixed(fuente$tnorm)) |
                  str_detect(fuente$tnorm, fixed(tnorm))))
  if (length(k)) return(list(pos = k[1], metodo = "titulo_recortado"))
  d <- drop(adist(tnorm, fuente$tnorm)) / pmax(nchar(tnorm), nchar(fuente$tnorm))
  anio_fuente <- if ("anio" %in% names(fuente)) fuente$anio else fuente$Year
  k <- which(d <= 0.10 & (is.na(anio) | is.na(anio_fuente) | anio_fuente == anio))
  if (length(k)) return(list(pos = k[which.min(d[k])], metodo = "titulo_similar"))
  sin
}

cruce <- seleccionados |>
  rowwise() |>
  mutate(
    m_sd = list(buscar(doi_cribado, tnorm, anio_cribado, sd)),
    m_gs = list(buscar(doi_cribado, tnorm, anio_cribado, gs)),
    pos_sd = m_sd$pos, metodo_sd = m_sd$metodo,
    pos_gs = m_gs$pos, metodo_gs = m_gs$metodo
  ) |>
  ungroup() |>
  select(-m_sd, -m_gs)

# Segunda pasada: si se halló en una fuente con DOI, buscar ese DOI en la otra
for (i in which(is.na(cruce$pos_sd) & !is.na(cruce$pos_gs))) {
  d <- gs$doi[cruce$pos_gs[i]]
  if (!is.na(d) && any(sd$doi == d, na.rm = TRUE)) {
    cruce$pos_sd[i] <- which(sd$doi == d)[1]; cruce$metodo_sd[i] <- "doi_via_gs"
  }
}
for (i in which(is.na(cruce$pos_gs) & !is.na(cruce$pos_sd))) {
  d <- sd$doi[cruce$pos_sd[i]]
  if (!is.na(d) && any(gs$doi == d, na.rm = TRUE)) {
    cruce$pos_gs[i] <- which(gs$doi == d)[1]; cruce$metodo_gs[i] <- "doi_via_sd"
  }
}

# -----------------------------------------------------------------------------
# 4. Tabla unificada (ScienceDirect tiene prioridad en metadatos)
# -----------------------------------------------------------------------------
s <- sd[cruce$pos_sd, ]
g <- gs[cruce$pos_gs, ]
titulo_gs_completo <- ifelse(str_detect(coalesce(g$Title, ""), "…"), NA, g$Title)

unificado <- tibble(
  id_registro     = cruce$id_registro,
  titulo          = primero(s$titulo, titulo_gs_completo, cruce$titulo_cribado),
  autores         = primero(s$autores, g$Authors),
  anio            = primero(s$anio, g$Year, cruce$anio_cribado),
  revista         = primero(s$revista, g$Source),
  volumen         = s$volumen,
  numero          = s$numero,
  paginas         = ifelse(vacio(s$pagina_inicio), NA,
                           ifelse(vacio(s$pagina_fin), s$pagina_inicio,
                                  paste0(s$pagina_inicio, "-", s$pagina_fin))),
  doi             = primero(s$doi, g$doi, cruce$doi_cribado),
  resumen         = primero(s$resumen, g$Abstract),
  palabras_clave  = s$palabras_clave,
  issn            = primero(s$issn, g$ISSN),
  url_articulo    = primero(s$url, g$ArticleURL, ifelse(is.na(cruce$doi_cribado), cruce$url_o_doi, NA)),
  url_texto_completo_gs = g$FullTextURL,
  tipo_gs         = g$Type,
  citas_gs        = g$Cites,
  fuente_cribado  = cruce$fuente_cribado,
  decision        = cruce$decision,
  justificacion   = cruce$justificacion,
  estado_anterior = cruce$estado_anterior,
  texto_completo_anterior = cruce$texto_completo_anterior,
  url_o_doi_cribado = cruce$url_o_doi,
  id_sciencedirect = s$id_fuente,
  coincidencia_sd = cruce$metodo_sd,
  id_google_scholar = g$id_fuente,
  coincidencia_gs = cruce$metodo_gs,
  encontrado = !is.na(cruce$pos_sd) | !is.na(cruce$pos_gs)
)

# -----------------------------------------------------------------------------
# 5. Salidas
# -----------------------------------------------------------------------------
write_excel_csv(unificado, file.path(carpeta_salida, "seleccionados_texto_completo.csv"), na = "")

ris_sel <- sd[sort(unique(na.omit(cruce$pos_sd))), ]
writeLines(paste(ris_sel$ris, collapse = "\n\n"),
           file.path(carpeta_salida, "seleccionados_sciencedirect.ris"), useBytes = TRUE)

gs_sel <- gs[cruce$pos_gs[!is.na(cruce$pos_gs)], ] |>
  mutate(id_registro = cruce$id_registro[!is.na(cruce$pos_gs)], .before = 1) |>
  select(-tnorm, -doi)
write_excel_csv(gs_sel, file.path(carpeta_salida, "seleccionados_google_scholar.csv"), na = "")

sin_coincidencia <- unificado |> filter(!encontrado) |>
  select(id_registro, titulo, anio, fuente_cribado, url_o_doi_cribado)
archivo_sin <- file.path(carpeta_salida, "seleccionados_sin_coincidencia.csv")
if (nrow(sin_coincidencia)) write_excel_csv(sin_coincidencia, archivo_sin, na = "") else
  if (file.exists(archivo_sin)) file.remove(archivo_sin)

# -----------------------------------------------------------------------------
# 6. Resumen
# -----------------------------------------------------------------------------
cat("\nSeleccionados:", nrow(unificado),
    "| encontrados:", sum(unificado$encontrado),
    "| sin coincidencia:", nrow(sin_coincidencia), "\n")
cat("Con DOI:", sum(!vacio(unificado$doi)), "| con resumen:", sum(!vacio(unificado$resumen)), "\n\n")
cat("Coincidencia en ScienceDirect:\n");  print(table(unificado$coincidencia_sd))
cat("\nCoincidencia en Google Scholar:\n"); print(table(unificado$coincidencia_gs))
if (nrow(sin_coincidencia)) { cat("\nSin coincidencia:\n"); print(sin_coincidencia, n = Inf) }
message("Archivo principal: ", file.path(carpeta_salida, "seleccionados_texto_completo.csv"))
