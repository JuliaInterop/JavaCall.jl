function Base.iterate(col::JProxy{<:java_lang})
    cl = getclass(pxyObj(col))
    info = infoFor(cl)
end
function Base.iterate(col::JProxy{<:java_util_AbstractCollection})
    i = col.iterator()
    nextGetter(col, i)()
end
Base.iterate(col::JProxy{<:java_util_AbstractCollection}, state) = state()
Base.IteratorSize(::JProxy{<:java_util_AbstractCollection}) = Base.HasLength()
Base.length(col::JProxy{<:java_util_AbstractCollection}) = col.size()

function nextGetter(col::JProxy{<:java_util_AbstractCollection}, iter)
    let pending = true, value # memoize value
        function ()
            if pending
                pending = false
                value = iter.hasNext() ? (iter.next(), nextGetter(col, iter)) : nothing
            else
                value
            end
        end
    end
end
