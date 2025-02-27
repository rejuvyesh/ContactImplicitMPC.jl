# Newton solver options
@with_kw mutable struct NewtonOptions{T}
    r_tol::T = 1.0e-5            # primal dual residual tolerance
    max_iter::Int = 10           # primal dual iter
    β_init::T = 1.0e-5           # initial dual regularization
    live_plotting::Bool = false  # visualize the trajectory during the solve
    verbose::Bool = false
    solver::Symbol = :lu_solver
end

struct NewtonResidual{T,vq2,vu1,vd,vI,vq0,vq1}
    r#::Vector{T}                           # residual

    q2::Vector{vq2}                    # rsd objective views
    u1::Vector{vu1}                    # rsd objective views

    rd::Vector{vd}                         # rsd dynamics lagrange multiplier views
    rI::Vector{vI}                         # rsd dynamics -I views [q2]
    q0::Vector{vq0}                        # rsd dynamics q0 views
    q1::Vector{vq1}                        # rsd dynamics q1 views
end

function NewtonResidual(model::ContactModel, env::Environment, H::Int)
    dim = model.dim

    nq = dim.q # configuration
    nu = dim.u # control
    nc = dim.c # contact
    nd = nq    # implicit dynamics constraint
    nr = nq + nu + nd # size of a one-time-step block

    off = 0
    iq = SizedVector{nq}(off .+ (1:nq)); off += nq # index of the configuration q2
    iu = SizedVector{nu}(off .+ (1:nu)); off += nu # index of the control u1
    iν = SizedVector{nd}(off .+ (1:nd)); off += nd # index of the dynamics lagrange multiplier ν1
    iz = copy(iq) # index of the IP solver solution [q2]

    r = zeros(H * nr)

    q2  = [view(r, (t - 1) * nr .+ iq) for t = 1:H]
    u1  = [view(r, (t - 1) * nr .+ iu) for t = 1:H]

    rd  = [view(r, (t - 1) * nr .+ iν) for t = 1:H]
    rI  = [view(r, (t - 1) * nr .+ iz) for t = 1:H]
    q0  = [view(r, (t - 3) * nr .+ iq) for t = 3:H]
    q1  = [view(r, (t - 2) * nr .+ iq) for t = 2:H]

    T = eltype(r)

    return NewtonResidual{T, eltype.((q2, u1))...,eltype.((rd, rI, q0, q1))...}(
        r, q2, u1, rd, rI, q0, q1)
end

struct NewtonJacobian{T,Vq,Vu,VI,VIT,Vq0,Vq0T,Vq1,Vq1T,Vu1,Vu1T,Vreg}
    R#::SparseMatrixCSC{T,Int}                 # jacobian

    obj_q2::Vector{Vq}                          # obj views
    obj_u1::Vector{Vu}                          # obj views

    obj_q1q2::Vector{Vq}
    obj_q2q1::Vector{Vq}

    IV::Vector{VI}                          # dynamics -I views [q2]
    ITV::Vector{VIT}                        # dynamics -I views [q2] transposed
    q0::Vector{Vq0}                         # dynamics q0 views
    q0T::Vector{Vq0T}                       # dynamics q0 views transposed
    q1::Vector{Vq1}                         # dynamics q1 views
    q1T::Vector{Vq1T}                       # dynamics q1 views transposed
    u1::Vector{Vu1}                         # dynamics u1 views
    u1T::Vector{Vu1T}                       # dynamics u1 views transposed
    reg::Vector{Vreg}                       # dual regularization views
end

