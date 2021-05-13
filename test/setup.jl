using Test

macro test_false(expr)
    esc(:(@test !($expr)))
end

macro test_nothing(expr)
    esc(:(@test ($expr) === nothing))
end

function _test_not_cnull(exprs...)
    for expr in exprs
        @test (expr) != C_NULL
    end
end

macro test_not_cnull(exprs...)
    esc(Expr(:call, :_test_not_cnull, exprs...))
end

function _test_isa(type, syms...)
    for sym in syms
        @test (sym) isa type
    end
end

macro test_isa(exprs...)
    type = exprs[end]
    syms = exprs[1:end-1]
    esc(Expr(:call, :_test_isa, type, syms...))
end

macro test_passed()
    @test true
end
