# This file is based on an implementation from CoxeterGroups.jl by Ulrich Thiel (@ulthiel), Cameron Braunstein (@CameronBraunstein),
# Joel Gibson (University of Sydney, @joelgibson), and Tom Schmit (@schto223)

###############################################################################
#
#   Weyl Groups
#
###############################################################################

@doc raw"""
    weyl_group(cartan_matrix::ZZMatrix) -> WeylGroup

Returns the Weyl group defined by a generalized Cartan matrix `cartan_matrix`.
"""
function weyl_group(cartan_matrix::ZZMatrix)
  return weyl_group(root_system(cartan_matrix))
end

@doc raw"""
    weyl_group(fam::Symbol, rk::Int) -> WeylGroup

Returns the Weyl group of the given type. See `cartan_matrix(fam::Symbol, rk::Int)` for allowed combinations.

# Examples
```jldoctest
julia> weyl_group(:A, 2)
Weyl group
  of root system of rank 2
    of type A2
```
"""
function weyl_group(fam::Symbol, rk::Int)
  return weyl_group(root_system(fam, rk))
end

@doc raw"""
    weyl_group(type::Vector{Tuple{Symbol,Int}}) -> WeylGroup

Returns the Weyl group of the given type. See `cartan_matrix(fam::Symbol, rk::Int)` for allowed combinations.
"""
function weyl_group(type::Vector{Tuple{Symbol,Int}})
  return weyl_group(root_system(type))
end

@doc raw"""
    weyl_group(type::Tuple{Symbol,Int}...) -> WeylGroup

Returns the Weyl group of the given type. See `cartan_matrix(fam::Symbol, rk::Int)` for allowed combinations.
"""
function weyl_group(type::Tuple{Symbol,Int}...)
  return weyl_group(root_system(collect(type)))
end

@doc raw"""
    (W::WeylGroup)(word::Vector{Int}) -> WeylGroupElem
"""
function (W::WeylGroup)(word::Vector{<:Integer}; normalize::Bool=true)
  return WeylGroupElem(W, word; normalize=normalize)
end

function Base.IteratorSize(::Type{WeylGroup})
  return Base.SizeUnknown()
end

function Base.eltype(::Type{WeylGroup})
  return WeylGroupElem
end

function Base.iterate(W::WeylGroup)
  state = (weyl_vector(root_system(W)), one(W))
  return one(W), state
end

function Base.iterate(W::WeylGroup, state::WeylIteratorNoCopyState)
  state = _iterate_nocopy(state)
  if isnothing(state)
    return nothing
  end

  return deepcopy(state[2]), state
end

@doc raw"""
    isfinite(W::WeylGroup) -> Bool
"""
function is_finite(W::WeylGroup)
  return W.finite
end

@doc raw"""
    one(W::WeylGroup) -> WeylGroupElem
"""
function Base.one(W::WeylGroup)
  return W(UInt8[]; normalize=false)
end

function Base.show(io::IO, mime::MIME"text/plain", W::WeylGroup)
  @show_name(io, W)
  @show_special(io, mime, W)
  io = pretty(io)
  println(io, LowercaseOff(), "Weyl group")
  print(io, Indent(), "of ", Lowercase())
  show(io, mime, root_system(W))
  print(io, Dedent())
end

function Base.show(io::IO, W::WeylGroup)
  @show_name(io, W)
  @show_special(io, W)
  io = pretty(io)
  if is_terse(io)
    print(io, LowercaseOff(), "Weyl group")
  else
    print(io, LowercaseOff(), "Weyl group of ", Lowercase(), root_system(W))
  end
end

function coxeter_matrix(W::WeylGroup)
  return cartan_to_coxeter_matrix(cartan_matrix(root_system(W)))
end

function elem_type(::Type{WeylGroup})
  return WeylGroupElem
end

@doc raw"""
    gen(W::WeylGroup, i::Int) -> WeylGroupElem

Returns the `i`th simple reflection (with respect to the underlying root system) of `W`.
"""
function gen(W::WeylGroup, i::Integer)
  @req 1 <= i <= ngens(W) "invalid index"
  return W(UInt8[i]; normalize=false)
end

