const JAVA_HOME_CANDIDATES = ["/usr/lib/jvm/default-java/",
                              "/usr/lib/jvm/default/"]

struct JavaCallError <: Exception
    msg::String
end

function javahome_winreg()
    keys = ["SOFTWARE\\JavaSoft\\Java Runtime Environment", "SOFTWARE\\JavaSoft\\Java Development Kit", "SOFTWARE\\JavaSoft\\JDK"]

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

@static Sys.isunix() ? (global const libname = "libjvm") : (global const libname = "jvm")

function findjvm()
    javahomes = Any[]
    libpaths = Any[]

    if haskey(ENV, "JAVA_HOME")
        push!(javahomes, ENV["JAVA_HOME"])
    else
        @static if Sys.iswindows()
            ENV["JAVA_HOME"] = javahome_winreg()
            push!(javahomes, ENV["JAVA_HOME"])
        end
        @static if Sys.isunix()
            # Find default javahome by checking location of the java command
            try
                javapath = chomp(read(`which java`,String))
                while(islink(javapath))
                    javapath = readlink(javapath)
                end
                javapath = dirname(javapath)
                javapath = match(r"(.*)(/jre)+(/bin)+",javapath)[1]
                push!(javahomes,javapath)
            catch err
                @info "JavaCall could not determine javapath from `which java`"
            end
        end
    end
    isfile("/usr/libexec/java_home") && push!(javahomes, chomp(read(`/usr/libexec/java_home`, String)))

    for fname ∈ JAVA_HOME_CANDIDATES
        isdir(fname) && push!(javahomes, fname)
    end

    push!(libpaths, pwd())
    for n in javahomes
        @static if Sys.iswindows()
            push!(libpaths, joinpath(n, "bin", "server"))
            push!(libpaths, joinpath(n, "jre", "bin", "server"))
            push!(libpaths, joinpath(n, "bin", "client"))
        end
        @static if Sys.islinux()
            if Sys.WORD_SIZE==64
                push!(libpaths, joinpath(n, "jre", "lib", "amd64", "server"))
                push!(libpaths, joinpath(n, "lib", "amd64", "server"))
            elseif Sys.WORD_SIZE==32
                push!(libpaths, joinpath(n, "jre", "lib", "i386", "server"))

                push!(libpaths, joinpath(n, "lib", "i386", "server"))
            end
        end
        push!(libpaths, joinpath(n, "jre", "lib", "server"))
        push!(libpaths, joinpath(n, "lib", "server"))
    end

    ext = @static Sys.iswindows() ? "dll" : (@static Sys.isapple() ? "dylib" : "so")
    ext = "."*ext

    try
        for n in libpaths
            libpath = joinpath(n,libname*ext);
            if isfile(libpath)
                if Sys.iswindows()
                    bindir = dirname(dirname(libpath))
                    m = filter(x -> occursin(r"msvcr(?:.*).dll",x), readdir(bindir))
                    if !isempty(m)
                        Libdl.dlopen(joinpath(bindir,m[1]))
                    end
                end
                global libjvm = Libdl.dlopen(libpath)
                @debug("Loaded $libpath")
                return
            end
        end
    catch
    end

    errorMsg =
        [
         "Cannot find java library $libname$ext\n",
         "Search Path:"
         ];
    for path in libpaths
        push!(errorMsg,"\n   $path")
    end
    throw(JavaCallError(reduce(*,errorMsg)))
end





struct JavaVMOption
    optionString::Ptr{UInt8}
    extraInfo::Ptr{Nothing}
end

struct JavaVMInitArgs
    version::Cint
    nOptions::Cint
    options::Ptr{JavaVMOption}
    ignoreUnrecognized::Cchar
end


@static Sys.isunix() ? (const sep = ":") : nothing
@static Sys.iswindows() ? (const sep = ";") : nothing
cp = OrderedSet{String}()
opts = OrderedSet{String}()

