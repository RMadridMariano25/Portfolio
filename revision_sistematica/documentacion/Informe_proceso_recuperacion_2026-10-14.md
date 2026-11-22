# Informe histórico del proceso de recuperación de textos completos

Revisión sistemática para *CPU-e, Revista de Investigación Educativa* sobre la relación entre la inteligencia artificial generativa (incluido ChatGPT), el pensamiento crítico y el rendimiento académico en educación superior.

Fecha del reporte: 14 de octubre de 2026.

> Documento histórico: describe el estado del trabajo en esa fecha. El manuscrito y el script PRISMA corresponden a etapas posteriores; este informe no describe el estado final de la revisión.

## Estado general

| Fase | Estado |
| --- | --- |
| Búsqueda en ScienceDirect y Google Scholar | Terminada |
| Eliminación de duplicados y cribado por título y resumen | Terminada (archivo de recribado) |
| Identificación de los seleccionados en los archivos originales | Terminada (script 01) |
| Descarga automática de PDF de acceso abierto | En proceso (script 02) |
| Recuperación manual de los PDF pendientes | En proceso (script 03 y registro manual) |
| Conversión de PDF a Markdown | Script listo (script 04) |
| Revisión de elegibilidad a texto completo | Pendiente |
| Actualización del PRISMA y del manuscrito | No iniciar hasta revisar la matriz de elegibilidad |

## Archivos de entrada

| Archivo | Ubicación | Contenido |
| --- | --- | --- |
| 9 archivos `ScienceDirect_citations_*.ris` | `data/raw/sciencedirect/` | 900 registros (100 por archivo) |
| 5 archivos `scholar_parcial*.csv` | `data/raw/google_scholar/` | 500 registros (100 por archivo), formato Publish or Perish |
| `recribado_criterios_2026.xlsx` | `data/raw/cribado/` | 132 registros cribados, con identificadores C001, C002... y hoja de criterios |

Los archivos de `data/raw/` son los originales y no se modifican.

## Registros seleccionados para texto completo

El archivo de recribado clasifica los 132 registros así:

| Decisión en el recribado | Registros | Pasa a texto completo |
| --- | --- | --- |
| Candidato - evaluar texto completo | 104 | Sí |
| Incluido previamente - revalidar | 22 | Sí |
| Excluir - evidencia suficiente | 6 | No |
| **Total** | **132** | **126** |

## Script 01: identificación de los seleccionados

Archivo: `scripts/01_identificar_seleccionados.R`.

Localiza los 126 seleccionados en las exportaciones originales para recuperar sus datos completos. El cruce sigue este orden:

1. DOI, tomado del Excel o de la fuente.
2. Título normalizado idéntico (sin acentos, mayúsculas ni signos).
3. Título recortado: Google Scholar corta títulos con "…" (53 de sus 500 registros); se acepta si un título contiene al otro y ambos tienen al menos 30 caracteres.
4. Título casi idéntico (distancia de edición de 10 % o menos) y mismo año.

Resultado:

- Los 126 registros se localizaron; ninguno quedó sin coincidencia.
- 80 se encontraron en ScienceDirect y 50 en Google Scholar (algunos en ambas).
- Todas las coincidencias concuerdan con la fuente indicada en el Excel y ningún registro original se asignó a dos identificadores.
- Los 5 cruces hechos por título se revisaron uno por uno: solo difieren en apóstrofos, mayúsculas o el recorte "…".
- 91 registros tienen DOI y 35 no; los 126 tienen resumen.

Archivos generados en `data/processed/`:

| Archivo | Contenido |
| --- | --- |
| `seleccionados_texto_completo.csv` | Archivo principal: una fila por registro con datos unificados y las columnas del cribado |
| `seleccionados_sciencedirect.ris` | Las 80 entradas originales de ScienceDirect, sin modificar |
| `seleccionados_google_scholar.csv` | Las 50 filas originales de Google Scholar, con su `id_registro` |

En los metadatos tiene prioridad ScienceDirect, porque trae DOI y resumen completos; de Google Scholar se conservan la URL del artículo y la URL de texto completo.

## Script 02: descarga automática con OpenAlex

Archivo: `scripts/02_descargar_pdf_openalex.R`.

Para cada registro:

1. Lo identifica en OpenAlex por DOI. Si no tiene DOI o no aparece, lo busca por título y solo acepta el resultado si el título coincide y el año difiere como máximo en uno.
2. Reúne las direcciones de PDF de acceso abierto: ubicaciones de OpenAlex (editorial y repositorios), PubMed Central, SciELO y el enlace de texto completo de Google Scholar.
3. Las prueba en orden y guarda la primera que sea un PDF real (el archivo empieza con `%PDF-` y pesa al menos 20 KB). Si una dirección devuelve una página web, se registra como "no es PDF".

No se fuerza la descarga de artículos de pago; quedan como pendientes. El script puede ejecutarse varias veces: no repite descargas y continúa donde se quedó si se interrumpe.

