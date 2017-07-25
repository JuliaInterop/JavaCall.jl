---
layout: default
---

#Types

Java types are mapped to native Julia types.

##Primitive Types

The Java primitive types are aliased to their corresponding types in Julia. When writing Julia code, it is usually convenient to use these aliases since they provide a direct correspondence when transcribing Java method signatures.

| Java Type        | Julia Alias           | Julia Type  |
| ------------- |-------------| -----|
| boolean      | jboolean | Uint8 |
| char      | jchar      |  Uint16  |
| int | jint      |    Int32 |
| long | jlong      |    Int64 |
| float | jfloat      |    Float32 |
| double | jdouble      |    Float64 |

##Java Objects

Any java object (as opposed to a primitive) is referenced in JNI via a pointer. In Julia this is a `Ptr{Void}`. The pointer to an object is wrapped into an instance of the `JavaObject{T}` composite type. The type parameter `T` is a symbol, and is the name of the Java class that the object belongs to. Thus, a java object of class `java.net.URL` will be stored in Julia as an instance of the composite type `JavaObject(:java.net.URL)` 

Java class identifiers (such as the `java.net.URL` above) cannot be expressed in Julia as a literal symbol, since the `.` is the composite field access operator. To express the required type, you will therefore have to write `JavaObject{symbol("java.net.URL")}`. This can get tedious very quickly. Therefore a `@jimport` macro is provided, which can covert a bare java type literal into the property parameterised `JavaObject` type. This type can then be aliased to a user defined name.

```julia
j_l_math = @jimport java.lang.Math
```

Some commonly used Java types have pre defined Julia aliases to make them easier to type

|Java Type|Julia Type| Julia Alias|
| ------- | -------- | ---------- |
| `java.lang.String` | `JavaObject{:java.lang.String}` | `JString` |
| `java.lang.Object` | `JavaObject{:java.lang.Object}` | `JObject` |

##Strings

A Java string object is represented in Julia as the `JString` type. A `JString` can be created from a plain Julia string using its constructor `JString(str::String)`. A `JString` object, returned, for example, from a Java method call, can be converted to a plain Julia string using the `bytestring(jstr::JString)` method.

##Multidimensional Arrays

Unlike Julia, Java doesn't support multidimensional arrays, but may emulate them using array of arrays, e.g.:

```java
double[][] create2DArray() { ... }
```

The result of such a function may be interpreted in Julia as both - `Vector{Vector{jdouble}}` or `Matrix{jdouble}`. JavaCall supports both cases (in the later case JavaCall also checks that all nested arrays have the same length):

```julia
jcall(obj, "create2DArray", Vector{Vector{jdouble}}, ())
jcall(obj, "create2DArray", Matrix{jdouble}, ())
```

Arrays with more than 2 dimensions are not supported, but one may still extract all the data using nested `Vector{...}` type, e.g.:

```julia
jcall(obj, "create3DArray", Vector{Vector{Vector{jdouble}}}, ())
```


##Conversions

The Julia representation of Java objects can be converted from one type to the other using the standard Julia `convert` method. 

```julia
convert(JObject, JString("hello"))
```

The conversion is checked, and will throw an error (equivalent to a java `ClassCastException`) if the object cannot be converted to the required type. Note that `jcall` will automatically attempt to convert the parameters to the specified types, and fail if the conversion fails. 

