using Statistics: median, mean, std
using PyPlot
using Printf: @sprintf
import JSON

function print_runtimes(num_particles_list::Vector{Int}, results::Dict, label::String)
    median_times = [median(results[num_particles][2]) for num_particles in num_particles_list]
    stdev_times = [std(results[num_particles][2]) for num_particles in num_particles_list]
    for (num_particles, median_time, stdev_time) in zip(num_particles_list, median_times, stdev_times)
        str = @sprintf("%s, %d particles: %0.3f +/- %0.3f", label, num_particles, median_time, stdev_time)
        println(str)
    end
end

function plot_results(num_particles_list::Vector{Int}, results::Dict, label::String,
            color::String, linestyle="-")
    println(keys(results))
    median_times = [median(results[string(num_particles)]["elapsed"]) for num_particles in num_particles_list]
    stdev_times = [std(results[string(num_particles)]["elapsed"]) for num_particles in num_particles_list]
    mean_lmls = [mean(results[string(num_particles)]["lmls"]) for num_particles in num_particles_list]
    stdev_lmls = [std(results[string(num_particles)]["lmls"]) for num_particles in num_particles_list]
    println("min: $(minimum(mean_lmls)))")
    println("max: $(maximum(mean_lmls)))")
    plot(median_times, mean_lmls, 
	    color=color,
	    label=label,
        linestyle=linestyle)
end

anglican_results = JSON.parsefile("anglican-filtering/anglican-results.json") # TODO this is for the wrong HMM.
venture_results = JSON.parsefile("venture/venture_results.json")
turing_results = JSON.parsefile("turing/turing_results.json")
gen_results_static_default_proposal = JSON.parsefile("gen/gen_results_static_default_proposal.json")
gen_results_lightweight_unfold_custom_proposal = JSON.parsefile("gen/gen_results_lightweight_unfold_custom_proposal.json")
gen_results_lightweight_unfold_default_proposal = JSON.parsefile("gen/gen_results_lightweight_unfold_default_proposal.json")
gen_results_lightweight_custom_proposal = JSON.parsefile("gen/gen_results_lightweight_custom_proposal.json")
gen_results_lightweight_default_proposal = JSON.parsefile("gen/gen_results_lightweight_default_proposal.json")
gen_results_static_custom_proposal = JSON.parsefile("gen/gen_results_static_custom_proposal.json")

# plot time accuracy curve
const turing_num_particles_list = [1, 2, 3, 5, 7, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 200, 300]
const gen_num_particles_list = [1, 2, 3, 5, 7, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 200, 300]
const venture_num_particles_list = [1, 3, 10, 30, 100]
const anglican_num_particles_list = [1, 2, 3, 5, 7, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 200, 300]
figure(figsize=(8,4))
plot_results(anglican_num_particles_list, anglican_results, "Anglican", "blue")
plot_results(venture_num_particles_list, venture_results, "Venture", "green")
plot_results(turing_num_particles_list, turing_results, "Turing", "purple")
plot_results(gen_num_particles_list, gen_results_lightweight_unfold_default_proposal, "Gen (Default Proposal)", "red", "--")
plot_results(gen_num_particles_list, gen_results_lightweight_unfold_custom_proposal, "Gen (Custom Proposal)", "orange", "--")
legend(loc="lower right")
ylabel("Accuracy (LML estimate)")
xlabel("seconds")
gca()[:set_xscale]("log")
tight_layout()
savefig("lml_estimates.pdf")

exit()

# experiments with static model
results_static_default_proposal = results["results_static_default_proposal"]
results_static_custom_proposal = results["results_static_custom_proposal"]

# experiments with lightweight model (no unfold)
results_lightweight_default_proposal = results["results_lightweight_default_proposal"]
results_lightweight_custom_proposal = results["results_lightweight_custom_proposal"]

# experiments with unfold
results_lightweight_unfold_default_proposal = results["results_lightweight_unfold_default_proposal"]
results_lightweight_unfold_custom_proposal = results["results_lightweight_unfold_custom_proposal"]

# experiments with Turing.jl
results_turing = results["results_turing"]

#const num_particles_list_default = [20, 30, 50, 70, 100, 200, 300]
const num_particles_list_custom = [1, 2, 3, 5, 7, 10, 20, 30, 50, 70, 100, 200, 300]
const num_particles_list_default = num_particles_list_custom
num_particles_list_turing = copy(num_particles_list_custom)
push!(num_particles_list_turing, 1000)

#######################
# print runtime table #
#######################

print_runtimes([100], results_turing, "Turing")
print_runtimes([100], results_static_default_proposal, "Restricted DSL  + unfold (default proposal)")
print_runtimes([100], results_lightweight_default_proposal, "Flexible DSL (default proposal)")
print_runtimes([100], results_lightweight_unfold_default_proposal, "Flexible DSL + unfold (default proposal)")

# Turing, 100 particles: 0.306 +/- 0.153
# Restricted DSL  + unfold (default proposal), 100 particles: 0.013 +/- 0.002
# Flexible DSL (default proposal), 100 particles: 0.926 +/- 0.066
#Flexible DSL + unfold (default proposal), 100 particles: 0.078 +/- 0.007

##################
# generate plots #
##################

# plot of all data

figure(figsize=(4,2))
plot_results(num_particles_list_custom, results_static_custom_proposal, "Custom Proposal", "orange")
plot_results(num_particles_list_default, results_static_default_proposal, "Default Proposal", "blue")
plot_results(num_particles_list_default, results_turing, "Turing", "red")
legend(loc="lower right")
ylabel("Accuracy (LML estimate)")
xlabel("seconds")
gca()[:set_xscale]("log")
tight_layout()
savefig("lml_estimates.pdf")
