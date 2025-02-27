"""
    linearized model-predictive control policy
"""

@with_kw mutable struct LinearizedMPCOptions{T}
	altitude_update::Bool = false
	altitude_impact_threshold::T = 1.0
	altitude_verbose::Bool = false
    ip_max_time::T = 1e5     # maximum time allowed for an InteriorPoint solve
    live_plotting::Bool=false # Use the live plotting tool to debug
end

mutable struct LinearizedMPC <: Policy
	traj
	ref_traj
	im_traj
	H
	stride
	altitude
	κ
	newton
	newton_mode
	s
	q0
	N_sample
	cnt
	opts
end

function linearized_mpc_policy(traj, s, obj;
	H_mpc = traj.H,
	N_sample = 1,
	κ_mpc = traj.κ[1],
	ip_type = :interior_point,
	mode = :configurationforce,
	newton_mode = :direct,
	n_opts = NewtonOptions(
		r_tol = 3e-4,
		max_iter = 5,
		verbose = false,
		live_plotting = false),
	mpc_opts = LinearizedMPCOptions(),
	ip_opts = eval(interior_point_options(ip_type))(
				γ_reg = 0.1,
				undercut = 5.0,
				κ_tol = κ_mpc,
				r_tol = 1.0e-8,
				diff_sol = true,
				solver = :empty_solver,
				max_time = mpc_opts.ip_max_time,)
	)

	traj = deepcopy(traj)
	ref_traj = deepcopy(traj)

	im_traj = ImplicitTraj(traj, s,
		ip_type = ip_type,
		κ = κ_mpc,
		max_time = mpc_opts.ip_max_time,
		opts=ip_opts,
		mode = mode)

	stride = get_stride(s.model, traj)
	altitude = zeros(s.model.dim.c)
	if newton_mode == :direct
		newton = Newton(s, H_mpc, traj.h, traj, im_traj, obj = obj, opts = n_opts)
	elseif newton_mode == :structure
		newton = NewtonStructure(s, H_mpc, traj, obj, κ_mpc, opts = n_opts)
	else
		@error "invalid Newton solver specified"
	end

	LinearizedMPC(traj, ref_traj, im_traj, H_mpc, stride, altitude, κ_mpc, newton, newton_mode, s, copy(ref_traj.q[1]),
		N_sample, N_sample, mpc_opts)
end


function policy(p::LinearizedMPC, x, traj, t)
	# reset
	if t == 1
		p.cnt = p.N_sample
		p.q0 = copy(p.ref_traj.q[1])
	end

    if p.cnt == p.N_sample
		(p.opts.altitude_update && t > 1) && (update_altitude!(p.altitude, p.s,
									traj, t, p.N_sample,
									threshold = p.opts.altitude_impact_threshold,
									verbose = p.opts.altitude_verbose))
		# update!(p.im_traj, p.traj, p.s, p.altitude, κ = p.κ) #@@@ keep the altitude update here
		set_altitude!(p.im_traj, p.altitude) #@@@ keep the altitude update here
		newton_solve!(p.newton, p.s, p.im_traj, p.traj,
			warm_start = t > 1, q0 = copy(p.q0), q1 = copy(x))
		update!(p.im_traj, p.traj, p.s, p.altitude, κ = p.κ) #@@@ only keep the rotation stuff not the altitude update.
		p.opts.live_plotting && live_plotting(p.s.model, p.traj, traj, p.newton, p.q0, copy(x), t)

		rot_n_stride!(p.traj, p.stride)
		p.q0 .= copy(x)
		p.cnt = 0
    end

    p.cnt += 1

	if p.newton_mode == :direct
    	return p.newton.traj.u[1] / p.N_sample # rescale output
	elseif p.newton_mode == :structure
		return p.newton.u[1] / p.N_sample
	else
		@error "newton mode specified not available"
	end
end
