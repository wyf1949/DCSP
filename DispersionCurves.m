function [Freq,Wavenumber,PhaseVelocity]=DispersionCurves(Sample,propAngle,df,nFreqs,...
    legDeg,nModes2Track,varargin)
% Calculates the dispersion curves for layered anisotropic materials using
% the Legendre and Laguerre polynomial approach
% Originally supplied by O. Bou-Matar, Lille
%
% INPUT: 
%   Sample        - Object with description of the layering and layer
%                 properties, see Sample.mat and Layer.mat for details 
%   propAngle     - Angle of wave propagation with respect to the main
%                 in-plane coordinate axis [rad]
%   df            - Frequency step in [Hz]
%   nFreqs        - Number of frequency steps
%   legDeg        - Degree of Legendre polynomial expansion - determines the maximum number of modes 3/2*legDeg
%   nModes2Track  - Number of modes to be tracked
% OPTIONAL:
%   saveOn      - Enable saving of the dispersion data
%   figOn       - Enable plotting
%   parOn       - switch on and off the paralell computing
% OUTPUT:
%   Freq        - Frequency vector in [Hz]
%   Wavenumber  - Matrix with wavenumbers corresponding to identified modes
%                 [1/m]
%   PhaseVelocity    - Matrix with phase velocities for identified modes in [m/s]

%% INPUT PARSING
numvarargs = length(varargin);
if numvarargs > 3
    error('myfuns:somefun2Alt:TooManyInputs', ...
        'requires at most 3 optional inputs');
end
optargs = {0,0,0};
optargs(1:numvarargs) = varargin;
[saveOn,figOn,parOn] = optargs{:};

%% PREPARE THE OTHER PARAMETERS
nLayers=Sample.nLayers;         % total number of layers in the sample
Nodes=ones(nLayers,1)*legDeg;   % vector with the number of nodes/order of polynomial expansion  per layer 
nNodes=3*sum(Nodes);            % total number of nodes in laminate x 3 components of displacement
nMax=3*sum(Nodes);              % max number of modes????   

%% NORMALIZATION PARAMETERS
Ca = 1e11;                      % Pa = N/m^2 normalization parameter
rhoa = 1e3;                     % kg/m^3 second normalization parameter 
dw = 2*pi*df;                   % Angular frequency step
k = zeros(nMax,nFreqs);

%% PREPARE PARTIAL MATRICES
Freq=nan(nFreqs,1);     % Initialize the frequency vector
Rho0=nan(nLayers,1);    % Density vector
F11=nan(3,3);
F12=nan(size(F11));
F22=nan(size(F11));
F33=nan(3,3,nLayers);
F31=nan(size(F11));
F32=nan(size(F11));
A1=nan(3,3,nLayers);
BB=nan(3,3,nLayers);
CC=nan(3,3,nLayers);
ABC=nan(3,3,nLayers);
A2=nan(3,3,nLayers);

