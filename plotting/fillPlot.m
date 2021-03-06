function [fh] = fillPlot(datatoPlot,graybkg,xaxis,axLim,method,lineColors,lineNames)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [fh] = fillPlot(datatoPlot,graybkg,xaxis,axLim,method,lineColors,lineNames)
%
%   datatoPlot  - matrix in the form nsubjectsxntimesxnlines
%   graybks     - logical vector length xaxis/ntimes indicating where to
%               display a gray patch
%   xaxis       - vector length equal to ntimes with the units to plot
%   axlim       - axis function input
%   method      - 
%               'mean'  - lines correspond to nsubjects means + SEM
%               'median - lines correspond to nsubjects median and IQR
%   linecolor   - matrix size nlinesx3 indicating the color of the lines
%   lineNames   - that
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[nSubj,nTimes,nLines] = size(datatoPlot);

fh =figure;
fh.Position(4) = fh.Position(4)/2; 
hold on

% gray background patch
if any(graybkg)
    
    if length(graybkg)~=nTimes
        error('Graybkg lenght different to times length')
    end
    grSt    = find(diff(graybkg)==1)+1;
    grEnd   = find(diff(graybkg)==-1);
    if length(grSt)<length(grEnd)               % in case  graybkg starts or ends with a 1
        grSt = [1 grSt];
    elseif length(grSt)>length(grEnd)
        grEnd = [grEnd length(graybkg)];
    end
    patch(xaxis([grSt;grEnd;grEnd;grSt]),...
        [axLim(3);axLim(3);axLim(4);axLim(4)]*ones(1,length(grSt)),...
        [.9 .9 .9],'EdgeColor','none')
end

axis(axLim)
hl = hline(0);
hl.LineWidth = 1;
hl.Color = [0 0 0];
vl = vline(0);
vl.LineWidth = 1;
vl.Color = [0 0 0];

for ll = 1:nLines
    if strcmp(method,'mean')
        auxM    = mean(datatoPlot(:,:,ll),1);
        auxSE   = std(datatoPlot(:,:,ll),0,1)./sqrt(nSubj);
        upper   = auxM+auxSE;
        lower   = auxM-auxSE;
    elseif strcmp(method,'median')  
        auxM    = median(datatoPlot(:,:,ll),1);
        upper   = prctile(datatoPlot(:,:,ll),75);
        lower   = prctile(datatoPlot(:,:,ll),25);
    end
%     plot(xaxis,datatoPlot(:,:,ll),'Color',lineColors(ll,:),'LineWidth',.1)
    jbfill(xaxis,upper,lower ,lineColors(ll,:),lineColors(ll,:)+.1,1,.4);
    hold on
%     plot(xaxis,auxM,'Color',lineColors(ll,:),'LineWidth',2)
end
for ll = 1:nLines
     if strcmp(method,'mean')
        auxM    = mean(datatoPlot(:,:,ll),1);
     elseif strcmp(method,'median')  
        auxM    = median(datatoPlot(:,:,ll),1);
     end
    lp(ll)  = plot(xaxis,auxM,'Color',lineColors(ll,:),'LineWidth',2);
end

if ~isempty(lineNames)
    [leghandle objleg] = legend(lp,lineNames);
    leghandle = adjustLegend(leghandle,objleg,8,[.85 .8 .05 .05]);
end

