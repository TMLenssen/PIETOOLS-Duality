function zero = zerosPI(dim_out,dim_in, vars, dom)
zero = mat2opvar(zeros(sum(dim_out), sum(dim_in)), [dim_out,dim_in], vars, dom);
end