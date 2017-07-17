---
layout: default
---

JavaCall supports iterating over Java collections (or anything exposing `java.util.Iterator` interface). E.g. the following code in Java:

```java
import java.util.ArrayList;

ArrayList<String> words = new ArrayList<>();
words.add("hello");
words.add("world");

for (String word : words) {
    System.out.println(word);
}

```

may be equivalently written in Julia as:

```julia
import JavaCall: iterator

JArrayList = @jimport java.util.ArrayList

words = JArrayList(())
jcall(words, "add", jboolean, (JObject,), "hello")
jcall(words, "add", jboolean, (JObject,), "world")

for word in iterator(words)
    println(word)
end
```