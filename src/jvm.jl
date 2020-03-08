const JNI_VERSION_1_1 = convert(Cint, 0x00010001)
const JNI_VERSION_1_2 = convert(Cint, 0x00010002)
const JNI_VERSION_1_4 = convert(Cint, 0x00010004)
const JNI_VERSION_1_6 = convert(Cint, 0x00010006)
const JNI_VERSION_1_8 = convert(Cint, 0x00010008)

const JNI_TRUE = convert(Cchar, 1)
const JNI_FALSE = convert(Cchar, 0)

# Return Values
const JNI_OK           = convert(Cint, 0)               #/* success */
const JNI_ERR          = convert(Cint, -1)              #/* unknown error */
const JNI_EDETACHED    = convert(Cint, -2)              #/* thread detached from the VM */
const JNI_EVERSION     = convert(Cint, -3)              #/* JNI version error */
const JNI_ENOMEM       = convert(Cint, -4)              #/* not enough memory */
const JNI_EEXIST       = convert(Cint, -5)              #/* VM already created */
const JNI_EINVAL       = convert(Cint, -6)              #/* invalid arguments */

const JAVA_HOME_CANDIDATES = ["/usr/lib/jvm/default-java/",
                              "/usr/lib/jvm/default/"]

function javahome_winreg()
    try
        keypath = "SOFTWARE\\JavaSoft\\Java Runtime Environment"
        value = querykey(WinReg.HKEY_LOCAL_MACHINE, keypath, "CurrentVersion")
        keypath *= "\\"*value
        return querykey(WinReg.HKEY_LOCAL_MACHINE, keypath, "JavaHome")
    catch
        try
            keypath = "SOFTWARE\\JavaSoft\\Java Development Kit"
            value = querykey(WinReg.HKEY_LOCAL_MACHINE, keypath, "CurrentVersion")
            keypath *= "\\"*value
            return querykey(WinReg.HKEY_LOCAL_MACHINE, keypath, "JavaHome")
        catch
            error("Cannot find an installation of Java in the Windows Registry. Please install a JRE/JDK, or set the JAVA_HOME environment variable if one is already installed.")
        end
    end
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

function addClassPath(s::String)
    if isloaded()
        @warn("JVM already initialised. This call has no effect")
        return
    end
    if s==""; return; end
    if endswith(s, "/*") && isdir(s[1:end-2])
        for x in s[1:end-1] .* readdir(s[1:end-2])
            endswith(x, ".jar") && push!(cp, x)
        end
        return
    end
    push!(cp, s)
    return
end

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

isloaded() = isdefined(JavaCall, :jnifunc) && isdefined(JavaCall, :penv) && penv != C_NULL

assertloaded() = isloaded() ? nothing : throw(JavaCallError("JVM not initialised. Please run init()"))
assertnotloaded() = isloaded() ? throw(JavaCallError("JVM already initialised")) : nothing

# Pointer to pointer to pointer to pointer alert! Hurrah for unsafe load
function init(opts)
    assertnotloaded()
    assertroottask_or_goodenv()
    opt = [JavaVMOption(pointer(x), C_NULL) for x in opts]
    ppjvm = Array{Ptr{JavaVM}}(undef, 1)
    ppenv = Array{Ptr{JNIEnv}}(undef, 1)
    vm_args = JavaVMInitArgs(JNI_VERSION_1_6, convert(Cint, length(opts)),
                             convert(Ptr{JavaVMOption}, pointer(opt)), JNI_TRUE)
    res = ccall(create, Cint, (Ptr{Ptr{JavaVM}}, Ptr{Ptr{JNIEnv}}, Ptr{JavaVMInitArgs}), ppjvm, ppenv,
                Ref(vm_args))
    res < 0 && throw(JavaCallError("Unable to initialise Java VM: $(res)"))
    global penv = ppenv[1]
    global pjvm = ppjvm[1]
    jnienv = unsafe_load(penv)
    jvm = unsafe_load(pjvm)
    global jvmfunc = unsafe_load(jvm.JNIInvokeInterface_)
    global jnifunc = unsafe_load(jnienv.JNINativeInterface_) #The JNI Function table
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
    jnienv = unsafe_load(penv)
    global jnifunc = unsafe_load(jnienv.JNINativeInterface_) #The JNI Function table
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
