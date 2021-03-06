classdef tf_fet_rpdni < tf_i
  %TF_RPDNI Random Pixel Difference, neighborhood indexing
  %   Detailed explanation goes here
  
  properties
    r; % [1] radius
    M; % [1] #pixel difference pairs per point
    
    A1; % [L, M*L] random points in canonical coordinate (<=r)
    A2;    
    
    Z; % [L,L] 0/1 template for knn: Z(:,i) indicates the knn for point i
    
    ind1; % [MLN, 3] linear index for 
    ind2; 
    
    is_bprop_in2; % true: bprop for in 2 (the image I); false: don't
  end
  
  methods
    function obj = tf_fet_rpd(Z)
      %%% internal data
      obj.r = 0.1;
      obj.M = 2;
      obj.Z = Z; 
      
      obj.is_bprop_in2 = false;
      
      %%% input output
      obj.i = [n_data(),n_data()];
      obj.o = n_data();
    end
    
    function ob = fprop(ob)
      ttt = tic; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %%% in 
      p = ob.i(1).a; % in 1: p [2,L,N]
      I = ob.i(2).a; % in 2: II [W,H,3,N]
      
      %%% do it: generate the features
      if ( isempty(ob.A1) ) % initialize if necessary
        ob = init_param(ob);
      end
      % the first
      pp1 = pagefun(@mtimes, p, ob.A1); % [2,ML,N], point set
      %%%% TODO: the right conversion!
      ob.ind1 = ones(numel(pp1)/2, 3); % [MLN, 3], linear index
      f1 = I( ob.ind1(:,1) ) ; % [MLN]
      % the second
      pp2 = pagefun(@mtimes, p, ob.A2); % [2,ML,N]
      %%%% TODO: the right conversion!
      ob.ind2 = ones(numel(pp2)/2, 3); % [MLN, 3]
      f2 = I( ob.ind2(:,1) ) ; % [MLN]

      %%% out 1: X [M, L, 1, N]
      % the values: [M*L*N] -> [M,L,1,N], the matconvnet format
      [~,L,N] = size(p);
      ob.o.a = reshape(f1-f2, [ob.M, L, 1, N]);
      ttt = toc(ttt); %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      fprintf(' tf_rpd.fprop: %.4fs ', ttt);
    end % fprop
    
    function ob = bprop(ob)
      ttt = tic; %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %%% out and in
      dX = ob.o.d;      % [M,L,1,N]
      dX = squeeze(dX); % [M,L,N]
      p  = ob.i(1).a;   % [2, L, N]
      II = ob.i(2).a;   % [W,H,3,N]
      
      %%% bprop for p: in1.d 
      [~,L,N] = size(p);
      % 
      f1x = II( ob.ind1(:,2) ); % [MLN]
      f1x = reshape(f1x, [1, ob.M,L,N]); % [1, M,L,N]
      f1y = II( ob.ind1(:,3) ); % [MLN]
      f1y = reshape(f1y, [1, ob.M,L,N]); % [1, M,L,N]
      GG1 = cat(1, f1x,f1y); % [2,M,L,N]
      % 
      f2x = II( ob.ind2(:,2) ); % [MLN]
      f2x = reshape(f2x, [1, ob.M,L,N]); % [1, M,L,N]
      f2y = II( ob.ind2(:,3) ); % [MLN]
      f2y = reshape(f2y, [1, ob.M,L,N]); % [1, M,L,N]
      GG2 = cat(1, f2x,f2y); % [2,M,L,N]
      % delta
      dXdX = reshape(dX,[1,ob.M,L,N]); % [1,M,L,N]
      dXdX = cat(1, dXdX,dXdX); % [2,M,L,N]
      % times
      tmp = (GG1-GG2) .* dXdX; % [2,M,L,N]
      %%% in 1.d: dp [2,L,N]
      ob.i(1).d = squeeze( sum(tmp,2) ); % [2,L,N] = squeeze( [2,1,L,N] )
      ttt = toc(ttt); %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %fprintf(' tf_rpd.bprop: %.4fs ', ttt);
      
      %%% whether bprop for I? (typically doesn't need it when training)
      ob.i(2).d = zeros( size(ob.i(2).a) ); % [W,H,3,N]
      if (~ob.is_bprop_in2), return; end
      
      %%% bprop for I: in2.d
      tmp1 = zeros( size(II) );     % [W,H,1,N]
      tmp1( ob.ind1(:,1) ) = dX(:); % [W,H,1,N], with MLN non-zero elements
      tmp2 = zeros( size(II) );     % [W,H,1,N]
      tmp2( ob.ind2(:,1) ) = dX(:); % [W,H,1,N], with MLN non-zero elements
      tmp = tmp1 - tmp2;            % [W,H,1,N]
      % write it
      ob.i(2).d(:,:,1,:) = tmp; % leave the other 2 channels

    end % bprop
    
    function ob = cvt_data(ob)
      % convert internal state
      ob.A1 = ob.ab.cvt_data( ob.A1 );
      ob.A2 = ob.ab.cvt_data( ob.A2 );
      % convert other
      ob = cvt_data@tf_i(ob);
    end % cvt_data
    
  end % methods
  
  %%% helpers
  methods
    function ob = init_param(ob)
      ob.A1 = rand_pnts_knn_convcomb(ob.Z, ob.M);
      ob.A2 = rand_pnts_knn_convcomb(ob.Z, ob.M);
    end % init_param
  end % methods
  
end % tf_fet_rpdni
