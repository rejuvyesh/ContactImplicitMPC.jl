@testset "MPC: Policy for Quadruped" begin
    T = Float64

    s = get_simulation("quadruped", "flat_2D_lc", "flat")
    model = s.model
    env = s.env

    ref_traj_ = deepcopy(ContactImplicitMPC.get_trajectory(s.model, s.env,
        joinpath(module_dir(), "src/dynamics/quadruped/gaits/gait2.jld2"),
        load_type = :split_traj_alt))

    ref_traj = deepcopy(ref_traj_)

    # time
    H = ref_traj.H
    h = ref_traj.h
    N_sample = 5
    H_mpc = 10
    h_sim = h / N_sample
    H_sim = 500

    # barrier parameter
    κ_mpc = 2.0e-4

    # obj
    obj = TrackingVelocityObjective(model, env, H_mpc,
        q = [Diagonal(1e-2 * [10; 0.02; 0.25; 0.25 * ones(model.dim.q-3)]) for t = 1:H_mpc],
        v = [Diagonal(0e-2 * [10; 0.02; 0.25; 0.25 * ones(model.dim.q-3)]) for t = 1:H_mpc],
        u = [Diagonal(3e-2 * ones(model.dim.u)) for t = 1:H_mpc],
        γ = [Diagonal(1.0e-100 * ones(model.dim.c)) for t = 1:H_mpc],
        b = [Diagonal(1.0e-100 * ones(model.dim.c * friction_dim(env))) for t = 1:H_mpc])

    # linearized MPC policy
    p = ContactImplicitMPC.linearized_mpc_policy(ref_traj, s, obj,
        H_mpc = H_mpc,
        N_sample = N_sample,
        κ_mpc = κ_mpc,
        n_opts = ContactImplicitMPC.NewtonOptions(
            r_tol = 3e-4,
            max_iter = 5),
        mpc_opts = ContactImplicitMPC.LinearizedMPCOptions())

    # initial configurations
    q1_ref = copy(ref_traj.q[2])
    q0_ref = copy(copy(ref_traj.q[1]))
    q1_sim = SVector{model.dim.q}(q1_ref)
    q0_sim = SVector{model.dim.q}(copy(q1_sim - (q1_ref - q0_ref) / N_sample))
    @assert norm((q1_sim - q0_sim) / h_sim - (q1_ref - q0_ref) / h) < 1.0e-8

    # simulator
    sim = ContactImplicitMPC.simulator(s, q0_sim, q1_sim, h_sim, H_sim,
        p = p,
        ip_opts = ContactImplicitMPC.InteriorPointOptions(
			γ_reg = 0.0,
			undercut = Inf,
            r_tol = 1.0e-8,
            κ_tol = 1.0e-8),
        sim_opts = ContactImplicitMPC.SimulatorOptions(warmstart = true))

    # simulator
    @test status = ContactImplicitMPC.simulate!(sim)
    ref_traj = deepcopy(ref_traj_)

    qerr, uerr, γerr, berr = ContactImplicitMPC.tracking_error(ref_traj, sim.traj, N_sample, idx_shift=[1])
    @test qerr < 0.0201 * 1.5 # 0.0201
    @test uerr < 0.0437 * 1.5 # 0.0437
    @test γerr < 0.374 * 1.5 # 0.374
    @test berr < 0.0789 * 1.5 # 0.0789
    qerr > 0.0201 * 1.2 && @warn "mild regression on q tracking: current tracking error = $qerr, nominal tracking error = 0.0201"
    uerr > 0.0437 * 1.2 && @warn "mild regression on u tracking: current tracking error = $uerr, nominal tracking error = 0.0437"
    γerr > 0.3740 * 1.2 && @warn "mild regression on γ tracking: current tracking error = $γerr, nominal tracking error = 0.374"
    berr > 0.0789 * 1.2 && @warn "mild regression on b tracking: current tracking error = $berr, nominal tracking error = 0.0789"
end

# @testset "MPC: Policy for Quadruped on Sinusoidal Terrain" begin
#     T = Float64