"""
    JavaCall.getClassPath()

    Obtains the Java classpath.

    Before JavaCall.init(), this reports the classpath constructed using
    JavaCall.addClasspath.

    After JavaCall.init(), this reports System.getProperty("java.class.path")
"""
function getClassPath()
    if isloaded()
        # jls = @jimport java.lang.System
        jls = JavaObject{Symbol("java.lang.System")}
        return jcall(jls, "getProperty", JString, (JString,), "java.class.path")::String
    else
        ccp = collect(cp)
        return join(ccp,sep)
    end
end

"""
    JavaCall.addClassPath(s::String)

    Add a string to the classpath. Must be called before JavaCall.init

    foo/*.jar will add all the jars in the directory foo to the classpath
    foo/*     will add all the jars and directories recursively including foo

    See also addClassPathRecursive and addJarsToClassPath
"""
function addClassPath(s::String)
    if isloaded()
        @warn("JVM already initialised. This call has no effect")
        return
    end
    if s==""; return; end
    dirname, pattern = splitdir(s)
    if pattern == "*.jar" && isdir(dirname)
        _addJarsToClassPath(dirname)
    elseif pattern == "*" && isdir(dirname)
        _addClassPathRecursive(dirname)
    else
        push!(cp, s)
    end
    return
end

function _addClassPathRecursive(dirname::String)
    push!(cp,dirname)
    for (root,dirs,filenames) in walkdir(dirname)
        addJarsToClassPath(filenames,root)
        union!(cp, [joinpath(root,dir) for dir in dirs])
    end
end
"""
    JavaCall.addClassPathRecursive(dirname::String)

    Adds dirname and all jars and directories in dirname recursively to the classpath
"""
addClassPathRecursive(dirname) = isloaded() ?
    @warn("JVM already initialized. This call has no effect") :
    _addClassPathRecursive(dirname)


function _addJarsToClassPath(files::Array{String,1},path::String="")
    for filename in files
        if endswith(filename,".jar")
            push!(cp, joinpath(path,filename) )
        end
    end
end
_addJarsToClassPath(dirname::String) = addJarsToClassPath(readdir(dirname),dirname)
"""
    JavaCall.addJarsToClassPath(dirname::String)

    Add jars in dirname to the classpath.
    Equivalent to JavaCall.addJarsToClasspath(readdir(dirname),dirname)

    JavaCall.addJarsToClassPath(files::Array{String,1}, [path::String])

    Add files which end in ".jar" to the classpath prefixed by an optional path
"""
addJarsToClassPath(args...) = isloaded() ?
    @warn("JVM already initialized. This call has no effect") :
    _addJarsToClassPath(args...)

addOpts(s::String) = isloaded() ? @warn("JVM already initialised. This call has no effect") : push!(opts, s)

function init()
    if isempty(cp)
        init(opts)
    else
        ccp = collect(cp)
        options = collect(opts)
        classpath = "-Djava.class.path="*join(ccp,sep)
        init(vcat(options, classpath))
    end
end

const ROOT_TASK_ERROR = JavaCallError(
    "Either the environmental variable JULIA_COPY_STACKS must be 1 " *
    "OR JavaCall must be used on the root Task.")

const JULIA_COPY_STACKS_ON_WINDOWS_ERROR = JavaCallError(
    "JULIA_COPY_STACKS should not be set on Windows.")

# JavaCall must run on the root Task or JULIA_COPY_STACKS is enabled
isroottask() = Base.roottask === Base.current_task()
@static if Sys.iswindows()
    isgoodenv() = ! JULIA_COPY_STACKS
    assertroottask_or_goodenv() = isgoodenv() ? nothing : throw(JULIA_COPY_STACKS_ON_WINDOWS_ERROR)
else
    isgoodenv() = JULIA_COPY_STACKS || isroottask()
    assertroottask_or_goodenv() = isgoodenv() ? nothing : throw(ROOT_TASK_ERROR)
end

isloaded() = JNI.is_jni_loaded() && isdefined(JavaCall, :penv) && penv != C_NULL

