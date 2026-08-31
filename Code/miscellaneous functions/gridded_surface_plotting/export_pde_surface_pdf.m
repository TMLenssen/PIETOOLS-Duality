function export_pde_surface_pdf(fig,fileName,settings)
%EXPORT_PDE_SURFACE_PDF Export the complete figure as one rasterized PDF.

if nargin < 3
    settings = struct;
end
settings = default_surface_plot_settings(settings);

resolution = settings.resolution;
if ~isscalar(resolution) || ~isnumeric(resolution) || ...
        ~isfinite(resolution) || resolution <= 0
    error('resolution must be a positive finite scalar.');
end
resolution = round(resolution);

padding = settings.layoutPadding;
if ~isscalar(padding) || ~isnumeric(padding) || ...
        ~isfinite(padding) || padding < 0
    error('layoutPadding must be a nonnegative finite scalar.');
end

outDir = fileparts(fileName);
if isempty(outDir)
    outDir = pwd;
end
prefix = tempname(outDir);
previewPng = [prefix,'_bounds.png'];
rawPng = [prefix,'_raw.png'];
croppedPng = [prefix,'.png'];
texFile = [prefix,'_compose.tex'];
pdfFile = [prefix,'_compose.pdf'];
auxFile = [prefix,'_compose.aux'];
logFile = [prefix,'_compose.log'];
cleanup = onCleanup(@()delete_temp_files(previewPng,rawPng,croppedPng, ...
    texFile,pdfFile,auxFile,logFile));

oldUnits = fig.Units;
fig.Units = 'inches';
figureSize = fig.Position(3:4);
fig.Units = oldUnits;
fig.Color = settings.figureBackground;
set(fig,'PaperUnits','inches','PaperPosition',[0 0 figureSize], ...
    'PaperSize',figureSize,'PaperPositionMode','manual');

% Render the complete figure in both passes. The small preview determines
% the content bounds; the final PNG contains every object at full quality.
drawnow;
previewResolution = 180;
print(fig,previewPng,'-dpng',sprintf('-r%d',previewResolution),'-opengl');
trim = rendered_content_trim(previewPng,settings.figureBackground, ...
    padding,figureSize);
print(fig,rawPng,'-dpng',sprintf('-r%d',resolution),'-opengl');

raster = imread(rawPng);
raster = crop_raster_to_trim(raster,figureSize,trim);
imwrite(raster,croppedPng,'png');
clear raster

compose_raster_pdf(croppedPng,texFile,pdfFile,fileName,figureSize,trim);
clear cleanup
end

function trim = rendered_content_trim(fileName,background,padding,figureSize)
imageData = imread(fileName);
if size(imageData,3) < 3
    imageData = repmat(imageData,1,1,3);
else
    imageData = imageData(:,:,1:3);
end
background = 255*reshape(validatecolor(background,'one'),1,1,3);
difference = max(abs(double(imageData)-background),[],3);
mask = difference > 2;
if ~any(mask,'all')
    trim = [0 0 0 0];
    return
end

[rows,columns] = find(mask);
[height,width,~] = size(imageData);
horizontalPadding = ceil(padding/figureSize(1)*width);
verticalPadding = ceil(padding/figureSize(2)*height);
leftPixel = max(1,floor(min(columns)-horizontalPadding));
rightPixel = min(width,ceil(max(columns)+horizontalPadding));
topPixel = max(1,floor(min(rows)-verticalPadding));
bottomPixel = min(height,ceil(max(rows)+verticalPadding));
trim = [(leftPixel-1)/width*figureSize(1), ...
    (height-bottomPixel)/height*figureSize(2), ...
    (width-rightPixel)/width*figureSize(1), ...
    (topPixel-1)/height*figureSize(2)];
end

function raster = crop_raster_to_trim(raster,figureSize,trim)
[height,width,~] = size(raster);
left = max(0,min(width-1,round(trim(1)/figureSize(1)*width)));
bottom = max(0,min(height-1,round(trim(2)/figureSize(2)*height)));
right = max(0,min(width-left-1,round(trim(3)/figureSize(1)*width)));
top = max(0,min(height-bottom-1,round(trim(4)/figureSize(2)*height)));
raster = raster(top+1:height-bottom,left+1:width-right,:);
end

function compose_raster_pdf(rasterFile,texFile,composedPdf,fileName, ...
    figureSize,trim)
rasterFile = strrep(rasterFile,'\','/');
croppedSize = figureSize-[trim(1)+trim(3),trim(2)+trim(4)];
if any(croppedSize <= 0)
    error('The computed content crop has nonpositive dimensions.');
end

fid = fopen(texFile,'w');
if fid < 0
    error('Unable to create temporary PDF composition file: %s',texFile);
end
closeFile = onCleanup(@()fclose(fid));
fprintf(fid,'\\documentclass[border=0pt]{standalone}\n');
fprintf(fid,'\\usepackage{graphicx}\n');
fprintf(fid,'\\begin{document}\n');
fprintf(fid,['\\includegraphics[width=%.12gin,height=%.12gin]', ...
    '{\\detokenize{%s}}\n'],croppedSize(1),croppedSize(2),rasterFile);
fprintf(fid,'\\end{document}\n');
clear closeFile

[texDir,~] = fileparts(texFile);
texCommandDir = strrep(texDir,'\','/');
texCommandFile = strrep(texFile,'\','/');
command = sprintf(['pdflatex -interaction=nonstopmode -halt-on-error ', ...
    '-output-directory="%s" "%s"'],texCommandDir,texCommandFile);
[status,output] = system(command);
if status ~= 0 || ~isfile(composedPdf)
    error('Raster PDF composition failed:\n%s',output);
end
[moved,message] = movefile(composedPdf,fileName,'f');
if ~moved
    error('Unable to write PDF %s: %s',fileName,message);
end
end

function delete_temp_files(varargin)
for k = 1:nargin
    if isfile(varargin{k})
        delete(varargin{k});
    end
end
end