#     s_sim = get_simulation("quadruped", "sine1_2D_lc", "sinusoidal")
#     s = get_simulation("quadruped", "flat_2D_lc", "flat")
#     model = s.model
#     env = s.env

#     nq = model.dim.q

#     ref_traj_ = deepcopy(ContactImplicitMPC.get_trajectory(s.model, s.env,
#         joinpath(module_dir(), "src/dynamics/quadruped/gaits/gait2.jld2"),
#         load_type = :split_traj_alt))
#     ref_traj = deepcopy(ref_traj_)

#     # time
#     H = ref_traj.H
#     h = ref_traj.h
#     N_sample = 5
#     H_mpc = 10
#     h_sim = h / N_sample
#     H_sim = 1500

#     # barrier parameter
#     κ_mpc = 2.0e-4

#     obj = TrackingObjective(model, env, H_mpc,
#         q = [Diagonal(1e-2 * [10; 0.02; 0.25; 0.25 * ones(nq-3)]) for t = 1:H_mpc],
#         u = [Diagonal(3e-2 * ones(model.dim.u)) for t = 1:H_mpc],
#         γ = [Diagonal(1.0e-100 * ones(model.dim.c)) for t = 1:H_mpc],
#         b = [Diagonal(1.0e-100 * ones(model.dim.c * friction_dim(env))) for t = 1:H_mpc])

#     p = linearized_mpc_policy(ref_traj, s, obj,
#         H_mpc = H_mpc,
#         N_sample = N_sample,
#         κ_mpc = κ_mpc,
#         n_opts = NewtonOptions(
#             r_tol = 3e-4,
#             max_iter = 5,
#             # verbose = true,
#             ),
#         mpc_opts = LinearizedMPCOptions(
#             # live_plotting=true,
#             altitude_update = true,
#             altitude_impact_threshold = 0.05,
#             altitude_verbose = false,
#             )
#         )


#     q1_ref = copy(ref_traj.q[2])
#     q0_ref = copy(ref_traj.q[1])
#     q1_sim = SVector{model.dim.q}(q1_ref)
#     q0_sim = SVector{model.dim.q}(copy(q1_sim - (q1_ref - q0_ref) / N_sample))
#     @assert norm((q1_sim - q0_sim) / h_sim - (q1_ref - q0_ref) / h) < 1.0e-8

#     sim = simulator(s_sim, q0_sim, q1_sim, h_sim, H_sim,
#         p = p,
#         ip_opts = InteriorPointOptions(
# 			γ_reg = 0.0,
# 			undercut = Inf,
#             r_tol = 1.0e-8,
#             κ_tol = 1.0e-8),
#         sim_opts = SimulatorOptions(warmstart = true)
#         )

#     @time status = simulate!(sim)
#     ref_traj = deepcopy(ref_traj_)

#     qerr, uerr, γerr, berr = ContactImplicitMPC.tracking_error(ref_traj, sim.traj, N_sample, idx_shift=[1])
#     @test qerr < 0.0333 * 1.5 # 0.0333
#     @test uerr < 0.0437 * 1.5 # 0.0437
#     @test γerr < 0.3810 * 1.5 # 0.3810
#     @test berr < 0.0795 * 1.5 # 0.0795
#     qerr > 0.0333 * 1.2 && @warn "mild regression on q tracking: current tracking error = $qerr, nominal tracking error = 0.0333"
#     uerr > 0.0437 * 1.2 && @warn "mild regression on u tracking: current tracking error = $uerr, nominal tracking error = 0.0437"
#     γerr > 0.3810 * 1.2 && @warn "mild regression on γ tracking: current tracking error = $γerr, nominal tracking error = 0.381"
#     berr > 0.0795 * 1.2 && @warn "mild regression on b tracking: current tracking error = $berr, nominal tracking error = 0.0795"
# end

