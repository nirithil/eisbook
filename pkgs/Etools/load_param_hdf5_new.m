function [Time,locn,par2D,par1D,rpar2D,err2D,errs2d]=load_param_hdf5_new(hdf5file,pars1d,pars2d,do_rpar)
% %Function to read the plasma parameters from hdf5 files
% [Time,locn,par2D,par1D,rpar2D,err2D]=load_param_hdf5_new(hdf5file,pars1d,pars2d,do_rpar)
% locn: [lat,lon, alt] of receiver site
% par2D: [Ran,Alt,Ne,Te,Ti,Vi,Coll,Comp,Res]
% par1D: [Az,El,Pt,Tsys]
% rpar2D: [ppRan,ppAlt,ppNe]
% err2d_id  = {'var_Ne' 'var_Tr' 'var_Ti' 'var_Vi' 'var_Collf'};
%   Note 1: 'Tr' as input will generate 'Te'. In this case 'Ti' is needed as input as well.
%   Note 2: 'Te' will generate NaN...
% Input:
%   pars1d  = names of parameters wanted in par1D
%   pars2d  = names of parameters wanted in par2D
%   do_rpar = true/false (extract pp-data or not)
%   errs2d  = generated in function: those parameters in pars2d with corresponding variances in the
%     HDF5 file will be
% Default (load_param_hdf5(hdf5file)) sets
%   pars1d  = {'az' 'el' 'Pt' 'Tsys'};
%   par2d_id  = {'range' 'h' 'Ne' 'Tr' 'Ti' 'Vi' 'Collf' 'po+' 'res'};
%   do_rpars = true
%   errs2d_id  = {'var_Ne' 'var_Tr' 'var_Ti' 'var_Vi' 'var_Collf'}

global name_ant name_expr r_RECloc path_GUP
Time=[]; par2d=[]; par1D=[]; rpar2d=[]; err2d=[];

filename = hdf5file;
[~,b] = fileparts(filename);
a = strfind(b,'@');
name_ant = b(a+1:end);

inform  = h5info(filename,'/metadata');
metavar = {inform.Datasets.Name}';
if ~isempty(find(strcmp(metavar,'names')))
    namesdata = h5read(filename,'/metadata/names');
    nnexpr = find(strcmp(deblank(namesdata(1,:)),'name_expr'));
    name_expr = deblank(namesdata{2,nnexpr});
end

if nargin == 1
    do_rpar = true;
    pars1d  = {'az' 'el' 'Pt' 'Tsys'};
    errs1d  = {''};
    pars2d  = {'range' 'h' 'Ne' 'Te' 'Ti' 'Vi' 'Collf' 'po+' 'res'};
    errs2d  = {'var_Ne' 'var_Te' 'var_Ti' 'var_Vi' 'var_Collf'};
    rpars2d = {'pprange' 'pprange' 'pp'};                            % pprange dublicate: one is to be changed to alt    
    rpars2d_for_merging  = {'pprange' 'pp' 'pperr' 'ppw'};
    Te_id  = 94;
    dTe_id = 95;
else
    if nargin<4, do_rpar = false; end
    if nargin<3, pars2d = {''}; end
    GuisdapParFile = fullfile(path_GUP,'matfiles','Guisdap_Parameters.xlsx'); % path to the .xlsx file
    [~,text] = xlsread(GuisdapParFile);
    parameters_list = text(:,1);    % list that includes all parameters and keep their positions from the excel arc 
    errs2d = {''};
    err2dind = 0;
    for jj = pars2d
        rowno = find(strcmp(parameters_list,['var_' char(jj)]));
        if ~isempty(rowno)
            err2dind = err2dind + 1;
            errs2d(err2dind) = parameters_list(rowno);
        end
    end
    errs1d = {''};
    err1dind = 0;
    for jj = pars1d
        rowno = find(strcmp(parameters_list,['var_' char(jj)]));
        if ~isempty(rowno)
            err1dind = err1dind + 1;
            errs1d(err1dind) = parameters_list(rowno);
        end
    end
end

if ~isempty(find(strcmp(metavar,'utime_pp')))
    do_rpar = false;
    warning(['pp data ignored since time_pp is different than time'])
end

if do_rpar
    rpars2d = {'pprange' 'pprange' 'pp'};                            % pprange dublicate: one is to be changed to alt    
    rpars2d_for_merging  = {'pprange' 'pp' 'pperr' 'ppw'};
end

