using Random
using LinearAlgebra
const ContactImplicitMPC = Main

include(joinpath(module_dir(), "src", "solver", "interior_point.jl"))
include(joinpath(module_dir(), "src", "solver", "mehrotra.jl"))

################################################################################
# Benchmark Utils
################################################################################

function get_benchmark_initialization(ref_traj::ContactTraj{T, nq},
		model::ContactModel, env::Environment, t::Int;
		z_dis = 1e-2, θ_dis = 1e-2) where {T,nq}
	Random.seed!(10)
	z = zeros(length(ref_traj.z[t]))
	q = deepcopy(ref_traj.θ[t][nq+1:2nq])
	z_initialize!(z, model, env, q)

	θ = deepcopy(ref_traj.θ[t])
	θ[1:nq] += θ_dis * ones(nq)
	return z, θ
end

function get_interior_point_solver(s::Simulation, space::Space, z, θ;
		r_tol = 1e-8, κ_tol = 1e-8, linear = false)
	model = s.model
	env = s.env

	lin = LinearizedStep(s, z, θ, 0.0) # /!| here we do not use κ from ref_traj
	if linear
		ip = interior_point(z, θ,
			s = space,
			oss = OptimizationSpace13(model, env),
			r!  = r!,
			rz! = rz!,
			rθ! = rθ!,
			r  = RLin(s, lin.z, lin.θ, lin.r, lin.rz, lin.rθ),
			rz = RZLin(s, lin.rz),
			rθ = RθLin(s, lin.rθ),
			opts = InteriorPointOptions(
			max_iter = 100,
			max_ls = 1;
			verbose = true,
			r_tol = r_tol,
			κ_tol = κ_tol,
			solver = :empty_solver,
			))
	else
		ip = interior_point(z, θ,
			s = space,
			oss = OptimizationSpace13(model, env),
			r! = s.res.r!,
			rz! = s.res.rz!,
			rθ! = s.res.rθ!,
			rz = s.rz,
			rθ = s.rθ,
			opts = InteriorPointOptions(
				max_iter = 100,
				r_tol = r_tol,
				κ_tol = κ_tol,
			))
	end
	return ip
end

################################################################################
# Benchmark Structures & Methods
################################################################################

# Benchmark
@with_kw mutable struct BenchmarkOptions{T}
	r_tol::T = 1.0e-8            # residual tolerance
	κ_tol::T = 1.0e-8            # bilinear tolerance
	z_dis::T = 1.0e-4            # disturbance on initial z
    θ_dis::T = 1.0e-4            # disturbance on initial θ
    linear::Bool = false         # whether to use or not the linearized residuals
end

mutable struct BenchmarkStatistics{T}
	failure::AbstractVector{Bool}
	iter::AbstractVector{Int}
	r_vio::AbstractVector{T}
	κ_vio::AbstractVector{T}
	cond_schur::AbstractVector{T}
end

function BenchmarkStatistics()
	failure = trues(0)
	iter = zeros(Int, 0)
	r_vio = zeros(0)
	κ_vio = zeros(0)
	cond_schur = zeros(0)
	return BenchmarkStatistics(failure, iter, r_vio, κ_vio, cond_schur)
end

function record!(stats::BenchmarkStatistics, s, i, r, κ, c)
	push!(stats.failure, s)
	push!(stats.iter, i)
	push!(stats.r_vio, r)
	push!(stats.κ_vio, κ)
	push!(stats.cond_schur, c)
	return nothing
end

function benchmark_interior_point!(stats::BenchmarkStatistics, s::Simulation,
	ref_traj::ContactTraj, space::Space; opts::BenchmarkOptions)

	nz = num_var(s.model, s.env)
	for t = 1:ref_traj.H
		z, θ = get_benchmark_initialization(ref_traj, s.model, s.env, t,
			z_dis = opts.z_dis,
			θ_dis = opts.θ_dis)
		ip = get_interior_point_solver(s, space, deepcopy(ref_traj.z[t]), deepcopy(ref_traj.θ[t]),
			r_tol = opts.r_tol,
			κ_tol = opts.κ_tol,
			linear = opts.linear)
		interior_point_solve!(ip, z, θ)
		rv = residual_violation(ip, ip.r)
		κv = bilinear_violation(ip, ip.r)
		fl = !((rv < opts.r_tol) && (κv < opts.κ_tol))
		record!(stats, fl, ip.iterations, rv, κv, NaN)
	end
	return nothing
