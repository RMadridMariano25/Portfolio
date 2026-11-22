# =============================================================================
# 02_descargar_pdf_openalex.R
# RSL: IA generativa, pensamiento crítico y rendimiento académico en
#      educación superior
#
# Qué hace este script:
#   Descarga los textos completos de acceso abierto de los registros
#   seleccionados (script 01). Para cada registro:
#     1. Lo identifica en OpenAlex: por DOI; si no tiene DOI, por título,
#        aceptando el resultado solo si el título coincide (y el año, ±1).
#     2. Junta las direcciones de PDF de acceso abierto que conoce OpenAlex
#        (editorial, repositorios, PubMed Central), la versión PDF de SciELO
#        y el enlace de texto completo que trae Google Scholar.
#     3. Las prueba en orden y guarda la primera que sea realmente un PDF.
#        Si una dirección devuelve una página web, se registra "no es PDF".
#   No se fuerza la descarga de artículos de pago: quedan como pendientes.
#
#   Se puede ejecutar varias veces: no vuelve a descargar los PDF que ya
#   están en la carpeta. Si consigues un PDF a mano, guárdalo como
#   data/pdf/<id_registro>.pdf y vuelve a ejecutar el script.
#
# Entradas: data/processed/seleccionados_texto_completo.csv (script 01)
# Salidas : data/pdf/<id_registro>.pdf
#           output/reporte_descargas_pdf.csv   (un registro por fila)
#           output/pendientes_recuperacion.html (lista para recuperar a mano)
#
# Clave de OpenAlex (recomendada): OPENALEX_API_KEY en .Renviron
#   usethis::edit_r_environ()  ->  OPENALEX_API_KEY=tu_clave  -> reiniciar R
#
# Paquetes: dplyr, readr, stringr, httr2, purrr, here, stringi
# =============================================================================

library(dplyr)
library(readr)
library(stringr)
library(httr2)
library(purrr)
library(here)

# -----------------------------------------------------------------------------
# 0. Configuración
# -----------------------------------------------------------------------------
entrada        <- here("data", "processed", "seleccionados_texto_completo.csv")
carpeta_pdf    <- here("data", "pdf")
carpeta_output <- here("output")
salida_reporte <- file.path(carpeta_output, "reporte_descargas_pdf.csv")
salida_html    <- file.path(carpeta_output, "pendientes_recuperacion.html")
dir.create(carpeta_pdf, recursive = TRUE, showWarnings = FALSE)
dir.create(carpeta_output, recursive = TRUE, showWarnings = FALSE)

api_key  <- Sys.getenv("OPENALEX_API_KEY")
correo   <- Sys.getenv("OPENALEX_EMAIL")   # opcional
pausa    <- 0.5     # segundos entre descargas
min_kb   <- 20      # un PDF de artículo pesa más que esto
verificar_enlaces_pendientes <- TRUE   # comprueba que respondan los enlaces de la lista HTML

`%||%` <- function(a, b) if (is.null(a)) b else a
vacio  <- function(x) is.na(x) | str_trim(x) == ""

# -----------------------------------------------------------------------------
# 1. Funciones
# -----------------------------------------------------------------------------
normalizar_titulo <- function(x) {
  x <- stringi::stri_trans_general(ifelse(is.na(x), "", x), "Latin-ASCII")
  x <- str_replace_all(tolower(x), "…|\\.\\.\\.", " ")
  str_squish(str_replace_all(x, "[^a-z0-9]+", " "))
}

consultar_openalex <- function(ruta, consulta = list()) {
  req <- request("https://api.openalex.org") |>
    req_url_path_append(ruta) |>
    req_url_query(!!!consulta) |>
    req_retry(max_tries = 3) |>
    req_error(is_error = function(resp) FALSE)
  if (nzchar(api_key)) req <- req |> req_url_query(api_key = api_key)
  if (nzchar(correo))  req <- req |> req_url_query(mailto = correo)
  resp <- tryCatch(req_perform(req), error = function(e) NULL)
  Sys.sleep(0.25)
  if (is.null(resp)) return(list(estado = "error_conexion"))
  if (resp_status(resp) == 404) return(list(estado = "no_encontrado"))
  if (resp_status(resp) == 429) return(list(estado = "limite_diario"))
  if (resp_status(resp) >= 400) return(list(estado = paste0("error_", resp_status(resp))))
  list(estado = "ok", datos = resp_body_json(resp))
}

