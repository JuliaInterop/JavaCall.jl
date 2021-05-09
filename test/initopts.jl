@testset verbose = true "Test Init Opts" begin
    @testset "init defaultopts" begin
        opts = defaultopts()
        @test_false opts.fromcurrentvm
        @test_nothing opts.javahome
        @test opts.jvmclasspath == []
        @test opts.jvmopts == []
    end

    @testset "init fromcurrentvm" begin
        opts = fromcurrentvm()
        @test opts.fromcurrentvm
        @test_nothing opts.javahome
        @test opts.jvmclasspath == []
        @test opts.jvmopts == []
    end

    @testset "init forjavahome" begin
        javahome = "JavaHome"
        opts = forjavahome(javahome)
        @test_false opts.fromcurrentvm
        @test opts.javahome == javahome
        @test opts.jvmclasspath == []
        @test opts.jvmopts == []
    end

    @testset "set/unset fromcurrentvm" begin
        opts = defaultopts()
        @test_false opts.fromcurrentvm
        setfromcurrentvm!(opts)
        @test opts.fromcurrentvm
        unsetfromcurrentvm!(opts)
        @test_false opts.fromcurrentvm
    end

    @testset "set/unset javahome" begin
        opts = defaultopts()
        @test_false opts.fromcurrentvm
        setfromcurrentvm!(opts)
        @test opts.fromcurrentvm
        unsetfromcurrentvm!(opts)
        @test_false opts.fromcurrentvm
    end

    @testset "push classpath" begin
        opts = defaultopts()
        firstentry = "First Entry"
        secondentry = "Second Entry"
        thirdentry = "Third Entry"
        fourthentry = "Fourth Entry"

        @test opts.jvmclasspath == []
        pushclasspath!(opts, firstentry)
        @test opts.jvmclasspath == [firstentry]
        pushclasspath!(opts, secondentry)
        @test opts.jvmclasspath == [firstentry, secondentry]
        pushclasspath!(opts, thirdentry, fourthentry)
        @test opts.jvmclasspath == [firstentry, secondentry, thirdentry, fourthentry]
    end

    @testset "push options" begin
        opts = defaultopts()
        firstopt = "First Option"
        secondopt = "Second Option"
        thirdopt = "Third Option"
        fourthopt = "Fourth Option"

        @test opts.jvmopts == []
        pushoptions!(opts, firstopt)
        @test opts.jvmopts == [firstopt]
        pushoptions!(opts, secondopt)
        @test opts.jvmopts == [firstopt, secondopt]
        pushoptions!(opts, thirdopt, fourthopt)
        @test opts.jvmopts == [firstopt, secondopt, thirdopt, fourthopt]
    end
end