%% LOAD AND STACK THE MATERIAL PROPERTIES FOR PLIES AND STROH MATRIX
for ply = 1:nLayers
    C = RotateElasticConstants(Sample.C(:,:,ply),Sample.Phi(ply),...
        Sample.Theta(ply),Sample.Psi(ply)); % stiffness tensor rotated to principal axis (of anisotropy)
    C = C./Ca;                  % normalization of stiffness tensor 
    Rho0(ply) = Sample.Rho(ply)/rhoa;  % convert kg/m^3 to g/cm^3
    F11(1,1) = C(1,1);          % F11 matrix component for building Stroh matrix
    F11(1,2) = C(1,6);
    F11(1,3) = C(1,5);
    F11(2,1) = C(1,6);
    F11(2,2) = C(6,6);
    F11(2,3) = C(5,6);
    F11(3,1) = C(1,5);
    F11(3,2) = C(5,6);
    F11(3,3) = C(5,5);

    F12(1,1) = C(1,6);
    F12(1,2) = C(1,2);
    F12(1,3) = C(1,4);
    F12(2,1) = C(6,6);
    F12(2,2) = C(2,6);
    F12(2,3) = C(4,6);
    F12(3,1) = C(5,6);
    F12(3,2) = C(2,5);
    F12(3,3) = C(4,5);

    F22(1,1) = C(6,6);
    F22(1,2) = C(2,6);
    F22(1,3) = C(4,6);
    F22(2,1) = C(2,6);
    F22(2,2) = C(2,2);
    F22(2,3) = C(2,4);
    F22(3,1) = C(4,6);
    F22(3,2) = C(2,4);
    F22(3,3) = C(4,4);

    F33(1,1,ply) = C(5,5);
    F33(1,2,ply) = C(4,5);
    F33(1,3,ply) = C(3,5);
    F33(2,1,ply) = C(4,5);
    F33(2,2,ply) = C(4,4);
    F33(2,3,ply) = C(3,4);
    F33(3,1,ply) = C(3,5);
    F33(3,2,ply) = C(3,4);
    F33(3,3,ply) = C(3,3);

    F31(1,1) = C(1,5);
    F31(1,2) = C(5,6);
    F31(1,3) = C(5,5);
    F31(2,1) = C(1,4);
    F31(2,2) = C(4,6);
    F31(2,3) = C(4,5);
    F31(3,1) = C(1,3);
    F31(3,2) = C(3,6);
    F31(3,3) = C(3,5);

    F32(1,1) = C(5,6);
    F32(1,2) = C(2,5);
    F32(1,3) = C(4,5);
    F32(2,1) = C(4,6);
    F32(2,2) = C(2,4);
    F32(2,3) = C(4,4);
    F32(3,1) = C(3,6);
    F32(3,2) = C(2,3);
    F32(3,3) = C(3,4);

    F21 = F12';
    F13 = F31';
    F23 = F32';

    A1(:,:,ply) = F11*cos(propAngle)^2+(F12+F21)*cos(propAngle)*sin(propAngle)+F22*sin(propAngle)^2;
    BB(:,:,ply) = (F13+F31)*cos(propAngle)+(F23+F32)*sin(propAngle);
    CC(:,:,ply) = -F33(:,:,ply);
    ABC(:,:,ply) = F31*cos(propAngle)+F32*sin(propAngle);
    A2(:,:,ply) = -Rho0(ply)*eye(3);
end

%% CALCULATION LOOP
if parOn == 1
  parforArg = 4;
  parfor_progress(nFreqs);
else
  parforArg = 0;
