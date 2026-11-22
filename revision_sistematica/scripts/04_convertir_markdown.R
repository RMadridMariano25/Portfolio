# =============================================================================
# 04_convertir_markdown.R
# RSL: IA generativa, pensamiento crítico y rendimiento académico en
#      educación superior
#
# Qué hace este script:
#   Convierte a Markdown cada PDF de data/pdf/ con MarkItDown (Microsoft),
#   para revisar el texto completo. Los PDF no se modifican y siguen siendo
#   la fuente para extraer datos (las tablas pueden salir desordenadas).
#
#   En cada ejecución solo convierte lo necesario:
#     - PDF sin .md                      -> se convierte
#     - PDF más reciente que su .md      -> se vuelve a convertir
#       (por ejemplo, si reemplazaste el PDF por una versión correcta)
#     - .md al día                       -> se omite
#     - archivo que no es un PDF válido  -> se omite y se avisa
#   Marca los .md casi vacíos: suelen ser PDF escaneados (imagen), que hay
#   que revisar en el PDF o pasar por OCR.
#
# Requisito: MarkItDown instalado:
#     pip install "markitdown[pdf]"
#   Comprueba en una terminal que funciona:  markitdown --help
#   Si el comando no se encuentra, el script intenta "python -m markitdown".
#
# Entradas: data/pdf/<id_registro>.pdf  (scripts 02 y 03, o a mano)
# Salidas : data/texto_completo_md/<id_registro>.md
#           output/conversion_markdown.csv  (estado, tamaño y alertas)
#
# Paquetes: dplyr, readr, stringr, here
# =============================================================================

library(dplyr)
library(readr)
library(stringr)
library(here)

carpeta_pdf    <- here("data", "pdf")
carpeta_md     <- here("data", "texto_completo_md")
salida_log     <- here("output", "conversion_markdown.csv")
min_caracteres <- 5000   # un artículo completo tiene muchos más caracteres

dir.create(carpeta_md, recursive = TRUE, showWarnings = FALSE)
dir.create(here("output"), showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Localizar MarkItDown
# -----------------------------------------------------------------------------
comando <- Sys.which("markitdown")
args_base <- character()
if (!nzchar(comando)) {
  for (py in c("python", "python3", "py")) {
    p <- Sys.which(py)
    if (nzchar(p) && suppressWarnings(system2(p, c("-m", "markitdown", "--help"),
                                               stdout = FALSE, stderr = FALSE)) == 0) {
      comando <- p; args_base <- c("-m", "markitdown"); break
    }
  }
}
if (!nzchar(comando)) {
  stop("No se encontró MarkItDown. Instálalo con: pip install \"markitdown[pdf]\" ",
       "y comprueba que 'markitdown --help' funciona en la terminal.")
}

es_pdf <- function(f) {
  inicio <- readBin(f, "raw", 5)
  length(inicio) == 5 && identical(inicio, charToRaw("%PDF-"))
}

contar_caracteres <- function(f) {
  if (!file.exists(f)) return(NA_real_)
  sum(nchar(readLines(f, warn = FALSE, encoding = "UTF-8"), type = "chars", allowNA = TRUE),
      na.rm = TRUE)
}

# -----------------------------------------------------------------------------
# 2. Decidir qué convertir
# -----------------------------------------------------------------------------
pdfs <- list.files(carpeta_pdf, pattern = "\\.pdf$", full.names = TRUE, ignore.case = TRUE)
if (length(pdfs) == 0) stop("No hay PDF en ", carpeta_pdf)

archivos <- tibble(
  pdf = pdfs,
  id_registro = tools::file_path_sans_ext(basename(pdfs)),
  md = file.path(carpeta_md, paste0(tools::file_path_sans_ext(basename(pdfs)), ".md"))
) |>
  mutate(
    pdf_valido = vapply(pdf, es_pdf, logical(1)),
    md_existe = file.exists(md),
    md_al_dia = md_existe & file.mtime(md) >= file.mtime(pdf),
    accion = case_when(
      !pdf_valido ~ "omitido_no_es_pdf",
      md_al_dia   ~ "ya_convertido",
      md_existe   ~ "reconvertir",
      TRUE        ~ "convertir"
    )
  )

por_convertir <- filter(archivos, accion %in% c("convertir", "reconvertir"))
cat("PDF: ", nrow(archivos), " | ya convertidos: ", sum(archivos$accion == "ya_convertido"),
    " | por convertir: ", nrow(por_convertir),
    " | no válidos: ", sum(archivos$accion == "omitido_no_es_pdf"), "\n", sep = "")

# -----------------------------------------------------------------------------
# 3. Convertir
# -----------------------------------------------------------------------------
errores <- setNames(rep(NA_character_, nrow(archivos)), archivos$id_registro)

for (k in seq_len(nrow(por_convertir))) {
  r <- por_convertir[k, ]
  tmp <- paste0(r$md, ".tmp")           # se escribe aparte: un fallo no deja un .md a medias
  salida <- suppressWarnings(system2(comando, c(args_base, shQuote(r$pdf), "-o", shQuote(tmp)),
                                     stdout = TRUE, stderr = TRUE))
  if (file.exists(tmp) && file.size(tmp) > 0) {
    file.rename(tmp, r$md)
    message(sprintf("[%d/%d] %s: convertido", k, nrow(por_convertir), r$id_registro))
  } else {
    unlink(tmp)
    errores[r$id_registro] <- str_trunc(paste(salida, collapse = " "), 300)
    message(sprintf("[%d/%d] %s: la conversión falló", k, nrow(por_convertir), r$id_registro))
  }
}

# -----------------------------------------------------------------------------
# 4. Registro y alertas
# -----------------------------------------------------------------------------
resumen <- archivos |>
  mutate(
    convertido = file.exists(md),
    n_caracteres = ifelse(convertido, vapply(md, contar_caracteres, numeric(1)), NA),
    alerta = case_when(
      !pdf_valido                   ~ "El archivo no es un PDF válido: reemplázalo",
      !convertido                   ~ paste("Conversión fallida:", coalesce(errores[id_registro], "")),
      n_caracteres < min_caracteres ~ "Texto casi vacío: probable PDF escaneado; revisar el PDF u OCR",
      TRUE                          ~ ""
    ),
    archivo_md = ifelse(convertido, file.path("data", "texto_completo_md", basename(md)), NA)
  ) |>
  select(id_registro, accion, convertido, n_caracteres, alerta, archivo_md)

write_excel_csv(resumen, salida_log, na = "")

cat("\nConvertidos en total: ", sum(resumen$convertido), " de ", nrow(resumen),
    " | en esta ejecución: ", nrow(por_convertir) - sum(!is.na(errores)),
    " | con alerta: ", sum(resumen$alerta != ""), "\n", sep = "")
if (any(resumen$alerta != "")) print(filter(resumen, alerta != "") |> select(id_registro, alerta), n = Inf)
message("Markdown en: ", carpeta_md, "\nRegistro: ", salida_log)