# Identificar el registro en OpenAlex: por DOI o, si no hay, por título verificado
identificar <- function(doi, titulo, anio) {
  if (!vacio(doi)) {
    oa <- consultar_openalex(paste0("works/doi:", doi))
    oa$metodo <- "doi"
    if (oa$estado != "no_encontrado" || vacio(titulo)) return(oa)
  }
  tn <- normalizar_titulo(titulo)
  if (nchar(tn) < 20) return(list(estado = "sin_identificador", metodo = "ninguno"))
  oa <- consultar_openalex("works", list(filter = paste0("title.search:", tn), `per-page` = 10))
  if (oa$estado != "ok") return(c(oa, metodo = "titulo"))
  for (w in oa$datos$results %||% list()) {
    tw <- normalizar_titulo(w$title %||% w$display_name %||% "")
    mismo_titulo <- tw == tn ||
      (nchar(tn) >= 30 && nchar(tw) >= 30 && (str_detect(tw, fixed(tn)) || str_detect(tn, fixed(tw)))) ||
      drop(adist(tn, tw)) / max(nchar(tn), nchar(tw)) <= 0.10
    anio_ok <- vacio(anio) || is.null(w$publication_year) ||
      abs(as.integer(w$publication_year) - as.integer(anio)) <= 1
    if (mismo_titulo && isTRUE(anio_ok)) return(list(estado = "ok", datos = w, metodo = "titulo_verificado"))
  }
  list(estado = "no_encontrado", metodo = "titulo")
}

# Direcciones de PDF candidatas, en orden de preferencia, con su origen
urls_candidatas <- function(work, url_articulo, url_gs) {
  u <- tibble(url = character(), fuente = character())
  agregar <- function(u, url, fuente) if (vacio(url %||% NA)) u else add_row(u, url = url, fuente = fuente)
  if (!is.null(work)) {
    u <- agregar(u, work$best_oa_location$pdf_url, "openalex_mejor_ubicacion")
    for (loc in work$locations %||% list()) u <- agregar(u, loc$pdf_url, "openalex_ubicacion")
    textos_pmc <- c(work$ids$pmcid %||% NA,
                    map_chr(work$locations %||% list(), \(l) l$landing_page_url %||% NA_character_))
    pmc <- unique(na.omit(str_match(textos_pmc, "pmc/articles/(?:PMC)?(\\d+)")[, 2]))
    for (p in pmc) {
      u <- agregar(u, paste0("https://europepmc.org/backend/ptpmcrender.fcgi?accid=PMC", p, "&blobtype=pdf"), "pubmed_central")
      u <- agregar(u, paste0("https://pmc.ncbi.nlm.nih.gov/articles/PMC", p, "/pdf/"), "pubmed_central")
    }
  }
  if (!vacio(url_articulo) && str_detect(url_articulo, "scielo.*script=sci_arttext")) {
    u <- agregar(u, str_replace(url_articulo, "sci_arttext", "sci_pdf"), "scielo")
  }
  u <- agregar(u, url_gs, "google_scholar")
  distinct(u, url, .keep_all = TRUE)
}

# Descarga y comprueba que sea un PDF de verdad
descargar_pdf <- function(url, destino) {
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp))
  req <- request(url) |>
    req_user_agent("RSL-IAgen-educacion-superior/1.0 (revision sistematica; R httr2)") |>
    req_timeout(60) |>
    req_error(is_error = function(resp) FALSE)
  resp <- tryCatch(req_perform(req, path = tmp), error = function(e) NULL)
  Sys.sleep(pausa)
  if (is.null(resp)) return("error_conexion")
  if (resp_status(resp) != 200) return(paste0("http_", resp_status(resp)))
  inicio <- readBin(tmp, "raw", 5)
  if (length(inicio) < 5 || !identical(inicio, charToRaw("%PDF-"))) return("no_es_pdf")
  if (file.size(tmp) < min_kb * 1024) return("pdf_demasiado_pequeno")
  file.copy(tmp, destino, overwrite = TRUE)
  "ok"
}

motivo_legible <- function(estado_id, n_urls, intentos) {
  case_when(
    estado_id == "sin_identificador" ~ "Sin DOI y título insuficiente para buscar en OpenAlex",
    estado_id == "no_encontrado"     ~ "No localizado en OpenAlex (ni por DOI ni por título verificado)",
    str_detect(estado_id, "^error")  ~ paste("Error al consultar OpenAlex:", estado_id),
    n_urls == 0                      ~ "Sin versión de acceso abierto conocida (probablemente de pago)",
    TRUE ~ paste("Ninguna dirección entregó un PDF válido:",
                 paste(unique(str_extract(intentos, "^[^ ]+")), collapse = ", "))
  )
}

# -----------------------------------------------------------------------------
# 2. Registros y reporte previo
# -----------------------------------------------------------------------------
registros <- read_csv(entrada, col_types = cols(.default = "c"), show_col_types = FALSE)

