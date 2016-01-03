println("module JNI")
println("import ..JavaCall: JNIEnv, JavaVM, jbyte, jchar, jshort, jint, jlong, jsize, jdouble, jfloat, jboolean")
for t in ["jobject", "jclass", "jthrowable", "jweak", "jmethodID", "jfieldID", "jvalue",  "jstring", "jarray", "JNINativeMethod"]
println("typealias $t Ptr{Void}")
end
for t in ["object", "boolean", "byte", "short", "int", "long", "float", "double", "char"]
println("typealias j$(t)Array Ptr{Void}")
end
println()

function arg_name(m)
  m.captures[3]
end

function arg_value(m)
  if m.captures[2] == "*" && m.captures[1] == "char" return "utf8($(m.captures[3]))" end
  m.captures[3]
end

decl_arg_type(m) = decl_arg_type(m.captures[1], m.captures[2])
ccall_arg_type(m; r=false) = ccall_arg_type(m.captures[1], m.captures[2], r=r)

function decl_arg_type(t, s)
  if s == "*"
    if t == "char"
      return "AbstractString"
    elseif t == "void"
      return "Ptr{Void}"
    elseif t == "JNIEnv"
      return "Ptr{JNIEnv}"
    else
      return "Array{$t,1}"
    end
  elseif t == "jsize" #|| t == "jint" || t == "jlong" || t == "jshort" || t == "jbyte"
    return Integer
  end

  if t == "void"
    return "Void"
  end

  return s == "" ? t : "Array{$t,1}"
end

function ccall_arg_type(t, s; r=false)
  if s == "*"
    if t == "char"
      return "Cstring"
    elseif t == "void"
      return "Ptr{Void}"
    elseif t == "JNIEnv"
      return "Ptr{JNIEnv}"
    else
      return "Ptr{$t}"
    end
  end

  if t == "void"
    return "Void"
  end

  return s == "" ? t : r ? "Ptr{$t}" : "Array{$t,1}"
end

julia_arg(m) = string(arg_name(m), "::", decl_arg_type(m))

for line in open(readlines, "jnienv.jl", "r")
  m = match(r"\# \s* ((?:void|j\w+)) \s* (\**) \s* \( \s* \* (\w+) \s* \) \s* \((.*)\) \s* ;"x, line)
  if m === nothing continue end

  if contains(m.captures[4], "...") continue end
  if contains(m.captures[4], "va_list") continue end

  rtype = ccall_arg_type(m.captures[1], m.captures[2], r=true)

  fname = m.captures[3]
  args = split(m.captures[4], ",")
  mm = map(x->match(r"^\s* (?:const\s+)? \s* ((?:void|j\w+|char|JNI\w+|JavaVM)) \s*? (\**) \s* (\w+) \s*$"x, x), args)

  julia_args = join(map(julia_arg, mm), ", ")
  arg_types = join(map(ccall_arg_type, mm), ", ")
  arg_names = join(map(arg_value, mm), ", ")

  print("export $fname\n")
  print("$fname($julia_args) =\n  ccall(Main.JavaCall.jnifunc.$(fname), $rtype, ($arg_types,), $arg_names)\n\n")
end

println("end")
