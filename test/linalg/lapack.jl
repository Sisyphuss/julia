# This file is a part of Julia. License is MIT: http://julialang.org/license

using Base.Test

let # syevr
    srand(123)
    Ainit = randn(5,5)
    for elty in (Float32, Float64, Complex64, Complex128)
        if elty == Complex64 || elty == Complex128
            A = complex(Ainit, Ainit)
        else
            A = Ainit
        end
        A = convert(Array{elty, 2}, A)
        Asym = A'A
        vals, Z = LAPACK.syevr!('V', copy(Asym))
        @test_approx_eq Z*scale(vals, Z') Asym
        @test all(vals .> 0.0)
        @test_approx_eq LAPACK.syevr!('N','V','U',copy(Asym),0.0,1.0,4,5,-1.0)[1] vals[vals .< 1.0]
        @test_approx_eq LAPACK.syevr!('N','I','U',copy(Asym),0.0,1.0,4,5,-1.0)[1] vals[4:5]
        @test_approx_eq vals LAPACK.syev!('N','U',copy(Asym))
    end
end

let # Test gglse
    for elty in (Float32, Float64, Complex64, Complex128)
        A = convert(Array{elty, 2}, [1 1 1 1; 1 3 1 1; 1 -1 3 1; 1 1 1 3; 1 1 1 -1])
        c = convert(Array{elty, 1}, [2, 1, 6, 3, 1])
        B = convert(Array{elty, 2}, [1 1 1 -1; 1 -1 1 1; 1 1 -1 1])
        d = convert(Array{elty, 1}, [1, 3, -1])
        @test_approx_eq LAPACK.gglse!(A, c, B, d)[1] convert(Array{elty}, [0.5, -0.5, 1.5, 0.5])
    end
end

let # xbdsqr
    n = 10
    for elty in (Float32, Float64)
        d, e = convert(Vector{elty}, randn(n)), convert(Vector{elty}, randn(n - 1))
        U, Vt, C = eye(elty, n), eye(elty, n), eye(elty, n)
        s, _ = LAPACK.bdsqr!('U', copy(d), copy(e), Vt, U, C)
        @test_approx_eq full(Bidiagonal(d, e, true)) U*Diagonal(s)*Vt

        @test_throws ArgumentError LAPACK.bdsqr!('A', d, e, Vt, U, C)
        @test_throws DimensionMismatch LAPACK.bdsqr!('U', d, [e; 1], Vt, U, C)
        @test_throws DimensionMismatch LAPACK.bdsqr!('U', d, e, Vt[1:end - 1, :], U, C)
        @test_throws DimensionMismatch LAPACK.bdsqr!('U', d, e, Vt, U[:,1:end - 1], C)
        @test_throws DimensionMismatch LAPACK.bdsqr!('U', d, e, Vt, U, C[1:end - 1, :])
    end
end

let # Issue #7886
    x, r = LAPACK.gelsy!([0 1; 0 2; 0 3.], [2, 4, 6.])
    @test_approx_eq x [0,2]
    @test r == 1
end

#gebal/gebak
for elty in (Float32, Float64, Complex64, Complex128)
    A = rand(elty,10,10)
    B = copy(A)
    ilo, ihi, scale = LAPACK.gebal!('B',B)
    Bvs = eigvecs(B)
    Avs = eigvecs(A)
    Bvs = LAPACK.gebak!('B','R',ilo,ihi,scale,Bvs)
    @test_approx_eq Bvs Avs
end

#gels
for elty in (Float32, Float64, Complex64, Complex128)
    A = rand(elty,10,10)
    X = rand(elty,10)
    B,Y,z = LAPACK.gels!('N',copy(A),copy(X))
    @test_approx_eq A\X Y
end

#getrf/getri
for elty in (Float32, Float64, Complex64, Complex128)
    A = rand(elty,10,10)
    iA = inv(A)
    A, ipiv = LAPACK.getrf!(A)
    A = LAPACK.getri!(A, ipiv)
    @test_approx_eq A iA
end

#geev - complex is easier for now
for elty in (Complex64, Complex128)
    A = rand(elty,10,10)
    Aw, Avl, Avr = LAPACK.geev!('N','V',copy(A))
    fA = eigfact(A)
    @test_approx_eq fA[:values] Aw
    @test_approx_eq fA[:vectors] Avr
end

#gtsv
for elty in (Float32, Float64, Complex64, Complex128)
    du = rand(elty,9)
    d  = rand(elty,10)
    dl = rand(elty,9)
    b  = rand(elty,10)
    c = Tridiagonal(dl,d,du) \ b
    b = LAPACK.gtsv!(dl,d,du,b)
    @test_approx_eq b c
end

#sytri and sytrf
for elty in (Float32, Float64, Complex64, Complex128)
    A = rand(elty,10,10)
    A = A + A.' #symmetric!
    B = copy(A)
    B,ipiv = LAPACK.sytrf!('U',B)
    @test_approx_eq triu(inv(A)) triu(LAPACK.sytri!('U',B,ipiv))
end

#trtri
for elty in (Float32, Float64, Complex64, Complex128)
    A = rand(elty,10,10)
    A = triu(A)
    B = copy(A)
    @test_approx_eq inv(A) LAPACK.trtri!('U','N',B)
end

#sysv
for elty in (Float32, Float64, Complex64, Complex128)
    A = rand(elty,10,10)
    A = A + A.' #symmetric!
    b = rand(elty,10)
    c = A \ b
    b,A = LAPACK.sysv!('U',A,b)
    @test_approx_eq b c
end

#hesv
for elty in (Complex64, Complex128)
    A = rand(elty,10,10)
    A = A + A' #hermitian!
    b = rand(elty,10)
    c = A \ b
    b,A = LAPACK.hesv!('U',A,b)
    @test_approx_eq b c
end

#ptsv
for elty in (Float32, Float64, Complex64, Complex128)
    dv = real(ones(elty,10))
    ev = zeros(elty,9)
    A = SymTridiagonal(dv,ev)
    if elty <: Complex
        A = Tridiagonal(conj(ev),dv,ev)
    end
    B = rand(elty,10,10)
    C = copy(B)
    @test_approx_eq A\B LAPACK.ptsv!(dv,ev,C)
end

#pttrf and pttrs
for elty in (Float32, Float64, Complex64, Complex128)
    dv = real(ones(elty,10))
    ev = zeros(elty,9)
    A = SymTridiagonal(dv,ev)
    if elty <: Complex
        A = Tridiagonal(conj(ev),dv,ev)
    end
    dv,ev = LAPACK.pttrf!(dv,ev)
    B = rand(elty,10,10)
    C = copy(B)
    if elty <: Complex
        @test_approx_eq A\B LAPACK.pttrs!('U',dv,ev,C)
    else
        @test_approx_eq A\B LAPACK.pttrs!(dv,ev,C)
    end
end

#posv
for elty in (Float32, Float64, Complex64, Complex128)
    A = rand(elty,10,10)
    A += real(diagm(10*real(rand(elty,10))))
    if elty <: Complex
        A = A + A'
    else
        A = A + A.'
    end
    B = rand(elty,10,10)
    D = copy(A)
    C = copy(B)
    D,C = LAPACK.posv!('U',D,C)
    @test_approx_eq A\B C
end
