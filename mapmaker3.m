function varargout=mapmaker3(X,Y,fcn,varargin)
%MAPMAKER2 Creates a 3D map for use in 'interp2' in Matlab or 'Mathworks 3D Map' in Simulink.
%   [X,Y,Z] = MAPMAKER2(X,Y,MODELFUN,TOLERANCE,MAPSIZE) creates a 2D map
%   for use in 'interp1' in Matlab or 'Mathworks 2D Map' in Simulink by
%   minimizing the error between the map interpolation and actual function
%   output.
%   X & Y are the starting independent axes. [0 100] would create a map
%   for the range of 0 to 100. If there are known non-linearities to map
%   around you can also specify intermediate points such as [0 4 100].
%
%   MODELFUN MODELFUN is a function, specified using @ or inline function
%   that accepts 2 arguments, the initial X & Y vectors and returns the
%   corresponding Z.
%   TOLERANCE is the termination tolerance. Defaults to 1e-3.
%   MAPSIZE is the termination map size. Defaults to inf.
%
%   X independent axis of the generated map.
%   Y dependent axis of the generated map.
%   
%   [...] = MAPMAKER3(X,MODELFUN,OPTIONS) specifies control parameters
%   for the algorithm used in NLINFIT.  OPTIONS is a structure with the
%   applicable parameters.
%
%       'tol'         - When Err<Tol the estimation stops. Defaults to 1e-3.
%       'maxSize'     - Termination map size.  Defaults to inf.
%       'usePercent'  - Use percentage error instead of absolute error. 
%                       (Est-Actual)/Actual. Defaults to true.
%       'n'           - Number of points to use for the 'actual' map.
%                       Defaults to 1e4.
%       'verbose'     - Be verbose, prints intermediate calculations.
%       'plot'        - Plot the actual vs interpolated maps, point of largest error. Defaults to false.
%       'pause'       - Time to pause on each plot. Defaults to 0.1s.
%       'assignIn'    - Assign all of the intermediate variables to the
%                       parent workspace.
%       'saveDefault' - Save the default options. Save any of the above options 
%                       as future defaults so OPTIONS does not have to be 
%                       specified every time. Defaults to false.
%
%   MAPMAKER2          - Prints help and the default settings.
%   defaults=MAPMAKER2 - Returns the default settings structure. Helpful to
%                        modify 'OPTIONS' instead of creating struct from scratch.
%   
%   Examples:
%   mapmaker2([0 100],@sqrt);
%
%   mapmaker2([0 100],@sqrt,1e-5)
%
%   mapmaker2([0 100],@sqrt,[],1000)
%
%   opts=mapmaker2;
%   opts.showPlot=true;
%   opts.verbose=true;
%   opts.usePercent=false;
%   opts.tol=1e-4;
%   [X,Y]=mapmaker2([0 4 9 16 25 100],@sqrt,opts)
%
%   opts=mapmaker2;
%   opts.showPlot=true;
%   opts.plotPause=0.01;
%   opts.verbose=true;
%   opts.maxSize=inf;
%   opts.tol=1e-3;
%   opts.n=1e4;
%   [X,Y]=mapmaker2([0 100],@sqrt,opts)
%
%   % It also works with inline functions.
%   y=@(x)(sin(x.^2+5))
%   x=0:1e-5:10;
%   [X,Y]=mapmaker2([0 10],y,1e-2);
%   [X2,Y2]=mapmaker2([0 10],y,[],10);
%   [X3,Y3]=mapmaker2([0 10],y,1e-4,100);
%   plot(x,y(x),X,Y,'-*',X2,Y2,'-o',X3,Y3,'-s');
%   legend('y(x)','1e-3 Tolerance','10 points max','1e-4 Tol OR 100 points')
%
%   See also mapmaker3, interp1

% Author: Jedediah Frey
% Created: Jul 2012
% Copyright 2012

%%%%
% Settings, input parsing & other non core stuff.
%%%%

% Settings & Defaults.
optFields=  {'tol','maxSize','usePercent','n','verbose','showPlot','plotPause','assignBase','saveDefault'};
optDefaults={1e-3 , inf     , true       ,1e4,false    , false    , 0.1       , false      , false};
% Get defaults from either saved preferences (if set) or above settings.
defaults=getDefaults(optFields,optDefaults);