matdata.metadata.par0d    = deblank(h5read(filename,'/metadata/par0d'));
matdata.data.par0d        = h5read(filename,'/data/par0d');
matdata.metadata.par1d    = deblank(h5read(filename,'/metadata/par1d'));
matdata.data.par1d        = h5read(filename,'/data/par1d');
matdata.metadata.utime    = deblank(h5read(filename,'/metadata/utime'));
matdata.data.utime        = h5read(filename,'/data/utime');

% Time
tcolumn1 = find(strcmp(matdata.metadata.utime(1,:),'time1')); 
tcolumn2 = find(strcmp(matdata.metadata.utime(1,:),'time2')); 
Time = datenum(datetime(matdata.data.utime(:,[tcolumn1 tcolumn2]),'ConvertFrom','posixtime'));



% Receiver location
rcolumn1 = find(strcmp(matdata.metadata.par0d(1,:),'RECloc1'));
rcolumn2 = find(strcmp(matdata.metadata.par0d(1,:),'RECloc2'));
rcolumn3 = find(strcmp(matdata.metadata.par0d(1,:),'RECloc3'));
r_RECloc = matdata.data.par0d([rcolumn1 rcolumn2 rcolumn3]);
locn=r_RECloc ;

ii2d = 0;
if ~isempty(find(strcmp(metavar,'par2d')))
    ii2d = 1;
    matdata.metadata.par2d    = deblank(h5read(filename,'/metadata/par2d'));
    matdata.data.par2d        = h5read(filename,'/data/par2d');
    column = find(strcmp(matdata.metadata.par2d(1,:),'Ne'));
    if isempty(column), column = find(strcmp(matdata.metadata.par2d(1,:),'h')); end
    if isempty(column), column = find(strcmp(matdata.metadata.par2d(1,:),'range')); end
    ndata2d =  length(matdata.data.par2d(:,column));
end

if do_rpar
    if ~isempty(find(strcmp(metavar,'par2d_pp')))
        matdata.metadata.par2d_pp = deblank(h5read(filename,'/metadata/par2d_pp'));
        matdata.data.par2d_pp     = h5read(filename,'/data/par2d_pp');
    else
        do_rpar = false;
        warning(['There is no par2d_pp data in the input HDF5-file'])
    end
end


% nh (number of altitude intervals for each record)
column = find(strcmp(matdata.metadata.par1d(1,:),'nrec'));
if isempty(column)
    column = find(strcmp(matdata.metadata.par0d(1,:),'nrec'));
    nh = matdata.data.par0d(column);
    nh = nh*ones(size(Time,1),1);
else
    nh = matdata.data.par1d(:,column);
end

nh_alt = max(nh);
n_tot  = size(Time,1);    % number of records

if ii2d    
    for ii = pars2d
        column = find(strcmp(matdata.metadata.par2d(1,:),ii));
        if isempty(column) && strcmp(ii,'h')                                        % if alt is empty, it is in par1d
            column = find(strcmp(matdata.metadata.par1d(1,:),ii));
            alt = matdata.data.par1d(:,column);                                
            par_tmp = kron(alt,ones(nh_alt,1));                                     % alt = [a s d f g h...] --> alt = [a a... s s... d d... f f... g g... h h...] (for nh_alt =2)
        elseif isempty(column) && strcmp(ii,'range')                                % if range is empty, it is in par1d
            column = find(strcmp(matdata.metadata.par1d(1,:),ii));
            range = matdata.data.par1d(:,column);                              
            par_tmp = kron(range,ones(nh_alt,1));                                   % range = [a s d f g h...] --> range = [a a... s s... d d... f f... g g... h h...] (for nh_alt =2)
        elseif strcmp(ii,'Te') && isempty(column) 
            Tr2Te_2d = 1;
            column = find(strcmp(matdata.metadata.par2d(1,:),'Tr'));
            if isempty(column)
                par_tmp = NaN(ndata2d,1);
            else 
                par_tmp = matdata.data.par2d(:,column);
            end
        elseif strcmp(ii,'res') && isempty(column) 
            column = find(strcmp(matdata.metadata.par2d(1,:),'res1'));
            if isempty(column)
                par_tmp = NaN(ndata2d,1);
            else
                par_tmp = matdata.data.par2d(:,column);
            end
        elseif isempty(column)
            column = find(strcmp(matdata.metadata.par1d(1,:),ii));
            if isempty(column)
                column = find(strcmp(matdata.metadata.par0d(1,:),ii));
                if isempty(column)
                    par_tmp = NaN(ndata2d,1);
                else
                    par_tmp = matdata.data.par0d(column)*ones(ndata2d,1);
                end
            else
                par_tmp = [];
                for ii = 1:n_tot
                    par_tmp = [par_tmp; matdata.data.par1d(ii,column)*ones(nh(ii),1)];
                end
            end            
        else
            par_tmp = matdata.data.par2d(:,column);
        end
        par2d = [par2d par_tmp];
        par_tmp = [];
    end 
    for ii = errs2d
        column = find(strcmp(matdata.metadata.par2d(1,:),ii));
        if strcmp(ii,'var_Te') && exist('Tr2Te')
            column = find(strcmp(matdata.metadata.par2d(1,:),'var_Tr'));
            if isempty(column)
                par_tmp = NaN(ndata2d,1);
            else 
                par_tmp = matdata.data.par2d(:,column);
            end
        elseif isempty(column)
            par_tmp = NaN(ndata2d,1);
        else
            par_tmp = sqrt(matdata.data.par2d(:,column));    % var --> error
        end
        err2d = [err2d par_tmp];
        par_tmp = [];
    end   
    
