module JImport

export @jimport

using JavaCall.JavaCodeGeneration

macro jimport(expr)
    :($__module__.eval(loadclass(Symbol($expr))))
end

end
