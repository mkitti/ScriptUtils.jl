using ScriptUtils
using Documenter

DocMeta.setdocmeta!(ScriptUtils, :DocTestSetup, :(using ScriptUtils); recursive=true)

makedocs(;
    modules=[ScriptUtils],
    authors="Mark Kittisopikul <markkitt@gmail.com> and contributors",
    repo="https://github.com/mkitti/ScriptUtils.jl/blob/{commit}{path}#{line}",
    sitename="ScriptUtils.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://mkitti.github.io/ScriptUtils.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/mkitti/ScriptUtils.jl",
    devbranch="main",
)
