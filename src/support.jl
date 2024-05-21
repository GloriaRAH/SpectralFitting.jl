@enumx ErrorStatistics begin
    Numeric
    Poisson
    Gaussian
    Unknown
end

"""
    abstract type AbstractDataLayout end

The data layout primarily concerns the relationship between the objective and
the domain. It is used to work out whether a model and a dataset are fittable,
and if not, whether a translation in the output of the model to the domain of
the model is possible.

The following methods may be used to interrogate support:
- [`preferred_support`](@ref) for inferring the preferred support of a model when multiple supports are possible.
- [`common_support`](@ref) to obtain the common support of two structures

The following method is also used to define the support of a model or dataset:
- [`supports`](@ref)
"""
abstract type AbstractDataLayout end

"""
    struct OneToOne <: AbstractDataLayout end

Indicates there is a one-to-one (injective) correspondence between each input
value and each output value. That is to say
```julia
length(objective) == length(domain)
```
"""
struct OneToOne <: AbstractDataLayout end

"""
    struct ContiguouslyBinned <: AbstractDataLayout end

Contiguously binned data layout means that the domain describes high and low
bins, with the objective being the value in that bin. This means
```julia
length(objective) + 1== length(domain)
```
Note that the _contiguous_ qualifer is to mean there is no gaps in the bins, and that
```math
\\Delta E_i = E_{i+1} - E_{i}
```

"""
struct ContiguouslyBinned <: AbstractDataLayout end

const DEFAULT_SUPPORT_ORDERING = (ContiguouslyBinned(), OneToOne())

"""
    preferred_support(x)

Get the preffered [`AbstractDataLayout`](@ref) of `x`. If multiple supports are available, 
the `DEFAULT_SUPPORT_ORDERING` is followed:

```
DEFAULT_SUPPORT_ORDERING = $(DEFAULT_SUPPORT_ORDERING)
```
"""
function preferred_support(x)
    for layout in DEFAULT_SUPPORT_ORDERING
        if supports(layout, x)
            return layout
        end
    end
    error("No prefered support for $(typeof(x))")
end

"""
    common_support(x, y)

Find the common [`AbstractDataLayout`](@ref) of `x` and `y`, following the ordering of
[`preferred_support`](@ref).
"""
function common_support(x, y)
    # todo: check if can be compile time eval'd else expand for loop or @generated

    # order of preference is important
    # can normally trivially fallback from one-to-one to contiguous bins to regular bins
    for layout in DEFAULT_SUPPORT_ORDERING
        if supports(layout, x) && supports(layout, y)
            return layout
        end
    end
    error("No common support between $(typeof(x)) and $(typeof(y)).")
end

function _support_reducer(x::OneToOne, y)
    if supports(x, y)
        return x
    else
        error("No common support!!")
    end
end
function _support_reducer(x::ContiguouslyBinned, y)
    if supports(x, y)
        return x
    else
        _support_reducer(OneToOne(), y)
    end
end
function _support_reducer(x, y)
    common_support(x, y)
end

common_support(args::Vararg) = reduce(_support_reducer, args)

"""
    supports(layout::AbstractDataLayout, x::Type)::Bool

Used to define whether a given type has support for a specific
[`AbstractDataLayout`](@ref). This method should be implemented to express new
support, not the query method.

To query, there is

    support(layout::AbstractDataLayout, x)::Bool
"""
supports(layout::AbstractDataLayout, x) = supports(layout, typeof(x))
supports(::ContiguouslyBinned, T::Type) = false
supports(::OneToOne, T::Type) = false

export OneToOne,
    ContiguouslyBinned, AbstractDataLayout, supports, preferred_support, common_support