function NewtonJacobian(model::ContactModel, env::Environment, H::Int)
    dim = model.dim

    nq = dim.q # configuration
    nu = dim.u # control
    nw = dim.w # disturbance
    nc = dim.c # contact
    nd = nq # implicit dynamics constraint
    nr = nq + nu + nd # size of a one-time-step block

    off = 0
    iq = SizedVector{nq}(off .+ (1:nq)); off += nq # index of the configuration q2
    iu = SizedVector{nu}(off .+ (1:nu)); off += nu # index of the control u1
    iν = SizedVector{nd}(off .+ (1:nd)); off += nd # index of the dynamics lagrange multiplier ν1
    iz = copy(iq)                                  # index of the IP solver solution [q2]
    iθ = vcat(iq .- 2nr, iq .- nr, iu) # index of the IP solver data [q0, q1, u1]

    R = spzeros(H * nr, H * nr)

    obj_q2  = [view(R, (t - 1) * nr .+ iq, (t - 1) * nr .+ iq) for t = 1:H]
    obj_u1  = [view(R, (t - 1) * nr .+ iu, (t - 1) * nr .+ iu) for t = 1:H]

    obj_q1q2  = [view(R, (t - 1) * nr .+ iq, t * nr .+ iq) for t = 1:H-1]
    obj_q2q1  = [view(R, t * nr .+ iq, (t - 1) * nr .+ iq) for t = 1:H-1]

    IV  = [view(R, CartesianIndex.((t - 1) * nr .+ iz, (t - 1) * nr .+ iν)) for t = 1:H]
    ITV = [view(R, CartesianIndex.((t - 1) * nr .+ iν, (t - 1) * nr .+ iz)) for t = 1:H]
    q0  = [view(R, (t - 1) * nr .+ iν, (t - 3) * nr .+ iq) for t = 3:H]
    q0T = [view(R, (t - 3) * nr .+ iq, (t - 1) * nr .+ iν) for t = 3:H]
    q1  = [view(R, (t - 1) * nr .+ iν, (t - 2) * nr .+ iq) for t = 2:H]
    q1T = [view(R, (t - 2) * nr .+ iq, (t - 1) * nr .+ iν) for t = 2:H]
    u1  = [view(R, (t - 1) * nr .+ iν, (t - 1) * nr .+ iu) for t = 1:H]
    u1T = [view(R, (t - 1) * nr .+ iu, (t - 1) * nr .+ iν) for t = 1:H]
    reg = [view(R, CartesianIndex.((t - 1) * nr .+ iν, (t - 1) * nr .+ iν)) for t = 1:H] # TODO: Cartesian indices to only grab diagonals

    return NewtonJacobian{eltype(R),
        eltype.((obj_q2, obj_u1))...,
        eltype.((IV, ITV, q0, q0T, q1, q1T, u1, u1T, reg))...}(
        R, obj_q2, obj_u1,
        obj_q1q2, obj_q2q1,
        IV, ITV, q0, q0T, q1, q1T, u1, u1T, reg)
end

mutable struct NewtonIndices{nq,nu,n1,n2,n3}
    nd::Int                                   # implicit dynamics constraint
    nr::Int                                   # size of a one-time-step block
    iq::SizedArray{Tuple{nq},Int,1,1}         # configuration indices
    iu::SizedArray{Tuple{nu},Int,1,1}         # control indices
    iν::SizedArray{Tuple{n1},Int,1,1}         # implicit dynamics lagrange multiplier
    iz::SizedArray{Tuple{n2},Int,1,1}         # IP solver solution [q2]
    iθ::SizedArray{Tuple{n3},Int,1,1}         # IP solver data [q0, q1, u1]
    Iq::Vector{SizedArray{Tuple{nq},Int,1,1}} # configuration indices
    Iu::Vector{SizedArray{Tuple{nu},Int,1,1}} # control indices
    Iν::Vector{SizedArray{Tuple{n1},Int,1,1}} # implicit dynamics lagrange multiplier
    Iz::Vector{SizedArray{Tuple{n2},Int,1,1}} # IP solver solution [q2]
    Iθ::Vector{SizedArray{Tuple{n3},Int,1,1}} # IP solver data [q0, q1, u1]
end

function NewtonIndices(model::ContactModel, env::Environment, H::Int)
    dim = model.dim
    nq = dim.q # configuration
    nu = dim.u # control
    nw = dim.w # disturbance
    nc = dim.c # contact
    nd = nq # implicit dynamics constraint
    nr = nq + nu + nd # size of a one-time-step block

    off = 0
    iq = SizedVector{nq}(off .+ (1:nq)); off += nq # index of the configuration q2
    iu = SizedVector{nu}(off .+ (1:nu)); off += nu # index of the control u1
    iν = SizedVector{nd}(off .+ (1:nd)); off += nd # index of the dynamics lagrange multiplier ν1
    iz = copy(iq)                                  # index of the IP solver solution [q2]
    iθ = vcat(iq .- 2nr, iq .- nr, iu) # index of the IP solver data [q0, q1, u1]

    Iq = [(t - 1) * nr .+ iq for t = 1:H]
    Iu = [(t - 1) * nr .+ iu for t = 1:H]
    Iν = [(t - 1) * nr .+ iν for t = 1:H]
    Iz = [(t - 1) * nr .+ iz for t = 1:H]
    Iθ = [(t - 1) * nr .+ iθ for t = 1:H]

    return NewtonIndices{nq,nu,nd,nd,2nq+nu}(
        nd, nr,
        iq, iu, iν, iz, iθ,
        Iq, Iu, Iν, Iz, Iθ)
