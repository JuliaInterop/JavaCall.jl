---
layout: default
---

#Lifecycle and API

##Loading

When the module is first loaded, via `using` or `load`, it searches for the JVM dynamic library, `libjvm.so|libjvm.dylib|jvm.dll`. The search is dependent on the `JAVA_HOME` environment variable, which must be set, except on OSX, where the `/usr/libexec/java_home` command is used to infer it. In case the library is not found, the module load fails, and no further functionality is available. 

If the JVM library is now found even when it legitimately exists, a workaround is to set the `JAVA_LIB` environment variable to the path to library file. However, a better option will be a pull request updating the library search code. 

Currently, as a debugging aid, the module will print the location of the jvm library when it loads. 

##Initialisation

The `JavaCall.init(args::Array{String, 1})` method must to used to load and initialise the Java Virtual Machine before any other functions in this module can be called. The `args` parameter is an array containing JVM initialisation arguments. This can be used to set, for example, the system classpath, and the maximum Java heap. Any valid commandline argument to the `java` command can be used. Unrecognised arguments are silently discarded. 

```julia
JavaCall.init(["-Xmx512M", "-Djava.class.path=$(@__DIR__)", "-verbose:jni", "-verbose:gc"])
```

Note that only one JVM can be initialised within a process. Hence, the `init` function can be called only once per process. 

##Referencing types

As described in the [types][types.html] section, the @jimport macro returns the Julia type that corresponds to the relevant Java class. This Julia type can the be used a proxy for the Java type, and can be used for instantiating objects of that class, or calling static methods on it. 
```julia
jlm = @jimport "java.lang.Math"
jnu = @jimport java.net.URL
```
The syntax for importing inner classes is slightly different. 
```java
package myPackage;
public class Outer {
    public class Inner{
      public void innerMethod() {
        System.out.println("In Inner class Method");
      }
    }l
	public Inner createrInnerObject() {
      Inner innerObj=new Inner();
      return innerObj;
  }
}
```
To import the outer and inner clasess, one would use `Outer$Inner` instead of `Outer.Inner`. 
```julia
jouter=@jimport myPackage.Outer
jinner=@jimport myPackage.Outer$Inner
```
##Calling Static Methods

The primary interface to Java methods is the `jcall` function. Like the inbuilt Julia `ccall` function, you need to supply the return type, a tuple of the argument types, and the method arguments themselves. The first argument to jcall however is the receiver of the method in Java. In case of static methods therefore, the receiver is the Julia type corresponding to the Java class that holds the method. 

Arguments are converted if possible to the specified types, via the usual Julia `convert` function. This includes converting `JavaObject` instances referencing a particular java class, to a `JavaObject` referencing its superclass. This allows some measure of the polymorphism inherent in Java methods. Strings are automatically converted, and hence Julia strings may be passed directly into `jcall`. 

```julia
jcall(jlm, "sin", jdouble, (jdouble,), pi/2) #1.0
```

##Initialising Objects via Constructors
Each of the Julia `JavaObject` types contain a constructor that looks much like the `jcall` function. You provide a tuple of argument types, and the arguments themselves, and it return an instance of `JavaObject` that wraps a Java object of the corresponding class. Unlike `jcall` however, in this case the receiver and the return type is implicit, and does not need to specified. 

```julia
gurl = jnu((JString,), "http://www.google.com")
outerObj= jouter((),)
```

##Calling Instance Methods

Calling instance methods uses the `jcall` function, with an instance of the `JavaObject` type as the receiver. As before, the method takes as arguments the return type, the tuple of the argument types, and the arguments themselves. 

```julia
jcall(gurl, "getHost", JString,()) #"wwww.google.com"
innerObj=jcall(outerObj, "createrInnerObject", jinner,())
jcall(innerObj, "innerMethod", Nothing,()) #Prints "In Inner class Method"
```

##Calling Array Methods

Java arrays are referenced as Julia `Arrays` of the relevant (aliased) Java types. Hence a Java `int[]` is `Array{jint, 1}` in Julia. And similar for all other primitive types. All arrays of non-primitive Java objects are `Array{JavaObject{T}, 1}` in Julia, where `T` is the name of the relevant Java class. 

```julia
j_u_arrays = @jimport java.util.Arrays
jcall(j_u_arrays, "binarySearch", jint, (Array{jint,1}, jint), [10,20,30,40,50,60], 40)
jcall(j_u_arrays, "binarySearch", jint, (Array{JavaObject,1}, JavaObject), ["123","abc","uvw","xyz"], "uvw")
jcall(j_u_arrays, "copyOf", Array{jint, 1}, (Array{jint, 1}, jint), [1,2,3], 3)
jcall(j_u_arrays, "copyOf", Array{JObject, 1}, (Array{JavaObject, 1}, jint), ["a","b","c"], 3)
```

As noted in the introduction, only one dimensional arrays are currently supported. 

```julia
s=JString("Hello World")
```

When a Java string is returned from a method call, it can be converted to a Julia string using the `bytestring(s::JString)` function. 


#Unload

The `JavaCall.destroy` command will unload the JVM, destryoing all its references. Note however that even after calling destroy, a new JVM cannot be initialised in the same process. Initialising a JVM is a completely one way process. 
