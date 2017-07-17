---
layout: default
---

#Reflection API

Sometimes it's impossible to infer exact object types and method signatures just from Javadocs. In such cases Java reflection API may be used to discover actual state of affairs. JavaCall provides convenient wrappers for the most import methods.

## Inspecting methods

Consider the case of generic collections:

```julia
JHashMap = @jimport java.util.HashMap
jmap = JHashMap(())
```
Because of [type erasure][1], JVM knows nothing about constraints of generic types and we can put any objects into `HashMap`. If we want to put a pair where both key and value are strings, we may naively write:

```julia
jcall(jmap, "put", JString, (JString, JString), "foo", "text value")
```

Which will immediately lead to the error:

> ERROR: Error calling Java: java.lang.NoSuchMethodError: put

This happens because although `HashMap` has a method called "put", in JVM this method has rather different signature. We can find it using function `listmethods`:

```
listmethods(jmap, "put")
# 1-element Array{JavaCall.JavaObject{Symbol("java.lang.reflect.Method")},1}:
# java.lang.Object put(java.lang.Object, java.lang.Object)
```

`listmethods()` returns an array of all object methods (represented as `JMethod` type), optionally filtering them by name. Julia than prints them so that you can inspect their signatures.

From the output of the previous command we see that `put()` expects 2 arguments of type `JObject` (alias to `java.lang.Object`) and returns an object of the same type. Now we can modify our call:


```julia
jcall(jmap, "put", JObject, (JObject, JObject), "foo", "text value")
```

Which works well. You can also inspect individual properties of Java methods using the following functions with self-explaining names:

 * `getname(::JMethod)`
 * `getreturntype(::JMethod)`
 * `getparametertypes(::JMethod)`


## Inspecting classes

Now imagine that somewhere later in the code we want to retrieve the value with the key "foo" from the map. The signature for this method is:

```julia
listmethods(jmap, "get")
# 1-element Array{JavaCall.JavaObject{Symbol("java.lang.reflect.Method")},1}:
#  java.lang.Object get(java.lang.Object)
```
So we can call this methods like this:

```julia
obj = jcall(jmap, "get", JObject, (JObject,), "foo")
# JavaCall.JavaObject{Symbol("java.lang.Object")}(Ptr{Void} @0x0000000000000000)
```
Note that this method returns an instance of `java.lang.Object`, although the underlying object may have a more narrow type. To call methods of underlying object in both - Java and Julia - we need to convert it to the expected type. E.g. in Java:

```java
HashMap map = new HashMap(); // note: no type parameters specified,
                             // so `map` is essentially a `HashMap<Object, Object>`
map.put("foo", "text value");
...
Object obj = map.get();
obj.trim();                  // compile-time error: Object doesn't have a method `trim()`

String str = (String)obj;
str.trim();                  // works fine
```
And in Julia:

```julia
jmap = JHashMap(())
jcall(jmap, "put", JObject, (JObject, JObject), "foo", "text value")
...
obj = jcall(jmap, "get", JObject, (JObject,), "foo")  # JavaObject{Symbol("java.lang.Object")}
jcall(obj, "trim", JString, ())  # run-time error: jcall can't find method `trim()` in `java.lang.Object`,
                                 # producing another `NoSuchMethodError`

str = convert(JString, obj)      # JavaObject{Symbol("java.lang.String")}
jcall(obj, "trim", JString, ())  # works fine
```

If we don't know exact type of the underlying object or want to save a couple of keystrokes, we can simply call `narrow`:

```
obj = jcall(jmap, "get", JObject, (JObject,), "foo")     # JavaObject{Symbol("java.lang.Object")}
narrow(obj)                                              # JavaObject{Symbol("java.lang.String")}
```

Other functions for inspecting object's class:

 * `getclass(obj::JavaObject)` - return an instance of `java.lang.Class` (aliases as `JClass`) representing `obj`'s class
 * `getname(cls::JClass)` - return the name of class `cls`


## Types are objects

Java relfection API isn't quite simple, working with it from Julia may be even harder. The reason is that you have to work with 4 different kinds of objects - Java types, Java objects, Julia types and Julia objects. Let's start with the Java side. 

In Java you normally work with objects, i.e. instances of classes, e.g. in:

```java
Foo foo = new Foo();
```
`Foo` is the name of the class and `foo` is an instance of that class. Just like `int` is the name of a type and `42` is an object of that type. 

In Julia syntax is different, but in general idea is the same:

```julia
bar = Bar()
```
`Bar` - name of a type, `bar` - an object of that type. 

JavaCall let's you treat Java classes (types of Java objects) just like you would normally do with other types:

```
JFoo = @jimport Foo    # import Java class Foo
jfoo = JFoo(())        # create an object of Java class Foo
```
This is how you normally use JavaCall and it should be pretty straightforward.

But both - in Julia and Java - **types/classes are themselves objects**! In Java, each class is an instance of `java.lang.Class` (e.g. `java.lang.Class<Foo>`) and in Julia each type is an object of type `DataType`. So when you have a name of a class/type at hand, you can treat them either as **types** or **objects**. For example in Java: 

```java
void myFunction(Foo foo) { ... }   // <-- Foo acts as a type, i.e. qualifier of
                                   //     objects that can be passed to the function

Class<Foo> fooClass = Foo.class             // <-- Foo acts as an object. You can create an instance of that class
Class<Foo> fooClass = Class.forName("Foo")  //     or call class methods (as opposed to instance methods) 
```

To access Java classes _as object_, Julia provides a special function:

```julia
foo_class = classforname("Foo")   # roughly equivalent to `Class.forName("Foo")` in Java
```

To summarize: 

 * `@jimport` makes Java class available as a type; this is how you normally work with Java classes
 * `classforname(...)` creates an object of `java.lang.Class` and returns a pointer to it







[1]: https://stackoverflow.com/questions/339699/java-generics-type-erasure-when-and-what-happens