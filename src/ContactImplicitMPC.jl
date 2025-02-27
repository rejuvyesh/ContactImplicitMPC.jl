
module ContactImplicitMPC

using BenchmarkTools
using Colors
using CoordinateTransformations
using FFMPEG
using FileIO
using ForwardDiff
using GeometryBasics
using IfElse
using InteractiveUtils
using JLD2
using LinearAlgebra
using Logging
using QDLDL
using MeshCat
using MeshCatMechanisms
using Meshing
using MeshIO
using Parameters
using Plots
using Random
using Rotations
using SparseArrays
using StaticArrays
using Symbolics
using Test

# Utilities
include("utils.jl") #

# Solver
include("solver/gn.jl")
include("solver/lu.jl")
include("solver/ldl.jl")
include("solver/qr.jl")
include("solver/schur.jl")
include("solver/cones.jl") #


# Environment
include("simulator/environment.jl")

# Dynamics
include("dynamics/model.jl")

# Simulator
include("simulation/index.jl")

# Solver
include("solver/interior_point.jl")

# Simulator
include("simulation/contact_methods.jl")
include("simulation/simulation.jl")
include("simulator/trajectory.jl")

include("dynamics/code_gen_dynamics.jl")
include("dynamics/fast_methods_dynamics.jl")

# Models
include("dynamics/quaternions.jl")
include("dynamics/mrp.jl")
include("dynamics/euler.jl")

include("dynamics/particle_2D/model.jl")
include("dynamics/particle/model.jl")
include("dynamics/hopper_2D/model.jl")
include("dynamics/hopper_3D/model.jl")
include("dynamics/quadruped/model.jl")
include("dynamics/flamingo/model.jl")
include("dynamics/pushbot/model.jl")
include("dynamics/rigidbody/model.jl")


# Simulator
include("simulator/policy.jl")
include("simulator/disturbances.jl")
include("simulator/simulator.jl")

# Simulation
include("simulation/environments/flat.jl")
include("simulation/environments/piecewise.jl")
include("simulation/environments/quadratic.jl")
include("simulation/environments/slope.jl")
include("simulation/environments/sinusoidal.jl")
include("simulation/environments/stairs.jl")

include("simulation/residual_approx.jl")
include("simulation/code_gen_simulation.jl")

# Controller
include("controller/linearized_step.jl")
include("controller/implicit_dynamics.jl")
include("controller/objective.jl")
include("controller/linearized_solver.jl")
include("controller/newton.jl")
include("controller/newton_indices.jl")
include("controller/newton_residual.jl")
include("controller/newton_jacobian.jl")
include("controller/mpc_utils.jl")
include("controller/policy.jl")
include("controller/newton_structure_solver/methods.jl")

# Visuals
include("dynamics/visuals.jl")
include("dynamics/visual_utils.jl")

export
    World,
    LinearizedCone,
    NonlinearCone,
    ContactModel,
    Dimensions,
    BaseMethods,
    DynamicsMethods,
    ResidualMethods,
    Environment,
    environment_2D,
    environment_3D,
    environment_2D_flat,
    environment_3D_flat,
    get_model,
    SparseStructure,
    LinearizedStep,
    bil_addition!,
    r_linearized!,
    rz_linearized!,
    ImplicitTraj,
    linearization!,
    implicit_dynamics!,
    TrackingObjective,
    TrackingVelocityObjective,
    second_order_cone_product,
    generate_base_expressions,
    RLin,
    RZLin,
    RθLin,
    ContactTraj,
    Simulation,
    num_var,
    num_data,
    get_simulation,
    get_trajectory,
    interior_point,
    InteriorPointOptions,
    interior_point_solve!,
    r!,
    rz!,
    rθ,
    generate_base_expressions,
    save_expressions,
    instantiate_base!,
    generate_dynamics_expressions,
    save_expressions,
    instantiate_dynamics!,
    environment_3D_flat,
    friction_dim,
    dim,
    sqrt_quat,
    cayley_map,
    L_multiply,
    R_multiply,
    R2,
    R3,
    FrictionCone,
    rotation,
    module_dir,
    open_loop_disturbances,
    disturbances,
    open_loop_policy,
    policy,
    linearized_mpc_policy,
    NewtonOptions,
    LinearizedMPCOptions,
    SimulatorOptions,
    simulator,
    simulate!,
    generate_residual_expressions,
    instantiate_residual!,
    ϕ_func,
    tracking_error,
    repeat_ref_traj,
    Schur,
    schur_factorize!,
    schur_solve!,
    LinearSolver,
    LUSolver,
    lu_solver,
    factorize!,
    linear_solve!,
    OptimizationSpace,
    OptimizationSpace13,
    index_q2,
    index_γ1,
    index_b1,
    index_ψ1,
    index_s1,
    index_η1,
    index_s2,
    index_q0,
    index_q1,
    index_u1,
    index_w1,
    index_μ,
    index_h,
    index_dyn,
    index_imp,
    index_mdp,
    index_fri,
    index_bimp,
    index_bmdp,
    index_bfri,
    linearization_var_index,
    linearization_term_index,
    index_ort,
    index_soc,
    num_var,
    num_data,
    num_bilinear,
    index_equr,
    index_ortr,
    index_socr

end # module
