---
layout: default
---

#Memory management and Garbage Collection

In the typical use, memory management and garbage collection is automatic over both the Julia and Java runtimes. 

All objects returned from Java via the JNI interface has a local reference automatically created in the JVM, to prevent it from being garbage collected. On the Julia side, these object references are wrapped in a JavaObject object. Each JavaObject instance is associated with a finalizer, that deletes the java local reference to the java object when the julia wrapper goes out of reference. This enables the java object to be garbage collected when no longer needed on the Julia side. 

One importance caveat to remember is that the memory pressure on the Java and Julia heaps are different. Thus, even if a Julia object has gone out of reference, the Julia runtime may not run the garbage collector for a long time. Which keeps the java objects in memory, even when no longer required. If you are allocating large amount of Java objects, the JVM may run out of heap before the Julia runtime decides to run a garbage collection cycle. 

If you are facing this problem, the simple workaround is to manually run the Julia garbage collector, via the `gc()` call, occasionally. 

Any `Class` objects referenced in Julia (which includes a reference to objects of that class) is never freed. This is usually not a problem, since they do not usually consume large amounts of memory. That is, unless you are generating many anonymous classes (for example, via proxy objects). You may need to increase your `PermGen` space if this is a problem for you. 

There are possibly some leaks still left in the system, please report issues as you find them. 