previo <- if (file.exists(salida_reporte)) {
  read_csv(salida_reporte, col_types = cols(.default = "c"), show_col_types = FALSE)
} else NULL

# -----------------------------------------------------------------------------
# 3. Identificar y descargar
# -----------------------------------------------------------------------------
resultados <- vector("list", nrow(registros))

for (i in seq_len(nrow(registros))) {
  r <- registros[i, ]
  destino <- file.path(carpeta_pdf, paste0(r$id_registro, ".pdf"))
  ruta_rel <- file.path("data", "pdf", paste0(r$id_registro, ".pdf"))

  # Ya descargado (automático o a mano): se conserva lo registrado antes
  if (file.exists(destino)) {
    p <- if (!is.null(previo)) filter(previo, id_registro == r$id_registro) else tibble()
    resultados[[i]] <- if (nrow(p) == 1 && p$descargado == "si") p else tibble(
      id_registro = r$id_registro, titulo = r$titulo, doi = r$doi,
      url_encontrada = NA, fuente_url = "manual", estado_acceso_abierto = NA,
      descargado = "si", motivo_fallo = NA, ruta_pdf = ruta_rel,
      id_openalex = NA, doi_openalex = NA, identificacion_openalex = NA,
      url_revista = r$url_articulo, urls_probadas = NA)
    next
  }

  oa <- identificar(r$doi, r$titulo, r$anio)
  if (oa$estado %in% c("limite_diario", "error_conexion")) {
    message("OpenAlex: ", oa$estado, ". Vuelve a ejecutar más tarde; continuará donde se quedó.")
    break
  }
  work <- if (oa$estado == "ok") oa$datos else NULL

  urls <- urls_candidatas(work, r$url_articulo, r$url_texto_completo_gs)
  intentos <- character()
  url_ok <- NA_character_; fuente_ok <- NA_character_
  for (k in seq_len(nrow(urls))) {
    res <- descargar_pdf(urls$url[k], destino)
    intentos <- c(intentos, paste0(res, " <- ", urls$url[k]))
    if (res == "ok") { url_ok <- urls$url[k]; fuente_ok <- urls$fuente[k]; break }
  }
  ok_desc <- !is.na(url_ok)

  resultados[[i]] <- tibble(
    id_registro = r$id_registro,
    titulo = r$titulo,
    doi = r$doi,
    url_encontrada = if (ok_desc) url_ok else
      (work$best_oa_location$landing_page_url %||% work$open_access$oa_url %||% NA_character_),
    fuente_url = fuente_ok,
    estado_acceso_abierto = work$open_access$oa_status %||% "desconocido",
    descargado = if (ok_desc) "si" else "no",
    motivo_fallo = if (ok_desc) NA else motivo_legible(oa$estado, nrow(urls), intentos),
    ruta_pdf = if (ok_desc) ruta_rel else NA,
    id_openalex = str_extract(work$id %||% NA_character_, "W\\d+"),
    doi_openalex = str_remove(work$doi %||% NA_character_, "^https://doi.org/"),
    identificacion_openalex = if (is.null(work)) oa$estado else oa$metodo,
    url_revista = (if (!vacio(r$url_articulo)) r$url_articulo else
      work$primary_location$landing_page_url %||% NA_character_),
    urls_probadas = if (length(intentos)) paste(intentos, collapse = " | ") else NA
  )
  message(sprintf("[%d/%d] %s -> %s", i, nrow(registros), r$id_registro,
                  if (ok_desc) paste("descargado de", fuente_ok) else "pendiente"))
}

reporte <- bind_rows(resultados)
if (!is.null(previo)) reporte <- bind_rows(reporte, filter(previo, !id_registro %in% reporte$id_registro))
reporte <- arrange(reporte, id_registro)
write_excel_csv(reporte, salida_reporte, na = "")

# -----------------------------------------------------------------------------
# 4. Lista de pendientes (HTML con enlaces)
# -----------------------------------------------------------------------------
estado_enlace <- function(url) {
  if (vacio(url)) return(NA_character_)
  req <- request(url) |> req_method("HEAD") |>
    req_user_agent("Mozilla/5.0 (RSL; verificacion de enlaces)") |>
    req_timeout(20) |> req_error(is_error = function(resp) FALSE)
  resp <- tryCatch(req_perform(req), error = function(e) NULL)
  if (is.null(resp)) return("sin respuesta")
  as.character(resp_status(resp))
}

