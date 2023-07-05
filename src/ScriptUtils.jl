"""
    ScriptUtils

Utility package for building scripts that loads a precompiled package.

The main concept is to enable small scripts that:
1) Activate the package environment in which they are contained.
2) Load the package
3) Execute a main function on `__init__`

Importantly, the main function will not be executed on module initialization
when loaded as a library from another package.

# Installation

To use this package, add ScriptUtils both to your default environment (e.g. v.1.9),
and your project package environment (e.g. Echo.jl as below).

```
using Pkg
Pkg.activate("/path/to/your/package")
Pkg.add("https://github.com/mkitti/ScriptUtils.jl")
Pkg.activate() # activate the default module
Pkg.add("https://github.com/mkitti/ScriptUtils.jl")
```

# Example

For example, we will create an Echo.jl package that can be run with
an echo.jl script.

The Echo.jl package has the following layout.
```
[drwxrwxr-x]  Echo.jl
├── [-rw-rw-r--]  Manifest.toml
├── [-rw-rw-r--]  Project.toml
├── [drwxrwxr-x]  scripts
│   └── [-rwxrwxr-x]  echo.jl
└── [drwxrwxr-x]  src
    ├── [-rw-rw-r--]  Echo.jl

2 directories, 4 files
```

Echo.jl/scripts/echo.jl has the following contents.
```
#!/bin/env julia
using ScriptUtils
@activate_dir ".."
using Echo
```

The `@activate_dir` macro finds the package environment, Echo.jl in this
example, and then activates the environment via `Pkg`.

Echo.jl/src/Echo.jl is a main package file and appears as follows.
```
module Echo
    using ScriptUtils
    @default_init()
    main(args=ARGS) = echo(args)
    echo(args) = println(join(args, " "))
end
```

The minimalist Project.toml declares ScriptUtils as a dependency.
```
name = "Echo"
uuid = "594283f3-b8da-40eb-8bd5-2e27980f0e39"

[deps]
ScriptUtils = "f569facd-b734-495c-9df5-0762dee8e069"
```

The script file can then be symlinked into the user's path (e.g. ~/bin) and
invoked as an executable script from any location.

```
\$ ln -s ~/src/Echo.jl/scripts/echo.jl ~/bin/

\$ echo.jl This is a test
  Activating project at `~/src/Echo.jl`
This is a test

# The package can still be loaded as a library and main will not run.
\$ julia --project=Echo.jl -e 'using Echo; Echo.echo(["Hello"])'
Hello
```

# Extended Help

## `@default_init` macro

The `@default_init()` macro declares the function `__init__` such that if the
`PROGRAM_FILE` is echo.jl, the lower case version of file name, then
`main(ARGS)` is run.

Echo.jl/src/Echo.jl can be expanded out if you would prefer to define your own
`__init__`:
```
module Echo
    using ScriptUtils
    __init__() = ismain(@script) ? main(ARGS) : nothing
    main(args=ARGS) = echo(args)
    echo(args) = println(join(args, " "))
end
```

## `@script` macro

Above, the `@script` macro locates a script file located in the `scripts`
directory. The default is the lowercase version of the calling file. The name
of the file can also be specified as an argument as below.

```
julia> @script("somefilename")
"~/src/Echo.jl/scripts/somefilename"
```
"""
module ScriptUtils
    export @activate_dir, @script, @default_init
    export @activate_and_use
    export ismain

    using Pkg

    """
        @activate_dir(relative_directory="..", always_quiet=false, popq=true))

    Activate a project environment directory relative to the current file.

    The default is to activate the parent directory of the directory where the
    file is located. If the script is located in the same folder as
    Project.toml, then specify `"."` as the first argument.

    `Pkg.activate` will print some text default to `stderr` by default about
    activating an environment. To suppress this output add a `-q` as the first
    argument. This `-q` will be removed from `ARGS` unless `popq` is `false`.

    The `always_quiet` positional argument will be always suppress
    `Pkg.activate` is set to true. The `-q` argument will not be used.
    """
    macro activate_dir(relative_dir="..", always_quiet=false, popq=true)
        script_file = String(__source__.file::Symbol)
        return :(ScriptUtils.activate_dir($relative_dir, $script_file, $always_quiet, $popq))
    end
    
    """
        activate_dir(relative_dir, script_file, always_quiet=false, popq=true)

    Supports the [`@activate_dir`](@ref) macro.
    """
    function activate_dir(relative_dir, script_file, always_quiet=false, popq=true)
        io = stdout
        if always_quiet
            popq = false
        end
        if always_quiet || length(ARGS) > 0 && ARGS[1] == "-q"
            io = devnull
            if popq
                popfirst!(ARGS)
            end
        end
        script_file = resolve_links(script_file)
        project_dir = joinpath(dirname(script_file), relative_dir)
        Pkg.activate(project_dir; io)
        Pkg.project()
    end

    """
        @activate_and_use(relative_dir="..", always_quiet=false, popq=true)

    Activate a project environment directory relative to the current file and
    use the associated package.

    See [`@activate_dir`](@ref) for details on the arguments.

    In addition to activating the environment, this macro will import the
    package using `Base.require`. If importing fails, then the macro will use
    `Pkg.instantiate()` before trying to import the package again.
    """
    macro activate_and_use(relative_dir="..", always_quiet=false, popq=true)
        script_file = String(__source__.file::Symbol)
        quote
            let pkg = ScriptUtils.activate_dir($relative_dir, $script_file, $always_quiet, $popq)
                try
                    Base.require(Main, Symbol(pkg.name))
                catch err
                    # Instantiate and try again
                    Pkg.instantiate()
                    Base.require(Main, Symbol(pkg.name))
                end
            end
        end
    end

    """
        @script(filename)

    Return the absolute path of a script file defaulting to scripts subdirectory
    of the package.
    """
    macro script(filename=nothing)
        if isnothing(filename)
            filename = lowercase(string(__module__, ".jl"))
        end
        #pkg_dir = dirname(dirname(String(__source__.file::Symbol)))
        pkg_dir = pkgdir(__module__)
        quote
            abspath(joinpath($pkg_dir, "scripts", $filename))
        end
    end

    """
        ismain(executable)

    Return true if the file specified by `executable` is equal to
    `PROGRAM_FILE`, resolving absolute paths and symbolic links.
    """
    function ismain(executable)
        @debug "ScriptUtils.ismain()" PROGRAM_FILE ARGS
        Base.isinteractive() && return false
        program_file = abspath(PROGRAM_FILE)
        program_file = resolve_links(program_file)
        @debug "ScriptUtils.ismain()" executable program_file
        return executable == program_file
    end

    """
        @default_init(script_file_absolute_path = nothing)

    Define a `__init__` function that will call `main(ARGS)` if a script file
    with the given absolute path is the `PROGRAM_FILE`.

    The default script file is lowercased name of the module with ".jl"
    appended in the scripts subfolder of the grandparent directory

    For example, if called from the file "Echo.jl/src/Echo.jl" then default
    script file will be "Echo.jl/script/echo.jl".
    """
    macro default_init(script_file=nothing)
        pkg_dir = dirname(dirname(pkg_file))
        if isnothing(script_file)
            script_file = abspath(joinpath(pkg_dir, "scripts", lowercase(string(__module__, ".jl"))))
        end
        esc(quote
            function __init__()
                if ScriptUtils.ismain($script_file)
                    main(ARGS)
                end
            end
        end)
    end

    """
        resolve_links(path)

    Recursively resolve symbol links.

    See also `islink` and `readlink`.
    """
    function resolve_links(path)
        while islink(path)
            path = readlink(path)
        end
        return path
    end
end