@testset "MPC Quadruped (long trajectory)" begin

	s = get_simulation("quadruped", "flat_2D_lc", "flat")
	model = s.model
	env = s.env

	ref_traj = deepcopy(ContactImplicitMPC.get_trajectory(s.model, s.env,
	    joinpath(module_dir(), "src/dynamics/quadruped/gaits/gait2.jld2"),
	    load_type = :split_traj_alt))

	# time
	H = ref_traj.H
	h = ref_traj.h
	N_sample = 5
	H_mpc = 10
	h_sim = h / N_sample
	H_sim = 9000

	# barrier parameter
	κ_mpc = 2.0e-4

	obj_mpc = TrackingObjective(model, env, H_mpc,
	    q = [Diagonal(1e-2 * [1.0; 0.02; 0.25; 0.25 * ones(model.dim.q-3)]) for t = 1:H_mpc],
	    u = [Diagonal(3e-2 * ones(model.dim.u)) for t = 1:H_mpc],
	    γ = [Diagonal(1.0e-100 * ones(model.dim.c)) for t = 1:H_mpc],
	    b = [Diagonal(1.0e-100 * ones(model.dim.c * friction_dim(env))) for t = 1:H_mpc])

	p = linearized_mpc_policy(ref_traj, s, obj_mpc,
	    H_mpc = H_mpc,
	    N_sample = N_sample,
	    κ_mpc = κ_mpc,
		mode = :configuration,
	    n_opts = NewtonOptions(
			solver = :lu_solver,
			r_tol = 3e-4,
			max_iter = 5,
			# max_time = ref_traj.h, # HARD REAL TIME
			),
	    mpc_opts = LinearizedMPCOptions(),
	    )

	q1_ref = copy(ref_traj.q[2])
	q0_ref = copy(ref_traj.q[1])
	q1_sim = SVector{model.dim.q}(q1_ref)
	q0_sim = SVector{model.dim.q}(copy(q1_sim - (q1_ref - q0_ref) / N_sample))
	@assert norm((q1_sim - q0_sim) / h_sim - (q1_ref - q0_ref) / h) < 1.0e-8

	sim = ContactImplicitMPC.simulator(s, q0_sim, q1_sim, h_sim, H_sim,
	    p = p,
	    ip_opts = ContactImplicitMPC.InteriorPointOptions(
			undercut = Inf,
			γ_reg = 0.0,
	        r_tol = 1.0e-8,
	        κ_tol = 1.0e-8,),
	    sim_opts = ContactImplicitMPC.SimulatorOptions(warmstart = true))

	status = ContactImplicitMPC.simulate!(sim, verbose = false)

	qerr, uerr, γerr, berr = tracking_error(ref_traj, sim.traj, N_sample, idx_shift = [1])
	@test qerr < 0.0202 * 1.5 # 0.0201
	@test uerr < 0.0437 * 1.5 # 0.0437
	@test γerr < 0.3780 * 1.5 # 0.3790
	@test berr < 0.0799 * 1.5 # 0.0798
	qerr > 0.0201 * 1.2 && @warn "mild regression on q tracking: current tracking error = $qerr, nominal tracking error = 0.0202"
	uerr > 0.0437 * 1.2 && @warn "mild regression on u tracking: current tracking error = $uerr, nominal tracking error = 0.0437"
	γerr > 0.3790 * 1.2 && @warn "mild regression on γ tracking: current tracking error = $γerr, nominal tracking error = 0.3780"
	berr > 0.0798 * 1.2 && @warn "mild regression on b tracking: current tracking error = $berr, nominal tracking error = 0.0799"
end


