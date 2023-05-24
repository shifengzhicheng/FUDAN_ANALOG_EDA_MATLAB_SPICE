function [reStep, nextTry] = DynamicStep(IteratorStep,CurError,xT,x0,T,stepTime)
nextTry = xT;
% reStep = IteratorStep;
reStep = min(T/10,...
    max(IteratorStep*exp(-atan(log(CurError/1e-3))/pi),...
    stepTime));
% reStep = IteratorStep*0.7 + CurError*0.3;
end