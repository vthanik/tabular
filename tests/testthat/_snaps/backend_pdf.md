# .check_latex_report passes a missing-but-bundled package

    Code
      tabular:::.check_latex_report(out)
    Message
      
      -- LaTeX packages for PDF output 
      ? TeX Live version (xelatex missing, or a non-TeX-Live distribution such as
      MiKTeX)
      v base
      v tabularray (not found, bundled copy used)
      v ninecolors (not found, bundled copy used)
      v All required LaTeX packages are available.

# .check_latex_report remedies name the TinyTeX bundle and TEXMFHOME

    Code
      tabular:::.check_latex_report(out)
    Message
      
      -- LaTeX packages for PDF output 
      ? TeX Live version (xelatex missing, or a non-TeX-Live distribution such as
      MiKTeX)
      v tabularray (not found, bundled copy used)
      x fancyhdr
      ! Missing 1 LaTeX package: "fancyhdr".
      Install with `tinytex::tlmgr_install(c('fancyhdr'))`.
      If the install stalls (commonly on Windows, where the default CTAN mirror
      redirects on every call), pin a concrete mirror once with
      `tinytex::tlmgr_repo("auto")` then retry.
      On an OS-managed TeX Live (RHEL/dnf, Debian/apt) or wherever tlmgr is locked:
      install a user-space TinyTeX with `tinytex::install_tinytex(bundle =
      "TinyTeX")` instead (the community bundle covers every package above). Never
      force a locked tlmgr with `--ignore-warning`.
      Where no TeX install is possible at all: download each missing `.sty` from CTAN
      into '~/texmf/tex/latex/<package>/' and set `TEXMFHOME` to '~/texmf'; xelatex
      resolves it from there without tlmgr.

# .check_latex_report flags a too-old TeX Live kernel

    Code
      tabular:::.check_latex_report(out, texlive_year = 2018L)
    Message
      
      -- LaTeX packages for PDF output 
      x TeX Live 2018 (LaTeX kernel too old; tabularray needs the 2022-11-01 kernel,
      TeX Live 2023 or newer)
      v base
      v tabularray (not found, bundled copy used)
      ! TeX Live 2018 cannot compile tabular's PDF output: the bundled tabularray requires the 2022-11-01 LaTeX kernel (TeX Live 2023 or newer).
      Update the TeX installation, or install a user-space TinyTeX with
      `tinytex::install_tinytex(bundle = "TinyTeX")` or `quarto install tinytex`
      (downloads from GitHub, so it also works behind proxies that block CTAN). Both
      land in the standard TinyTeX location, which tabular and `tinytex::latexmk()`
      prefer over the `PATH` automatically.
      In a containerised workspace (Domino / Posit Workbench / Databricks): ask the
      image admin to update TeX Live, or render to RTF / HTML / DOCX instead via
      `emit(spec, "out.rtf")`.

# .check_latex_report passes a current TeX Live year

    Code
      tabular:::.check_latex_report(out, texlive_year = 2026L)
    Message
      
      -- LaTeX packages for PDF output 
      v TeX Live 2026
      v base
      v tabularray
      v All required LaTeX packages are available.

