# .check_latex_report passes a missing-but-bundled package

    Code
      tabular:::.check_latex_report(out)
    Message
      
      -- LaTeX packages for PDF output 
      v base
      v tabularray (not found, bundled copy used)
      v ninecolors (not found, bundled copy used)
      v All required LaTeX packages are available.

# .check_latex_report remedies name the TinyTeX bundle and TEXMFHOME

    Code
      tabular:::.check_latex_report(out)
    Message
      
      -- LaTeX packages for PDF output 
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

