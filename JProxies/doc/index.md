## JProxy
JProxy lets you use Java-like syntax to access fields and methods in Java. You can:
* Get field values
* Set field values
* Call methods
* Create static proxies to access static members
Primitive types and strings are converted to Julia objects on field accesses and method returns and converted back to Java types when sent as arguments to Java methods.
*NOTE: Because of this, if you need to call Java methods on a string that you got from Java, you'll have to use `JProxy(str)` to convert the Julia string to a proxied Java string*
To invoke static methods, set static to true (see below).
To get a JProxy's Java object, use `JavaObject(proxy)`
### Examples
```jldoctest
julia> a=JProxy(@jimport(java.util.ArrayList)(()))
[]
julia> a.size()
0
julia> a.add("hello")
true
julia> a.get(0)
"hello"
julia> a.isEmpty()
false

julia> a.toString()
"[hello]"

julia> b = a.clone()
[hello]

julia> b.add("derp")
true

julia> a == b
false

julia> b == b
true

julia> JProxy(@jimport(java.lang.System)).getName()
"java.lang.System"

julia> JProxy(@jimport(java.lang.System);static=true).out.println("hello")
hello
```