else
    %No 2d-data in hdf5-file, but 1d (or 0d) data put into par2D anyway.')
    for ii = pars2d
        column = find(strcmp(matdata.metadata.par1d(1,:),ii));
        if isempty(column) && strcmp(ii,'h')                                        % if alt is empty, it is in par1d
            column = find(strcmp(matdata.metadata.par0d(1,:),ii));
            alt = matdata.data.par0d(column);                                
            par_tmp = alt*ones(n_tot,1);                                              % alt = [a] (0d) --> alt = [a a a ...] (1d)
        elseif isempty(column) && strcmp(ii,'range')                                % if range is empty, it is in par1d
            column = find(strcmp(matdata.metadata.par0d(1,:),ii));
            range = matdata.data.par0d(column);                              
            par_tmp = range*ones(n_tot,1);                                            % range = [a] (0d) --> range = [a a a ... ] (1d)
        elseif strcmp(ii,'Te') && isempty(column) 
            Tr2Te_2d = 1;
            column = find(strcmp(matdata.metadata.par1d(1,:),'Tr'));
            if isempty(column)
                par_tmp = NaN(n_tot,1);
            else 
                par_tmp = matdata.data.par1d(:,column);
            end
        elseif isempty(column) && strcmp(ii,'res')
            column = find(strcmp(matdata.metadata.par1d(1,:),'res1'));
            par_tmp = matdata.data.par1d(:,column);
        elseif isempty(column)
            column = find(strcmp(matdata.metadata.par0d(1,:),ii));
            if isempty(column)
                par_tmp = NaN(n_tot,1);
            else
                par_tmp = matdata.data.par0d(column)*ones(n_tot,1);
            end            
        else
            par_tmp = matdata.data.par1d(:,column);
        end
        par2d = [par2d par_tmp];
        par_tmp = [];
    end
    for ii = errs2d
        column = find(strcmp(matdata.metadata.par1d(1,:),ii));
        if strcmp(ii,'var_Tr') && exist('Tr2Te')
            column = find(strcmp(matdata.metadata.par2d(1,:),'var_Tr'));
            if isempty(column)
                par_tmp = NaN(n_tot,1);
            else 
                par_tmp = matdata.data.par1d(:,column);
            end
        elseif isempty(column)
            par_tmp = NaN(n_tot,1);
        else
            par_tmp = sqrt(matdata.data.par1d(:,column));    % var --> error
        end
        err2d = [err2d par_tmp];
        par_tmp = [];
    end   
end

% 2d: Cast azimuth and elevation into range 0-360 and 0-90 degrees
% respectively:
elno2d = find(strcmp(pars2d,'el'));
azno2d = find(strcmp(pars2d,'az'));
if elno2d
    d=find(par2d(:,elno2d)>90);
    par2d(d,elno2d)=180-par2d(d,elno2d);
    if azno2d
        par2d(d,azno2d)=par2d(d,azno2d)+180;       
    end
end
if azno2d
    par2d(:,azno2d)=mod(par2d(:,azno2d)+360,360);
end

