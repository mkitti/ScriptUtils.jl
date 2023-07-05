module MultipleScripts
    using ScriptUtils
    using StaticStrings
    __init__() =
        ismain(@script("cat.jl")) ? cat(ARGS) :
        ismain(@script("tail.jl")) ? tail(ARGS) :
        error("Unknown script: $PROGRAM_FILE")

    function cat(args)
        for arg in args
            printstyled(arg, color=:magenta)
            println(":")
            s = read(arg, String)
            println(s)
        end
    end
    function tail(args)
        for file in args
            println()
            printstyled(file, color=:magenta)
            println(":")
            _tail_one_file(file)
        end
    end
    function _tail_one_file(file, n=10)
        lines = Vector{String}(undef, n)
        counter = 0
        for line in eachline(file)
            counter += 1
            lines[mod1(counter, n)] = line
        end
        for i in 1:n
            j = mod1(counter+i, n)
            if isassigned(lines, j)
                println(lines[j])
            end
        end
    end
end
