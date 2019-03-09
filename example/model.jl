using Gen
import Random
using DataFrames
using CSV

############################
# reverse mode AD for fill #
############################

using ReverseDiff

function Base.fill(x::ReverseDiff.TrackedReal{V,D,O}, n::Integer) where {V,D,O}
    tp = ReverseDiff.tape(x)
    out = ReverseDiff.track(fill(ReverseDiff.value(x), n), V, tp)
    ReverseDiff.record!(tp, ReverseDiff.SpecialInstruction, fill, (x, n), out)
    return out
end

@noinline function ReverseDiff.special_reverse_exec!(instruction::ReverseDiff.SpecialInstruction{typeof(fill)})
    x, n = instruction.input
    output = instruction.output
    ReverseDiff.istracked(x) && ReverseDiff.increment_deriv!(x, sum(ReverseDiff.deriv(output)))
    ReverseDiff.unseed!(output) 
    return nothing
end 

@noinline function ReverseDiff.special_forward_exec!(instruction::ReverseDiff.SpecialInstruction{typeof(fill)})
    x, n = instruction.input
    ReverseDiff.value!(instruction.output, fill(ReverseDiff.value(x), n))
    return nothing
end 

#########
# model #
#########

struct Params
    prob_outlier::Float64
    slope::Float64
    intercept::Float64
    noise::Float64
end

const OUTLIER_STD = 10.

@gen function datum(x::Float64, prob_outlier::Float64, @ad(slope), @ad(intercept), noise::Float64)
    if @addr(bernoulli(prob_outlier), :z)
        (mu, std) = (0., OUTLIER_STD)
    else
        (mu, std) = (x * slope + intercept, noise)
    end
    return @addr(normal(mu, std), :y)
end

data = plate(datum)

@gen function model(xs::Vector{Float64})
    prob_outlier = @addr(uniform(0, 0.5), :prob_outlier)
    noise = @addr(gamma(1, 1), :noise)
    slope = @addr(normal(0, 2), :slope)
    intercept = @addr(normal(0, 2), :intercept)
    params = Params(prob_outlier, slope, intercept, noise)
    @diff begin
        addrs = [:prob_outlier, :slope, :intercept, :noise]
        diffs = [@choicediff(addr) for addr in addrs]
        argdiff = all(map(isnodiff, diffs)) ? noargdiff : unknownargdiff
    end
    n = length(xs)
    ys = @addr(data(xs, fill(prob_outlier, n), fill(slope, n), fill(intercept, n), fill(noise, n)), :data, argdiff)
    return ys
end

#############
# rendering #
#############

using PyPlot
const POINT_SIZE = 10

function render_dataset(x::Vector{Float64}, y::Vector{Float64}, xlim, ylim)
    ax = plt[:gca]()
    ax[:scatter](x, y, c="black", alpha=1., s=POINT_SIZE)
    ax[:set_xlim](xlim)
    ax[:set_ylim](ylim)
end

function render_linreg(trace, xlim, ylim; line_alpha=1.0, point_alpha=1.0, show_color=true, show_line=true, show_points=true)
    xs = get_call_record(trace).args[1]
    assignment = get_assignment(trace)
    ax = plt[:gca]()
    if show_line
        slope = assignment[:slope]
        intercept = assignment[:intercept]
        line_xs = [xlim[1], xlim[2]]
        line_ys = slope * line_xs .+ intercept
        plt[:plot](line_xs, line_ys, color="black", alpha=line_alpha)
        noise = assignment[:noise]
        plt[:fill_between](line_xs, line_ys .- 2*noise, line_ys .+ 2*noise, color="black", alpha=0.2)
    end

    # plot data points
    if show_points
        colors = Vector{String}(undef, length(xs))
        ys = Vector{Float64}(undef, length(xs))
        for i=1:length(xs)
            if show_color
                is_outlier = assignment[:data => i => :z]
                color = is_outlier ? "red" : "blue"
            else
                color = "black"
            end
            y = assignment[:data => i => :y]
            colors[i] = color
            ys[i] = y
        end
        ax[:scatter](xs, ys, c=colors, alpha=point_alpha, s=POINT_SIZE)
    end
    ax[:set_xlim](xlim)
    ax[:set_ylim](ylim)
end