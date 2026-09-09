# !!! info "Written by AI, not regularly reviewed"
#     This page is written by AI and is not reviewed regularly by a human.
#
# # Scaling a field
#
# A field of ``N`` values on a [`Grid`](@ref) is scaled in place by ``\alpha`` with `scale!`; the
# energy ``E = \tfrac{1}{2} h \sum_i u_i^2`` scales by ``\alpha^2``.
using GBGFixture
grid = Grid(4, 0.5)
u = [1.0, 2.0, 3.0, 4.0]
before = total_energy(u, grid)
scale!(u, u, 2.0)
after = total_energy(u, grid)
after / before   ## the ratio is ``\alpha^2 = 4``