end

mutable struct Newton{T,nq,nu,nw,nz,nθ,n1,n2,n3}
    jac::NewtonJacobian{T}                          # NewtonJacobian
    res::NewtonResidual{T}                          # residual
    res_cand::NewtonResidual{T}                     # candidate residual
    Δ::NewtonResidual{T}                            # step direction in the Newton solve, it contains: q2-qH+1, u1-uH, γ1-γH, b1-bH, λd1-λdH
    ν::Vector{SizedArray{Tuple{n1},T,1,1}}          # implicit dynamics lagrange multiplier
    ν_cand::Vector{SizedArray{Tuple{n1},T,1,1}}         # candidate implicit dynamics lagrange multiplier
    traj::ContactTraj       # optimized trajectory
    traj_cand::ContactTraj # trial trajectory used in line search
    Δq::Vector{SizedArray{Tuple{nq},T,1,1}}         # difference between the traj and ref_traj
    Δu::Vector{SizedArray{Tuple{nu},T,1,1}}         # difference between the traj and ref_traj
    ind::NewtonIndices                                 # indices of a one-time-step block
    obj::Objective                              # obj function
    solver::LinearSolver
    β::T
    opts::NewtonOptions{T}                          # Newton solver options
end

function Newton(s::Simulation, H::Int, h::T,
    traj::ContactTraj, im_traj::ImplicitTraj;
    obj::Objective = TrackingObjective(s.model, s.env, H),
    opts::NewtonOptions = NewtonOptions(), κ::T=im_traj.ip[1].κ[1]) where T

    model = s.model
    env = s.env

    dim = model.dim
    ind = NewtonIndices(model, env, H)

    nq = dim.q
    nu = dim.u
    nw = dim.w
    nz = num_var(model, env)
    nθ = num_data(model)
    nd = ind.nd

    jac = NewtonJacobian(model, env, H)

    # precompute Jacobian for pre-factorization
    implicit_dynamics!(im_traj, s, traj, κ = [κ]) #@@@
    jacobian!(jac, im_traj, obj, H, opts.β_init)

    res = NewtonResidual(model, env, H)
    res_cand = NewtonResidual(model, env, H)

    Δ = NewtonResidual(model, env, H)

    ν = [zeros(SizedVector{ind.nd,T}) for t = 1:H]
    ν_cand = deepcopy(ν)

    traj = contact_trajectory(model, env, H, h, κ=κ)
    traj_cand = contact_trajectory(model, env, H, h, κ=κ)

    Δq  = [zeros(SizedVector{nq,T}) for t = 1:H]
    Δu  = [zeros(SizedVector{nu,T}) for t = 1:H]

    # regularization
    β = copy(opts.β_init)

    # linear solver
    solver = eval(opts.solver)(jac.R)

    return Newton{T,nq,nu,nw,nz,nθ,nd,nd,2nq+nu}(
        jac, res, res_cand, Δ, ν, ν_cand, traj, traj_cand,
        Δq, Δu, ind, obj, solver, β, opts)
end

function initialize_jacobian!(jac::NewtonJacobian, obj::Objective, H::Int)

    fill!(jac.R, 0.0)

    # Objective
    hessian!(jac, obj)

    for t = 1:H
        # Implicit dynamics
        jac.IV[t] .-= 1.0
        jac.ITV[t] .-= 1.0
    end

    return nothing
end