% If just called with no inputs.
if nargin==0
    % If the user just wants the default settings, assign them and return.
    if nargout==1
        varargout{1}=defaults;
        return;
    end
    % Print the help for the script.
    help(mfilename('fullfile'));
    % Print off 'Defaults header'
    fprintf('\nDefaults:\n');
    % For each of the available option settings.
    for i=1:numel(optFields)
        field=optFields{i};
        % If the field is a logical fprintf won't work, workaround.
        if islogical(defaults.(field))
            if defaults.(field)
                fprintf('\t%-11s - true\n',field);
            else
                fprintf('\t%-11s - false\n',field);
            end
        else
            % Else use fprintf to print the options.
            fprintf('\t%-11s - %f\n',field,defaults.(field));
        end
    end
    % Exit
    return;
end
% Check that the number of inputs and outputs is assigned correctly.
error(nargchk(1, 4, nargin, 'struct'))
error(nargchk(0, 4, nargout, 'struct'))
%
if nargin==1&&isstruct(X)
    opts=X;
    opts.saveDefault=true;
elseif nargin==2 % If exactly 2 inputs are given.
    opts.maxSize=defaults.maxSize;
    opts.tol=defaults.tol;
elseif nargin==4 % If exactly 4 inputs are given.
    % If the option is set, use it otherwise use the default settings.
    if isempty(varargin{1})
        opts.tol=defaults.tol;
    else
        opts.tol=varargin{1};
    end
    if isempty(varargin{2})
        opts.maxSize=defaults.maxSize;
    else
        opts.maxSize=varargin{2};
    end
elseif nargin==3&&~isstruct(varargin{1}) % If exactly 3 inputs are given. & it's not the structure.
    % If the option is set, use it otherwise use the default settings.
    if isempty(varargin{1})
        opts.tol=defaults.tol;
    else
        opts.tol=varargin{1};
    end
    opts.maxSize=defaults.maxSize;
else
    opts=varargin{1};
end
% For each of the option fields.
for i=1:numel(optFields)
    field=optFields{i};
    % If the field is available
    if isfield(opts,field)
        assignHere(field,opts.(field)); % Assign the setvalue to the workspace.
        opts=rmfield(opts,field); % Remove the field.
    else % If it is not available.
        assignHere(field,defaults.(field)); % Assign the default to the workspace.
    end
end
if saveDefault
    for i=1:numel(optFields)
        if strcmpi('saveDefault',optFields{i}); % Don't save the save option
            continue;
        end
        setpref(mfilename,optFields{i},eval(optFields{i}))
    end
    disp('Default options saved');
    % If only the input options were given return.
    if nargin==1
        return;
    end
end

% Throwa warning for unidentified fields in the opt settings.
unknownFields=fieldnames(opts);
for i=1:numel(unknownFields)
   warning('MAPMAKER:UNKNOWNFIELD','Unknown field ''%s''',unknownFields{i}); 
end
%%%%
% Core mapmaker processing.
%%%%
% Create the 'true' X and Y to tune the map to.
if length(X)<2
   error('Must specify at least 2 points to start with');
else
   X=reshape(X,1,length(X));
   X=unique(sort(X));
end
if n>=100
    X_interp=linspace(X(1),X(end),n);
else
    X_interp=X(1):n:X(end);
end
Y_actual=feval(fcn,X_interp);

% If the plot is enabled.
if showPlot
    f=gcf;
%     set(f,'OuterPosition',get(0,'ScreenSize')) left no room for toolbars.
    set(f,'units','normalized','outerposition',[0 .1 1 .9],'Visible','on');
    plot([0 0]);
    clf(f);
    pause(plotPause);
end
if verbose
   fprintf('%10s%10s%10s%10s%10s%10s\n','PctErr','AbsErr','Tol','MapSize','MaxSize','n'); 
end
% Calculation loop.
err=inf; % Set initial error high so the while loop enters.
while err>tol&&length(X)<maxSize
    % Calculate the map outputs at the given X positions.
    Y=feval(fcn,X);
    % Estimate what the map will look like using the near continuous function
    Y_est=interp1(X,Y,X_interp);
    % Calculate the error between the Y estimated and Y 'actual'.
    errPct=abs((Y_est-Y_actual)./Y_actual);
    errAbs=abs((Y_est-Y_actual));
    % Determine the index of the maximum error.
    if usePercent
        i=find(errPct==max(errPct));
        err=max(errPct);
    else
        i=find(errAbs==max(errAbs));
        err=max(errAbs);
    end
    % If plot is enabled.
    if showPlot
        % Show
        plot(X_interp,Y_est,'--r',X_interp,Y_actual,'b',X_interp(i),Y_actual(i),'r*',X,Y,'gp');
        legend('Interpolated Y','Actual Y','Max Error Point','Map Points');
        pause(plotPause);
    end
    if verbose
        fprintf('%10.5g%10.5g%10.5g%10d%10d%10g\n',max(errPct),max(errAbs),tol,size(X,2),maxSize,n);
    end
    % For each of the max error points (since there can be more than 1)
    X=[X X_interp(i)];
    % Sort X and only grab unique points.
    X=unique(sort(X));
