function norm_L2 = L2(X)
scalar_part = norm(double(X.P));
L2_part = vector_polynomial_L2_norm(X.Q2, X.I);
norm_L2 = sqrt(scalar_part^2 + L2_part^2);
end