#println("module JNI")
#println("import ..JavaCall: JNIEnv, JavaVM, jbyte, jchar, jshort, jint, jlong, jsize, jdouble, jfloat, jboolean")
#for t in ["jobject", "jclass", "jthrowable", "jweak", "jmethodID", "jfieldID",  "jstring", "jarray", "JNINativeMethod"]
#println("$t = Ptr{Nothing}")
#end
#for t in ["object", "boolean", "byte", "short", "int", "long", "float", "double", "char"]
#println("j$(t)Array = Ptr{Nothing}")
#end
#println("jvalue = Int64")
#println()
println("# === Below Generated by ",PROGRAM_FILE," ===")
println("")

function arg_name(m)
  m.captures[3]
end

function arg_value(m)
  #if m.captures[2] == "*" && m.captures[1] == "char" return "String($(m.captures[3]))" end
  if m.captures[3] == "env"
      "penv[]"
  else
     m.captures[3]
  end
end

decl_arg_type(m) = decl_arg_type(m.captures[1], m.captures[2])
ccall_arg_type(m; r=false) = ccall_arg_type(m.captures[1], m.captures[2], r=r)

function decl_arg_type(t, s)
  if s == "*"
    if t == "char"
      return "AnyString"
    elseif t == "void"
      return "Ptr{Nothing}"
    elseif t == "JNIEnv"
      return "Ptr{JNIEnv}"
    else
      return "Array{$t,1}"
#      return "Ptr{$t}"
    end
  elseif t == "jsize" #|| t == "jint" || t == "jlong" || t == "jshort" || t == "jbyte"
    return Integer
  end

  if t == "void"
    return "Nothing"
  end

  return s == "" ? t : "Array{$t,1}"
#  return s == "" ? t : "Ptr{$t}"
end

function ccall_arg_type(t, s; r=false)
  if s == "*"
    if t == "char"
      return "Cstring"
    elseif t == "void"
      return "Ptr{Nothing}"
    elseif t == "JNIEnv"
      return "Ptr{JNIEnv}"
    else
      return "Ptr{$t}"
    end
  end

  if t == "void"
    return "Nothing"
  end

  # No asterisk: type
  # If return type, Ptr
  # Else Array
  return s == "" ? t : r ? "Ptr{$t}" : "Array{$t,1}"
end

# julia_arg(m) = string(arg_name(m), "::", decl_arg_type(m))
function julia_arg(m)
    if arg_name(m) == "isCopy"
        "isCopy::PtrIsCopy"
    elseif arg_name(m) == "elems"
        string(arg_name(m), "::", "Ptr{$(m.captures[1])}") 
    else
        string(arg_name(m), "::", decl_arg_type(m))
    end
end

for line in open(readlines, "jnienv.jl", "r")
  # m: match comments
  # Example:
  # # jclass ( *GetSuperclass) (JNIEnv *env, jclass sub);
  # Group 1: Return type ((?:void|char|j\w+)) "jclass"
  # Group 2: Asterisk (\**) ""
  # Group 3: Function name (\w+) "GetSuperclass"
  # Group 4: Arguments \((.*)\) "JNIEnv *env, jclass sub"
  m = match(r"\# \s* (?:const\s*)? ((?:void|char|j\w+)) \s* (\**) \s* \( \s* \* (\w+) \s* \) \s* \((.*)\) \s* ;"x, line)
  if m === nothing continue end

  # Ignore functions with variable argument syntax
  # Only process vararg functions that end in A
  if occursin("...", m.captures[4]) continue end
  if occursin("va_list", m.captures[4]) continue end

  # Get return type
  rtype = ccall_arg_type(m.captures[1], m.captures[2], r=true)

  # Function name
  fname = m.captures[3]
  # Split arguments
  args = split(m.captures[4], ",")

  # mm: Analyze arguments
  # Example: [1] "JNIEnv *env", [2] "jclass sub"
  # Group 1: Argument type ((?:void|j\w+|char|JNI\w+|JavaVM))
  # Group 2: Asterisk (\**)
  # Group 3: Argument name (\w+)
  mm = map(x->match(r"^\s* (?:const\s+)? \s* ((?:void|j\w+|char|JNI\w+|JavaVM)) \s*? (\**) \s* (\w+) \s*$"x, x), args)

  # skip the JNIEnv arg for julia since it is passed as a global to ccall
  julia_args = join(map(julia_arg, mm)[2:end], ", ")
  arg_types = join(map(ccall_arg_type, mm), ", ")
  arg_names = join(map(arg_value, mm), ", ")

  # Commented out export command
  # print("#export $fname\n")
  print("$fname($julia_args) =\n  ccall(jniref[].$(fname), $rtype, ($arg_types,), $arg_names)\n\n")
end

# println("end")
println("")
println("# === Above Generated by ",PROGRAM_FILE," ===")