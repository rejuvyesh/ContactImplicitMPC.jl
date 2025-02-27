"""
    particle dynamics
    - 3D particle subject to contact forces

    - configuration: q = (x, y, z) ∈ R³
    - impact force (magnitude): γ ∈ R₊
    - friction force: β ∈ R⁴₊
        - friction coefficient: μ ∈ R₊

    Discrete Mechanics and Variational Integrators
        pg. 363
"""
mutable struct Particle{T} <: ContactModel
    dim::Dimensions
    m::T # mass
    g::T # gravity
    μ_world::T # friction coefficient
	μ_joint::T

	base::BaseMethods
	dyn::DynamicsMethods

	joint_friction::SVector
end

function lagrangian(model::Particle, q, q̇)
	L = 0.0

	L += 0.5 * model.m * (transpose(q̇) * q̇)
	L -= model.m * model.g * q[3]

	return L
end

function kinematics(::Particle, q)
	return q
end

# mass matrix
function M_func(model::Particle, q)
    m = model.m

    Diagonal(@SVector [m, m, m])
end

# gravity
function C_func(model::Particle, q, q̇)
    m = model.m
    g = model.g

    @SVector [0.0, 0.0, m * g]
end

# signed distance function
function ϕ_func(model::Particle, env::Environment, q)
	SVector{1}(q[3] - env.surf(q[1:2]))
end


# control Jacobian
function B_func(model::Particle, q)
    SMatrix{3, 3}([1.0 0.0 0.0;
                   0.0 1.0 0.0;
                   0.0 0.0 1.0])
end

# disturbance Jacobian
function A_func(model::Particle, q)
    SMatrix{3, 3}([1.0 0.0 0.0;
                   0.0 1.0 0.0;
                   0.0 0.0 1.0])
end

# contact Jacobian
function J_func(model::Particle, env::Environment, q)
    SMatrix{3, 3}([1.0 0.0 0.0;
                   0.0 1.0 0.0;
				   0.0 0.0 1.0])
end

function contact_forces(model::Particle, env::Environment{<:World, LinearizedCone}, γ1, b1, q2, k)
	m = friction_mapping(env)

	SVector{3}(transpose(rotation(env, k[1:2])) * [m * b1; γ1])
end

function contact_forces(model::Particle, env::Environment{<:World, NonlinearCone}, γ1, b1, q2, k)
	m = friction_mapping(env)

	SVector{3}(transpose(rotation(env, k[1:2])) * [b1; γ1])
end

function velocity_stack(model::Particle, env::Environment{<:World, LinearizedCone}, q1, q2, k, h)
	v = J_func(model, env, q2) * (q2 - q1) / h[1]

	v_surf = rotation(env, k[1:2]) * v

	SVector{4}(transpose(friction_mapping(env)) * v_surf[1:2])
end

function velocity_stack(model::Particle, env::Environment{<:World, NonlinearCone}, q1, q2, k, h)
	v = J_func(model, env, q2) * (q2 - q1) / h[1]

	v_surf = rotation(env, k[1:2]) * v

	SVector{2}(v_surf[1:2])
end


# Dimensions
nq = 3              # configuration dimension
nu = 3              # control dimension
nw = 3              # disturbance dimension
nc = 1              # number of contact points

particle = Particle(Dimensions(3, 3, 3, 1, 0), 1.0, 9.81, 1.0, 0.0,
	BaseMethods(), DynamicsMethods(),
	SVector{3}(zeros(3)))
