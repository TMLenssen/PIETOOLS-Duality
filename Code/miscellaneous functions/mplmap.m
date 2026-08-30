function cmap = mplmap(name,n)
%MPLMAP Matplotlib-style colormaps for MATLAB.
%   cmap = mplmap(name,n)
%   Example: colormap(mplmap('Spectral_r',256))

if nargin < 2, n = 256; end
if ~isscalar(n) || n < 1 || n ~= round(n)
    error('n must be a positive integer.');
end

key = lower(strrep(name,'-','_'));

switch key
    case 'viridis'
        rgb=[68 1 84;72 40 120;62 74 137;49 104 142;38 130 142;31 158 137;53 183 121;110 206 88;181 222 43;253 231 37];
    case 'plasma'
        rgb=[13 8 135;65 4 157;106 0 168;141 8 165;174 28 158;203 55 138;229 81 112;248 149 64;253 195 40;240 249 33];
    case 'inferno'
        rgb=[0 0 4;31 12 72;85 15 109;136 34 106;186 54 85;227 89 51;249 140 10;252 195 39;252 255 164];
    case 'magma'
        rgb=[0 0 4;28 16 68;79 18 123;129 37 129;181 54 122;229 80 100;251 135 97;254 194 135;252 253 191];
    case 'cividis'
        rgb=[0 32 76;0 48 103;35 73 115;73 96 115;109 117 110;143 137 101;178 158 88;212 178 72;246 199 61;255 233 69];
    case {'spectral','spectral_r'}
        rgb=[158 1 66;213 62 79;244 109 67;253 174 97;254 224 139;255 255 191;230 245 152;171 221 164;102 194 165;50 136 189;94 79 162];
        if endsWith(key,'_r'), rgb=flipud(rgb); end
    case {'rdbu','rdbu_r'}
        rgb=[103 0 31;178 24 43;214 96 77;244 165 130;253 219 199;247 247 247;209 229 240;146 197 222;67 147 195;33 102 172;5 48 97];
        if endsWith(key,'_r'), rgb=flipud(rgb); end
    case {'rdylbu','rdylbu_r'}
        rgb=[165 0 38;215 48 39;244 109 67;253 174 97;254 224 144;255 255 191;224 243 248;171 217 233;116 173 209;69 117 180;49 54 149];
        if endsWith(key,'_r'), rgb=flipud(rgb); end
    case 'coolwarm'
        rgb=[59 76 192;98 130 234;141 176 254;184 208 249;221 221 221;244 183 165;239 138 98;210 70 60;180 4 38];
    case 'twilight'
        rgb=[226 217 226;170 191 224;103 126 187;53 73 143;48 39 113;92 49 120;157 71 104;205 119 111;226 178 155;226 217 226];
    case 'twilight_shifted'
        rgb=[226 217 226;226 178 155;205 119 111;157 71 104;92 49 120;48 39 113;53 73 143;103 126 187;170 191 224;226 217 226];
    case 'turbo'
        cmap=turbo(n); return
    otherwise
        error('Unknown colormap "%s".',name);
end

cmap=interp1(linspace(0,1,size(rgb,1)),rgb/255,linspace(0,1,n),'pchip');
cmap=max(0,min(1,cmap));
end