function update_jacobian!(jac::NewtonJacobian, im_traj::ImplicitTraj, obj::Objective,
    H::Int, β::T) where T


    # reset
    for t = 1:H
        if t >= 3
            fill!(jac.q0[t-2], 0.0)
            fill!(jac.q0T[t-2], 0.0)
        end

        if t >= 2
            fill!(jac.q1[t-1], 0.0)
            fill!(jac.q1T[t-1], 0.0)
        end

        fill!(jac.u1[t], 0.0)
        fill!(jac.u1T[t], 0.0)

        # Dual regularization
        fill!(jac.reg[t], 0.0)
    end

    nq = size(jac.q0[1])[1]

    for t = 1:H
        if t >= 3
            jac.q0[t-2]  .+= im_traj.δq0[t][1:nq, :]
            jac.q0T[t-2] .+= im_traj.δq0[t][1:nq, :]'
        end

        if t >= 2
            jac.q1[t-1]  .+= im_traj.δq1[t][1:nq, :]
            jac.q1T[t-1] .+= im_traj.δq1[t][1:nq, :]'
        end

        jac.u1[t]  .+= im_traj.δu1[t][1:nq, :]
        jac.u1T[t] .+= im_traj.δu1[t][1:nq, :]'

        # Dual regularization
        jac.reg[t] .-= 1.0 * β * im_traj.ip[t].κ # TODO sort the κ stuff, maybe make it a prameter of this function
    end

    return nothing
end

function jacobian!(jac::NewtonJacobian, im_traj::ImplicitTraj, obj::Objective,
    H::Int, β::T) where T

    initialize_jacobian!(jac, obj, H)
    update_jacobian!(jac, im_traj, obj, H, β)

    return nothing
end

function residual!(res::NewtonResidual, core::Newton,
    ν::Vector, im_traj::ImplicitTraj, traj::ContactTraj, ref_traj::ContactTraj)

    # unpack
    opts = core.opts
    obj = core.obj
    res.r .= 0.0

    nq = size(res.q0[1])[1]

    # Objective
    gradient!(res, obj, core, traj, ref_traj)
    for t in eachindex(ν)
        # Implicit dynamics
        res.rd[t] .+= im_traj.d[t][1:nq]

        # Minus Identity term #∇qk1, ∇γk, ∇bk
        res.rI[t] .-= ν[t]

        t >= 3 ? res.q0[t-2] .+= im_traj.δq0[t][1:nq, :]' * ν[t] : nothing
        t >= 2 ? res.q1[t-1] .+= im_traj.δq1[t][1:nq, :]' * ν[t] : nothing
        res.u1[t] .+= im_traj.δu1[t][1:nq, :]' * ν[t]
    end

    return nothing
end



function delta!(Δx::SizedArray{Tuple{nx},T,1,1}, x, x_ref) where {nx,T}
    Δx .= x
    Δx .-= x_ref
    return nothing
end

#TODO: add minus function

function update_traj!(traj_cand::ContactTraj, traj::ContactTraj,
        ν_cand::Vector, ν::Vector, Δ::NewtonResidual{T}, α::T) where T

    H = traj_cand.H

    for t = 1:H
        traj_cand.q[t+2] .= traj.q[t+2] .- α .* Δ.q2[t]
        traj_cand.u[t] .= traj.u[t] .- α .* Δ.u1[t]

        ν_cand[t]  .= ν[t] .- α .* Δ.rd[t]
    end

    update_z!(traj_cand)
    update_θ!(traj_cand)

    return nothing
end

function copy_traj!(traj::ContactTraj, traj_cand::ContactTraj, H::Int)
    Ht = traj.H
    Hs = traj_cand.H # MAYBE BREAKING TEST

    @assert Hs >= H
    @assert Ht >= H

    traj.κ .= traj_cand.κ

    for t in eachindex(1:H + 2)
        traj.q[t] .= traj_cand.q[t]
    end

    for t in eachindex(1:H)
        traj.u[t] .= traj_cand.u[t]
        traj.w[t] .= traj_cand.w[t]
        traj.z[t] .= traj_cand.z[t]
        traj.θ[t] .= traj_cand.θ[t]
    end

    return nothing
end

