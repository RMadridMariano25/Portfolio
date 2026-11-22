# Instala los paquetes una sola vez si te faltan:
# install.packages(c("DiagrammeR", "DiagrammeRsvg", "rsvg"))

library(DiagrammeR)
library(DiagrammeRsvg)
library(rsvg)
library(here)

dir.create(here("figuras"), showWarnings = FALSE)

diagrama_prisma <- grViz("
digraph prisma {

  graph [
    layout = dot,
    rankdir = TB,
    splines = ortho,
    nodesep = 0.55,
    ranksep = 0.65,
    bgcolor = white,
    pad = 0.3
  ]

  node [
    shape = box,
    style = 'rounded,filled',
    fillcolor = '#EAF2F8',
    color = '#29465B',
    fontname = Arial,
    fontsize = 12,
    margin = '0.22,0.16',
    penwidth = 1.3
  ]

  edge [
    color = '#29465B',
    penwidth = 1.2,
    arrowsize = 0.7
  ]

  inicial [
    label = 'Resultados mostrados por los buscadores\\nGoogle Scholar: 20 665\\nScienceDirect: 3 577\\nTotal: 24 242'
  ]

  filtrados [
    label = 'Registros retenidos en los CSV\\ntras la exportación y los filtros\\nGoogle Scholar: 80\\nScienceDirect: 135\\nTotal: 215'
  ]

  duplicados [
    label = 'Registros duplicados eliminados\\n(n = 3)',
    fillcolor = white
  ]

  unificados [
    label = 'Registros unificados\\n(n = 212)'
  ]

  no_matriz [
    label = 'Registros que no pasaron\\na la matriz de recribado\\n(n = 80)',
    fillcolor = white
  ]

  recribados [
    label = 'Registros recribados por título y resumen\\n(n = 132)'
  ]

  excluidos_inicial [
    label = 'Registros excluidos antes\\nde buscar el texto completo\\n(n = 6)',
    fillcolor = white
  ]

  buscados [
    label = 'Publicaciones buscadas para recuperación\\n(n = 126)'
  ]

  no_recuperados [
    label = 'Publicaciones no recuperadas\\n(n = 31)',
    fillcolor = white
  ]

  evaluados [
    label = 'Publicaciones evaluadas a texto completo\\n(n = 95)'
  ]

  excluidos_texto [
    label = 'Publicaciones excluidas tras\\nevaluar el texto completo\\n(n = 37)',
    fillcolor = white
  ]

  incluidos [
    label = 'Estudios incluidos en la revisión\\n(n = 58)',
    fillcolor = '#DDEEDC',
    color = '#39734B'
  ]

  nota [
    shape = plain,
    fontname = Arial,
    fontsize = 10,
    label = 'Nota: los 24 242 son resultados mostrados por las plataformas;\\nno equivalen a registros examinados o excluidos individualmente.'
  ]

  inicial -> filtrados
  filtrados -> unificados
  filtrados -> duplicados
  unificados -> recribados
  unificados -> no_matriz
  recribados -> buscados
  recribados -> excluidos_inicial
  buscados -> evaluados
  buscados -> no_recuperados
  evaluados -> incluidos
  evaluados -> excluidos_texto
  incluidos -> nota [style = invis]

  {rank = same; filtrados; duplicados}
  {rank = same; unificados; no_matriz}
  {rank = same; recribados; excluidos_inicial}
  {rank = same; buscados; no_recuperados}
  {rank = same; evaluados; excluidos_texto}
}
")

# Mostrarlo en RStudio
diagrama_prisma

# Guardar el diagrama en la carpeta de figuras del proyecto
svg <- export_svg(diagrama_prisma)

rsvg_png(
  charToRaw(svg),
  file = here("figuras", "diagrama_prisma_58_estudios.png"),
  width = 2400
)

cat("Archivo creado:", here("figuras", "diagrama_prisma_58_estudios.png"), "\n")