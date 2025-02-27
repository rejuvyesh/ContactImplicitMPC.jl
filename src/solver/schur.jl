"""
    Schur complement structure of the form:
       M = A B
           C D
       |A B| |x| = |u|
       |C D| |y| = |v|
    M ∈ R{n+m,n+m}
    A ∈ R{n,n}
    D ∈ R{m,m}
    The Schur complement is taken about A, the top-left block:
        SC = D - C * A^-1 * B
"""
mutable struct Schur{T,n,m,nn,nm,mm}
    A::SMatrix{n,n,T,nn}
    B::SMatrix{n,m,T,nm}
    C::SMatrix{m,n,T,nm}
    D::SMatrix{m,m,T,mm}
    Ai::SMatrix{n,n,T,nn} # Inverse of A
    CAi::SMatrix{m,n,T,nm} # C*A^{-1}
    CAiB::SMatrix{m,m,T,mm} # C*A^{-1}*B
    gs_data::SDMGSSolver{m,T} # Schur complement of the block A in M
    u::SVector{n,T}
    v::SVector{m,T}
    x::SVector{n,T}
    y::SVector{m,T}
end

"""
    Initialize a Schur Object from a matrix M. The matrix M is split in 4 blocks:
        - top left block = n x n
        - bottom right block = m x m
"""
function Schur(M::AbstractMatrix{T}; n::Int=1, m::Int=size(M)[1]-n) where {T}
    @assert all(size(M) .== n+m)
    A = SMatrix{n,n,T,n^2}(M[1:n,      1:n])
    B = SMatrix{n,m,T,n*m}(M[1:n,      n .+ (1:m)])
    C = SMatrix{m,n,T,n*m}(M[n .+ (1:m),1:n])
    D = SMatrix{m,m,T,m^2}(M[n .+ (1:m),n .+ (1:m)])
    Ai = inv(A)
    CAi = C*Ai
    CAiB = C*Ai*B
    gs_data = SDMGSSolver(m,T=T)
    factorize!(gs_data, D - CAiB)
    u = zeros(SVector{n,T})
    v = zeros(SVector{m,T})
    x = zeros(SVector{n,T})
    y = zeros(SVector{m,T})
    return Schur{T,n,m,n^2,n*m,m^2}(A,B,C,D,Ai,CAi,CAiB,gs_data,u,v,x,y)
end

"""
    Update the Schur complement structure to handle a change in the D matrix.
    It recomputes the Gram-Schmidt factorization of the Schur complement of the block A.
"""
function schur_factorize!(S::Schur{T,n,m,nn,nm,mm}, D::AbstractMatrix{T}) where {T,n,m,nn,nm,mm}
    # update D, gs_data and the shur complement
    # we may want to set S.D to D so that it's clean, even if it's not necessary
    # S.D = D
    CAiB = S.CAiB
    gs_data = S.gs_data
    factorize!(gs_data, D - CAiB)
    return nothing
end

"""
    Solve for [x;y] given [u,v] and the factorized matrix M.
"""
function schur_solve!(S::Schur{T,n,m,nn,nm,mm}, u::AbstractVector{T}, v::AbstractVector{T}) where {T,n,m,nn,nm,mm}
    B  = S.B
    Ai = S.Ai
    CAi = S.CAi
    gs_data = S.gs_data
    S.u = u
    S.v = v
    us = S.u # staticarrays
    vs = S.v # staticarrays
    # S.x = Ai*(us + B*(As*(C*(Ai*us) - vs)))
    # S.y = As*(- C*(Ai*us) + vs)

    qr_solve!(gs_data, CAi*us - vs)
    temp = gs_data.xs
    S.x = Ai*(us + B*temp)
    S.y = - temp
    return nothing
end
