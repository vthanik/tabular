# parse_inline snapshot suite (25 strings)

    Code
      summary_table
    Output
                                                                                              plain 
                                                                                            "plain" 
                                                                                      plain_newline 
                                                                          "plain | newline | plain" 
                                                                                            md_bold 
                                                                                      "bold(plain)" 
                                                                                          md_italic 
                                                                                    "italic(plain)" 
                                                                                            md_code 
                                                                                      "code(plain)" 
                                                                                            md_link 
                                                                                      "link(plain)" 
                                                                                             md_sup 
                                                                               "plain | sup(plain)" 
                                                                                             md_sub 
                                                                       "plain | sub(plain) | plain" 
                                                                                           md_mixed 
      "bold(plain) | plain | italic(plain) | plain | code(plain) | plain | sup(plain) | sub(plain)" 
                                                                                      md_link_title 
                                                                                      "link(plain)" 
                                                                                     md_inline_html 
                                                                      "plain | bold(plain) | plain" 
                                                                                      md_hard_break 
                                                                "plain | newline | newline | plain" 
                                                                                           md_empty 
                                                                                                 "" 
                                                                                             html_b 
                                                                                      "bold(plain)" 
                                                                                        html_strong 
                                                                                      "bold(plain)" 
                                                                                            html_em 
                                                                                    "italic(plain)" 
                                                                                             html_i 
                                                                                    "italic(plain)" 
                                                                                           html_sup 
                                                                                       "sup(plain)" 
                                                                                           html_sub 
                                                                                       "sub(plain)" 
                                                                                          html_code 
                                                                                      "code(plain)" 
                                                                                             html_a 
                                                                                      "link(plain)" 
                                                                                          html_span 
                                                                                      "span(plain)" 
                                                                                            html_br 
                                                                          "plain | newline | plain" 
                                                                                       html_unknown 
                                                                                            "plain" 
                                                                                         html_empty 
                                                                                                 "" 

# inline-format snapshot errors

    Code
      md(NA_character_)
    Condition
      Error:
      ! `text` must not be `NA`.
      i Use `""` for an empty render.

---

    Code
      html(c("a", "b"))
    Condition
      Error:
      ! `text` must be length 1.
      x You supplied length 2.
      i Wrap each line separately when composing multi-line content.

---

    Code
      parse_inline(c("a", "b"))
    Condition
      Error:
      ! `x` must be a length-1 character or <inline_ast>.
      x You supplied a character vector of length 2.
      i Wrap multi-line content as `md()` or `html()`.