function reset!(core::Newton, ref_traj::ContactTraj;
    warm_start::Bool = false, initial_offset::Bool = false,
    q0 = ref_traj.q[1], q1 = ref_traj.q[2])

    # H = ref_traj.H
    H_mpc = core.traj.H
    opts = core.opts

    # Reset β value
    core.β = opts.β_init

    if !warm_start
		# Reset duals
		for t = 1:H_mpc
			fill!(core.ν[t], 0.0)
			fill!(core.ν_cand[t], 0.0)
		end

		# Set up trajectory
        copy_traj!(core.traj, ref_traj, core.traj.H)

        if initial_offset
		    rd = -0.03 * [[1, 1]; ones(model.dim.q - 2)]
		    core.traj.q[1] .+= rd
		    core.traj.q[2] .+= rd
			update_θ!(core.traj, 1)
			update_θ!(core.traj, 2)
		end
	end
    core.traj.q[1] .= deepcopy(q0)
    core.traj.q[2] .= deepcopy(q1)

    update_θ!(core.traj, 1)
    update_θ!(core.traj, 2)

    # initialized residual Jacobian
    initialize_jacobian!(core.jac, core.obj, core.traj.H)

	# Set up traj cand
	core.traj_cand = deepcopy(core.traj)

	return nothing
end

function newton_solve!(core::Newton, s::Simulation,
    im_traj::ImplicitTraj, ref_traj::ContactTraj;
    warm_start::Bool = false, initial_offset::Bool = false,
    q0 = ref_traj.q[1], q1 = ref_traj.q[2])

    # @show "newton_solve!" #@@@
	reset!(core, ref_traj, warm_start = warm_start,
        initial_offset = initial_offset, q0 = q0, q1 = q1)

    # Compute implicit dynamics about traj
	implicit_dynamics!(im_traj, s, core.traj, κ = im_traj.ip[1].κ)

    # Compute residual
    residual!(core.res, core, core.ν, im_traj, core.traj, ref_traj)

    r_norm = norm(core.res.r, 1)

    for l = 1:core.opts.max_iter
        # check convergence
        # println("lbefor = ", l, "  norm = ", r_norm / length(core.res.r)) #@@@
        r_norm / length(core.res.r) < core.opts.r_tol && break
        # Compute NewtonJacobian
        update_jacobian!(core.jac, im_traj, core.obj, core.traj.H, core.β)

        # Compute Search Direction
        linear_solve!(core.solver, core.Δ.r, core.jac.R, core.res.r)

        # line search the step direction
        α = 1.0
        iter = 0

        # candidate step
        update_traj!(core.traj_cand, core.traj, core.ν_cand, core.ν, core.Δ, α)

        # Compute implicit dynamics for candidate
		implicit_dynamics!(im_traj, s, core.traj_cand, κ = im_traj.ip[1].κ)

        # Compute residual for candidate
        residual!(core.res_cand, core, core.ν_cand, im_traj, core.traj_cand, ref_traj)
        r_cand_norm = norm(core.res_cand.r, 1)

        while r_cand_norm^2.0 >= (1.0 - 0.001 * α) * r_norm^2.0
            α = 0.5 * α

            iter += 1
            if iter > 6
                break
            end

            update_traj!(core.traj_cand, core.traj, core.ν_cand, core.ν, core.Δ, α)

            # Compute implicit dynamics about trial_traj
			implicit_dynamics!(im_traj, s, core.traj_cand, κ = im_traj.ip[1].κ)

            residual!(core.res_cand, core, core.ν_cand, im_traj, core.traj_cand, ref_traj)
            r_cand_norm = norm(core.res_cand.r, 1)
        end

        # update
        update_traj!(core.traj, core.traj, core.ν, core.ν, core.Δ, α)
        core.res.r .= core.res_cand.r
        r_norm = r_cand_norm
        # println("lafter = ", l, "  norm = ", r_norm / length(core.res.r)) #@@@

        # regularization update
        if iter > 6
            core.β = min(core.β * 1.3, 1.0e2)
        else
            core.β = max(1.0e1, core.β / 1.3)
        end

        # print status
        core.opts.verbose && println(" l: ", l ,
                "     r̄: ", scn(norm(core.res_cand.r, 1) / length(core.res_cand.r), digits = 0),
                "     r: ", scn(norm(core.res.r, 1) / length(core.res.r), digits = 0),
                "     Δ: ", scn(norm(core.Δ.r, 1) / length(core.Δ.r), digits = 0),
                "     α: ", -Int(round(log(α))),
                "     κ: ", scn(im_traj.ip[1].κ[1], digits = 0))
    end

    return nothing
end
