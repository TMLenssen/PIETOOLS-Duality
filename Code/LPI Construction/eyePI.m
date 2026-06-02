function eyePI = eyePI(dim, vars, dom)
eyePI = mat2opvar(eye(sum(dim)), [dim,dim], vars, dom);
end