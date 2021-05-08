module InitOptions

export defaultopts, fromcurrentvm, forjavahome, setfromcurrentvm!, unsetfromcurrentvm!,
       setjavahome!, unsetjavahome!, pushclasspath!, pushoptions!

#=
Struct to configure the JavaCall package when initializing

fromcurrentvm specifies if the jvm that is currently running should be used
    when executing java calls. If set to true then the other parameters will
    be ignored as the jvm is already running.

javahome specifies a specific javahome to use, if unset than a javahome will be searched
    by examining the JAVA_HOME variable and other common directories for a Java installation

jvmclasspath defines a vector of locations to add to the classpath when creating the jvm

jvmopts defines a vector of options to send the jvm
=#
mutable struct JavaCallInitOptions
    fromcurrentvm::Bool
    javahome::Union{String, Nothing}
    jvmclasspath::AbstractVector{String}
    jvmopts::AbstractVector{String}
end

defaultopts()::JavaCallInitOptions = JavaCallInitOptions(false, nothing, [], [])

fromcurrentvm()::JavaCallInitOptions = JavaCallInitOptions(true, nothing, [], [])

forjavahome(javahome::String) = JavaCallInitOptions(false, javahome, [], [])

function setfromcurrentvm!(initopts::JavaCallInitOptions)
    initopts.fromcurrentvm = true
    return initopts
end

function unsetfromcurrentvm!(initopts::JavaCallInitOptions)
    initopts.fromcurrentvm = false
    return initopts
end

function setjavahome!(initopts::JavaCallInitOptions, javahome::String)
    initopts.javahome = javahome
    return initopts
end

function unsetjavahome!(initopts::JavaCallInitOptions)
    initopts.javahome = nothing
    return initopts
end

function pushclasspath!(initopts::JavaCallInitOptions, entries::String...)
    push!(initopts.jvmclasspath, entries...)
    return initopts
end

function pushoptions!(initopts::JavaCallInitOptions, opts::String...)
    push!(initopts.jvmopts, opts...)
    return initopts
end

function Base.show(io::IO, opts::JavaCallInitOptions)
    print(io, "JavaCallInitOptions("*
        "fromcurrentvm=$(opts.fromcurrentvm), "* 
        "javahome=$(opts.javahome), "* 
        "jvmclasspath=$(opts.jvmclasspath), "*
        "jvmopts=$(opts.jvmopts))")
end

end
