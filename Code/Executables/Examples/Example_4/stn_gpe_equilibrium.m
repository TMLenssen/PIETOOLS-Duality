function [tildeXStar,tildeZStar,tildeUStar,operatingPoints] = stn_gpe_equilibrium(diseaseLevels)
%STN_GPE_EQUILIBRIUM Equilibria of the centered STN--GPe model.
%   Each row corresponds to one entry of diseaseLevels:
%     tildeXStar(k,:) = [tilde x_S^star,tilde x_G^star]
%     tildeZStar(k,:) = [tilde z_S^star,tilde z_G^star]
%     tildeUStar(k)   = tilde u^star = 0.
%   The untilded deviation variables therefore have equilibrium x=z=u=0.

diseaseLevels = diseaseLevels(:);
tildeXStar = zeros(numel(diseaseLevels),2);
tildeZStar = zeros(numel(diseaseLevels),2);
tildeUStar = zeros(numel(diseaseLevels),1);
operatingPoints = struct([]);
initialGuess = [0;0];
options = optimset('Display','off','TolX',1e-12,'TolFun',1e-12, ...
    'MaxIter',1e4,'MaxFunEvals',1e4);

for index = 1:numel(diseaseLevels)
    Kd = diseaseLevels(index);
    weights = [19.0,1.12,6.60,2.42,15.1] ...
        +Kd*([20.0,10.7,12.3,9.20,139.4] ...
        -[19.0,1.12,6.60,2.42,15.1]);

    p.wSG = weights(1);
    p.wGS = weights(2);
    p.wGG = weights(3);
    p.wCS = weights(4);
    p.wXG = weights(5);
    p.Ctx = 27;
    p.Str = 2;
    p.MS = 300;
    p.BS = 17;
    p.MG = 400;
    p.BG = 75;

    residual = @(x) [x(1)-sigmoid( ...
        -p.wGS*x(2)+p.wCS*p.Ctx,p.MS,p.BS); ...
        x(2)-sigmoid(p.wSG*x(1)-p.wGG*x(2)-p.wXG*p.Str, ...
        p.MG,p.BG)];
    objective = @(x) sum(residual(x).^2);
    [rates,residualSquared] = fminsearch(objective,initialGuess,options);

    p.diseaseLevel = Kd;
    p.xS0 = rates(1);
    p.xG0 = rates(2);
    p.cS = (p.MS/4)*log((p.MS-p.BS)/p.BS);
    p.cG = (p.MG/4)*log((p.MG-p.BG)/p.BG);
    p.uS0 = -p.wGS*p.xG0+p.wCS*p.Ctx;
    p.uG0 = p.wSG*p.xS0-p.wGG*p.xG0-p.wXG*p.Str;
    p.tildeXSStar = p.xS0-p.MS/2;
    p.tildeXGStar = p.xG0-p.MG/2;
    p.tildeZSStar = p.uS0-p.cS;
    p.tildeZGStar = p.uG0-p.cG;
    p.tildeUStar = 0;
    p.fS0 = sigmoid(p.uS0,p.MS,p.BS);
    p.fG0 = sigmoid(p.uG0,p.MG,p.BG);
    p.slopeS = 4*(p.fS0/p.MS)*(1-p.fS0/p.MS);
    p.slopeG = 4*(p.fG0/p.MG)*(1-p.fG0/p.MG);
    p.equilibriumResidual = sqrt(residualSquared);
    if p.equilibriumResidual>1e-8
        error('Equilibrium residual %.3e at Kd=%.6g.', ...
            p.equilibriumResidual,Kd);
    end

    tildeXStar(index,:) = [p.tildeXSStar,p.tildeXGStar];
    tildeZStar(index,:) = [p.tildeZSStar,p.tildeZGStar];
    tildeUStar(index) = p.tildeUStar;
    if index==1
        operatingPoints = p;
    else
        operatingPoints(index) = p;
    end
    initialGuess = rates;
end
end

function value = sigmoid(input,maximumRate,baselineRate)
value = maximumRate./(1+exp(-4*input/maximumRate) ...
    .*((maximumRate-baselineRate)/baselineRate));
end
