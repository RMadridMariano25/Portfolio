# Inteligencia artificial generativa, pensamiento crítico y rendimiento académico en educación superior

Revisión sistemática sobre la relación entre la inteligencia artificial generativa, el pensamiento crítico y el rendimiento académico en estudiantes de educación superior. Las fuentes de búsqueda del proyecto son ScienceDirect y Google Scholar.

## Documento principal

[Consultar el manuscrito de la revisión sistemática](documentos/Revision_sistematica_IA_generativa_educacion_superior.docx).

## Organización del repositorio

| Ubicación | Contenido |
| --- | --- |
| `documentos/` | Manuscrito de la revisión sistemática en Word. |
| `figuras/` | Gráficas de distribución y caracterización de los estudios. |
| `scripts/` | Scripts de R numerados según el flujo de trabajo. |
| `data/raw/` | Exportaciones originales de ScienceDirect y Google Scholar, archivo de cribado y criterios. |
| `data/processed/` | Registros seleccionados y metadatos unificados. |
| `data/pdf/` | Artículos recuperados en PDF, identificados por código de registro. |
| `data/texto_completo_md/` | Textos completos convertidos a Markdown. |
| `output/` | Registros de recuperación y conversión, y listado HTML de recuperación manual. |
| `documentacion/` | Informe histórico del proceso e índice de los grupos de lectura originales. |
| `revision_sistematica.Rproj` | Proyecto de RStudio para trabajar desde la raíz del repositorio. |

## Preparación del entorno

Abrir `revision_sistematica.Rproj` en RStudio. Los scripts utilizan rutas relativas a la raíz del proyecto mediante `here`.

Instalar los paquetes de R necesarios una sola vez:

```r
install.packages(c(
  "dplyr", "readr", "stringr", "readxl", "purrr", "httr2", "here", "stringi",
  "DiagrammeR", "DiagrammeRsvg", "rsvg"
))
```

Para convertir PDF a Markdown, el script 04 requiere Python y MarkItDown:

```bash
python -m pip install "markitdown[pdf]"
```

El script 02 puede utilizar la variable de entorno `OPENALEX_API_KEY`, descrita en sus comentarios. Las claves se configuran localmente en `.Renviron`.

## Scripts disponibles

| Orden | Archivo | Función |
| --- | --- | --- |
| 1 | `scripts/01_identificar_seleccionados.R` | Localizar los registros seleccionados en las exportaciones originales. |
| 2 | `scripts/02_descargar_pdf_openalex.R` | Buscar y descargar versiones de acceso abierto de los textos completos. |
| 3 | `scripts/03_lista_recuperacion.R` | Generar el listado y el estado de recuperación manual. |
| 4 | `scripts/04_convertir_markdown.R` | Convertir los PDF recuperados a Markdown. |
| 5 | `scripts/05_diagrama_prisma.R` | Generar `figuras/diagrama_prisma_58_estudios.png` a partir de los conteos escritos en el script. |

Los scripts pueden ejecutarse desde RStudio o mediante `source("scripts/nombre_del_script.R")` con el proyecto abierto. Las descargas requieren conexión a Internet. Volver a ejecutar los scripts puede actualizar los archivos de salida existentes.

## Alcance de los archivos conservados

El manuscrito y el script del diagrama PRISMA reportan 58 estudios incluidos. Los archivos de búsqueda, recuperación y lectura documentan distintas etapas del proceso y contienen registros adicionales; sus cantidades no representan por sí mismas el total final de estudios incluidos.

El [informe del proceso del 14 de octubre de 2026](documentacion/Informe_proceso_recuperacion_2026-10-14.md) se conserva como antecedente histórico. Las fases que allí figuran como pendientes corresponden a esa fecha.

El script PRISMA contiene conteos explícitos y no calcula automáticamente las decisiones de elegibilidad. El paquete original no aporta un script de elegibilidad ni los scripts que generaron las gráficas existentes.

Los archivos de `data/raw/` conservan su contenido original. Los códigos `C001`, `C002`, etc. permiten relacionar los metadatos, los PDF y los textos convertidos. Se eliminaron las copias idénticas del corpus y del ZIP de exportaciones; el [índice de grupos de lectura](documentacion/Indice_grupos_lectura.md) conserva la agrupación original.

## Subir a GitHub

Descomprimir la carpeta y subir su contenido al repositorio, de modo que `README.md` quede en la raíz. Para cargar el conjunto completo de artículos y datos, se puede utilizar GitHub Desktop o Git.
