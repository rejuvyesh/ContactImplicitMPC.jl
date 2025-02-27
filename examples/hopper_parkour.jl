const ContactImplicitMPC = Main
include(joinpath(@__DIR__, "..", "src/dynamics", "hopper_2D", "visuals.jl"))
T = Float64
vis = Visualizer()
open(vis)

# Define a special stride where x and z are updated.
function get_stride(model::Hopper2D, traj::ContactTraj)
    stride = zeros(SizedVector{model.dim.q})
    stride[1:2] = traj.q[end-1][1:2] - traj.q[1][1:2]
    return stride
end

# get hopper model
s = get_simulation("hopper_2D", "flat_2D_lc", "flat")
s_sim = get_simulation("hopper_2D", "stairs3_2D_lc", "stairs")

# MPC parameters
N_sample = 10
H_mpc = 10
κ_mpc = 2.0e-4
n_opts = NewtonOptions(
    r_tol = 3e-4,
    max_iter = 5)
mpc_opts = LinearizedMPCOptions(
    altitude_update = true,
    altitude_impact_threshold = 0.1,
    altitude_verbose = true)


################################################################################
# Stair climbing
################################################################################

# get stair trajectory
ref_traj_ = get_trajectory(s.model, s.env,
    joinpath(module_dir(), "src/dynamics/hopper_2D/gaits/hopper_stair_ref.jld2"),
    load_type=:split_traj_alt)
ref_traj = deepcopy(ref_traj_)

visualize_robot!(vis, model, ref_traj)

# Horizon
H = ref_traj.H
h = ref_traj.h
h_sim = h / N_sample
H_sim = 240*N_sample

# Objective
obj = TrackingVelocityObjective(s.model, s.env, H_mpc,
    v = [Diagonal(1e-3 * [1e-2,1,1,10]) for t = 1:H_mpc],
    q = [[Diagonal(1e-0 * [1e1,1e-1,1,1])   for t = 1:H_mpc-5]; [Diagonal(1e-1 * [1,1e-1,1e1,0.1])   for t = 1:5]],
    u = [Diagonal(1e-0 * [1e0, 1e0]) for t = 1:H_mpc],
    γ = [Diagonal(1e-100 * ones(s.model.dim.c)) for t = 1:H_mpc],
    b = [Diagonal(1e-100 * ones(s.model.dim.c * friction_dim(s.env))) for t = 1:H_mpc])

# Policy
p = linearized_mpc_policy(ref_traj, s, obj,
    H_mpc = H_mpc,
    N_sample = N_sample,
    κ_mpc = κ_mpc,
    n_opts = n_opts,
    mpc_opts = mpc_opts)

# Get initial configurations
q1_ref = copy(ref_traj.q[2])
q0_ref = copy(ref_traj.q[1])
q1_sim = SVector{model.dim.q}(q1_ref)
q0_sim = SVector{model.dim.q}(copy(q1_sim - (q1_ref - q0_ref) / N_sample))
@assert norm((q1_sim - q0_sim) / h_sim - (q1_ref - q0_ref) / h) < 1.0e-8

# p = open_loop_policy(ref_traj.u, N_sample = N_sample)
# Simulate the stair climbing
sim_stair = ContactImplicitMPC.simulator(s_sim, q0_sim, q1_sim, h_sim, H_sim,
    p = p,
    ip_opts = ContactImplicitMPC.InteriorPointOptions(
        γ_reg = 0.0,
        undercut = Inf,
        r_tol = 1.0e-8,
        κ_tol = 1.0e-8),
    sim_opts = ContactImplicitMPC.SimulatorOptions(warmstart = true))

@time status = simulate!(sim_stair)


# plot_surface!(vis, s_sim.env, n=400)
anim = visualize_robot!(vis, model, sim_stair.traj, sample=10, name=:Sim, α=1.0)


plt = plot(layout=(3,1), legend=false)
plot!(plt[1,1], hcat(Vector.(vcat([fill(ref_traj.q[i], N_sample) for i=1:H]...))...)',
    color=:red, linewidth=3.0)