assertloaded() = isloaded() ? nothing : throw(JavaCallError("JVM not initialised. Please run init()"))
assertnotloaded() = isloaded() ? throw(JavaCallError("JVM already initialised")) : nothing

# Pointer to pointer to pointer to pointer alert! Hurrah for unsafe load
function init(opts)
    assertnotloaded()
    assertroottask_or_goodenv()
    opt = [JavaVMOption(pointer(x), C_NULL) for x in opts]
    ppjvm = Array{Ptr{JavaVM}}(undef, 1)
    ppenv = Array{Ptr{JNIEnv}}(undef, 1)
    vm_args = JavaVMInitArgs(JNI.JNI_VERSION_1_8, convert(Cint, length(opts)),
                             convert(Ptr{JavaVMOption}, pointer(opt)), JNI_TRUE)
    res = ccall(create, Cint, (Ptr{Ptr{JavaVM}}, Ptr{Ptr{JNIEnv}}, Ptr{JavaVMInitArgs}), ppjvm, ppenv,
                Ref(vm_args))
    res < 0 && throw(JavaCallError("Unable to initialise Java VM: $(res)"))
    global penv = ppenv[1]
    global pjvm = ppjvm[1]
    jvm = unsafe_load(pjvm)
    global jvmfunc = unsafe_load(jvm.JNIInvokeInterface_)
    JNI.load_jni(penv)
    return
end

"""
    init_current_vm()

Allow initialization from running VM. Uses the first VM it finds.

# Example using JNA

```java
package zot.julia;

import com.sun.jna.Native;

public class Julia {
    static {
        Native.register("julia");
        jl_init__threading();
    }

    public static double bubba = Math.random();

    public static native void jl_init__threading();
    public static native void jl_eval_string(String code);
    public static native void jl_atexit_hook(int status);

    public static void main(String args[]) {
        System.out.println("test");
        jl_eval_string("println(\"test from Julia\")");
        jl_eval_string("using JavaCall");
        jl_eval_string("JavaCall.init_current_vm()");
        jl_eval_string("println(\"initialized VM\")");
        jl_eval_string("jlm = @jimport java.lang.Math");
        jl_eval_string("println(jcall(jlm, \"sin\", jdouble, (jdouble,), pi/2))");
        jl_eval_string("jl = @jimport zot.julia.Julia");
        System.out.println("Bubba should be " + bubba);
        jl_eval_string("println(\"bubba: \", jfield(jl, \"bubba\", jdouble))");
        jl_eval_string("println(\"Done with tests\")");
        jl_atexit_hook(0);
    }
}
```
"""
function init_current_vm()
    ppjvm = Array{Ptr{JavaVM}}(undef, 1)
    ppenv = Array{Ptr{JNIEnv}}(undef, 1)
    pnum = Array{Cint}(undef, 1)
    ccall(Libdl.dlsym(libjvm, :JNI_GetCreatedJavaVMs), Cint, (Ptr{Ptr{JavaVM}}, Cint, Ptr{Cint}), ppjvm, 1, pnum)
    global pjvm = ppjvm[1]
    jvm = unsafe_load(pjvm)
    global jvmfunc = unsafe_load(jvm.JNIInvokeInterface_)
    ccall(jvmfunc.GetEnv, Cint, (Ptr{Nothing}, Ptr{Ptr{JNIEnv}}, Cint), pjvm, ppenv, JNI_VERSION_1_8)
    global penv = ppenv[1]
    JNI.load_jni(penv)
end

function destroy()
    if (!isdefined(JavaCall, :penv) || penv == C_NULL)
        throw(JavaCallError("Called destroy without initialising Java VM"))
    end
    assertroottask_or_goodenv()
    res = ccall(jvmfunc.DestroyJavaVM, Cint, (Ptr{Nothing},), pjvm)
    res < 0 && throw(JavaCallError("Unable to destroy Java VM"))
    global penv=C_NULL; global pjvm=C_NULL;
end
