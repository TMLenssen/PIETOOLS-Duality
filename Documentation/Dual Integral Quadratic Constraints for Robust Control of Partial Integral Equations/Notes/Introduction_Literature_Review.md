Literature checked for the introduction revision, 16 September 2026.

The introduction follows the sequence PDE applications and robustness, direct PDE systems theory and control, ODE robust-control tools and approximation, PIE representations and nominal synthesis, PIE robustness analysis, IQC dissipativity and factorization, and the synthesis obstacle. Per the author's revised preference, it ends with the organization of the paper. Forward section references are confined to that closing paragraph.

The opening now uses foundational physical modeling works, following the author's preference for seminal PDE references rather than control-oriented application surveys:

- Fourier, [Théorie analytique de la chaleur (1822)](https://www.e-rara.ch/zut/doi/10.3931/e-rara-19706), for heat conduction.
- d'Alembert, [Recherches sur la courbe que forme une corde tenduë mise en vibration](https://webusers.imj-prg.fr/~david.aubin/cours/Textes/Dalembert-HAB-1747-cordes-vibrantes.pdf), for the vibrating-string wave equation. The bibliography follows the volume year 1747 and notes publication in 1749.
- Stokes, [On the Theories of the Internal Friction of Fluids in Motion, and of the Equilibrium and Motion of Elastic Solids](https://doi.org/10.1017/CBO9780511702242.005), for viscous fluid motion. The cited edition is the 1880 collected-paper reprint, pp. 75–129, explicitly identified as the memoir read in 1845.

Control-oriented application references checked in the preceding revision and retained in the bibliography, but no longer cited in the opening:

- Morris (2020), [Controller Design for Distributed Parameter Systems](https://link.springer.com/book/10.1007/978-3-030-34949-3). The [introductory chapter](https://link.springer.com/chapter/10.1007/978-3-030-34949-3_1) explains how spatially dependent physical quantities lead to PDE models, with thermal, structural, and fluid examples.
- Christofides (2001), [Control of nonlinear distributed process systems: Recent developments and challenges](https://doi.org/10.1002/aic.690470302). The [author-hosted paper](https://pdclab.seas.ucla.edu/Publications/PDChristofides/PDChristofides_AIChEJ_2001_47_Control_Nonlinear_Distributed_Process_Systems_Recent_Developments_and_Challenges.pdf) motivates distributed control through semiconductor processing and other chemical-engineering applications.
- Bewley (2001), [Flow control: new challenges for a new Renaissance](https://www.sciencedirect.com/science/article/abs/pii/S0376042100000166). This review connects control to fluid mechanics, including transition and turbulence regulation.

New bibliography entries:

| Key | Verified source | Role in the introduction |
| --- | --- | --- |
| doyle1989statespace | Doyle, Glover, Khargonekar, and Francis (1989), [author-hosted paper](https://www.doyle.caltech.edu/images/doyle/2/20/TAC1989.pdf), DOI 10.1109/9.29425 | Algebraic Riccati equations as a finite-dimensional route to H-infinity synthesis. |
| boyd1994lmi | Boyd, El Ghaoui, Feron, and Balakrishnan (1994), [author's book page](https://stanford.edu/~boyd/lmibook/) | LMI methods and convex optimization in systems and control. |
| morris2001hinfinityapproximation | Morris (2001), [publisher abstract](https://www.sciencedirect.com/science/article/abs/pii/S0167691101001438), DOI 10.1016/S0167-6911(01)00143-8 | Conditions for convergence of Riccati approximations and performance of finite-dimensional controllers for an infinite-dimensional plant. This supports a qualified account of approximation-based control. |
| balas1978modal | Balas (1978), [publisher article](https://epubs.siam.org/doi/10.1137/0316030) | Modal control of a lumped approximation and the effect of control spillover into neglected modes. |

Checks on the central existing references:

- [Peet's PIE representation paper](https://par.nsf.gov/servlets/purl/10285388) establishes the PI algebra and exact PDE-to-PIE conversion for its specified class. The introduction distinguishes exact plant conversion from the finite-dimensional parameterization used to search for certificates.
- [Shivakumar, Das, and Peet's nominal synthesis paper](https://arxiv.org/abs/2208.13104v4) supplies the duality and nominal state-feedback starting point. Its [institutional publication record](https://research.tue.nl/en/publications/dual-representations-and-hsubsub-optimal-control-of-partial-diffe/) confirms the 2026 journal metadata already in the bibliography.
- [Toolhally et al.'s author preprint](https://arxiv.org/abs/2511.03379) explicitly uses PIEs for the inkjet fixation-unit digital twin and reports validation using operational data from a commercial printer. The existing journal citation is retained; the application claim was checked against the preprint.
- [Das et al. (2020)](https://control.asu.edu/Publications/2020/Das_CDC_2020.pdf) treats uncertain ODE–PDE stability and performance with PI multipliers and LPIs.
- [Talitckii et al. (2023)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10387136/) develops hard IQCs with infinite-dimensional channels and a sufficient PIE KYP test.
- [Lenssen et al.'s author preprint](https://arxiv.org/html/2511.14896v1) includes robust Luenberger observer synthesis. The introduction identifies state-feedback synthesis through dual IQCs as the present target, without claiming to introduce all robust PIE synthesis.
- [Seiler (2015)](https://dept.aem.umn.edu/~SeilerControl/Papers/2015/Seiler_15TAC_StabilityAnalysisWithDIandIQCs.pdf) explains the factorization requirements for finite-horizon IQCs and nonnegative storage. The introduction qualifies the J-spectral-factorization claim accordingly.
- [Venkataraman and Seiler (2018)](https://experts.umn.edu/en/publications/convex-lpv-synthesis-of-estimators-and-feedforwards-using-duality) develops dual IQCs and convex estimator/feedforward synthesis for gridded LPV systems. It supports the immediate methodological connection.

Scope checks against the manuscript:

- Explain the two controller–certificate couplings using the ODE analysis LMI, without referring ahead to the PIE analysis equation.
- The synthesis corollary takes an admissible factorization as given. The introduction consequently states convexity for a prescribed factorization; it does not assert joint convex optimization over arbitrary dynamic multipliers and the controller.
- Dynamic-filter controllers require additional signal availability. This qualification is retained in the contribution paragraph.