@doc raw"""
    gens(W::WeylGroup) -> WeylGroupElem

Returns the simple reflections (with respect to the underlying root system) of `W`.
"""
function gens(W::WeylGroup)
  return [gen(W, i) for i in 1:ngens(W)]
end

@doc raw"""
    longest_element(W::WeylGroup) -> WeylGroupElem

Returns the unique longest element of `W`.
"""
function longest_element(W::WeylGroup)
  @req is_finite(W) "$W is not finite"

  _, w0 = conjugate_dominant_weight_with_elem(-weyl_vector(root_system(W)))
  return w0
end

@doc raw"""
    number_of_generators(W::WeylGroup) -> Int

Returns the number of generators of the `W`, i.e. the rank of the underyling root system.
"""
function number_of_generators(W::WeylGroup)
  return rank(root_system(W))
end

@doc raw"""
    order(::Type{T}, W::WeylGroup) where {T} -> T

Returns the order of `W`.
"""
function order(::Type{T}, W::WeylGroup) where {T}
  if !is_finite(W)
    throw(InfiniteOrderError(W))
  end

  ord = T(1)
  for (fam, rk) in root_system_type(root_system(W))
    if fam == :A
      ord *= T(factorial(rk + 1))
    elseif fam == :B || fam == :C
      ord *= T(2^rk * factorial(rk))
    elseif fam == :D
      ord *= T(2^(rk - 1) * factorial(rk))
    elseif fam == :E
      if rk == 6
        ord *= T(51840)
      elseif rk == 7
        ord *= T(2903040)
      elseif rk == 8
        ord *= T(696729600)
      end
    elseif fam == :F
      ord *= T(1152)
    else
      ord *= T(12)
    end
  end

  return ord
end

@doc raw"""
    root_system(W::WeylGroup) -> RootSystem

Returns the underlying root system of `W`.
"""
function root_system(W::WeylGroup)
  return W.root_system
end

###############################################################################
# Weyl group elements

function Base.:(*)(x::WeylGroupElem, y::WeylGroupElem)
  @req x.parent === y.parent "$x, $y must belong to the same Weyl group"

  p = deepcopy(y)
  for s in Iterators.reverse(word(x))
    lmul!(p, s)
  end
  return p
end

function Base.:(*)(x::WeylGroupElem, rw::Union{RootSpaceElem,WeightLatticeElem})
  @req root_system(parent(x)) === root_system(rw) "Incompatible root systems"

  rw2 = deepcopy(rw)
  for s in Iterators.reverse(word(x))
    reflect!(rw2, Int(s))
  end

  return rw2
end

function Base.:(*)(rw::Union{RootSpaceElem,WeightLatticeElem}, x::WeylGroupElem)
  @req root_system(parent(x)) === root_system(rw) "Incompatible root systems"

  rw2 = deepcopy(rw)
  for s in word(x)
    reflect!(rw2, Int(s))
  end

  return rw2
end

# to be removed once GroupCore is supported
function Base.:(^)(x::WeylGroupElem, n::Int)
  if n == 0
    return one(parent(x))
  elseif n < 0
    return inv(x)^(-n)
  end

  px = deepcopy(x)
  for _ in 2:n
    for s in Iterators.reverse(word(x))
      lmul!(px, s)
    end
  end

  return px
end

@doc raw"""
    <(x::WeylGroupElem, y::WeylGroupElem) -> Bool

Returns whether `x` is smaller than `y` with respect to the Bruhat order,
i.e., whether some (not necessarily connected) subexpression of a reduced
decomposition of `y`, is a reduced decomposition of `x`.
"""
function Base.:(<)(x::WeylGroupElem, y::WeylGroupElem)
  @req parent(x) === parent(y) "$x, $y must belong to the same Weyl group"

  if length(x) >= length(y)
    return false
  elseif isone(x)
    return true
  end

  tx = deepcopy(x)
  for i in 1:length(y)
    b, j, _ = explain_lmul(tx, y[i])
    if !b
      deleteat!(word(tx), j)
      if isone(tx)
        return true
      end
    end

    if length(tx) > length(y) - i
      return false
    end
  end

  return false
end

