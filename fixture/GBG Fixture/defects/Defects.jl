# defects/Defects.jl — the planted defect corpus of the fixture (ARCHITECTURE §8, §12.B). NEVER included
# by the package: the self-tests scan it with a derived config whose `src` surface adds this file. Every
# docstring below carries exactly the class `defects.toml` names for it; the clean twins live in src/.
"""
    FixtureDefects

The module of planted defects; each docstring below is one class of §12.B.
"""
module FixtureDefects

using ..FixtureA: Grid, twice

"""
    knob_setting(x)

Turn the knob to adjust the result. The argument `x` is the input.
"""
knob_setting(x) = x

"""
    bare_partial(u)

The derivative ``\\partial_i u`` at a node. The argument `u` is the field.
"""
bare_partial(u) = u

"""
    thin_space(u)

The product ``a\\,b`` of two entries. The argument `u` is the field.
"""
thin_space(u) = u

"""
    frac_unbraced(u)

The half ``\\tfrac12 u`` of a field. The argument `u` is the field.
"""
frac_unbraced(u) = u

"""
    neg_thin_bigl(u)

The bracket ``\\!\\bigl(u\\bigr)`` around a field. The argument `u` is the field.
"""
neg_thin_bigl(u) = u

"""
    neg_thin_double(u)

The sum ``\\!\\!\\sum_i u_i`` over a field. The argument `u` is the field.
"""
neg_thin_double(u) = u

"""
    mathbb_digit(u)

The indicator ``\\mathbb{1}`` of a field. The argument `u` is the field.
"""
mathbb_digit(u) = u

"""
    mathbf_banned(u)

The vector ``\\mathbf{u}`` of values. The argument `u` is the field.
"""
mathbf_banned(u) = u

"""
    boldsymbol_unbraced(u)

The vector ``\\boldsymbol u`` of values. The argument `u` is the field.
"""
boldsymbol_unbraced(u) = u

"""
    left_right(u)

The bracket ``\\left(u\\right)`` around a field. The argument `u` is the field.
"""
left_right(u) = u

"""
    ref_abut(u)

The double of a field is [`twice`](@ref)`(u)`. The argument `u` is the field.
"""
ref_abut(u) = u

"""
    GhostField(n)

A record with a stale field list. The fields are:

- `n` — the node count.
- `spacing` — the spacing, which the struct no longer has.
"""
struct GhostField
    n::Int
end

"""
    UndocField(n, spacing)

A record missing a bullet. The fields are:

- `n` — the node count.
"""
struct UndocField
    n::Int
    spacing::Float64
end

"""
    mixed_link_run(u)

Related: [`twice`](@ref) and `scale!` share the loop. The argument `u` is the field.
"""
mixed_link_run(u) = u

"""
    bold_arg_bullet(u; tolerance = 0)

A bolded argument bullet. The arguments are:

- **`u`** — the field.
- `tolerance` — the tolerance.
"""
bold_arg_bullet(u; tolerance = 0) = u

"""
    inline_math_split(u)

The mean is ``\\bar u = \\tfrac{1}{N}
- \\sum_i u_i`` over the nodes. The argument `u` is the field.
"""
inline_math_split(u) = u

"""
    swallowed_escape(u)

The gradient ``\nabla u`` of a field. The argument `u` is the field.
"""
swallowed_escape(u) = u

"""
    retired_claim(u)

In this package the factor one third is used for the energy. The argument `u` is the field.
"""
retired_claim(u) = u

"""
    paragraph_over_cap(u)

The argument `u` is the field. This paragraph runs on far past the cap of one hundred and twenty
words so that the shape scan has something to measure, and it keeps going with more words about the
field, the grid, the nodes, the spacing, the mean, the energy, the factor, the convention, the
aliasing, the destination, the source, the loop, the entry, the index, the length, the mismatch, the
error, the exception, the message, the reader, the page, the site, the build, the scan, the tier, the
hard and the triage, the population, the exemption, the ledger, the reason, the expiry, the doctor,
the check, the pass, the fail, the warn, the round, the lane, the hat, the anchor, the gate, the pin,
the managed file, the template, the slot, the render, the sidecar, the hash, the sync, the init, the
fixture, the defect, the class, the twin, the test, the arm, the must-hit, the clean, the corpus, the
tool, the consumer, the behaviour, the data, and the one thing connecting them.
"""
paragraph_over_cap(u) = u

