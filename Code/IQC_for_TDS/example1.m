clc; clear;
% % using 2d PDE in PIETOOLS_PDE_Ex_Heat_Eq_w_Interior_Delay(GUI,params)  % % 
% %---------------------------------------------------------------------% %
% % Diffusive Equation with Delay in Dynamics (Caliskan 2009):
% For c = 1, a0 = 1.9, and a1 = 1, stable for tau<1.0347.
% % PDE         x_{t}  = c*x_{s1s1}(t,s1) + a0*x(t,s1) - a1*x(t-tau,s1);    s1 in [0,pi]   
% % With BCs    x(t,s1=0) = 0;   
% %             x(t,s1=pi) = 0;

% % Feedback Interconnection % %
% % Diffusive Equation with Delay in Dynamics (Caliskan 2009):
% % NOMINAL PDE         x_{t}  = c*x_{s1s1}(t,s1) + a0*x(t,s1) - a1*x(t,s1) + a1*u(t, s);    s1 in [0,pi]   
% % With BCs    x(t,s1=0) = 0, x(t,s1=pi) = 0;
% %
% % Uncertainty u(t, s) = (x(t,s1) - x(t-tau,s1))


pvar s
c = 1;      a0 = 1.9;       a1 = 1;
ne = 1;     tau = 1; 
a = 0;      b = pi;


x = pde_var(s,[a,b]);
y = pde_var('output',1,s,[a,b]);
u = pde_var('input',1,s,[a,b]);
PDE_t = [diff(x,'t')==c*diff(x,s,2)+a0*x-a1*x + a1*u; 
         subs(x,s,a)==0;     subs(x,s,b)==0; y==x];

PIE = convert(PDE_t, 'pie');
% % IQC % %
% For finite-dimesnional case (See https://arxiv.org/pdf/1504.02502)
% or (Stability analysis of systems with uncertain time-varying delays, Kao Rantzer)
% 
% Pi(s) = [|Psi(s)|^2 0
%            0       -1]
% system has a representation 
% Psi(s) = (4s^2 + 14s+0.02)/(s^2 + 4.5s+7.1)
% it can be shown that |Psi(s)|>|e^{-s} - 1| (using bodeplot)
% and

% work with very heavy settings
z = 2*[2.0000   7.0000   0.0100];
p = [1.0000    4.5000    7.1000];
opts = lpisettings('veryheavy');



% P. Seiler option
% work with heavy settings
% z = 2*[1.0000   3.5000   1.e-6];
% p = [1.0000    4.5000    7.1000];
% opts = lpisettings('heavy');

% z = z + 0.001*p; 

T = mat2opvar(eye(2), [0 0; 2 2], PIE.vars, PIE.dom);
[Am, Bm, Cm, Dm] = tf2ss(z, p);% state space representation

% % % inverse of Psi
% Tinv = T;
% [Ainv, Binv, Cinv, Dinv] = tf2ss(p, z);% state space representation of Psi^{-1}

A = mat2opvar(Am, [0 0; 2 2], PIE.vars, PIE.dom);
B = mat2opvar(Bm, [0 0; 2 1], PIE.vars, PIE.dom);
C = mat2opvar(Cm, [0 0; 1 2], PIE.vars, PIE.dom);
D = mat2opvar(Dm, [0 0; 1 1], PIE.vars, PIE.dom);


% IQC has the form 
% % % % (||Psi v||^2 - ||Delta v||^2) >=0 
% or the multiplier is given by
% [Psi^* 0] [1  0] [Psi 0]
% [0     I] [0 -1] [0   I]
%
% [Psi 0] [G] = [Psi G]
% [0   I] [I]   [ I   ]  => ||Psi G|| < 1 
%
% [Psi G; I] has a state-space representation
op0 = mat2opvar([0,0], [0,0; 1, 2], PIE.vars, PIE.dom); 
op02 = mat2opvar([0,0,0], [0,0; 1, 3], PIE.vars, PIE.dom); 
op1 = mat2opvar([1], [0,0; 1, 1], PIE.vars, PIE.dom); 
T_psiG = blkdiag(PIE.T, T);
A_psiG = [PIE.A, op0 ; 
          B*PIE.C1, A];
B_psiG = [PIE.B1; B*PIE.D11];
C_psiG = [D*PIE.C1, C; op02];
D_psiG = [D*PIE.D11; op1];

% % % % % % Settings % % % % % %

prog = lpiprogram(PIE.vars(:, 1), PIE.vars(:, 2), PIE.dom);

% Define P operator
[prog, P1op] = poslpivar(prog, [T_psiG.dim(1,1), T_psiG.dim(2,2)],opts.dd2);
[prog, P2op] = poslpivar(prog, [T_psiG.dim(1,1), T_psiG.dim(2,2)],opts.dd1, opts.options3);
Pop = P1op + P2op;


% Also declare an indefinite operator Qop=Pop*T so that Pop = Top'*Qop. 
Qdeg = get_lpivar_degs(Pop,T_psiG);
[prog, Qop] = lpivar(prog, T_psiG.dim,Qdeg);
prog = lpi_eq(prog, T_psiG'*Qop - Pop); % Equality T_psiG' Q = P 


% % % % % % KYP LEMMA % % % % % % % %
Kop = mat2opvar([1 0; 0 -1], [0 0; 2 2], PIE.vars, PIE.dom);

Dop = [A_psiG'*Qop + Qop' * A_psiG,   Qop' * B_psiG;
       B_psiG' * Qop          ,    1.e-6*op1 ];


Mop  = [C_psiG  D_psiG ]' * Kop * [ C_psiG   D_psiG ];


DDop = Dop + Mop;

options.psatz = 1;
% prog = lpi_ineq(prog, -DDop, options );   
d2 = degbalance(DDop);
% d2{2} = d2{2}/2;
% d2{3} = d2{3}/2;2
[prog, Deop] = poslpivar(prog, [DDop.dim(1,1) , DDop.dim(2,2)], opts.dd2);
options3.psatz=1;
[prog, De2op] = poslpivar(prog, [DDop.dim(1,1) ,DDop.dim(2,2)], opts.dd1, opts.options3);

prog = lpi_eq(prog,Deop + De2op + DDop ); % DDop <=0
sos_options.solver = 'mosek'; 
prog = sossolve(prog, sos_options); 

% @article{CALISKAN2009,
% title = {Stability Analysis of the Heat Equation with Time-Delayed Feedback},
% journal = {IFAC Proceedings Volumes},
% volume = {42},
% number = {6},
% pages = {220-224},
% year = {2009},
% note = {6th IFAC Symposium on Robust Control Design},
% issn = {1474-6670},
% doi = {https://doi.org/10.3182/20090616-3-IL-2002.00038},
% url = {https://www.sciencedirect.com/science/article/pii/S1474667015404057},
% author = {Sina Yamaç çalişkan and Hitay özbay},
% }