# @testset "MPC quadruped: long trajectory with structured newton solver" begin
#
# 	s = get_simulation("quadruped", "flat_2D_lc", "flat")
# 	model = s.model
# 	env = s.env
#
# 	ref_traj = deepcopy(ContactImplicitMPC.get_trajectory(s.model, s.env,
# 	    joinpath(module_dir(), "src/dynamics/quadruped/gaits/gait2.jld2"),
# 	    load_type = :split_traj_alt))
#
# 	# time
# 	H = ref_traj.H
# 	h = ref_traj.h
# 	N_sample = 5
# 	H_mpc = 10
# 	h_sim = h / N_sample
# 	H_sim = 9000
#
# 	# barrier parameter
# 	κ_mpc = 1.0e-4
#
# 	obj_mpc = quadratic_objective(model, H_mpc,
# 	    q = [Diagonal(1e-2 * [1.0; 0.02; 0.25; 0.25 * ones(model.dim.q-3)]) for t = 1:H_mpc+2],
# 	    v = [Diagonal(0.0 * ones(model.dim.q)) for t = 1:H_mpc],
# 	    u = [Diagonal(3e-2 * ones(model.dim.u)) for t = 1:H_mpc-1])
# 	# obj_mpc = TrackingObjective(model, env, H_mpc,
# 	#     q = [Diagonal(1e-2 * [1.0; 0.02; 0.25; 0.25 * ones(model.dim.q-3)]) for t = 1:H_mpc],
# 	#     u = [Diagonal(3e-2 * ones(model.dim.u)) for t = 1:H_mpc],
# 	#     γ = [Diagonal(1.0e-100 * ones(model.dim.c)) for t = 1:H_mpc],
# 	#     b = [Diagonal(1.0e-100 * ones(model.dim.c * friction_dim(env))) for t = 1:H_mpc])
#
# 	p = linearized_mpc_policy(ref_traj, s, obj_mpc,
# 	    H_mpc = H_mpc,
# 	    N_sample = N_sample,
# 	    κ_mpc = κ_mpc,
# 		mode = :configuration,
# 		ip_type = :mehrotra,
# 		newton_mode = :structure,
# 	    n_opts = NewtonOptions(
# 			solver = :lu_solver,
# 			r_tol = 3e-4,
# 			max_iter = 5,
# 			# max_time = ref_traj.h, # HARD REAL TIME
# 			),
# 	    mpc_opts = LinearizedMPCOptions(),
# 		ip_opts = InteriorPointOptions(
# 			max_iter = 100,
# 			verbose = false,
# 			r_tol = 1.0e-4,
# 			κ_tol = 1.0e-4,
# 			diff_sol = true,
# 			# κ_reg = 1e-3,
# 			# γ_reg = 1e-1,
# 			solver = :empty_solver,
# 			),
# 	    )
#
# 	q1_ref = copy(ref_traj.q[2])
# 	q0_ref = copy(ref_traj.q[1])
# 	q1_sim = SVector{model.dim.q}(q1_ref)
# 	q0_sim = SVector{model.dim.q}(copy(q1_sim - (q1_ref - q0_ref) / N_sample))
# 	@assert norm((q1_sim - q0_sim) / h_sim - (q1_ref - q0_ref) / h) < 1.0e-8
#
# 	sim = ContactImplicitMPC.simulator(s, q0_sim, q1_sim, h_sim, H_sim,
# 	    p = p,
# 	    ip_opts = ContactImplicitMPC.InteriorPointOptions(
# 	        r_tol = 1.0e-8,
# 	        κ_tol = 1.0e-6,
# 	        diff_sol = true),
# 	    sim_opts = ContactImplicitMPC.SimulatorOptions(warmstart = true))
#
# 	status = ContactImplicitMPC.simulate!(sim, verbose = true)
#
# 	qerr, uerr, γerr, berr = tracking_error(ref_traj, sim.traj, N_sample, idx_shift = [1])
# 	@test qerr < 0.0202 * 1.5 # 0.0202
# 	@test uerr < 0.0437 * 1.5 # 0.0437
# 	@test γerr < 0.3780 * 1.5 # 0.3780
# 	@test berr < 0.0799 * 1.5 # 0.0799
# 	qerr > 0.0201 * 1.2 && @warn "mild regression on q tracking: current tracking error = $qerr, nominal tracking error = 0.0202"
# 	uerr > 0.0437 * 1.2 && @warn "mild regression on u tracking: current tracking error = $uerr, nominal tracking error = 0.0437"
# 	γerr > 0.3790 * 1.2 && @warn "mild regression on γ tracking: current tracking error = $γerr, nominal tracking error = 0.3780"
# 	berr > 0.0798 * 1.2 && @warn "mild regression on b tracking: current tracking error = $berr, nominal tracking error = 0.0799"
#
# end