end
% Evaluate Y at the current X axis points.
Y=feval(fcn,X);
if nargout==2
    varargout{1}=X;
    varargout{2}=Y;
else
    X=reshape(X,length(X),1);
    Y=reshape(Y,length(Y),1);
    varargout{1}=[X Y];
end

if assignBase
    vars=who;
    for i=1:numel(vars);
        assignin('base',vars{i},eval(vars{i}));
    end
end

% Gets the preferences for the current mfile or sets the option based on
% defaults.
function defaults=getDefaults(fields,default)
GROUP=mfilename; % Use the mfilename as the preference group.
if numel(fields)~=numel(default)
   error('Number of fields and number of default settings does not match. Cannot proceed'); 
end
for i=1:numel(fields)
    field=fields{i};
    if ispref(GROUP,field)
        defaults.(field)=getpref(GROUP,field);
    else
        defaults.(field)=default{i};
    end
end

% Assign value where called. Easier than doing an 'eval([])' etc.
function assignHere(name,V)
assignin('caller',name,V);



























nLimit=1e4; % Most amount of points to interpolate to.
n=1e1; % Number of datapoints to use to interpolate to.
firstPass=true;
if usePercent
    title('Percent Error');
else
    title('Absolute Error');
end

while n<nLimit % Speeds up 3D stuff to converge on a set of maps faster
    if length(X)==2||~firstPass
        X_interp=linspace(X(1),X(end),n);
    elseif length(X)==4 % To flat map the front and end of the map.
        X_interp=[X(1) linspace(X(2),X(end-1),n-2) X(end)];
    else
        error('Don''t know how to handle this one. Look at the source code');
    end
    if length(Y)==2||~firstPass
        Y_interp=linspace(Y(1),Y(end),n);
    elseif length(X)==4 % To flat map the front and end of the map.
        Y_interp=[Y(1) linspace(Y(2),Y(end-1),n-2) Y(end)];
    else
        error('Don''t know how to handle this one. Look at the source code');
    end
    [X_interpM,Y_interpM]=meshgrid(X_interp,Y_interp);
    err=inf;
    while max(max(err))>tol&&length(X)<maxMapSize;
        Z_actual=feval(fcn,X_interp,Y_interp);
        Z=feval(fcn,X,Y);
        [X_tmp,Y_tmp]=meshgrid(X,Y);
        Z_est=interp2(X_tmp,Y_tmp,Z,X_interpM,Y_interpM);
        if usePercent % Use Percent Error
            err=abs((Z_est-Z_actual)./Z_actual);
            err2=abs((Z_est-Z_actual));
        else % Use Actual Error
            err2=abs((Z_est-Z_actual)./Z_actual);
            err=abs((Z_est-Z_actual));
        end
        hold off;
        clear C;
        C(:,:,1)=zeros(size(Z_actual));
        C(:,:,2)=.5*ones(size(Z_actual));
        C(:,:,3)=zeros(size(Z_actual));
        subplot(211);
        surf(X_interp,Y_interp,Z_actual,C);
        hold all;
        clear C;
        C(:,:,1)=ones(size(Z));
        C(:,:,2)=zeros(size(Z));
        C(:,:,3)=zeros(size(Z));
        surf(X,Y,Z,C);
        subplot(211);
        surf(X_interp,Y_interp,err);
        pause(0.1);
        i=find(max(err,[],1)==max(max(err)));
        for k=1:length(i)
            if ~any(X_interp(i(k))==X)
                X=[X X_interp(i(k))];
            end
        end
        i=find(max(err,[],2)==max(max(err)));
        for k=1:length(i)
            if ~any(Y_interp(i(k))==Y)
                Y=[Y Y_interp(i(k))];
            end
        end
        X=sort(X);
        Y=sort(Y);
        fprintf('%1d%2d %10.5f %10.5f %10.5f %4d %4d %4d %4d\n',max(max(err))>tol,length(X)<maxMapSize,max(max(err)),max(max(err2)),tol,size(X,2),maxMapSize,n,nLimit);
    end
    if length(X)>=length(X_interp)
        n=n*2;
        firstPass=false;
    else
        n=inf;
    end
end
vars=who;
for i=1:numel(vars);
    assignin('base',vars{i},eval(vars{i}));
end