end

function benchmark!(stats::BenchmarkStatistics, s::Simulation,
		ref_traj::ContactTraj, space::Space; opts::BenchmarkOptions, solver::Symbol)
	if solver == :interior_point
		benchmark_interior_point!(stats, s, ref_traj, space; opts = opts)
	else
		@warn "Unknown solver"
	end
	return nothing
end

function benchmark(s::AbstractVector{Simulation},
		ref_traj::AbstractVector{<:ContactTraj}, space::AbstractVector{<:Space}, dist::AbstractVector{<:Real};
		opts = BenchmarkOptions(), solver::Symbol)

	stats = Vector{BenchmarkStatistics}()
	nsim = length(s)
	ndis = length(dist)
	@assert length(ref_traj) == nsim

	for i = 1:ndis
		sta = BenchmarkStatistics()
		opts.z_dis = dist[i]
		opts.θ_dis = dist[i]
		for j = 1:nsim
			benchmark!(sta, s[j], ref_traj[j], space[j]; opts = opts, solver = solver)
		end
		push!(stats, sta)
	end
	return stats
end


################################################################################
# Loading Problems
################################################################################

s_quadruped = ContactImplicitMPC.get_simulation("quadruped", "flat_2D_lc", "flat")
s_flamingo = ContactImplicitMPC.get_simulation("flamingo", "flat_2D_lc", "flat")
s_hopper = ContactImplicitMPC.get_simulation("hopper_2D", "flat_2D_lc", "flat")
s_particle_2D = ContactImplicitMPC.get_simulation("particle_2D", "flat_2D_nc", "flat_nc")
s_particle = ContactImplicitMPC.get_simulation("particle", "flat_3D_nc", "flat_nc")
s_box_quat_lc = get_simulation("box", "flat_3D_lc", "flat_lc")
s_box_quat_nc = get_simulation("box", "flat_3D_nc", "flat_nc")

ref_traj_quadruped = deepcopy(ContactImplicitMPC.get_trajectory(s_quadruped.model, s_quadruped.env,
    joinpath(ContactImplicitMPC.module_dir(), "src/dynamics/quadruped/gaits/gait2.jld2"),
    load_type = :split_traj_alt))
ref_traj_flamingo = deepcopy(ContactImplicitMPC.get_trajectory(s_flamingo.model, s_flamingo.env,
    joinpath(ContactImplicitMPC.module_dir(), "src/dynamics/flamingo/gaits/gait_forward_36_4.jld2"),
    load_type = :split_traj_alt))
ref_traj_hopper = deepcopy(ContactImplicitMPC.get_trajectory(s_hopper.model, s_hopper.env,
    joinpath(ContactImplicitMPC.module_dir(), "src/dynamics/hopper_2D/gaits/gait_forward.jld2"),
    load_type = :joint_traj))
ref_traj_particle_2D = deepcopy(get_trajectory(s_particle_2D.model, s_particle_2D.env,
	joinpath(module_dir(), "src/dynamics/particle_2D/gaits/gait_NC.jld2"),
	load_type = :joint_traj))
ref_traj_particle = deepcopy(get_trajectory(s_particle.model, s_particle.env,
	joinpath(module_dir(), "src/dynamics/particle/gaits/gait_NC.jld2"),
	load_type = :joint_traj))
ref_traj_box_quat_lc = deepcopy(get_trajectory(s_box_quat_lc.model, s_box_quat_lc.env,
	joinpath(module_dir(), "src/dynamics/box/gaits/gait_LC.jld2"),
	load_type = :joint_traj))
ref_traj_box_quat_nc = deepcopy(get_trajectory(s_box_quat_nc.model, s_box_quat_nc.env,
	joinpath(module_dir(), "src/dynamics/box/gaits/gait_NC.jld2"),
	load_type = :joint_traj))


space_quadruped = Euclidean(num_var(s_quadruped.model, s_quadruped.env))
space_flamingo = Euclidean(num_var(s_flamingo.model, s_flamingo.env))
space_hopper = Euclidean(num_var(s_hopper.model, s_hopper.env))
space_particle_2D = Euclidean(num_var(s_particle_2D.model, s_particle_2D.env))
space_particle = Euclidean(num_var(s_particle.model, s_particle.env))
space_box_quat_lc = rn_quaternion_space(
	num_var(s_box_quat_lc.model, s_box_quat_lc.env) - 1,
	x -> Gz_func(s_box_quat_lc.model, s_box_quat_lc.env, x),
	collect([(1:3)..., (8:num_var(s_box_quat_lc.model, s_box_quat_lc.env))...]),
	collect([(1:3)..., (7:num_var(s_box_quat_lc.model, s_box_quat_lc.env)-1)...]),
	[collect((4:7))],
	[collect((4:6))])
