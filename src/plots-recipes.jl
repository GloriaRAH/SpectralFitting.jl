using Printf
using RecipesBase

plotting_domain(dataset::AbstractDataset) = SpectralFitting.spectrum_energy(dataset)
plotting_domain(dataset::InjectiveData) = dataset.domain

@recipe function _plotting_func(dataset::InjectiveData; data_layout = OneToOne())
    seriestype --> :scatter
    markersize --> 1.0
    markershape --> :none
    markerstrokecolor --> :auto
    yerr -> dataset.codomain_variance
    xerr -> dataset.domain_variance
    label --> make_label(dataset)
    minorgrid --> true
    dataset.domain, dataset.codomain
end

@recipe function _plotting_func(
    dataset::AbstractDataset;
    data_layout = ContiguouslyBinned(),
    xscale = :linear,
)
    seriestype --> :scatter
    markersize --> 0.5
    markershape --> :none
    (rate, rateerror) = (
        make_objective(data_layout, dataset),
        make_objective_variance(data_layout, dataset),
    )
    _yerr = sqrt.(rateerror)
    yerr --> _yerr
    _xerr = SpectralFitting.bin_widths(dataset) ./ 2
    xerr --> _xerr
    markerstrokecolor --> :auto
    xlabel --> "Energy (keV)"
    ylabel --> SpectralFitting.objective_units(dataset)
    label --> SpectralFitting.make_label(dataset)
    minorgrid --> true
    x = plotting_domain(dataset)

    if xscale == :log10
        x = plotting_domain(dataset)
        _xerr = SpectralFitting.bin_widths(dataset) ./ 2
        min_x = x[1] - _xerr[1]
        max_x = x[end] + _xerr[end]
        xticks --> get_tickslogscale((min_x, max_x))
    end

    I = @. !isinf(x) && !isinf(rate)
    @views (x[I], rate[I])
end

@recipe _plotting_func(::Type{<:FittingResult}, result::FittingResult) = result[1]

@recipe function _plotting_func(result::FittingResultSlice)
    label --> Printf.@sprintf("χ2=%.2f", result.χ2)
    seriestype --> :stepmid
    dataset = SpectralFitting.get_dataset(result)
    y = invoke_result(result, result.u)
    x = plotting_domain(dataset)
    x, y
end

# ratio plots
@userplot RatioPlot
@recipe function _plotting_func(
    r::RatioPlot;
    datacolor = :auto,
    modelcolor = :auto,
    label = :auto,
)
    if length(r.args) != 1 || !(typeof(r.args[1]) <: AbstractFittingResult)
        error(
            "Ratio plots first argument must be `AbstractDataset` and second argument of type `AbstractFittingResult`.",
        )
    end

    result = r.args[1] isa FittingResult ? r.args[1][1] : r.args[1]
    data = get_dataset(result)
    x = plotting_domain(data)
    y = invoke_result(result, result.u)

    y_ratio = @. result.objective / y

    ylabel --> "Ratio [data / model]"
    xlabel --> "Energy (keV)"
    minorgrid --> true

    if (label == :auto)
        label = make_label(data)
    end

    @series begin
        linestyle --> :dash
        seriestype --> :hline
        label --> false
        color --> modelcolor
        [1.0]
    end

    @series begin
        markerstrokecolor --> datacolor
        label --> label
        seriestype --> :scatter
        markershape --> :none
        markersize --> 0.5
        yerror --> sqrt.(result.variance) ./ y
        xerror --> SpectralFitting.bin_widths(data) ./ 2
        x, y_ratio
    end
end

# residual plots
# TODO: multiple datasets require repeated calls to this function (write a wrapper later)
@userplot ResidualPlot
@recipe function _plotting_fun(r::ResidualPlot)
    # check that the function has been passed one dataset and one fit result
    if length(r.args) != 1 || !(typeof(r.args[1]) <: AbstractFittingResult)
        error(
            "Ratio plots first argument must be `AbstractDataset` and second argument of type `AbstractFittingResult`.",
        )
    end
    result = r.args[1] isa FittingResult ? r.args[1][1] : r.args[1]
    data = SpectralFitting.get_dataset(result)

    @series begin
        linestyle --> :dash
        seriestype --> :hline
        label --> false
        [0]
    end

    seriestype --> :stepmid
    fill --> (0, 0.3, :auto)
    y_residuals = residuals(result)
    x = plotting_domain(data)
    (x, y_residuals)