plot!(plt[1,1], hcat(Vector.(sim_stair.traj.q)...)', color=:blue, linewidth=1.0)
plot!(plt[2,1], hcat(Vector.(vcat([fill(ref_traj.u[i][1:nu], N_sample) for i=1:H]...))...)',
    color=:red, linewidth=3.0)
plot!(plt[2,1], hcat(Vector.([u[1:model.dim.u] for u in sim_stair.traj.u]*N_sample)...)', color=:blue, linewidth=1.0)
plot!(plt[3,1], hcat(Vector.([γ[1:model.dim.c] for γ in sim_stair.traj.γ]*N_sample)...)', color=:blue, linewidth=1.0)



# ghost
ref_traj_full_ = get_trajectory(s.model, s.env,
    joinpath(module_dir(), "src/dynamics/hopper_2D/gaits/hopper_stairs_3_v3.jld2"),
    load_type=:split_traj_alt)
ref_traj_full = deepcopy(ref_traj_full_)

idx = [10, 300, 500, 1100, 1300, 1900, 2100]
α = [0.2, 0.2, 0.4, 0.4, 0.6, 0.6, 0.6]
hopper_parkour_ghost!(vis, sim_stair, sim_stair.traj, ref_traj_full, idx = idx, α = α)

################################################################################
# Front flip
################################################################################

# get trajectory
ref_traj_ = get_trajectory(s.model, s.env,
    joinpath(module_dir(), "src/dynamics/hopper_2D/gaits/hopper_tall_flip_ref.jld2"),
    load_type=:split_traj_alt)
ref_traj = deepcopy(ref_traj_)
# offset the trajectory
for t = 1:ref_traj.H+2
    ref_traj.q[t][1] += sim_stair.traj.q[end][1]
end

# time
H = ref_traj.H
h = ref_traj.h
h_sim = h / N_sample
H_sim = 64*N_sample

# Objective
obj = TrackingVelocityObjective(s.model, s.env, H_mpc,
    v = [Diagonal(1e-13 * [1e-2,1,1,10]) for t = 1:H_mpc],
    q = [[Diagonal(1e-10 * [1e1,1e1,1,1])   for t = 1:H_mpc-5]; [Diagonal(1e-11 * [1,1e1,1e1,0.1])   for t = 1:5]],
    u = [Diagonal(1e-0 * [1e0, 1e0]) for t = 1:H_mpc],
    γ = [Diagonal(1e-100 * ones(s.model.dim.c)) for t = 1:H_mpc],
    b = [Diagonal(1e-100 * ones(s.model.dim.c * friction_dim(s.env))) for t = 1:H_mpc])

# Policy
p = linearized_mpc_policy(ref_traj, s, obj,
    H_mpc = H_mpc,
    N_sample = N_sample,
    κ_mpc = κ_mpc,
    n_opts = n_opts,
    mpc_opts = mpc_opts,
    )

# Initial configurations
q0_sim = deepcopy(SVector{model.dim.q}(sim_stair.traj.q[end-1]))
q1_sim = deepcopy(SVector{model.dim.q}(sim_stair.traj.q[end]))

sim_flip = ContactImplicitMPC.simulator(s_sim, q0_sim, q1_sim, h_sim, H_sim,
    p = p,
    ip_opts = ContactImplicitMPC.InteriorPointOptions(
        γ_reg = 0.0,
        undercut = Inf,
        r_tol = 1.0e-8,
        κ_tol = 1.0e-8),
    sim_opts = ContactImplicitMPC.SimulatorOptions(warmstart = true))

@time status = ContactImplicitMPC.simulate!(sim_flip)


# plot_surface!(vis, s.env, xlims = [-1, 3], ylims = [-1, 1])
anim = visualize_robot!(vis, model, sim_flip.traj, sample=10, name=:Sim, α=1.0)
anim = visualize_robot!(vis, model, ref_traj, anim=anim, name=:Ref, α=0.3)

################################################################################
# Full trajectory
################################################################################

ref_traj_full = get_trajectory(s.model, s.env,
    joinpath(module_dir(), "src/dynamics/hopper_2D/gaits/hopper_stairs_flip_ref.jld2"),
    load_type=:split_traj_alt)

N_sample = 10
sim_traj_full = [sim_stair.traj.q[1:end-2]; sim_flip.traj.q]
anim = visualize_robot!(vis, model,
    [sim_traj_full[1:N_sample:end]..., [sim_traj_full[end] for i = 1:50]...],
    name = :Sim, α = 1.0, h = h_sim*N_sample)
anim = visualize_robot!(vis, model,
    [ref_traj_full.q..., [ref_traj_full.q[end] for i = 1:50]...],
    anim = anim, name = :Ref, α = 0.15, h = h_sim*N_sample)
stairs!(vis)
# settransform!(vis["/Cameras/default"],
#         compose(Translation(0.0, -95.0, -1.0), LinearMap(RotY(0.0 * π) * RotZ(-π / 2.0))))
# setprop!(vis["/Cameras/default/rotated/<object>"], "zoom", 20)

plot_lines!(vis, model, ref_traj_full.q, offset = -0.3)
plot_lines!(vis, model, sim_traj_full, offset = -0.5, size = 6)




filename = "hopper_parkour_ref"
MeshCat.convert_frames_to_video(
    "/home/simon/Downloads/$filename.tar",
    "/home/simon/Documents/video/$filename.mp4", overwrite=true)

convert_video_to_gif(
    "/home/simon/Documents/video/$filename.mp4",
    "/home/simon/Documents/video/$filename.gif", overwrite=true)
