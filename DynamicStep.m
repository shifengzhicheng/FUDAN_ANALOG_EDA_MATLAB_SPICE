function [reStep, nextTry] = DynamicStep(IteratorStep,CurError,xT,x0)
nextTry = xT;
% reStep = IteratorStep*(1+log10(CurError/1e-6));
reStep = IteratorStep*0.7 + CurError*0.3;
end