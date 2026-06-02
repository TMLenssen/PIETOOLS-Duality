function norm_L2 = vector_polynomial_L2_norm(polynomial_vec, dom)
    norm_L2 = 0;
    for i = 1:length(polynomial_vec)
        polynomial = polynomial_vec(i);  % Access polynomial by index
        coeffs = polynomial.coefficient;
        deg = polynomial.degmat;
        
        if isempty(deg)
            % Handle constant polynomial (L2 norm for constant c over domain [a,b] is sqrt(c^2 * (b - a)))
            norm_L2 = norm_L2 + abs(coeffs) * (dom(2) - dom(1));  
        else
            % Define the polynomial function p(x)
            p = @(x) sum(coeffs .* x.^deg);
            % Define the integrand function (p(x))^2
            integrand = @(x) (p(x)).^2;
            % Compute the integral over the domain
            integral_value = integral(integrand, dom(1), dom(2));
            % Add the square root of the integral to the norm
            norm_L2 = norm_L2 + sqrt(integral_value);
        end
    end
end