@testset "Controller: Implicit Dynamics" begin
	T = Float64
	s = get_simulation("particle", "flat_3D_lc", "flat_lc")

	model = s.model
	env = s.env

	nq = model.dim.q
	nu = model.dim.u
	H = 10
	h = 0.0001
	κ = 1e-6
	nq = model.dim.q

	q0 = SVector{nq,T}([0.0, 0.0, 1.0])
	q1 = SVector{nq,T}([0.0, 0.0, 1.0])

	ip_opts = ContactImplicitMPC.InteriorPointOptions(
		κ_tol = 1.0e-8, r_tol = 1.0e-10)

	sim = ContactImplicitMPC.simulator(s, q0, q1, h, H;
		p = ContactImplicitMPC.no_policy(model),
		d = ContactImplicitMPC.no_disturbances(model),
		ip_opts = ip_opts,
		sim_opts = ContactImplicitMPC.SimulatorOptions{T}())

	ContactImplicitMPC.simulate!(sim, verbose = false)
	ref_traj = deepcopy(sim.traj)
	ref_traj.κ .= κ # sets κ_tol for the im_traj IP solvers
	traj0 = deepcopy(ref_traj)

	im_traj = ContactImplicitMPC.ImplicitTraj(ref_traj, s, mode = :configuration)
	ContactImplicitMPC.implicit_dynamics!(im_traj, s, traj0)

	# Implicit dynamics contraint violation is ≈ 0
	for t = 1:H
		@test norm(im_traj.d[t], Inf) < 1.0e-5
	end


	# Quadruped reference trajectory
	s = ContactImplicitMPC.get_simulation("quadruped", "flat_2D_lc", "flat")
	model = s.model
	env = s.env

	ref_traj = deepcopy(ContactImplicitMPC.get_trajectory(model, env,
	    joinpath(module_dir(), "src/dynamics/quadruped/gaits/gait2.jld2"),
	    load_type = :split_traj_alt))

	ip_opts = eval(ContactImplicitMPC.interior_point_options(:interior_point))(
				κ_tol = 2.0 * 1.0e-4,
				r_tol = 1.0e-8,
				diff_sol = true,
				solver = :empty_solver)

	im_traj = ContactImplicitMPC.ImplicitTraj(ref_traj, s,
		ip_type = :interior_point,
		κ = 1.0e-4,
		mode = :configuration,
		opts=ip_opts)

	ContactImplicitMPC.implicit_dynamics!(im_traj, s, ref_traj)

	@test all([norm(im_traj.dq2[t], Inf) < 1.0e-2 for t = 1:ref_traj.H-1])
end