"""
    fields_not_last(n)

A record whose field heading is followed by another heading. The fields are:

- `n` — the node count.

# Fields

- `n` — the node count.

# Notes

A note after the field list.
"""
struct FieldsNotLastRecord
    n::Int
end

"""
    returns_typed(x) -> Union{Nothing,Bool}

A typed RETURN annotation, which is not a typed argument: the scan that reads the parenthesised list must
leave this one alone. The argument is `x`, the value tested. Returns the flag, or nothing.
"""
returns_typed(x) = x > 0 ? true : nothing

"""
    typed_signature(x::Real; scale::Real = 1.0) -> Real

A signature that types its arguments where the rule asks for names and defaults alone, the types
belonging to the bullets. The arguments are:

- `x` — the value, a real.
- `scale` — what it is multiplied by, a real.

Returns the product.
"""
typed_signature(x::Real; scale::Real = 1.0) = x * scale

"""
    wrong_args_form(a, b, c)

Three arguments bound in running prose where the rule asks for the bulleted form. The arguments are `a`,
the first; `b`, the second; and `c`, the third. Returns nothing.
"""
wrong_args_form(a, b, c) = nothing

"""
    prose_reference(u)

The argument `u` is the field. The method of Cooley and Tukey, [*An algorithm for the machine calculation of complex Fourier series*](https://doi.org/10.1090/S0025-5718-1965-0178586-1), Mathematics of Computation 19 (1965), is applied to it: the whole reference sits in the sentence, where the rule says author–year belongs.
"""
prose_reference(u) = u

"""
    doi_missing(u)

The argument `u` is the field.

Reference: A. N. Other, [*A paper the references never list*](https://doi.org/10.9999/never-listed),
Journal of Nothing 1 (2001).
"""
doi_missing(u) = u

"""
    argcov_gap(u, grid, factor)

Scales a field on a grid. The arguments are `u`, the field, and `grid`, the grid it lives on. Returns
the scaled field.
"""
argcov_gap(u, grid, factor) = u

"""
    formula_backticks(u)

The condition `u ≤ 1` holds at every node. The argument `u` is the field.
"""
formula_backticks(u) = u

"""
    manual_spacing(u)

The relation ``a \; = \; b`` between two entries. The argument `u` is the field.
"""
manual_spacing(u) = u

"""
    code_in_math(u)

The bound ``spacing < 1`` on the grid. The argument `u` is the field.
"""
code_in_math(u) = u

"""
    crammed_citation(u)

The argument `u` is the field.

References: A. Author (2001); B. Author (2002); C. Author (2003).
"""
crammed_citation(u) = u

"""
    dead_section_ref(u)

See §4 of docs/ARCHITECTURE.md for the convention. The argument `u` is the field.
"""
dead_section_ref(u) = u

"""
    lowercase_opener(u)

The argument `u` is the field. `twice` doubles it before the sum.
"""
lowercase_opener(u) = u

"""
    wide_signature(first_argument_with_a_long_name, second_argument_with_a_long_name, third_one, fourth)

A signature wider than eighty-eight columns. The arguments are `first_argument_with_a_long_name`,
`second_argument_with_a_long_name`, `third_one` and `fourth`, all fields.
"""
wide_signature(a, b, c, d) = a

"""
    abutting_span(coefficient)

The factor `coefficient` ``= -D\\tau`` in the exponent. The argument `coefficient` is the factor.
"""
abutting_span(coefficient) = coefficient

"""
    twice(x; stale = 1)

A stale signature: `twice` takes no keyword. The arguments are `x`, the number, and `stale`, a keyword
that does not exist.
"""
function stale_keyword end

"""
    unlinked_cross_module(u)

The mean is computed by mean_value in the sibling module, mentioned bare as `mean_value`. The
argument `u` is the field.
"""
unlinked_cross_module(u) = u

"""
    double_link(u)

The double [`twice`](@ref) of a field, and again [`twice`](@ref). The argument `u` is the field.
"""
double_link(u) = u

end # module FixtureDefects
