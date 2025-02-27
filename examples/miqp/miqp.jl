ENV["GUROBI_HOME"] = "/home/simon/software/gurobi912/linux64/"
ENV["GRB_LICENSE_FILE"] = "/home/simon/software/gurobi912/gurobi.lic"

using Gurobi
using JuMP
using LinearAlgebra
using MeshCat
using Plots
using Test

include("structures.jl")
include("visuals.jl")

# probem data
T = 40 # horizon (T+1 states, T controls)
H = 380 # simulation horizon
dt = 0.04 # step size
x0 = [0.00, 0.0] # initial state
Q = 1.0 # cost on state
Qf = 50.0 # cost on state
R = 1.0 # cost on control
β = 1e3 # extreme values in MIQP

# dynamics model
model = WallPendulum12(2, 1, 1.0, 1.0, 10.0, 1e4, 0.1) # m l g k d

# dynamics model
A1, B1, c1 = dynamics_model(model, dt, mode = :none)
A2, B2, c2 = dynamics_model(model, dt, mode = :left)
A3, B3, c3 = dynamics_model(model, dt, mode = :right)

A = [A1, A2, A3]
B = [B1, B2, B3]
c = [c1, c2, c3]

# domains
C1 = domain(model, mode = :none)
C2 = domain(model, mode = :left)
C3 = domain(model, mode = :right)
C = [C1, C2, C3]

# problem
prob = WallProblem16(model, T, x0, Q, Qf, R, β, A, B, c, C)

# disturbances
i1 = 20
i2 = i1 + 100
i3 = i2 + 40
i4 = i3 + 100
i5 = i4 + 60
ind = [i1, i2, i3, i4, i5]
w = [[-15.5], [+15.5], [+15.5], [-11.5], [-10.5]]

# simulation
x, u, s = simulate!(prob, x0, H, w = w, iw = ind)
sum(s) / (H * dt) # 4.52
maximum(s) / dt #17.6
mean(s) # 0.18
sqrt(mean((s .- mean(s)).^2)) #

# visualization
DTx = range(0.0, step = dt, length = size(x)[1])
DTu = range(0.0, step = dt, length = size(u)[1])
plot(DTu, hcat(u...)', label = "u")
plot(DTx[1:end], hcat(x...)'[1:end,:], label = ["θ" "θd"])

# vis = Visualizer()
# open(vis)
build_robot!(vis, model)
set_robot!(vis, model, [0.10, 0.1])
anim = visualize_robot!(vis, model, x, h = dt)

pθ_right = generate_pusher_traj(ind, w, x, side=:right)
pθ_left  = generate_pusher_traj(ind, w, x, side=:left)
visualize_disturbance!(vis, model, pθ_right, anim=anim, sample=1, offset=0.02, name=:PusherRight)
visualize_disturbance!(vis, model, pθ_left,  anim=anim, sample=1, offset=0.02, name=:PusherLeft)



# filename = "wall_pendulum_with_pusher"
# MeshCat.convert_frames_to_video(
#     "/home/simon/Downloads/$filename.tar",
#     "/home/simon/Documents/video/$filename.mp4", overwrite=true)
#
# convert_video_to_gif(
#     "/home/simon/Documents/video/$filename.mp4",
#     "/home/simon/Documents/video/$filename.gif", overwrite=true)

# system simplified compared to PushBot
    # only 1 control and 2 states
    # linearized about equilibrium point
    # only 3 contact modes considered (no stick-slip modes, no friction considered)
# performance compared to PushBot with LCI-MPC
    # on average 5 time slower than real-time on the same computer
    # especially struggling with contact switches (steps are 15x slower than real-time MPC)
