module PkgHelpers

# freeze the current package versions; overwrites the current Project.toml file
using Pkg, TOML

export freeze, create_project

"""
    freeze(julia=juliaversion())

Freezes the current package versions by adding them to the Project.toml file.

Parameters:

- julia:   version string for Julia compatibility, e.g. "1" or "~1.8, ~1.9, ~1.10"
- relaxed: if set to `true`, the minor version number is omitted from the generated  
           compat entries. This means, non-breaking minor updates are allowed.

For strict compatibility only add the Julia versions you tested your project with.
The parameters `status` and `mytoml` are internal and only needed for the unit tests.
"""
function freeze(pkg; julia=juliaversion(), relaxed = false, status="", mytoml="")
    function printkv(io, dict, key)
        if key in keys(dict)
            value = dict[key]
            if key == "authors"
                println(io, "$key = ", value)
            else
                println(io, "$key = \"", value, "\"")
            end
        end
    end
    function print_section(io, dict, key)
        if key in keys(dict)
            println(io)
            println(io, "[$(key)]")
            TOML.print(io, dict[key])
        end
    end
    project_file, compat = project_compat(pkg, relaxed; status=status)
    if mytoml != ""
        project_file = mytoml
    end
    if compat.count > 0
        dict = (TOML.parsefile(project_file))
        push!(compat, ("julia" => julia))
        open(project_file, "w") do io
            printkv(io, dict, "name")
            printkv(io, dict, "uuid")
            printkv(io, dict, "authors")
            printkv(io, dict, "version")
            print_section(io, dict, "deps")
            println(io)
            println(io, "[compat]")
            TOML.print(io, compat)
            print_section(io, dict, "extras")
            print_section(io, dict, "targets")
        end
    end
    println("Added $(compat.count) entries to the compat section!")
    nothing
end

"""
    project_compat(pkg, prn=false)

Create a dictionary of package dependencies and their current versions.

Returns the full file name of the Project.toml file and the dictionary
`compat` that can be added to the Project.toml file to freeze the package
versions.
"""
function project_compat(pkg, relaxed; prn=false, status="")
    if status==""
        io = IOBuffer();
        pkg.status(; io)
        st = String(take!(io))
    else
        st = status
    end
    i = 1
    project_file=""
    compat = Dict{String, Any}()
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
                push!(compat, (String(pkg)=>String("~"*vers)))
            end
        end
        i += 1
    end
    project_file = expanduser(split(project_file,'`')[2])
    project_file, compat
end

function test(mod::Module)
    io = IOBuffer();
    mod.status(; io)
    st = String(take!(io))
    println(st)
end

function juliaversion()
    res=VERSION
    "~" * repr(Int64(res.major)) * "." * repr(Int64(res.minor))
end

function create_project(name, packages=[])
    mkdir(name)
    cd(name)
    Pkg.activate(".")
    Pkg.status()
end

end
