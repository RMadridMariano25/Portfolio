# =============================================================================
# 03_lista_recuperacion.R
# RSL: IA generativa, pensamiento crítico y rendimiento académico en
#      educación superior
#
# Qué hace este script:
#   Genera una página HTML con TODOS los registros seleccionados para el
#   texto completo, indicando cuáles ya tienen PDF y cuáles faltan, con
#   enlaces para buscarlos a mano (DOI, registro original, texto completo
#   de Google Scholar y búsqueda por título en Google Scholar).
#
#   Un registro cuenta como "Recuperado" si existe data/pdf/<id_registro>.pdf
#   y es un PDF válido. No depende de OpenAlex: funciona antes o después del
#   script 02. Si existe el reporte del script 02, añade el motivo del fallo.
#
#   Flujo: abre el HTML, descarga a mano los pendientes, guárdalos en
#   data/pdf/ con el nombre indicado y vuelve a ejecutar este script.
#
# Entradas: data/processed/seleccionados_texto_completo.csv (script 01)
#           data/pdf/*.pdf
#           output/reporte_descargas_pdf.csv (opcional, script 02)
# Salidas : output/recuperacion_manual.html
#           output/estado_recuperacion.csv
#
# Paquetes: dplyr, readr, stringr, here
# =============================================================================

library(dplyr)
library(readr)
library(stringr)
library(here)

entrada        <- here("data", "processed", "seleccionados_texto_completo.csv")
carpeta_pdf    <- here("data", "pdf")
reporte_02     <- here("output", "reporte_descargas_pdf.csv")
salida_html    <- here("output", "recuperacion_manual.html")
salida_csv     <- here("output", "estado_recuperacion.csv")
dir.create(here("output"), showWarnings = FALSE)

vacio <- function(x) is.na(x) | str_trim(x) == ""

es_pdf <- function(f) {
  if (!file.exists(f)) return(FALSE)
  inicio <- readBin(f, "raw", 5)
  length(inicio) == 5 && identical(inicio, charToRaw("%PDF-"))
}

# -----------------------------------------------------------------------------
# 1. Estado de cada registro
# -----------------------------------------------------------------------------
registros <- read_csv(entrada, col_types = cols(.default = "c"), show_col_types = FALSE)

reporte <- if (file.exists(reporte_02)) {
  read_csv(reporte_02, col_types = cols(.default = "c"), show_col_types = FALSE) |>
    select(id_registro, motivo_fallo, doi_openalex, fuente_url)
} else {
  tibble(id_registro = character(), motivo_fallo = character(),
         doi_openalex = character(), fuente_url = character())
}

estado <- registros |>
  left_join(reporte, by = "id_registro") |>
  mutate(
    archivo_pdf = file.path(carpeta_pdf, paste0(id_registro, ".pdf")),
    recuperado  = vapply(archivo_pdf, es_pdf, logical(1)),
    pdf_invalido = file.exists(archivo_pdf) & !recuperado,
    estado = case_when(recuperado ~ "Recuperado",
                       pdf_invalido ~ "Archivo no válido",
                       TRUE ~ "Pendiente"),
    doi_usar = ifelse(vacio(doi), doi_openalex, doi),
    url_doi  = ifelse(vacio(doi_usar), NA, paste0("https://doi.org/", doi_usar)),
    url_busqueda_gs = paste0("https://scholar.google.com/scholar?q=",
                             URLencode(paste0('"', str_remove_all(titulo, "…"), '"'),
                                       reserved = TRUE)),
    nota = case_when(
      recuperado ~ ifelse(vacio(fuente_url), "PDF en carpeta", paste("Descargado de", fuente_url)),
      pdf_invalido ~ "El archivo existe pero no es un PDF válido: reemplázalo",
      !vacio(motivo_fallo) ~ motivo_fallo,
      TRUE ~ ""
    )
  ) |>
  arrange(factor(estado, c("Pendiente", "Archivo no válido", "Recuperado")), id_registro)