end
parfor (kk=0:nFreqs-1,parforArg)
    w = dw+dw*kk;
    Freq(kk+1) = w/(2*pi);
    ka = w*sqrt(rhoa/Ca);
    F1 = zeros(nNodes,nNodes);
    G1 = zeros(nNodes,nNodes);
    H1 = zeros(nNodes,nNodes);
    Ntemp = 1;
    for ply = 1:nLayers      % Preparation of the computational values from Legendre polynomials
        As = zeros(3*(Nodes(ply)-2),3*Nodes(ply));
        Bs = zeros(3*(Nodes(ply)-2),3*Nodes(ply));
        Cs = zeros(3*(Nodes(ply)-2),3*Nodes(ply));
        for mm=0:Nodes(ply)-3
            for nn=0:Nodes(ply)-1
                Bs(3*mm+1:3*(mm+1),3*nn+1:3*(nn+1)) = 2/Sample.H(ply)*BB(:,:,ply)/ka*PmdPn(mm,nn); 
                Cs(3*mm+1:3*(mm+1),3*nn+1:3*(nn+1)) = 4/(Sample.H(ply)^2)*CC(:,:,ply)/ka^2*Pmd2Pn(mm,nn);
                if (mm == nn)
                    As(3*mm+1:3*(mm+1),3*nn+1:3*(nn+1)) = 2*A1(:,:,ply)/(2*nn+1);
                    Cs(3*mm+1:3*(mm+1),3*nn+1:3*(nn+1)) = Cs(3*mm+1:3*(mm+1),3*nn+1:3*(nn+1))+2*A2(:,:,ply)/(2*nn+1);
                end
            end
        end          
        H1(Ntemp:Ntemp+3*(Nodes(ply)-2)-1,3*sum(Nodes(1:ply-1))+1:3*sum(Nodes(1:ply))) = As;
        F1(Ntemp:Ntemp+3*(Nodes(ply)-2)-1,3*sum(Nodes(1:ply-1))+1:3*sum(Nodes(1:ply))) = Bs;
        G1(Ntemp:Ntemp+3*(Nodes(ply)-2)-1,3*sum(Nodes(1:ply-1))+1:3*sum(Nodes(1:ply))) = Cs;
        Ntemp = Ntemp+3*(Nodes(ply)-2);
    end

    % Conditions of continuity between plies - ply and ply+1
    for ply = 1:nLayers-1
        % Continuity of displacement on the interface - ply and ply+1
        Ds = zeros(3,3*Nodes(ply+1));
        Es = zeros(3,3*Nodes(ply));
        for nn=0:Nodes(ply)-1
            Es(:,3*nn+1:3*(nn+1)) = eye(3);
        end
        for nn=0:Nodes(ply+1)-1
            Ds(:,3*nn+1:3*(nn+1)) = -(-1)^nn*eye(3);
        end

        G1(Ntemp:Ntemp+2,3*sum(Nodes(1:ply-1))+1:3*sum(Nodes(1:ply))) = Es;
        G1(Ntemp:Ntemp+2,3*sum(Nodes(1:ply))+1:3*sum(Nodes(1:ply+1))) = Ds;

        Ntemp = Ntemp+3; 

        % Continuity of normal stress on the interface - ply and ply+1
        % ii+1
        Ds = zeros(3,3*Nodes(ply));
        Es = zeros(3,3*Nodes(ply));
        Dp = zeros(3,3*Nodes(ply+1));
        Ep = zeros(3,3*Nodes(ply+1));
        for nn=0:Nodes(ply)-1
            Ds(:,3*nn+1:3*(nn+1)) = -ABC(:,:,ply);
            Es(:,3*nn+1:3*(nn+1)) = 2/Sample.H(ply)*F33(:,:,ply)/ka*nn*(nn+1)/2;
        end
        for nn=0:Nodes(ply+1)-1
            Dp(:,3*nn+1:3*(nn+1)) = ABC(:,:,ply+1)*(-1)^nn;
            Ep(:,3*nn+1:3*(nn+1)) = -2/Sample.H(ply+1)*F33(:,:,ply+1)/ka*(-1)^(nn+1)*nn*(nn+1)/2;
        end
        F1(Ntemp:Ntemp+2,3*sum(Nodes(1:ply-1))+1:3*sum(Nodes(1:ply))) = Ds;
        F1(Ntemp:Ntemp+2,3*sum(Nodes(1:ply))+1:3*sum(Nodes(1:ply+1))) = Dp;
        G1(Ntemp:Ntemp+2,3*sum(Nodes(1:ply-1))+1:3*sum(Nodes(1:ply))) = Es;
        G1(Ntemp:Ntemp+2,3*sum(Nodes(1:ply))+1:3*sum(Nodes(1:ply+1))) = Ep;

        Ntemp = Ntemp+3;            
    end

    % Boundary conditions at the lower interface
    Ds = zeros(3,3*Nodes(1));
    Es = zeros(3,3*Nodes(1));
    for nn=0:Nodes(1)-1
        Ds(:,3*nn+1:3*(nn+1)) = ABC(:,:,1)*(-1)^nn;
        Es(:,3*nn+1:3*(nn+1)) = -2/Sample.H(1)*F33(:,:,1)/ka*(-1)^(nn+1)*nn*(nn+1)/2;
    end
    F1(Ntemp:Ntemp+2,1:3*Nodes(1)) = Ds;
    G1(Ntemp:Ntemp+2,1:3*Nodes(1)) = Es;        

    Ntemp = Ntemp+3;

    % Boundary conditions at the upper interface
    Dp = zeros(3,3*Nodes(nLayers));
    Ep = zeros(3,3*Nodes(nLayers));
    for nn=0:Nodes(nLayers)-1
        Dp(:,3*nn+1:3*(nn+1)) = -ABC(:,:,nLayers);
        Ep(:,3*nn+1:3*(nn+1)) = 2/Sample.H(nLayers)*F33(:,:,nLayers)/ka*nn*(nn+1)/2;
    end
    F1(Ntemp:Ntemp+2,3*sum(Nodes(1:nLayers-1))+1:3*sum(Nodes(1:nLayers))) = Dp;
    G1(Ntemp:Ntemp+2,3*sum(Nodes(1:nLayers-1))+1:3*sum(Nodes(1:nLayers))) = Ep;

    % Calculation of the eigenvalue problem
    M1 = [F1 -eye(nNodes);-H1 zeros(nNodes)];
    M2 = [G1 zeros(nNodes);zeros(nNodes) eye(nNodes)];
    [~,K] = eig(M1,M2);        % bottleneck, calculates the mode shapes and "wavenumbers"
    kp = zeros(2*nNodes,1);
    
    % GPU version of the previous calculation of the eigenvalue problem.
    % However it does not support the generalized eigenvalue problem yet,
    % os it can't be used 
