@doc raw"""
    is_base_space_fully_specified(m::AbstractFTheoryModel)

Return `true` if the F-theory model has a concrete base space and `false` otherwise.

```jldoctest
julia> t = literature_model(arxiv_id = "1109.3454", equation = "3.1")
Assuming that the first row of the given grading is the grading under Kbar

Global Tate model over a not fully specified base -- SU(5)xU(1) restricted Tate model based on arXiv paper 1109.3454 Eq. (3.1)

julia> is_base_space_fully_specified(t)
false
```
"""
is_base_space_fully_specified(m::AbstractFTheoryModel) = !(typeof(m.base_space) <: FamilyOfSpaces)

@doc raw"""
    is_partially_resolved(m::AbstractFTheoryModel)

Return `true` if resolution techniques were applied to the F-theory model,
thereby potentially resolving its singularities. Otherwise, return `false`.

```jldoctest
julia> B3 = projective_space(NormalToricVariety, 3)
Normal toric variety

julia> w = torusinvariant_prime_divisors(B3)[1]
Torus-invariant, prime divisor on a normal toric variety

julia> t = literature_model(arxiv_id = "1109.3454", equation = "3.1", base_space = B3, model_sections = Dict("w" => w), completeness_check = false)
Construction over concrete base may lead to singularity enhancement. Consider computing singular_loci. However, this may take time!

Global Tate model over a concrete base -- SU(5)xU(1) restricted Tate model based on arXiv paper 1109.3454 Eq. (3.1)

julia> is_partially_resolved(t)
false

julia> t2 = blow_up(t, ["x", "y", "x1"]; coordinate_name = "e1")
Partially resolved global Tate model over a concrete base -- SU(5)xU(1) restricted Tate model based on arXiv paper 1109.3454 Eq. (3.1)

julia> is_partially_resolved(t2)
true
```
"""
is_partially_resolved(m::AbstractFTheoryModel) = get_attribute(m, :partially_resolved)