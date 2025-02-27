using ContactImplicitMPC

using Test
using ForwardDiff
using JLD2
using QDLDL
using Symbolics
using StaticArrays
using LinearAlgebra
using Random
using SparseArrays
using BenchmarkTools
using Quaternions

# Solver
include("solver/qr.jl")
include("solver/ldl.jl")
include("solver/lu.jl")
include("solver/schur.jl")
include("solver/ip_solver.jl")

# Dynamics
include("dynamics/lagrangian.jl") # need to fix d_fast
include("dynamics/model.jl")
include("dynamics/particle.jl")
include("dynamics/quadruped.jl")
include("dynamics/quaternion.jl")

# Simulator
include("simulator/rotations.jl")
include("simulator/environment.jl")
include("simulator/trajectory.jl")
include("simulator/simulator.jl")
include("simulator/particle.jl")
# include("simulator/hopper_2D.jl") #TODO: set tests to raibert model
include("simulator/hopper_3D.jl")
include("simulator/quadruped.jl")
include("simulator/open_loop.jl")
include("simulator/flamingo.jl")

# Controller
include("controller/objective.jl")
include("controller/linearized_step.jl")
include("controller/implicit_dynamics.jl")
include("controller/linearized_solver.jl")
include("controller/newton.jl")
include("controller/newton_structure_solver.jl") # fails on github actions

# MPC examples
include("controller/mpc_quadruped.jl")
include("controller/mpc_flamingo.jl")