%     M1 = gpuArray([F1 -eye(nNodes);-H1 zeros(nNodes)]);
%     M2 = gpuArray([G1 zeros(nNodes);zeros(nNodes) eye(nNodes)]);
%     [~,Kgpu] = eig(M1,M2);        % bottleneck, calculates the mode shapes and "wavenumbers"
%     K=gather(Kgpu);
%     kp = zeros(2*nNodes,1);
    
    % clean-up the unreasonable wavenumbers
    for ply=1:2*nNodes
        if (K(ply,ply) == 0)
            kp(ply) = NaN;
        else
            kp(ply) = 1i/K(ply,ply)*ka;
        end
    end
    for ply=1:2*nNodes
        if (real(kp(ply)) == 0)
            kp(ply) = NaN;
        else
            if (abs(imag(kp(ply)))/abs(real(kp(ply))) > 1e-8)
                kp(ply) = NaN;        
            end
        end
    end

    [interm, ~] = sort(kp);
    k(:,kk+1) = interm(1:nMax);
    if parOn ==1
        parfor_progress;
    end    
end
if parOn ==1
    parfor_progress(0);
end

%% ADJUST THE UNITS
Wavenumber = abs(real(k))./(2*pi);
Wavenumber(Wavenumber>2500)=nan;      % Delete the insanely high wavenumbers
Wavenumber=Wavenumber(1:2:end,:);     % two subsequent modes are duplicates, so take just one of them
Wavenumber=DispersionCurveSorting(Freq,Wavenumber,nModes2Track);

%% CALCULATE THE VELOCITY
PhaseVelocity=nan(size(Wavenumber));
for mode=1:size(Wavenumber,1)
    PhaseVelocity(mode,:)=Freq'./squeeze(Wavenumber(mode,:));
end 

%% SAVING
if saveOn == 1
    save 'DispData' 'Freq' 'Wavenumber' 'PhaseVelocity' 
end

%% VISUALIZATION
if figOn == 1
    fUnits='f';
    switch fUnits
        case 'f'
            FreqPlt=Freq*1e-3; % frequency in kHz
            xLab='Frequency [kHz]';
        case 'fd'
            FreqPlt=Freq*Sample.hTot*1e-3;   % frequency-thickness product in MHz*mm
            xLab='Frequency-thickness [MHz \cdot mm]';
    end

    figure
    ax(1)=subplot(2,1,1);
    plot(FreqPlt,Wavenumber,'*','MarkerSize',2);
    p1=gca;
    p1.TickLabelInterpreter='latex';
    xlim([FreqPlt(1),FreqPlt(end)])
    ylim([0,500]);
    ylabel(strcat('Wavenumber [$$m^{-1}$$]'),'FontSize',10)

    ax(2)=subplot(2,1,2);
    hold on
    plot(FreqPlt,PhaseVelocity,'*','MarkerSize',2);
    p2=gca;
    p2.TickLabelInterpreter='latex';
    xlim([FreqPlt(1) FreqPlt(end)])
    ylim([0 1e4]);
    ylabel(strcat('Phase velocity [$$ms^{-1}$$]'),'FontSize',10)
    xlabel(xLab,'FontSize',10);
    linkaxes(ax(1:2),'x');
end