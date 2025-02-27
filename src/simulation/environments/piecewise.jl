function piecewise(x)
	IfElse.ifelse(x[1] < 0.5, 0.0,
		IfElse.ifelse(x[1] < 2.0, m_ss * x[1] - 0.5 * m_ss,
			-0.250 * m_ss * (x[1] - 2.0) + 1.5 * m_ss))
end

function d_piecewise(x)
	IfElse.ifelse(x[1] < 0.5, 0.0,
		IfElse.ifelse(x[1] < 2.0, m_ss,
			-0.250 * m_ss))
end

function mirror_and_repeat(x; l::T = 5.0) where {T}
	# l = length of the pattern  ---^_/^-
	# we repeat it this way ---^_/^--^\_^------^_/^--^\_^---
	# section ≡ even -> normal pattern
	# section ≡ odd -> mirrored pattern
	section = floor(x / l)
	x_rel = x % l
	mir = (section % 2) == 1
	if !mir
		x_mir = x_rel
	elseif mir # mirroring
		x_mir = l - x_rel
	end
	mult = mir == 1 ? -1 : 1
	return x_mir, mult
end

# smooth kinks w/ cubic polynomial
poly(a, z) = a[4] + a[3] * z + a[2] * z^2.0 + a[1] * z^3.0
d_poly(a, z) = a[3] + 2.0 * a[2] * z + 3.0 * a[1] * z^2.0

function generate_piecewise_terrain(mss; repeat::Bool = false)
	# piece 1
	m1 = 0.0
	x1 = 0.4
	y1 = m1 * x1

	m2 = m_ss
	x2 = 0.6
	y2 = m2 * 0.1

	A1 = [x1^3.0 x1^2.0 x1 1.0;
	      x2^3.0 x2^2.0 x2 1.0;
		  3.0 * x1^2.0 2.0 * x1 1.0 0.0;
		  3.0 * x2^2.0 2.0 * x2 1.0 0.0]
	b1 = [y1; y2; m1; m2]

	a1 = A1 \ b1

	@assert isapprox(poly(a1, x1) - y1, 0.0, atol = 1.0e-8)
	@assert isapprox(poly(a1, x2) - y2, 0.0, atol = 1.0e-8)

	# piece 2
	m1 = m_ss
	x1 = 1.4
	y1 = m_ss * x1

	m2 = -0.250 * m_ss
	x2 = 1.6
	y2 = m_ss * 1.5 + m2 * 0.1

	A2 = [x1^3.0 x1^2.0 x1 1.0;
	      x2^3.0 x2^2.0 x2 1.0;
		  3.0 * x1^2.0 2.0 * x1 1.0 0.0;
		  3.0 * x2^2.0 2.0 * x2 1.0 0.0]
	b2 = [y1; y2; m1; m2]

	a2 = A2 \ b2

	@assert isapprox(poly(a2, x1) - y1, 0.0, atol = 1.0e-8)
	@assert isapprox(poly(a2, x2) - y2, 0.0, atol = 1.0e-8)

	if !repeat
		function piecewise_smoothed(x)
			IfElse.ifelse(x[1] < 0.4, 0.0,
				IfElse.ifelse(x[1] < 0.6, poly(a1, x[1]),
					IfElse.ifelse(x[1] < 1.9, m_ss * x[1] - 0.5 * m_ss,
						IfElse.ifelse(x[1] < 2.1, poly(a2, x[1] - 0.5),
						-0.250 * m_ss * (x[1] - 2.0) + 1.5 * m_ss))))
		end

		function d_piecewise_smoothed(x)
			IfElse.ifelse(x[1] < 0.4, 0.0,
				IfElse.ifelse(x[1] < 0.6, d_poly(a1, x[1]),
					IfElse.ifelse(x[1] < 1.9, m_ss,
						IfElse.ifelse(x[1] < 2.1, d_poly(a2, x[1] - 0.5),
						-0.250 * m_ss))))
		end
		return piecewise_smoothed, d_piecewise_smoothed
	elseif repeat
		@show "repp"
		function piecewise_repeat_smoothed(x)
			x_mir, mult = mirror_and_repeat(x[1]; l = 5.0)
			IfElse.ifelse(x_mir < 0.4, mult * 0.0,
				IfElse.ifelse(x_mir < 0.6, mult * poly(a1, x_mir),
					IfElse.ifelse(x_mir < 1.9, mult * (m_ss * x_mir - 0.5 * m_ss),
						IfElse.ifelse(x_mir < 2.1, mult * poly(a2, x_mir - 0.5),
						mult * (-0.250 * m_ss * (x_mir - 2.0) + 1.5 * m_ss)))))
		end

		function d_piecewise_repeat_smoothed(x)
			x_mir, mult = mirror_and_repeat(x[1]; l = 5.0)
			IfElse.ifelse(x_mir < 0.4, 0.0,
				IfElse.ifelse(x_mir < 0.6, d_poly(a1, x_mir),
					IfElse.ifelse(x_mir < 1.9, m_ss,
						IfElse.ifelse(x_mir < 2.1, d_poly(a2, x_mir - 0.5),
						-0.250 * m_ss))))
		end
		return piecewise_repeat_smoothed, d_piecewise_repeat_smoothed
	end
end

# x = range(-1.0, stop = 4.0, length = 1000)
# plot(x, piecewise.(x))#, aspect_ratio = :equal)
# plot!(x, piecewise_smoothed.(x))#, aspect_ratio = :equal)
#
# plot(x, d_piecewise.(x), aspect_ratio = :equal)
# plot!(x, d_piecewise_smoothed.(x), aspect_ratio = :equal)

m_ss = tan(deg2rad(10.0)) # 10 degree slope
p1, dp1 = generate_piecewise_terrain(m_ss, repeat = false)
piecewise1_2D_lc = Environment{R2, LinearizedCone}(p1, dp1)
plot(-1:0.01:15, piecewise1_2D_lc.surf.(-1:0.01:15))
plot!(-1:0.01:15, piecewise1_2D_lc.surf_grad.(-1:0.01:15))

m_ss = tan(deg2rad(-15.0)) # 10 degree slope
p2, dp2 = generate_piecewise_terrain(m_ss)
piecewise2_2D_lc = Environment{R2, LinearizedCone}(p2, dp2)
# plot(-1:0.01:15, piecewise2_2D_lc.surf.(-1:0.01:15))
# plot!(-1:0.01:15, piecewise2_2D_lc.surf_grad.(-1:0.01:15))


# vis = Visualizer()
# open(vis)
# plot_surface!(vis, piecewise1_2D_lc, n = 100)
# plot_surface!(vis, piecewise2_2D_lc, n = 100)
