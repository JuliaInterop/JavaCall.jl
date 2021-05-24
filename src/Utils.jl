module Utils

export chain, flatmap

function chain(itrs...)
    Base.Iterators.flatten(itrs)
end

function flatmap(f, c)
    map(f, c) |> Base.Iterators.flatten
end

function snakecase_from_camelcase(str::String)
    stringbuilder = IOBuffer()
    inuppercase = false
    for c in str
        if !inuppercase && isuppercase(c)
            print(stringbuilder, '_')
            inuppercase = true
        elseif inuppercase && islowercase(c)
            inuppercase = false
        end
        print(stringbuilder, lowercase(c))
    end
    String(take!(stringbuilder))
end

end