write_excel_csv(
  estado |> transmute(id_registro, titulo, anio, revista, doi = doi_usar, estado, nota,
                      ruta_pdf = ifelse(recuperado, file.path("data", "pdf", paste0(id_registro, ".pdf")), NA)),
  salida_csv, na = "")

# -----------------------------------------------------------------------------
# 2. HTML
# -----------------------------------------------------------------------------
esc <- function(x) {
  x <- ifelse(is.na(x), "", x)
  x <- str_replace_all(x, "&", "&amp;"); x <- str_replace_all(x, "<", "&lt;")
  str_replace_all(x, ">", "&gt;")
}
enlace <- function(url, texto) ifelse(vacio(url), "",
  paste0('<a href="', esc(url), '" target="_blank">', texto, "</a>"))

clase <- c("Recuperado" = "ok", "Pendiente" = "pend", "Archivo no válido" = "inv")

filas <- paste0(
  '<tr class="', clase[estado$estado], '">',
  "<td><b>", estado$id_registro, "</b><br><small>archivo: ", estado$id_registro, ".pdf</small></td>",
  '<td><span class="et">', estado$estado, "</span>",
  ifelse(vacio(estado$nota), "", paste0("<br><small>", esc(estado$nota), "</small>")), "</td>",
  "<td>", esc(estado$titulo), "<br><small>", esc(str_extract(estado$autores, "^[^;,]+")),
  " (", esc(estado$anio), "). <i>", esc(estado$revista), "</i></small></td>",
  "<td>", enlace(estado$url_doi, "DOI"), " ",
  enlace(estado$url_articulo, "Registro"), " ",
  enlace(estado$url_texto_completo_gs, "Texto completo (GS)"), " ",
  enlace(estado$url_busqueda_gs, "Buscar en Scholar"), "</td></tr>",
  collapse = "\n")

n <- table(factor(estado$estado, c("Recuperado", "Pendiente", "Archivo no válido")))

html <- paste0(
  '<!doctype html><html lang="es"><head><meta charset="utf-8">',
  "<title>Recuperación de textos completos</title><style>",
  "body{font-family:system-ui,sans-serif;margin:24px;max-width:1200px}",
  "table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #ccc;",
  "padding:8px;vertical-align:top;text-align:left}a{margin-right:10px}",
  ".et{font-weight:600}.ok .et{color:#1a7f37}.pend .et{color:#b35900}.inv .et{color:#c62828}",
  "tr.ok{background:#f3faf4}.res span{margin-right:18px}",
  "</style></head><body>",
  "<h1>Recuperación de textos completos (", nrow(estado), " registros)</h1>",
  '<p class="res"><span><b>Recuperados:</b> ', n[["Recuperado"]], "</span>",
  "<span><b>Pendientes:</b> ", n[["Pendiente"]], "</span>",
  if (n[["Archivo no válido"]] > 0) paste0("<span><b>Archivo no válido:</b> ", n[["Archivo no válido"]], "</span>") else "",
  "</p>",
  "<p>Generado el ", format(Sys.Date()), ". Guarda cada PDF en <code>data/pdf/</code> ",
  "con el nombre indicado y vuelve a ejecutar el script 03 para actualizar esta lista. ",
  "Los enlaces DOI, Registro y Texto completo (GS) provienen de los registros originales; ",
  "\"Buscar en Scholar\" es una búsqueda por título.</p>",
  "<table><tr><th>ID</th><th>Estado</th><th>Referencia</th><th>Enlaces</th></tr>",
  filas, "</table></body></html>")
writeLines(html, salida_html, useBytes = TRUE)

cat("\nRegistros:", nrow(estado), "| recuperados:", n[["Recuperado"]],
    "| pendientes:", n[["Pendiente"]], "| archivo no válido:", n[["Archivo no válido"]], "\n")
message("Lista: ", salida_html)
