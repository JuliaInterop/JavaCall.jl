module JavaVM

export init, destroy

using JavaCall.JNI
using JavaCall.InitOptions
using JavaCall.Utils

const JAVA_HOME_CANDIDATES = [
    "/usr/lib/jvm/default-java/",
    "/usr/lib/jvm/default/"
]

init() = init(defaultopts())

init(opts::JavaCallInitOptions) = init(Val(opts.fromcurrentvm), opts)

function init(::Val{false}, opts::JavaCallInitOptions)
    @verify !jvmloaded() "JVM already initialised."
    fullopts = []
    push!(fullopts, "-Djava.class.path="*join(opts.jvmclasspath, ":"))
    push!(fullopts, opts.jvmopts...)
    JNI.init_new_vm(findjvm(opts.javahome), fullopts)
end

function init(::Val{true}, opts::JavaCallInitOptions)
    @verify !jvmloaded() "JVM already initialised."
    JNI.init_current_vm(findjvm(opts.javahome))
end

function destroy()
    @verify jvmloaded() "JVM not initialised."
    JNI.destroy_vm()
end

jvmloaded() = JNI.is_jni_loaded() && JNI.is_env_loaded()

function findjvm(javahome::Union{String, Nothing})
    try
        return possible_javahomes(javahome) |> 
            l -> flatmap(libpathdirectories, l) |> 
            # Include pwd in directories to search for libpath
            l -> chain((pwd(),), l) |>
            l -> flatmap(libpathfromdirectory, l)  |>
            # Return only first path
            first
    catch
        errormsg = [
            "Cannot find java library $(libfile)\n",
            "Search Path:"
        ]
        for path in possible_javahomes(javahome) |> l -> flatmap(libpathdirectories, l) |> l -> chain((pwd(),), l)
            push!(errormsg,"\n   $path")
        end
        error(reduce(*,errormsg))
    end
end

possible_javahomes(javahome::String) = [javahome]
possible_javahomes(::Nothing) = possible_javahomes()

@static if Sys.isunix()
    function possible_javahomes()
        javahomes = Any[]
        if haskey(ENV, "JAVA_HOME")
            push!(javahomes, ENV["JAVA_HOME"])
        else
            # Find default javahome by checking location of the java command
            try
                javapath = chomp(read(`which java`,String))
                while(islink(javapath))
                    javapath = readlink(javapath)
                end
                javapath = dirname(javapath)
                javapath = match(r"(.*)((/jre/bin)|(/bin))+",javapath)[1]
                push!(javahomes,javapath)
            catch err
                @debug "JavaCall could not determine javapath from `which java`" err
            end
        end
        isfile("/usr/libexec/java_home") && push!(javahomes, chomp(read(`/usr/libexec/java_home`, String)))
    
        for fname ∈ JAVA_HOME_CANDIDATES
            isdir(fname) && push!(javahomes, fname)
        end
        javahomes
    end

    @static if Sys.isapple()
        libfile = "libjvm.dylib"

        function libpathdirectories(java_home::AbstractString)::Vector{AbstractString}
            [
                joinpath(java_home, "jre", "lib", "server"),
                joinpath(java_home, "lib", "server")
            ]
        end

        function libpathfromdirectory(directory::AbstractString)::Vector{AbstractString}
            libpath = joinpath(directory, libfile)
            return (isfile(libpath) ? [libpath] : [])
        end
    else
        libfile = "libjvm.so"

        function libpathdirectories(java_home::AbstractString)::Vector{AbstractString}
            libpaths = []
            if Sys.WORD_SIZE==64
                push!(libpaths, joinpath(java_home, "jre", "lib", "amd64", "server"))
                push!(libpaths, joinpath(java_home, "lib", "amd64", "server"))
            elseif Sys.WORD_SIZE==32
                push!(libpaths, joinpath(java_home, "jre", "lib", "i386", "server"))

                push!(libpaths, joinpath(java_home, "lib", "i386", "server"))
            end
            push!(libpaths, joinpath(java_home, "jre", "lib", "server"))
            push!(libpaths, joinpath(java_home, "lib", "server"))
            libpaths
        end

        function libpathfromdirectory(directory::AbstractString)::Vector{AbstractString}
            libpath = joinpath(directory,libfile)
            return (isfile(libpath) ? [libpath] : [])
        end
    end
else
    libfile = "jvm.dll"

    function javahome_winreg()
        keys = ["SOFTWARE\\JavaSoft\\Java Runtime Environment", "SOFTWARE\\JavaSoft\\Java Development Kit", "SOFTWARE\\JavaSoft\\JRE", "SOFTWARE\\JavaSoft\\JDK"]
    
        for key in keys
            try
                value = querykey(WinReg.HKEY_LOCAL_MACHINE, key, "CurrentVersion")
                key *= "\\" * value
                return querykey(WinReg.HKEY_LOCAL_MACHINE, key, "JavaHome")
            catch
                # Try the next value in the loop.
            end
        end
    
        error("Cannot find an installation of Java in the Windows Registry. Please install a JRE/JDK, or set the JAVA_HOME environment variable if one is already installed.")
    end

    function possible_javahomes()
        javahomes = Any[]
        if haskey(ENV, "JAVA_HOME")
            push!(javahomes, ENV["JAVA_HOME"])
        else
            ENV["JAVA_HOME"] = javahome_winreg()
            push!(javahomes, ENV["JAVA_HOME"])
        end
        isfile("/usr/libexec/java_home") && push!(javahomes, chomp(read(`/usr/libexec/java_home`, String)))
    
        for fname ∈ JAVA_HOME_CANDIDATES
            isdir(fname) && push!(javahomes, fname)
        end
        javahomes
    end

    function libpathdirectories(java_home::AbstractString)::Vector{AbstractString}
        [
            joinpath(java_home, "bin", "server"),
            joinpath(java_home, "jre", "bin", "server"),
            joinpath(java_home, "bin", "client"),
            joinpath(java_home, "jre", "lib", "server"),
            joinpath(java_home, "lib", "server")
        ]
    end

    function libpathfromdirectory(directory::AbstractString)::Vector{AbstractString}
        libpath = joinpath(directory, libfile)
        if isfile(libpath)
            bindir = dirname(dirname(libpath))
            m = filter(x -> occursin(r"msvcr(?:.*).dll",x), readdir(bindir))
            if !isempty(m)
                return [joinpath(bindir,m[1]),libpath]
            end
        end
        return []
    end
end

end
