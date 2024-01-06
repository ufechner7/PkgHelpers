module PkgHelpers

using Pkg, TOML

export freeze, lower_bound, copy_manifest

"""
    lower_bound(pkg; julia=nothing, relaxed = false, copy_manifest=false, keep=true)

Adds the current package versions as lower bound to the compat section of the Project.toml file.

# Arguments
- pkg:           the module Pkg
- julia:         version string for Julia compatibility, e.g. "1" or "1.8"
- relaxed:       if set to `true`, the minor version number is omitted  
                 from the generated compat entries.
- copy_manifest: if `true`, create a copy of the current `Manifest.toml` file using
                 a naming scheme like "Manifest.toml-1.10-windows"
- keep:          if `true` (deftault) any existing compat entries are kept as is (maybe reordered)

# Examples
```julia-repl
using Pkg
lower_bound(Pkg)
```
"""
function lower_bound(pkg; julia=nothing, relaxed = false, copy_manifest=false, keep=true)
    if isnothing(julia)
        julia = juliaversion(true)
    end
    freeze1(pkg; julia=julia, relaxed=relaxed, lowerbound=true)
    if copy_manifest
        PkgHelpers.copy_manifest()
    end
end

"""
    freeze(pkg; julia=juliaversion(), relaxed = false, copy_manifest=false, keep=true)

Freezes the current package versions by adding them to the Project.toml file.

# Arguments

- pkg:           the module Pkg
- julia:         version string for Julia compatibility, e.g. "1" or "~1.8, ~1.9, ~1.10"
- relaxed:       if set to `true`, the minor version number is omitted from the generated  
                 compat entries. This means, non-breaking minor updates are allowed.
- copy_manifest: if `true`, create a copy of the current `Manifest.toml` file using
                 a naming scheme like "Manifest.toml-1.10-windows"
- keep:          if `true` (deftault) any existing compat entries are kept as is (maybe reordered)

For strict compatibility only add the Julia versions you tested your project with.

# Examples
```julia-repl
using Pkg, PkgHelpers
freeze(Pkg, copy_manifest=true)
freeze(Pkg; julia="~1.9, ~1.10", copy_manifest=true)
```
"""
function freeze(pkg; julia=nothing, relaxed = false, copy_manifest=false, keep=true)
    if isnothing(julia)
        julia = juliaversion()
    end
    freeze1(pkg; julia=julia, relaxed=relaxed)
    if copy_manifest
        PkgHelpers.copy_manifest()
    end
end

function freeze1(pkg; julia=nothing, relaxed = false, lowerbound=false, status="", mytoml="", keep=true)
    if isnothing(julia)
        julia=juliaversion()
    end
    project_file, prj_compat = project_compat(pkg, relaxed, lowerbound; status=status)
    push!(prj_compat, ("julia" => julia))
    if mytoml != ""
        project_file = mytoml
    end
    if prj_compat.count > 0
        dict = TOML.parsefile(project_file)
        ori_compat = Dict{String, String}(get(dict, "compat", ()))
        compat = merge_compats(ori_compat, prj_compat; keep=keep)
        dict["compat"] = compat
        open(project_file, "w") do io
            TOML.print(io, dict; sorted=true, by=toml_order)
        end
        println("Compat section now has $(compat.count) entries (was $(ori_compat.count)).")
    end
    nothing
end

function merge_compats(compat::Dict{String, String}, project_compat::Dict{String, String}; keep=true)
    if keep
        return merge(project_compat, compat)
    else
        return project_compat
    end
end

"""
    project_compat(pkg,relaxed,lowerbound; prn=false, status="")

Create a dictionary of package dependencies and their current versions.

Returns the full file name of the Project.toml file and the dictionary
`compat` that can be added to the Project.toml file to freeze the package
versions.

Returns the tuple (project_file, compat).
"""
function project_compat(pkg, relaxed, lowerbound; prn=false, status="")
    if status==""
        io = IOBuffer();
        pkg.status(; io=io)
        st = String(take!(io))
    else
        st = status
    end
    i = 1
    project_file=""
    compat = Dict{String, String}()
    for line in eachline(IOBuffer(st))
        if prn; println(line); end
        if occursin(".toml", line)
            project_file=line
        elseif occursin("] ", line)
            pkg_vers = split(line, "] ")[2]
            if occursin(" v", pkg_vers)
                pkg  = split(pkg_vers, " v")[1]
                vers = split(pkg_vers, " v")[2]
                if relaxed
                    vers_array=split(vers, '.')
                    vers=vers_array[1]*'.'*vers_array[2]
                end
                if lowerbound
                    push!(compat, (String(pkg)=>String("^"*vers)))
                elseif relaxed
                    push!(compat, (String(pkg)=>String("~"*vers)))
                else
                    push!(compat, (String(pkg)=>String("="*vers)))
                end
            end
        end
        i += 1
    end
    project_file = expanduser(split(project_file,'`')[2])
    project_file, compat
end

"""
    juliaversion(lowerbound=false)

Returns the version number in the form "~1.10" by default and in the form
"1.10" when called with the parameter `true`.
"""
function juliaversion(lowerbound=false)
    res=VERSION
    res = repr(Int64(res.major)) * "." * repr(Int64(res.minor))
    if ! lowerbound
        res = "~" * res
    end
    res
end

"""
    copy_manifest()

Create a copy of the current manifest, using a naming scheme like "Manifest.toml-1.10-windows"
which includes the major Julia version number and the name of the operating system to be
added and committed to git as backup.
"""
function copy_manifest()
    local os
    if Sys.iswindows()
        os = "-windows"
    elseif Sys.islinux()
        os = "-linux"
    else
        os = "-apple"
    end
    # check julia version
    ver = repr(Int64(VERSION.major)) * "." * repr(Int64(VERSION.minor))
    backup = "Manifest.toml-" * ver * os
    cp("Manifest.toml", backup; force=true)
    println("Created the file $(backup), please commit and push it to git!")
end

"""
    docu()

Display the HTML documentation in a browser window.
"""
function docu()
    if Sys.islinux()
        Base.run(`xdg-open "docs/build/index.html"`; wait=false)
    end
    nothing
end

"""
    toml_order(key)

Specify the correct order for the different items of the TOML files.
The keys `name`, `uuid`, `autors` and `version` occur in that order at the top of the TOML 
as keys pointing to string values.
They are followed by the `deps`, `compat`, `extras` and `targets` keys that point to 
dictionaries a level lower.
"""
function toml_order(key::S)::Union{Int, S} where {S<:AbstractString}
    d = Dict{String, Int}(
        "name" => 10,
        "uuid" => 20,
        "authors" => 30,
        "version" => 40,
        "deps" => 50,
        "compat" => 60,
        "extras" => 70,
        "targets" => 80,
    )
    return get(d, key, key)
end

end