function Base.:(==)(x::WeylGroupElem, y::WeylGroupElem)
  return parent(x) === parent(y) && word(x) == word(y)
end

function Base.deepcopy_internal(x::WeylGroupElem, dict::IdDict)
  if haskey(dict, x)
    return dict[x]
  end

  y = parent(x)(deepcopy_internal(word(x), dict); normalize=false)
  dict[x] = y
  return y
end

@doc raw"""
    getindex(x::WeylGroupElem, i::Int) -> UInt8

Returns the index of simple reflection at the `i`th position in the normal form of `x`.
"""
function Base.getindex(x::WeylGroupElem, i::Int)
  return word(x)[i]
end

function Base.hash(x::WeylGroupElem, h::UInt)
  b = 0x80f0abce1c544784 % UInt
  h = hash(parent(x), h)
  h = hash(word(x), h)

  return xor(h, b)
end

@doc raw"""
    inv(x::WeylGroupElem) -> WeylGroupElem

Returns the inverse of `x`.
"""
function Base.inv(x::WeylGroupElem)
  y = parent(x)(sizehint!(UInt8[], length(x)); normalize=false)
  for s in word(x)
    lmul!(y, s)
  end
  return y
end

@doc raw"""
    isone(x::WeylGroupElem) -> Bool

Returns whether `x` is the identity.
"""
function Base.isone(x::WeylGroupElem)
  return isempty(word(x))
end

@doc raw"""
    length(x::WeylGroupElem) -> Int

Returns the length of `x`.
"""
function Base.length(x::WeylGroupElem)
  return length(word(x))
end

@doc raw"""
    parent(x::WeylGroupElem) -> WeylGroup

Returns the Weyl group that `x` is an element of.
"""
function Base.parent(x::WeylGroupElem)
  return x.parent
end

@doc raw"""
    rand(rng::Random.AbstractRNG, rs::Random.SamplerTrivial{WeylGroup})

Returns a random element of the Weyl group. The elements are not uniformally distributed.
"""
function Base.rand(rng::Random.AbstractRNG, rs::Random.SamplerTrivial{WeylGroup})
  W = rs[]
  return W(Int.(Random.randsubseq(rng, word(longest_element(W)), 2 / 3)))
end

function Base.show(io::IO, x::WeylGroupElem)
  @show_name(io, x)
  @show_special_elem(io, x)
  if length(word(x)) == 0
    print(io, "id")
  else
    print(io, join(Iterators.map(i -> "s$i", word(x)), " * "))
  end
end

@doc raw"""
    lmul(x::WeylGroupElem, i::Integer) -> WeylGroupElem

Returns the result of multiplying `x` from the left by the `i`th simple reflection.
"""
function lmul(x::WeylGroupElem, i::Integer)
  return lmul!(deepcopy(x), i)
end

@doc raw"""
    lmul!(x::WeylGroupElem, i::Integer) -> WeylGroupElem

Returns the result of multiplying `x` in place from the left by the `i`th simple reflection.
"""
function lmul!(x::WeylGroupElem, i::Integer)
  b, j, r = explain_lmul(x, i)
  if b
    insert!(word(x), j, r)
  else
    deleteat!(word(x), j)
  end

  return x
end

# explains what multiplication of s_i from the left will do.
# Returns a tuple where the first entry is true/false, depending on whether an insertion or deletion will happen,
# the second entry is the position, and the third is the simple root.
function explain_lmul(x::WeylGroupElem, i::Integer)
  @req 1 <= i <= rank(root_system(parent(x))) "Invalid generator"

  insert_index = 1
  insert_letter = UInt8(i)

  root = insert_letter
  for s in 1:length(x)
    if x[s] == root
      return false, s, x[s]
    end

    root = parent(x).refl[Int(x[s]), Int(root)]
    if iszero(root)
      # r is no longer a minimal root, meaning we found the best insertion point
      return true, insert_index, insert_letter
    end

    # check if we have a better insertion point now. Since word[i] is a simple
    # root, if root < word[i] it must be simple.
    if root < x[s]
      insert_index = s + 1
      insert_letter = UInt8(root)
    end
  end

  return true, insert_index, insert_letter