space_box_quat_nc = rn_quaternion_space(
	num_var(s_box_quat_nc.model, s_box_quat_nc.env) - 1,
	x -> Gz_func(s_box_quat_nc.model, s_box_quat_nc.env, x),
	collect([(1:3)..., (8:num_var(s_box_quat_nc.model, s_box_quat_nc.env))...]),
	collect([(1:3)..., (7:num_var(s_box_quat_nc.model, s_box_quat_nc.env)-1)...]),
	[collect((4:7))],
	[collect((4:6))])


################################################################################
# Running Benchmark
################################################################################

s = [
	s_quadruped, s_flamingo, s_hopper,
	# s_particle_2D, s_particle,
	# s_box_quat_lc,
	# s_box_quat_nc
	]
ref_traj = [
	ref_traj_quadruped, ref_traj_flamingo, ref_traj_hopper,
	# ref_traj_particle_2D, ref_traj_particle,
	# ref_traj_box_quat_lc,
	# ref_traj_box_quat_nc
	]
space = [
	space_quadruped, space_flamingo, space_hopper,
	# space_particle_2D, space_particle,
	# space_box_quat_lc,
	# space_box_quat_nc
	]
# s = [s_particle_2D, s_particle]
# ref_traj = [ref_traj_particle_2D, ref_traj_particle]
# s = [s_quadruped, s_flamingo, s_hopper]
# ref_traj = [ref_traj_quadruped, ref_traj_flamingo, ref_traj_hopper]

dist = [1e-6, 1e-5, 1e-4, 1e-3, 1e-2]
tol = 1e-7
opts_nonlin = BenchmarkOptions(r_tol = tol, κ_tol = tol, linear = false)
opts_lin = BenchmarkOptions(r_tol = tol, κ_tol = tol, linear = true)
stats = Dict{Symbol, AbstractVector{BenchmarkStatistics}}()
keys = [
	:interior_point_lin,
	:interior_point_nonlin,
	]

stats[:interior_point_nonlin] = benchmark(
	s,
	deepcopy.(ref_traj),
	space,
	dist,
	opts = opts_nonlin,
	solver = :interior_point,
	)

stats[:interior_point_lin] = benchmark(
	s,
	deepcopy.(ref_traj),
	space,
	dist,
	opts = opts_lin,
	solver = :interior_point,
	)

function display_statistics!(plt, plt_ind, stats::AbstractVector{BenchmarkStatistics}, dist;
		field::Symbol = :iter, solver::String = "solver")
	data = [mean(getfield(s, field)) for s in stats]
	linestyle = occursin("nonlin", solver) ? :solid : :dot
	linewidth = occursin("nonlin", solver) ? 3.0 : 5.0
	marker    = occursin("nonlin", solver) ? :circ : :utriangle
	if occursin("interior_point_base", solver)
		color = :red
	elseif occursin("interior_point", solver)
		color = :orange
	elseif occursin("mehrotra", solver)
		color = :black
	end

	plot!(plt[plt_ind...], dist, data,
		xlabel = "disturbances",
		ylabel = String(field),
		label = false,
		xlims = [minimum(dist), maximum(dist)*100],
		ylims = [0, Inf],
		xaxis = :log,
		legend = :right,
		linestyle = linestyle,
		color = color,
		linewidth = linewidth)
	scatter!(plt[plt_ind...], dist, data,
		label = solver,
		marker = marker,
		markercolor = color,
		markeralpha = 0.6,
		markerstrokecolor = :black,
		markerstrokewidth = 2.0,
		color = color,
		markersize = 8.0,
		)
	display(plt)
	return nothing
end


################################################################################
# Benchmark Results
################################################################################

plt = plot(size = (800, 600), layout = (3, 1), fmt = :svg)
for k in keys
	display_statistics!(plt, [1,1], stats[k], dist, field = :iter, solver = String(k))
end
for k in keys
	display_statistics!(plt, [2,1], stats[k], dist, field = :failure,  solver = String(k))
end
for k in keys
	display_statistics!(plt, [3,1], stats[k], dist, field = :cond_schur,  solver = String(k))
end