Salidas:

- `data/pdf/<id_registro>.pdf`.
- `output/reporte_descargas_pdf.csv`: identificador, título, DOI, URL encontrada, estado de acceso abierto, descargado (sí/no), motivo del fallo, ruta del PDF y datos de trazabilidad.
- `output/pendientes_recuperacion.html`: pendientes con enlaces verificados (código HTTP junto a cada enlace).

Se recomienda definir `OPENALEX_API_KEY` en `.Renviron`.

## Script 03: lista de recuperación manual

Archivo: `scripts/03_lista_recuperacion.R`.

Genera `output/recuperacion_manual.html` con los 126 registros y su estado:

- **Recuperado**: existe `data/pdf/<id_registro>.pdf` y es un PDF válido.
- **Pendiente**: falta el PDF.
- **Archivo no válido**: existe el archivo, pero no es un PDF.

Cada fila incluye enlaces al DOI, al registro original, al texto completo de Google Scholar y una búsqueda por título en Google Scholar. Si existe el reporte del script 02, añade el motivo del fallo. También genera `output/estado_recuperacion.csv`.

Flujo de uso: descargar a mano los pendientes, guardarlos en `data/pdf/` con el nombre indicado y volver a ejecutar el script.

## Registro manual de recuperación

Archivo: `output/registro_recuperacion_manual.csv`.

Plantilla con los 126 registros para anotar el resultado de la búsqueda manual. Las columnas de identificación ya están llenas; se completan dos:

| Columna | Valores |
| --- | --- |
| `recuperado` | `si` o `no` |
| `motivo` | Frase fija, por ejemplo: `de pago sin acceso institucional`, `no localizado`, `enlace roto`, `solo resumen disponible`, `idioma no elegible`, `retractado` |

Debe guardarse como CSV UTF-8 y no se deben borrar filas ni cambiar los identificadores.

## Script 04: conversión a Markdown

Archivo: `scripts/04_convertir_markdown.R`.

Convierte cada PDF de `data/pdf/` a Markdown con MarkItDown (Microsoft) en `data/texto_completo_md/`. En cada ejecución solo convierte los PDF sin `.md` o los que se reemplazaron después de su conversión; omite los que ya están al día y los archivos que no son PDF. Marca como alerta los textos con menos de 5,000 caracteres, que suelen ser PDF escaneados. Registra el resultado en `output/conversion_markdown.csv`.

Requisito: `pip install "markitdown[pdf]"`.

## Orden de ejecución

1. `01_identificar_seleccionados.R`
2. `02_descargar_pdf_openalex.R`
3. `03_lista_recuperacion.R` (repetir tras cada lote de PDF descargados a mano)
4. `04_convertir_markdown.R` (repetir cuando haya PDF nuevos)

Paquetes de R: `dplyr`, `readr`, `stringr`, `readxl`, `purrr`, `httr2`, `here` y `stringi`.

## Siguiente fase: elegibilidad a texto completo

Se construirá una matriz de elegibilidad con un registro por fila, con la decisión, la razón principal y la página o sección donde se verificó. Criterios de la hoja "Criterios y alcance" del archivo de recribado:

| Criterio | Regla |
| --- | --- |
| Ventana | 2023 al 26 de septiembre de 2026 |
| Diseño | Estudio empírico primario con datos y resultados: experimental, cuasiexperimental, transversal, longitudinal o cualitativo |
| Publicación | Artículo de revista arbitrada, en español o inglés, con texto completo accesible |
| Población | Estudiantes de educación superior; docentes solo si hay resultados observados en estudiantes |
| Exposición | Uso, interacción o intervención con IA generativa (ChatGPT, LLM o sistema que la integre) |
| Resultado A | Pensamiento crítico medido, demostrado en tarea o reportado explícitamente por participantes |
| Resultado B | Rendimiento académico (calificaciones, promedio, pruebas, tareas evaluadas o percepción explícita de rendimiento) |
| Resultado elegible | Basta A o B; los resultados nulos o adversos son elegibles |
| No sustitutos | No inferir pensamiento crítico de metacognición, motivación, creatividad o autorregulación, ni rendimiento de satisfacción o compromiso |

Se excluyen:

- Revisiones sistemáticas, narrativas y metaanálisis.
- Protocolos sin resultados.
- Tesis, ponencias y trabajos no arbitrados.
- Estudios que solo evalúan las respuestas del modelo.
- Población no universitaria.
- Estudios sobre aceptación general de la IA sin resultados académicos ni de pensamiento crítico.
- Artículos sin texto completo verificable.

## Reglas pendientes

- No actualizar el diagrama PRISMA ni el manuscrito hasta reconciliar los registros y revisar la matriz de elegibilidad; los conteos actuales son provisionales.
- Los artículos que no se recuperen deben constar en el registro manual con su motivo, porque se reportan como "no recuperados" en el PRISMA.