end

function parent_type(::Type{WeylGroupElem})
  return WeylGroup
end

# rename to reduced decompositions ?
function reduced_expressions(x::WeylGroupElem; up_to_commutation::Bool=false)
  return ReducedExpressionIterator(x, up_to_commutation)
end

@doc raw"""
    word(x::WeylGroupElem) -> Vector{UInt8}
"""
function word(x::WeylGroupElem)
  return x.word
end

function fp_group(W::WeylGroup; set_properties::Bool=true)
  return codomain(isomorphism(FPGroup, W; set_properties))
end

function isomorphism(::Type{FPGroup}, W::WeylGroup; set_properties::Bool=true)
  R = root_system(W)
  F = free_group(rank(R))

  gcm = cartan_matrix(R)
  rels = [
    (gen(F, i) * gen(F, j))^coxeter_matrix_entry_from_cartan_matrix(gcm, i, j) for
    i in 1:rank(R) for j in i:rank(R)
  ]

  G, _ = quo(F, rels)

  if set_properties
    set_is_finite(G, is_finite(W))
    is_finite(W) && set_order(G, order(W))
  end

  iso = function (w::WeylGroupElem)
    return G([i => 1 for i in word(w)])
  end

  isoinv = function (g::FPGroupElem)
    return W(abs.(letters(g)))
  end

  return MapFromFunc(W, G, iso, isoinv)
end

function permutation_group(W::WeylGroup; set_properties::Bool=true)
  return codomain(isomorphism(PermGroup, W; set_properties))
end

function isomorphism(::Type{PermGroup}, W::WeylGroup; set_properties::Bool=true)
  @req is_finite(W) "Weyl group is not finite"
  R = root_system(W)
  type, ordering = root_system_type_with_ordering(R)

  if length(type) != 1
    error("Not implemented (yet)")
  end
  if !issorted(ordering)
    error("Not implemented (yet)")
  end
  coxeter_type, n = only(type)
  if coxeter_type == :A
    G = symmetric_group(n + 1)

    iso = function (w::WeylGroupElem)
      reduce(*, [cperm(G, [i, i + 1]) for i in word(w)]; init=cperm(G))
    end

    isoinv = function (p::PermGroupElem)
      word = UInt8[]
      for cycle in cycles(p)
        transpositions = [
          sort([c, cycle[i + 1]]) for (i, c) in enumerate(cycle) if i < length(cycle)
        ]
        for t in transpositions
          word = reduce(
            vcat,
            [
              [i for i in t[1]:(t[2] - 1)],
              [i for i in reverse(t[1]:(t[2] - 2))],
              word,
            ],
          )
        end
      end
      return W(word)
    end
  else
    error("Not implemented (yet)")
  end

  if set_properties
    set_order(G, order(W))
  end

  return MapFromFunc(W, G, iso, isoinv)
end

###############################################################################
# ReducedExpressionIterator

function Base.IteratorSize(::Type{ReducedExpressionIterator})
  return Base.SizeUnknown()
end

function Base.eltype(::Type{ReducedExpressionIterator})
  return Vector{UInt8}
end

function Base.iterate(iter::ReducedExpressionIterator)
  w = deepcopy(word(iter.el))
  return w, w
end

function Base.iterate(iter::ReducedExpressionIterator, word::Vector{UInt8})
  isempty(word) && return nothing

  rk = rank(root_system(parent(iter.el)))

  # we need to copy word; iterate behaves differently when length is (not) known
  next = deepcopy(word)
  weight = reflect!(weyl_vector(root_system(parent(iter.el))), Int(next[1]))

  i = 1
  s = rk + 1
  while true
    # search for new simple reflection to add to the word
    while s <= rk && weight.vec[s] > 0
      s += 1
    end

    if s == rk + 1
      i += 1
      if i == length(next) + 1
        return nothing
      elseif i == 1
        return next, next
      end

      # revert last reflection and continue with next one
      s = Int(next[i])
      reflect!(weight, s)
      s += 1
    else
      if iter.up_to_commutation &&
        i < length(word) &&
        s < next[i + 1] &&
        is_zero_entry(cartan_matrix(root_system(parent(iter.el))), s, Int(next[i + 1]))
        s += 1
        continue
      end

      next[i] = UInt8(s)
      reflect!(weight, s)
      i -= 1
      s = 1
    end
  end
