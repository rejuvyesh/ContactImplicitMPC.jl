abstract type LinearSolver end

mutable struct EmptySolver <: LinearSolver
    F::Any
end

function empty_solver(A::Any)
    EmptySolver(A)
end

"""
    GaussNewton solver
"""
struct GNSolver <: LinearSolver end

function gn_solver(A)
    # TODO: make more efficient
    GNSolver()
end

function linear_solve!(solver::GNSolver, x::Vector{T}, A::SparseMatrixCSC{T,Int}, b::Vector{T}) where T
    ldiv!(x, lu!(Array(A' * A)), Array(A' * b)) # solve
end

function linear_solve!(solver::GNSolver, x::Matrix{T}, A::AbstractMatrix{T}, B::AbstractMatrix{T}) where T
    ldiv!(x, lu!(A' * A), A' * B) # solve
end
