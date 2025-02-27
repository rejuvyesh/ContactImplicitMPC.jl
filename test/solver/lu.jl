@testset "LU solver" begin
    n = 20
    m = 10
    A = rand(n, n)
    X = rand(n, m)
    B = rand(n, m)
    x = rand(n)
    b = rand(n)

    sol = ContactImplicitMPC.lu_solver(A)
    ContactImplicitMPC.linear_solve!(sol, X, A, B)
    @test norm(A * X - B, Inf) < 1e-10

    sol = ContactImplicitMPC.lu_solver(A)
    ContactImplicitMPC.linear_solve!(sol, x, A, b)
    @test norm(A * x - b, Inf) < 1e-10
end

# n = 20
# m = 10
# A = rand(n, n)
# X = rand(n, m)
# B = rand(n, m)
# x = rand(n)
# b = rand(n)
#
# sol = ContactImplicitMPC.lu_solver(A)
# @benchmark ContactImplicitMPC.linear_solve!($sol, $X, $A, $B)
# @test norm(A * X - B, Inf) < 1e-10
#
# sol = ContactImplicitMPC.lu_solver(A)
# @benchmark ContactImplicitMPC.linear_solve!($sol, $x, $A, $b)
# @test norm(A * x - b, Inf) < 1e-10
# @benchmark factorize!($sol, $A)
# @benchmark ldiv!($x, $(sol.lu), $b)
