# extras/makeExposureSetsFigures.R
#
# Generates man/figures/exposure-sets-month{4,9}{,-dark}.svg
#
# Run with: Rscript extras/makeExposureSetsFigures.R

make_svg <- function(index_month, dark = FALSE) {

  ## ── Colours ─────────────────────────────────────────────────────────────
  if (dark) {
    bg           <- "#0d1117"; fg      <- "#e6e6e3"
    muted        <- "#a0a3aa"; gridcol <- "#34363d"
    bar_col      <- "#6b6e76"
    accent       <- "#8fa0f0"
    pale_acc     <- "#8fa0f0"; pale_acc_op <- 0.14
    grn          <- "#5cc39d"
    pale_grn     <- "#5cc39d"; pale_grn_op <- 0.16
  } else {
    bg           <- "#ffffff"; fg      <- "#1b1d22"
    muted        <- "#5d6169"; gridcol <- "#d9d9d2"
    bar_col      <- "#a3a6ad"
    accent       <- "#3448b5"
    pale_acc     <- "#3448b5"; pale_acc_op <- 0.10
    grn          <- "#1d7a5c"
    pale_grn     <- "#1d7a5c"; pale_grn_op <- 0.12
  }

  ## ── Layout constants ────────────────────────────────────────────────────
  W         <- 760
  H         <- 375
  tl0       <- 92          # timeline left x
  tl1       <- 470         # timeline right x
  ppm       <- (tl1 - tl0) / 24   # px per month = 15.75
  rows_top  <- 52          # y where first row begins
  rh        <- 42          # row height
  n_rows    <- 6
  axis_y    <- rows_top + n_rows * rh   # = 304
  status_x  <- 494         # status text left edge
  label_x   <- 88          # patient label right edge (right-aligned)

  ## ── Helper functions ────────────────────────────────────────────────────
  # Convert month value to x position
  xm <- function(m) tl0 + m * ppm

  # y-center of row i (0-indexed)
  row_cy <- function(i) rows_top + (i + 0.5) * rh

  # Format number cleanly for SVG (drop trailing .0)
  v <- function(x) {
    r <- round(x, 2)
    if (r == round(r, 0)) {
      as.character(as.integer(round(r, 0)))
    } else {
      sub("0+$", "", as.character(r))
    }
  }

  # Diamond SVG points string
  diamond_pts <- function(cx, cy, r = 7)
    paste0(v(cx), ",", v(cy - r), " ",
           v(cx + r), ",", v(cy),  " ",
           v(cx), ",", v(cy + r), " ",
           v(cx - r), ",", v(cy))

  ## ── Patient definitions ──────────────────────────────────────────────────
  # g0/g1: months on GLP-1 RA; surg: surgery month; out: outcome month
  pts <- list(
    list(nm = "Patient 1", g0 = 0, g1 = 24, surg = NA_real_, out = NA_real_),
    list(nm = "Patient 2", g0 = 0, g1 =  9, surg =  9,       out = NA_real_),
    list(nm = "Patient 3", g0 = 0, g1 = 24, surg = NA_real_, out = NA_real_),
    list(nm = "Patient 4", g0 = 0, g1 =  6, surg = NA_real_, out = NA_real_),
    list(nm = "Patient 5", g0 = 0, g1 =  4, surg =  4,       out = NA_real_),
    list(nm = "Patient 6", g0 = 0, g1 =  7, surg = NA_real_, out =  7)
  )

  ## ── Status classification (rules applied in order) ───────────────────────
  classify <- function(p) {
    if (!is.na(p$surg) && p$surg == index_month) return("switcher")
    if (!is.na(p$surg) && p$surg  < index_month) return("inelig_surg")
    if (!is.na(p$out)  && p$out  <= index_month) return("inelig_out")
    if (p$g1 < index_month)                       return("inelig_stop")
    if (!is.na(p$surg) && p$surg  > index_month)  return("comp_cens")
    "comp"
  }

  styles <- list(
    switcher    = list(
      text = paste0("Switcher: surgery at month ", index_month),
      col  = accent,  bold = TRUE,
      bgf  = pale_acc,  bgo = pale_acc_op,  op = 1.0),
    comp        = list(
      text = "Comparator: on GLP-1 RA",
      col  = grn,     bold = TRUE,
      bgf  = pale_grn,  bgo = pale_grn_op,  op = 1.0),
    comp_cens   = list(
      text = "Comparator (censored at own surgery)",
      col  = grn,     bold = TRUE,
      bgf  = pale_grn,  bgo = pale_grn_op,  op = 1.0),
    inelig_surg = list(
      text = "Not eligible: already had surgery",
      col  = muted,   bold = FALSE,
      bgf  = NA,  bgo = 0,  op = 0.38),
    inelig_out  = list(
      text = "Not eligible: outcome before index",
      col  = muted,   bold = FALSE,
      bgf  = NA,  bgo = 0,  op = 0.38),
    inelig_stop = list(
      text = "Not eligible: stopped GLP-1 RA",
      col  = muted,   bold = FALSE,
      bgf  = NA,  bgo = 0,  op = 0.38)
  )

  ## ── Build SVG string ─────────────────────────────────────────────────────
  svg_lines <- character(0)
  a <- function(...) svg_lines <<- c(svg_lines, paste0(...))

  theme_label <- if (dark) " (dark)" else ""

  a('<?xml version="1.0" encoding="UTF-8"?>')
  a('<svg xmlns="http://www.w3.org/2000/svg"')
  a('     viewBox="0 0 ', W, ' ', H, '" width="', W, '" height="', H, '"')
  a('     role="img">')
  a('  <title>Prevalent new-user design: comparator selection, index at month ',
    index_month, theme_label, '</title>')
  a('  <style>')
  a('    text {')
  a('      font-family: -apple-system, "Segoe UI", Helvetica, Arial, sans-serif;')
  a('    }')
  a('  </style>')

  # ── Background ──
  a('  <rect width="', W, '" height="', H, '" fill="', bg, '"/>')

  # ── Vertical gridlines (at months 0, 6, 12, 18, 24) ──
  for (gm in c(0, 6, 12, 18, 24)) {
    gx <- xm(gm)
    a('  <line x1="', v(gx), '" y1="', rows_top,
      '" x2="', v(gx), '" y2="', axis_y,
      '" stroke="', gridcol, '" stroke-width="1"/>')
  }

  # ── Row highlight backgrounds (drawn before row content) ──
  for (i in 0:(n_rows - 1)) {
    p  <- pts[[i + 1]]
    cy <- row_cy(i)
    st <- classify(p)
    si <- styles[[st]]
    if (!is.na(si$bgf) && si$bgo > 0) {
      a('  <rect x="4" y="', v(cy - 19), '" width="752" height="38"')
      a('        fill="', si$bgf, '" fill-opacity="', si$bgo, '" rx="2"/>')
    }
  }

  # ── Index vertical line ──
  ix <- xm(index_month)
  a('  <line x1="', v(ix), '" y1="20" x2="', v(ix), '" y2="', axis_y, '"')
  a('        stroke="', accent, '" stroke-width="2"/>')
  a('  <text x="', v(ix), '" y="16" text-anchor="middle"',
    ' fill="', accent, '" font-weight="bold" font-size="12">Index: month ', index_month, '</text>')

  # ── Row content ──
  for (i in 0:(n_rows - 1)) {
    p  <- pts[[i + 1]]
    cy <- row_cy(i)
    st <- classify(p)
    si <- styles[[st]]

    # Wrap ineligible rows in a reduced-opacity group
    if (si$op < 1) {
      a('  <g opacity="', si$op, '">')
    } else {
      a('  <g>')
    }

    # Patient name (right-aligned)
    a('    <text x="', label_x, '" y="', v(cy + 4), '"')
    a('          text-anchor="end" fill="', fg,
      '" font-weight="bold" font-size="12">', p$nm, '</text>')

    # GLP-1 RA bar
    a('    <rect x="', v(xm(p$g0)), '" y="', v(cy - 5),
      '" width="', v(xm(p$g1) - xm(p$g0)), '" height="10"')
    a('          fill="', bar_col, '" rx="2.5"/>')

    # Surgery: dashed tail + diamond (diamond drawn on top)
    if (!is.na(p$surg)) {
      sx <- xm(p$surg)
      a('    <line x1="', v(sx), '" y1="', v(cy),
        '" x2="', v(xm(24)), '" y2="', v(cy), '"')
      a('          stroke="', accent,
        '" stroke-width="1.5" stroke-dasharray="4 3"/>')
      a('    <polygon points="', diamond_pts(sx, cy), '"')
      a('             fill="', accent, '"/>')
    }

    # Outcome × symbol
    if (!is.na(p$out)) {
      ox <- xm(p$out)
      a('    <text x="', v(ox), '" y="', v(cy + 5), '"')
      a('          text-anchor="middle" fill="', fg,
        '" font-size="16" font-weight="bold">&#215;</text>')
    }

    # Status label
    fw <- if (si$bold) "bold" else "normal"
    a('    <text x="', status_x, '" y="', v(cy + 4), '"')
    a('          fill="', si$col, '" font-weight="', fw,
      '" font-size="12">', si$text, '</text>')

    a('  </g>')
  }

  # ── Axis line ──
  a('  <line x1="', tl0, '" y1="', axis_y,
    '" x2="', tl1, '" y2="', axis_y,
    '" stroke="', fg, '" stroke-width="1.5"/>')

  # ── Axis ticks and month labels ──
  for (gm in c(0, 6, 12, 18, 24)) {
    gx <- xm(gm)
    a('  <line x1="', v(gx), '" y1="', axis_y,
      '" x2="', v(gx), '" y2="', axis_y + 5,
      '" stroke="', fg, '" stroke-width="1.5"/>')
    a('  <text x="', v(gx), '" y="', axis_y + 17,
      '" text-anchor="middle" fill="', fg, '" font-size="12">', gm, '</text>')
  }

  # ── Axis caption ──
  mid_x <- v((tl0 + tl1) / 2)
  a('  <text x="', mid_x, '" y="', axis_y + 33,
    '" text-anchor="middle" fill="', muted,
    '" font-size="11">Months since starting a GLP-1 RA</text>')

  # ── Legend ──
  ly <- axis_y + 58   # = 362

  # Item 1: grey bar + "On GLP-1 RA"
  a('  <rect x="100" y="', ly - 5, '" width="24" height="10"')
  a('        fill="', bar_col, '" rx="2.5"/>')
  a('  <text x="130" y="', ly + 4, '" fill="', fg, '" font-size="12">On GLP-1 RA</text>')

  # Item 2: surgery diamond + "Surgery"
  a('  <polygon points="', diamond_pts(252, ly), '"')
  a('           fill="', accent, '"/>')
  a('  <text x="266" y="', ly + 4, '" fill="', fg, '" font-size="12">Surgery</text>')

  # Item 3: outcome × + "Outcome"
  a('  <text x="355" y="', ly + 5, '"')
  a('        text-anchor="middle" fill="', fg,
    '" font-size="14" font-weight="bold">&#215;</text>')
  a('  <text x="366" y="', ly + 4, '" fill="', fg, '" font-size="12">Outcome</text>')

  a('</svg>')

  paste(svg_lines, collapse = "\n")
}

## ── Write all four files ────────────────────────────────────────────────────
dir.create("man/figures", showWarnings = FALSE, recursive = TRUE)

for (im in c(4, 9)) {
  for (dk in c(FALSE, TRUE)) {
    suffix <- if (dk) "-dark" else ""
    fname  <- sprintf("man/figures/exposure-sets-month%d%s.svg", im, suffix)
    writeLines(make_svg(im, dk), fname)
    cat("Wrote", fname, "\n")
  }
}

cat("\nDone. Open files to inspect:\n")
cat("  open man/figures/exposure-sets-month9.svg\n")
cat("  open man/figures/exposure-sets-month4.svg\n")