for ii = pars1d
    if strcmp(ii,'Tsys')
        column = find(contains(matdata.metadata.par1d(1,:),'Tsys'));  % check for Tsys or (Tsys1, Tsys2 ...)
    elseif strcmp(ii,'Te ') && isempty(column)
        Tr2Te_1d = 1;
        column = find(contains(matdata.metadata.par1d(1,:),'Tr'));
    else
        column = find(strcmp(matdata.metadata.par1d(1,:),ii));
    end
    if isempty(column)
        if strcmp(ii,'Tsys')
            column = find(contains(matdata.metadata.par0d(1,:),'Tsys'));  % check for Tsys or (Tsys1, Tsys2 ...) 
        elseif strcmp(ii,'Te')   % Te and Tr
            column = find(contains(matdata.metadata.par0d(1,:),'Te'));
            if isempty(column)
                column = find(contains(matdata.metadata.par0d(1,:),'Tr'));
            else
                clear(Tr2Te_1d)
            end
        else
            column = find(strcmp(matdata.metadata.par0d(1,:),ii));
        end
        if isempty(column)
            par_tmp = NaN(n_tot,1);
            if strcmp(ii,'Te')
                warning('Neither Tr och Te were present in par1d or par0d, and therefore set to NaN in par1D')
            else
                warning([char(ii) ' was not present in par1d nor par0d, and therefore set to NaN in par1D'])
            end
        else
            if strcmp(ii,'Tsys')
                par_tmp = median(matdata.data.par0d(column))*ones(n_tot,1);
            else
                par_tmp = matdata.data.par0d(column)*ones(n_tot,1);
            end
        end
    else
        if strcmp(ii,'Tsys')
            par_tmp = median(matdata.data.par1d(:,column),2);   % median of rows
        else
            par_tmp = matdata.data.par1d(:,column);
        end
    end
    par1D = [par1D par_tmp];
    par_tmp = [];   
end   

% 1d: Cast azimuth and elevation into range 0-360 and 0-90 degrees
% respectively:
elno1d = find(strcmp(pars1d,'el'));
azno1d = find(strcmp(pars1d,'az'));
if elno1d
    d=find(par1D(:,elno1d)>90);
    par1D(d,elno1d)=180-par1D(d,elno1d);
    if azno1d
        par1D(d,azno1d)=par1D(d,azno1d)+180; 
        
    end
end
if azno1d
    par1D(:,azno1d)=mod(par1D(:,azno1d)+360,360);
end

if exist('Tr2Te_2d')    % (Tr -> Te and dTr --> dTe),    the code assumes that either (Tr,var_Tr), [b=0] or (Te,var_Te) [b=1] coexists. Is this true?
    tino    = find(strcmp(pars2d,'Ti'));
    if isempty(tino)
        error('Ti must be in pars2d in order to calculate Te from Tr')
    end
    vartino = find(strcmp(errs2d,'var_Ti'));
    trno    = find(strcmp(pars2d,'Te'));      % Tr values have been sat 'Te'
    vartrno = find(strcmp(errs2d,'var_Te'));  % var_Tr values have been sat 'var_Te'
    err2d(:,vartrno) = (err2d(:,vartino)./par2d(:,tino) + err2d(:,vartrno)./par2d(:,trno)).*(par2d(:,tino).*par2d(:,trno)); %dTe = (dTi/Ti+dTr/Tr)*Te
    a = find(isinf(err2d(:,trno)));
    err2d(a,trno) = NaN;
    par2d(:,trno) = par2d(:,trno).*par2d(:,tino);       % Te = Tr*Ti
end

if exist('Tr2Te_1d')    % (Tr -> Te and dTr --> dTe),    the code assumes that either (Tr,var_Tr), [b=0] or (Te,var_Te) [b=1] coexists. Is this true?
    tino    = find(strcmp(pars1d,'Ti'));
    if isempty(tino)
        error('Ti must be in pars1d in order to calculate Te from Tr')
    end
    vartino = find(strcmp(errs1d,'var_Ti'));
    trno    = find(strcmp(pars1d,'Te'));        % Tr values have been sat 'Te'
    vartrno = find(strcmp(errs1d,'var_Te'));    % var_Tr values have been sat 'var_Te'
    err1d(:,vartrno) = (err1d(:,vartino)./par1d(:,tino) + err1d(:,vartrno)./par1d(:,trno)).*(par1d(:,tino).*par1d(:,trno)); %dTe = (dTi/Ti+dTr/Tr)*Te
    a = find(isinf(err1d(:,trno)));
    err1d(a,trno) = NaN;
    par1d(:,trno) = par1d(:,trno).*par1d(:,tino);       % Te = Tr*Ti
end

