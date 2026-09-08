# The LaTeX idiom (`RULE.TEX.*`)

Every rule here is standard LaTeX idiom plus a few documented exceptions, not a matter of taste; when
unsure, reach for a standard LaTeX reference and KaTeX's published support table, never a
plausible-sounding typographic argument. Documenter renders KaTeX client-side, so a formula's TeX is the
page's text.

### RULE.TEX.RENDERED_MATH
All mathematics in docstrings and doc pages is rendered LaTeX, never a Unicode-glyph approximation, and
every code object is bound to its math symbol on first mention. Inline math is a double-backtick span,
display math a ```` ```math ```` block; inside a `"""` docstring every LaTeX backslash is doubled. Plain `#`
comments stay Unicode, being unrendered. Write the binding explicitly — `laplacian` ``\equiv \Delta`` —
so the reader always knows which symbol is which function, and write it as one span inside a rendered
docstring.

### RULE.TEX.CODE_IN_MATH
A code identifier never sits inside a math span, because the renderer sets it as the product of italic
single letters. Backtick it in prose; a code name that must appear inside a formula is `\texttt{…}`.

### RULE.TEX.ONE_SPAN
A formula is one LaTeX span, never split across a math span and an adjacent code span. Keep it one span,
a trailing code name in `\texttt{}`.

### RULE.TEX.INLINE_ONE_LINE
An inline math span stays on one source line, because a wrapped continuation that begins with a list or
blockquote leader is parsed as a new list item and silently drops the span out of math mode. Break the
prose around the span, never the span; the docs build fails on the defect.

### RULE.TEX.NO_HSCROLL
Nothing scrolls horizontally: a long docstring signature is hand-wrapped with a hanging indent under the
first argument, and a wide display formula is broken with `aligned`, `gathered` or `split`. Neither a
rendered code block nor display math auto-wraps; inline math reflows and is exempt. Never pack several
equations on one line behind `\quad`.

### RULE.TEX.CODE_SPAN_JULIA
A backtick span holds only well-formed Julia — a name, type, call or expression — never math that merely
looks code-ish. A half-open interval, an inequality, a product, a lone `≤` or `·` glyph is LaTeX; the real
operators `×`, `⋅` and `≈` backticked are code and stay.

### RULE.TEX.SPACING
Never space manually around a relation or binary operator, never put `\!` before a `\bigl`, never `\!\!`
before a sum, and never write `\,` except before an upright differential. Spacing next to `=`, `<`, `\in`,
`+` or `-` doubles the space TeX already puts there; `\!` before a delimiter that follows an operator or
name jams the delimiter into it, there being no gap to remove; between multiplied factors juxtaposition
is standard, and when a gratuitous thin space is removed it becomes a plain space, never nothing.
Correct and not to be "fixed": `\sim\!`, `\,\mathrm{d}x`, `\quad`/`\qquad` between display equations,
and `\mathrm{Re}` versus `\operatorname{Re}` before a delimiter.

### RULE.TEX.MATHBB
`\mathbb` is written only on a capital `A`–`Z` or `k`, and the indicator or identity is `\mathbf{1}`.
KaTeX's blackboard font covers only those glyphs, so `\mathbb` on a digit falls back to a plain glyph with
the font silently dropped.

### RULE.TEX.MATHBF
`\mathbf` is admitted only for an agreed list of strings, and vectors and tensors follow the package's one
vector notation. For this package the admitted strings are {{notation.mathbf_allowed}} and the vector
notation is {{notation.vectors}}: component notation with index letters, or bold italic `\boldsymbol{u}`
with a braced argument, or no vector notation at all. Never the other, and never an upright `\mathbf`
outside the admitted list.

### RULE.TEX.LEFTRIGHT
`\left` and `\right` are banned; every delimiter is sized by hand with `\bigl`/`\Bigl` … `\bigr`/`\Bigr`.
Manual delimiters are Open and Close atoms with no added gap, where `\left … \right` is an Inner atom that
adds a spurious gap around the fence. Sole exception: a system or cases written `\left\{ … \right.`; the
arrow commands are not delimiters and are unaffected.

### RULE.TEX.PARTIAL
A partial derivative is `\partial_{x_i}`, subscripting the coordinate, and a bare-index `\partial_i` is
banned. A second-order derivative is `\partial^2_{x_i x_i}`, a repeated index summed.

### RULE.TEX.IMAGINARY
The imaginary unit is upright `\mathrm{i}`, and `i`, `j`, `k` are indices. Never a bare italic `i`, never
`\imath` or `\mathbb{i}`; the differential is likewise upright, `\,\mathrm{d}x`.

### RULE.TEX.FRAC_BRACED
Every fraction argument is braced: `\tfrac{1}{2}`, never `\tfrac12` and never `\tfrac N2`. Both render
alike; the braces are the house style and the scan is exact.

### RULE.TEX.BOLDSYMBOL_BRACED
Every `\boldsymbol` argument is braced: `\boldsymbol{u}`, never `\boldsymbol u`. The unbraced form takes
one token and silently stops at a subscript.

### RULE.TEX.SWALLOWED_ESCAPE
Inside a Julia docstring every LaTeX backslash is doubled, because a single backslash before `a`, `b`,
`e`, `f`, `n`, `r`, `t`, `v`, an octal digit, `x`, `u` or `U` is swallowed by the string parser. The
rendered formula then lacks the command with no error anywhere.

### RULE.TEX.RENDERED_MARKUP
No emphasis marker survives into rendered prose. An emphasis nesting CommonMark cannot resolve, such as
`*a **b***`, renders as literal asterisks; the built page, not the source, is where it shows, and the docs
build scans the built HTML for it.

### RULE.TEX.GREEK_AB
Accumulation scalars are written Unicode `α` and `β` everywhere — arguments, locals, kernel bodies and
docstrings — and the named ASCII holdouts stay. A hand-written operation spelling them `alpha`/`beta` is
drift; a flag naming the α/β variant and an external window-shape `beta` in an English-register block are
the recorded exceptions.