end

@userplot PlotResult
@recipe function _plotting_fun(r::PlotResult; xscale = :identity)
    if length(r.args) != 2 ||
       !(typeof(r.args[1]) <: AbstractDataset) ||
       !(
           (typeof(r.args[2]) <: AbstractFittingResult) ||
           (eltype(r.args[2]) <: AbstractFittingResult)
       )
        error(
            "First argument must be `AbstractDataset` and second argument of (el)type `AbstractFittingResult` (got $(typeof(r.args[1])) and $(typeof(r.args[2])))",
        )
    end
    layout --> @layout [
        top{0.75h}
        bottom{0.25h}
    ]

    data = r.args[1]
    results = r.args[2] isa Base.AbstractVecOrTuple ? r.args[2] : (r.args[2],)


    if xscale == :log10
        _x = plotting_domain(data)
        _xerr = SpectralFitting.bin_widths(data) ./ 2
        min_x = _x[1] - _xerr[1]
        max_x = _x[end] + _xerr[end]
        xticks --> get_tickslogscale((min_x, max_x))
    end

    @series begin
        subplot := 1
        xlabel := ""
        ylabel := SpectralFitting.objective_units(data)
        data
    end

    for (i, res) in enumerate(results)
        color := i + 1
        r = res isa FittingResultSlice ? res : res[1]
        x = plotting_domain(SpectralFitting.get_dataset(r))
        @series begin
            subplot := 1
            r
        end
        @series begin
            xlabel --> "Energy (keV)"
            subplot := 2
            link := :x
            seriestype --> :stepmid
            yscale := :identity
            label := false
            fill --> (0, 0.3, :auto)
            y_residuals = residuals(r)
            (x, y_residuals)
        end
    end
end

"""
    get_tickslogscale(lims; skiplog=false)

Return a tuple (ticks, ticklabels) for the axis limit `lims`
where multiples of 10 are major ticks with label and minor ticks have no label
skiplog argument should be set to true if `lims` is already in log scale.

Modified from [https://github.com/JuliaPlots/Plots.jl/issues/3318](Plots.jl/#3318).
"""
function get_tickslogscale(lims::Tuple{T,T}; skiplog::Bool = false) where {T<:AbstractFloat}
    mags = if skiplog
        # if the limits are already in log scale
        floor.(lims)
    else
        floor.(log10.(lims))
    end
    rlims = if skiplog
        10 .^ (lims)
    else
        lims
    end

    total_tickvalues = []
    total_ticknames = []

    rgs = range(mags..., step = 1)
    for (i, m) in enumerate(rgs)
        if m >= 0
            tickvalues = range(Int(10^m), Int(10^(m + 1)); step = Int(10^m))
            ticknames = vcat(
                [string(round(Int, 10^(m)))],
                ["" for i = 2:9],
                [string(round(Int, 10^(m + 1)))],
            )
        else
            tickvalues = range(10^m, 10^(m + 1); step = 10^m)
            ticknames = vcat([string(10^(m))], ["" for i = 2:9], [string(10^(m + 1))])
        end

        if i == 1
            # lower bound
            indexlb = findlast(x -> x < rlims[1], tickvalues)
            if isnothing(indexlb)
                indexlb = 1
            end
        else
            indexlb = 1
        end
        if i == length(rgs)
            # higher bound
            indexhb = findfirst(x -> x > rlims[2], tickvalues)
            if isnothing(indexhb)
                indexhb = 10
            end
        else
            # do not take the last index if not the last magnitude
            indexhb = 9
        end

        total_tickvalues = vcat(total_tickvalues, tickvalues[indexlb:indexhb])
        total_ticknames = vcat(total_ticknames, ticknames[indexlb:indexhb])
    end
    return (total_tickvalues, total_ticknames)
end