npar2d = length(pars2d);
nerr2d = length(errs2d);
par2D  = NaN(nh_alt,n_tot,npar2d);
err2D  = NaN(nh_alt,n_tot,nerr2d);

nhalt_tmp = 0;

for ii = 1:n_tot
    altrange = (nhalt_tmp+1):(nhalt_tmp+nh(ii));
    par2D(1:nh(ii),ii,:) = par2d(altrange,:); 
    err2D(1:nh(ii),ii,:) = err2d(altrange,:);    % variance --> error
    nhalt_tmp = nhalt_tmp + nh(ii);
end

if nargin == 1
    par2D(:,:,1:2) = par2D(:,:,1:2)/1000;       % range, alt --> km
    par1D(:,3) = par1D(:,3)/10000;              % W --> 10 kW
end

if do_rpar
    for ii = rpars2d
        column = find(strcmp(matdata.metadata.par2d_pp(1,:),ii));
        par_tmp = matdata.data.par2d_pp(:,column);
        rpar2d = [rpar2d par_tmp];
        par_tmp = [];
    end

    for ii = rpars2d_for_merging
   
        column = find(strcmp(matdata.metadata.par2d_pp(1,:),ii));
        if strcmp(ii,'pprange')
            if ~isempty(column)
                pprange = matdata.data.par2d_pp(:,column); 
            else pprange = []; 
            end
        end
        if strcmp(ii,'pp')
            if ~isempty(column)
                pp = matdata.data.par2d_pp(:,column);
            else pp = [];
            end
        end
        if strcmp(ii,'pperr')
            if ~isempty(column)
                pperr = matdata.data.par2d_pp(:,column);
            else pperr = [];
            end
        end
        if strcmp(ii,'ppw')
            if ~isempty(column)
                ppw = matdata.data.par2d_pp(:,column);
            else ppw = [];
            end
        end
    end
   
    column = find(strcmp(matdata.metadata.par1d(1,:),'ppnrec'));
    if isempty(column) 
        column = find(strcmp(matdata.metadata.par0d(1,:),'ppnrec'));
        npprange = matdata.data.par0d(column);
        npprange = npprange*ones(size(Time,1),1);
    else
        npprange = matdata.data.par1d(:,column);
    end
    npprange_range = max(npprange);
    nrpar2d = length(rpars2d);
    rpar2D  = NaN(npprange_range,n_tot,nrpar2d);
    
    npprange_tmp = 0;
    for ii = 1:n_tot
        rangerange = (npprange_tmp+1):(npprange_tmp+npprange(ii));
        
        if ~isempty(pp),      pp_tomerge = pp(rangerange);           else pp_tomerge = [];      end 
        if ~isempty(pperr),   pperr_tomerge = pperr(rangerange);     else pperr_tomerge = [];   end
        if ~isempty(ppw),     ppw_tomerge = ppw(rangerange);         else ppw_tomerge = [];     end
        if ~isempty(pprange), pprange_tomerge = pprange(rangerange); else pprange_tomerge = []; end
        
        [pprange_merged,pperror_merged,ppw_merged,pp_merged,pprofile_id] = pp_merge(pprange_tomerge/1000,pperr_tomerge,ppw_tomerge/1000,pp_tomerge);   % /1000: m --> km 
        npprange_merged(ii) = length(pprange_merged);
        rpar2D(1:npprange_merged(ii),ii,:) = [pprange_merged pprange_merged pp_merged];
        npprange_tmp = npprange_tmp + npprange(ii);
    end

    % Remove redundant NaNs from rpar2D (since the merged is smaller than unmerged)
    npprange_merged_max = max(npprange_merged);
    rpar2D = rpar2D(1:npprange_merged_max,:,:);
    
    
    % caluclate ppalt fromm pprange
    re=6370;
    elev = [];
    if elno1d
        elev = par1D(:,elno1d);
    elseif elno2d
        elev = par2D(1,:,elno2d)';
    end
    
    if elev
        for ii = 1:n_tot  
            x = rpar2D(:,ii,1)/re;
            rpar2D(:,ii,2) = re*sqrt(1+x.*(x+2*sin(elev(ii)/57.2957795)))-re;
        end
    else
        rpar2D(:,:,2) = NaN;
        warning(['Needs "el" in pars1d or pars2d in order to calculate pph (altitude) from pprange.'])
    end
    if nargin > 1
        rpar2D(:,:,1:2) = rpar2D(:,:,1:2)*1000;     % km --> m
    end
else
    rpar2D = [];
end

Time = Time';

