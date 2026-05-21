%% 文件作者：郑志宇
% 在shooting_method中采用动态步长的表示方法
function [reStep, nextTry] = DynamicStep(IteratorStep,CurError,xT,x0,T,stepTime)
nextTry = xT/2+x0/2;
reStep = IteratorStep;
% reStep = min(T/10,...
%     max(IteratorStep*exp(-atan(log(CurError))/pi),...
%     stepTime));
% reStep = IteratorStep*0.7 + CurError*0.3;
end