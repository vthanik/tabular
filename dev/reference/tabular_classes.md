# tabular S7 classes

S7 class definitions backing tabular's display-side IR. Users do not
construct these directly except for
[`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md);
every other class is built and chained by the verb pipeline
([`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md)
-\> [`cols()`](https://vthanik.github.io/tabular/dev/reference/cols.md)
-\>
[`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md)
-\>
[`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md)
-\>
[`style()`](https://vthanik.github.io/tabular/dev/reference/style.md)
-\>
[`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md)
-\>
[`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md)
-\>
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md)
/ [`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md)).

## Details

The class set is intentionally small (~11 concepts) so the IR fits in
one mental model:

|  |  |  |
|----|----|----|
| class | role | constructor |
| `tabular_spec` | root container; carries data + every other spec slot | [`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md) |
| `col_spec` | per-column DSL (usage, label, format, align, ...) | [`col_spec()`](https://vthanik.github.io/tabular/dev/reference/col_spec.md) |
| `header_node` | one node in the multi-level header tree | internal — built by [`headers()`](https://vthanik.github.io/tabular/dev/reference/headers.md) |
| `sort_spec` | sort keys + per-key direction | internal — built by [`sort_rows()`](https://vthanik.github.io/tabular/dev/reference/sort_rows.md) |
| `style_node` | one resolved style attribute set (per-cell) | internal — built by [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md) |
| `style_layer` | one `tabular_location` + style_node | internal — built by [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md) |
| `style_spec` | the cascade root (defaults + cols + headers + layers) | internal — built by [`style()`](https://vthanik.github.io/tabular/dev/reference/style.md) |
| `pagination_spec` | page-split policy (keep_together, panels, floors) | internal — built by [`paginate()`](https://vthanik.github.io/tabular/dev/reference/paginate.md) |
| `preset_spec` | render geometry (paper, orientation, font, margins) | internal — built by [`preset()`](https://vthanik.github.io/tabular/dev/reference/preset.md) |
| `inline_ast` | parsed inline-formatting AST (runs of bold / sup / …) | internal — built by `.parse_inline()` |
| `tabular_grid` | resolved per-page cells + ASTs + styles + headers | [`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md) |

Every spec slot is typed: a verb that would mutate a slot to an invalid
value fails at construction time (the S7 validator runs as a last-line
defense behind the cli-friendly verb-level validators).

**Class predicates.** Each class has a matching `is_<name>()` predicate;
see
[`tabular_predicates`](https://vthanik.github.io/tabular/dev/reference/tabular_predicates.md)
for the full list.

## See also

**Class predicates:**
[`tabular_predicates`](https://vthanik.github.io/tabular/dev/reference/tabular_predicates.md).

**Pipeline entry verbs:**
[`tabular()`](https://vthanik.github.io/tabular/dev/reference/tabular.md),
[`as_grid()`](https://vthanik.github.io/tabular/dev/reference/as_grid.md),
[`emit()`](https://vthanik.github.io/tabular/dev/reference/emit.md).
