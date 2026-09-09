# GBGFixture — architecture

!!! info "Written by AI, not regularly reviewed"
    This page is written by AI and is not reviewed regularly by a human.

## 1. Purpose

A grid of ``N`` nodes at spacing ``h`` carries a value field ``u``. The package scales a field in place
and reduces it to its mean and its discrete energy. Every operation is exact at every node; the energy
uses the one-half convention ``E = \tfrac{1}{2} h \sum_i u_i^2``.

## 2. Invariants

- An in-place operation writes its destination and nothing else; the destination may alias the source.
- A reduction never allocates a field-sized temporary.
- The imaginary unit, where it appears, is upright ``\mathrm{i}``; a vector is written in components.

## 3. Decision log

1. **The energy convention.** The factor one half follows Cooley and Tukey (1965); a factor one third
   was considered and declined.
2. **Aliasing.** `scale!` admits `destination === source` because the loop reads each entry before it
   writes it.

## References

- J. W. Cooley, J. W. Tukey, [*An algorithm for the machine calculation of complex Fourier series*](https://doi.org/10.1090/S0025-5718-1965-0178586-1), Mathematics of Computation 19 (1965).
