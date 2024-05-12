
function goodness(
    result::AbstractFittingResult,
    u::AbstractVector{T},
    σ::AbstractVector{T};
    N = 1000,
    stat = ChiSquared(),
    distribution = Distributions.Normal,
    refit = true,
) where {T}
    measures = zeros(T, N)
    config = deepcopy(result.config)
    for i in eachindex(measures)
        # sample the next parameters
        for i in eachindex(u)
            m = u[i]
            d = σ[i]
            # TODO: respect the upper and lower bounds of the parameters
            distr = Distributions.Truncated(distribution(m, d), get_lowerlimit(config.parameters[i]), get_upperlimit(config.parameters[i])) 
            set_value!(config.parameters[i], rand(distr))
        end

        if refit
            new_result = fit(config, LevenbergMarquadt())
        end
        measures[i] = measure(stat, new_result)
    end

    perc = 100 * count(<(result.χ2), measures) / N
    @info "% with measure < result = $(perc)"

    measures
end 

function goodness(result::AbstractFittingResult, σu = estimated_error(result); kwargs...)
    @assert !isnothing(σu) "σ cannot be nothing, else algorithm has no parameter intervals to sample from."
    goodness(result, estimated_params(result), σu; kwargs...)
end

export goodness