# interpolation error messages are stable

    Code
      interp("a{}b")
    Condition
      Error:
      ! Found an empty interpolation with nothing between the braces.
      i Put an R expression inside, or double a brace to write a literal one.

---

    Code
      interp("a{b")
    Condition
      Error:
      ! Unterminated interpolation in "a{b".
      x An opening brace was never closed.
      i Double a brace to write a literal one.

---

    Code
      interp("a}b")
    Condition
      Error:
      ! Unbalanced braces in "a}b".
      x Found a closing brace with no matching open brace.
      i Double a brace to write a literal one.

---

    Code
      interp("{1 +}")
    Condition
      Error:
      ! Could not parse the interpolation "1 +".
      x R parse error: <text>:2:0: unexpected end of input 1: 1 + ^.

---

    Code
      interp("{nope_unbound_symbol}")
    Condition
      Error:
      ! Could not evaluate the interpolation "nope_unbound_symbol".
      x object 'nope_unbound_symbol' not found.

---

    Code
      interp("{1:2}")
    Condition
      Error:
      ! The interpolation "1:2" must produce a single value.
      x It produced 2 values after coercion to character.

