module Echo
    using ScriptUtils
    __init__() = ismain(@script) ? main(ARGS) : nothing
    main(args=ARGS) = echo(args)
    echo(args) = println(join(args, " "))
end