end

###############################################################################
# WeylIteratorNoCopy

# Iterates over all weights in the Weyl group orbit of the dominant weight `weight`,
# or analogously over all elements in the quotient W/W_P
# The iterator returns a tuple (wt, x), such that x*wt == iter.weight;
# this choice is made to align with conjugate_dominant_weight_with_elem

function Base.IteratorSize(::Type{WeylIteratorNoCopy})
  return Base.SizeUnknown()
end

function Base.eltype(::Type{WeylIteratorNoCopy})
  return WeylIteratorNoCopyState
end

function Base.iterate(iter::WeylIteratorNoCopy)
  state = deepcopy(iter.weight), one(iter.weyl_group)
  return state, state
end

# based on [Ste01], 4.C and 4.D
function Base.iterate(iter::WeylIteratorNoCopy, state::WeylIteratorNoCopyState)
  state = _iterate_nocopy(state)
  if isnothing(state)
    return nothing
  end
  return state, state
end

function _iterate_nocopy(state::WeylIteratorNoCopyState)
  wt, path = state[1], word(state[2])
  R = root_system(wt)

  ai = isempty(path) ? UInt8(0) : path[end]
  # compute next descendant index
  di = UInt8(0)
  while true
    di = next_descendant_index(Int(ai), Int(di), wt)
    if !iszero(di)
      break
    elseif isempty(path)
      return nothing
    elseif iszero(di)
      reflect!(wt, Int(ai))
      di = pop!(path)
      ai = isempty(path) ? UInt8(0) : path[end]
    end
  end

  push!(path, di)
  reflect!(wt, Int(di))
  return state
end

# based on [Ste01], 4.D
function next_descendant_index(ai::Int, di::Int, wt::WeightLatticeElem)
  if iszero(ai)
    for j in (di + 1):rank(root_system(wt))
      if !iszero(wt[j])
        return j
      end
    end
    return 0
  end

  for j in (di + 1):(ai - 1)
    if !iszero(wt[j])
      return j
    end
  end

  for j in (max(ai, di) + 1):rank(root_system(wt))
    if is_zero_entry(cartan_matrix(root_system(wt)), ai, j)
      continue
    end

    ok = true
    for k in ai:(j - 1)
      if reflect(wt, j)[k] < 0
        ok = false
        break
      end
    end
    if ok
      return j
    end
  end

  return 0
end

###############################################################################
# WeylOrbitIterator

@doc raw"""
    weyl_orbit(wt::WeightLatticeElem)

Returns an iterator over the Weyl group orbit at the weight `wt`.
"""
function weyl_orbit(wt::WeightLatticeElem)
  return WeylOrbitIterator(wt)
end

@doc raw"""
    weyl_orbit(R::RootSystem, vec::Vector{<:Integer})

Shorthand for `weyl_orbit(WeightLatticeElem(R, vec))`.
"""
function weyl_orbit(R::RootSystem, vec::Vector{<:Integer})
  return weyl_orbit(WeightLatticeElem(R, vec))
end

@doc raw"""
    weyl_orbit(W::WeylGroup, vec::Vector{<:Integer})

Shorthand for `weyl_orbit(root_system(R), vec)`.
"""
function weyl_orbit(W::WeylGroup, vec::Vector{<:Integer})
  return weyl_orbit(root_system(W), vec)
end

function Base.IteratorSize(::Type{WeylOrbitIterator})
  return Base.IteratorSize(WeylIteratorNoCopy)
end

function Base.eltype(::Type{WeylOrbitIterator})
  return WeightLatticeElem
end

function Base.iterate(iter::WeylOrbitIterator)
  (wt, _), data = iterate(iter.nocopy)
  return deepcopy(wt), data
end

function Base.iterate(iter::WeylOrbitIterator, state::WeylIteratorNoCopyState)
  it = iterate(iter.nocopy, state)
  if isnothing(it)
    return nothing
  end

  (wt, _), state = it
  return deepcopy(wt), state
end
