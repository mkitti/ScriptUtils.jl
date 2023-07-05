module Echo
    using ScriptUtils
    @default_init()
    main(args=ARGS) = echo(args)
    echo(args) = println(join(args, " "))
end
