export HMat;

@enum ADMISSTYPES ADMISS_STRONG ADMISS_STANDARD ADMISS_MILD ADMISS_WEAK;
@enum BLOCKTYPES LOWRANK DENSE HMAT;

type HMat{T<:Number}
    # variables
    height::    Int
    width::     Int
    level::     Int
    trg::       Array{Int,1}
    src::       Array{Int,1}
    blockType:: BLOCKTYPES
    childHMat:: Array{HMat{T},2}
    UMat::      Array{T,2}
    VMat::      Array{T,2}
    DMat::      Array{T,2}
    # global settings
    EPS::       Float64
    MAXRANK::   Int
    MINN::      Int

    HMat() = new()
end

function admiss(x,y,type_admiss)
    if ((type_admiss == ADMISS_STRONG) || (type_admiss == ADMISS_STANDARD))
        if maximum(x-y) > 1
            return true;
        else
            return false;
        end
    elseif type_admiss == ADMISS_MILD
        if sum(abs(x-y)) > 1
            return true;
        else
            return false;
        end
    elseif type_admiss == ADMISS_WEAK
        if x != y
            return true;
        else
            return false;
        end
    end
end

function Z2Cmapper(n,minn,tensor)
    if maximum(n) <= minn
        return reshape(tensor,prod(n));
    end
    nl = ifloor(n/2);
    nr = n-nl;
    nv = zeros(n);
    nrange = Array(Any,2,1);
    offset = 0;
    order = vec(zeros(Int64,prod(n),1));
    for i = 0:2^2-1
        for d = 0:2-1
            nv[d+1] = nl[d+1]*(1-mod(i>>d,2))+nr[d+1]*mod(i>>d,2);
            nrange[d+1] = nl[d+1]*mod(i>>d,2)+(1:ifloor(nv[d+1]));
        end
        order[offset+(1:prod(nv))] = Z2Cmapper(nv,minn,tensor[nrange[1],nrange[2]]);
        offset = offset + prod(nv);
    end
    return order;
end

function svdtrunc(A,eps,mR)
    (U, S, V) = svd(full(A),thin=true);
    if minimum(size(A))>1 && S[1] > 1e-15
        idx = find(find(S/S[1].>eps).<=mR);
        return U[:,idx], S[idx], V[:,idx];
    else
        return U, S, V;
    end
end

function HMatd2h{T}(D::AbstractMatrix{T}, nTrg, nSrc, type_admiss, idxTrg, idxSrc, level, EPS, MaxRank, minn)
    node = HMat{T}();
    node.height = prod(nTrg);
    node.width = prod(nSrc);
    node.trg = idxTrg;
    node.src = idxSrc;
    node.level = level;

    node.EPS = EPS;
    node.MAXRANK = MaxRank;
    node.MINN = minn;

    if admiss(idxTrg,idxSrc,type_admiss)
        (Utmp, Stmp, Vtmp) = svdtrunc(D,EPS,MaxRank);
        node.blockType = LOWRANK;
        if length(Stmp) > 0
            node.UMat = Utmp.*sqrt(Stmp)';
            node.VMat = Vtmp.*sqrt(Stmp)';
        else
            node.UMat = Utmp;
            node.VMat = Vtmp;
        end
    elseif maximum(nTrg) <= minn || maximum(nSrc) <= minn
        node.blockType = DENSE;
        node.DMat = full(D);
    else
        node.blockType = HMAT;
        node.childHMat = Array(HMat{T},4,4);
        trg = 2*idxTrg;
        src = 2*idxSrc;
        toffset = 0;
        for tx = 0:1, ty = 0:1
            trg = 2*idxTrg + [tx,ty];
            (txlen,tylen) = ifloor(nTrg/2).*(1-[tx,ty]) + iceil(nTrg/2).*[tx,ty];
            tRange = toffset + (1:txlen*tylen);
            toffset = toffset + txlen*tylen;

            soffset = 0;
            for sx = 0:1, sy = 0:1
                src = 2*idxSrc + [sx,sy];
                (sxlen,sylen) = ifloor(nSrc/2).*(1-[sx,sy]) + iceil(nSrc/2).*[sx,sy];
                sRange = soffset + (1:sxlen*sylen);
                soffset = soffset + sxlen*sylen;
                node.childHMat[tx*2+ty+1,sx*2+sy+1] = HMatd2h(D[tRange,sRange],[txlen,tylen],[sxlen,sylen],type_admiss,trg,src,level+1,EPS,MaxRank,minn);
            end
        end
    end
    return node;
end

include("../src/hcopy.jl");
include("../src/hadjoint.jl");
include("../src/hempty.jl");
include("../src/hidentity.jl");
include("../src/hmatvec.jl");
include("../src/hcompress.jl");
include("../src/huncompress.jl");
include("../src/hscale.jl");
include("../src/hadd.jl");
include("../src/hnorm.jl");
include("../src/hmul.jl");
include("../src/hinv.jl");
include("../src/hNewton.jl");
