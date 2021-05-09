module IteratorUtils

export chain, flatmap

function chain(itrs...)
    Base.Iterators.flatten(itrs)
end

function flatmap(f, c)
    map(f, c) |> Base.Iterators.flatten
end

end