esc <- function(x) {
  x <- ifelse(is.na(x), "", x)
  x <- str_replace_all(x, "&", "&amp;"); x <- str_replace_all(x, "<", "&lt;")
  str_replace_all(x, ">", "&gt;")
}
enlace <- function(url, texto, estado = NA) {
  ifelse(vacio(url), "<span class='nd'>no disponible</span>",
         paste0('<a href="', esc(url), '" target="_blank">', texto, "</a>",
                ifelse(is.na(estado), "", paste0(" <small>(", estado, ")</small>"))))
}

doi_final <- function(d1, d2) ifelse(vacio(d1), d2, d1)

pendientes <- registros |>
  inner_join(filter(reporte, descargado == "no") |>
               select(id_registro, doi_openalex, motivo_fallo, url_revista, estado_acceso_abierto),
             by = "id_registro") |>
  mutate(doi_usar = doi_final(doi, doi_openalex),
         url_doi = ifelse(vacio(doi_usar), NA, paste0("https://doi.org/", doi_usar)),
         url_busqueda_gs = paste0("https://scholar.google.com/scholar?q=",
                                  URLencode(paste0('"', titulo, '"'), reserved = TRUE)))

if (verificar_enlaces_pendientes && nrow(pendientes)) {
  message("Verificando enlaces de ", nrow(pendientes), " pendientes...")
  pendientes <- pendientes |>
    mutate(est_doi = map_chr(url_doi, estado_enlace),
           est_rev = map_chr(url_revista, estado_enlace),
           est_gs  = map_chr(url_texto_completo_gs, estado_enlace))
} else {
  pendientes <- pendientes |> mutate(est_doi = NA, est_rev = NA, est_gs = NA)
}

filas <- paste0(
  "<tr><td><b>", pendientes$id_registro, "</b><br><small>guardar como: ",
  pendientes$id_registro, ".pdf</small></td>",
  "<td>", esc(pendientes$titulo), "<br><small>", esc(str_extract(pendientes$autores, "^[^;,]+")),
  " (", esc(pendientes$anio), "). <i>", esc(pendientes$revista), "</i></small>",
  "<br><small class='m'>", esc(pendientes$motivo_fallo), "</small></td>",
  "<td>", esc(ifelse(vacio(pendientes$doi_usar), "sin DOI", pendientes$doi_usar)), "</td>",
  "<td>", enlace(pendientes$url_doi, "DOI", pendientes$est_doi), "<br>",
  enlace(pendientes$url_revista, "Revista", pendientes$est_rev), "<br>",
  enlace(pendientes$url_texto_completo_gs, "Google Scholar (texto completo)", pendientes$est_gs), "<br>",
  enlace(pendientes$url_busqueda_gs, "Buscar en Google Scholar"), "</td></tr>",
  collapse = "\n")

html <- paste0(
  '<!doctype html><html lang="es"><head><meta charset="utf-8">',
  "<title>Pendientes de recuperación</title><style>",
  "body{font-family:system-ui,sans-serif;margin:24px;max-width:1200px}",
  "table{border-collapse:collapse;width:100%}td,th{border-bottom:1px solid #ccc;",
  "padding:8px;vertical-align:top;text-align:left}.nd{color:#999}.m{color:#a33}",
  "</style></head><body>",
  "<h1>Artículos pendientes de recuperar (", nrow(pendientes), ")</h1>",
  "<p>Generado el ", format(Sys.Date()), ". Los enlaces provienen de los registros ",
  "originales (ScienceDirect, Google Scholar) o de OpenAlex; entre paréntesis, el código ",
  "HTTP de la verificación (200 = responde; 403 suele ser bloqueo a robots, no enlace roto). ",
  "\"Buscar en Google Scholar\" es una búsqueda por título, no un enlace al artículo. ",
  "Guarda cada PDF en <code>data/pdf/</code> con el nombre indicado y vuelve a ejecutar el script.</p>",
  "<table><tr><th>ID</th><th>Referencia y motivo</th><th>DOI</th><th>Enlaces</th></tr>",
  filas, "</table></body></html>")
writeLines(html, salida_html, useBytes = TRUE)

# -----------------------------------------------------------------------------
# 5. Resumen
# -----------------------------------------------------------------------------
cat("\nRegistros: ", nrow(registros), " | procesados: ", nrow(reporte),
    " | descargados: ", sum(reporte$descargado == "si"),
    " | pendientes: ", sum(reporte$descargado == "no"), "\n", sep = "")
cat("\nIdentificación en OpenAlex:\n"); print(count(reporte, identificacion_openalex))
cat("\nEstado de acceso abierto:\n");   print(count(reporte, estado_acceso_abierto))
cat("\nOrigen de los PDF descargados:\n"); print(count(filter(reporte, descargado == "si"), fuente_url))
message("Reporte: ", salida_reporte, "\nPendientes: ", salida_html)
