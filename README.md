# PkgHelpers
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://ufechner7.github.io/PkgHelpers.jl/dev)
[![Build Status](https://github.com/ufechner7/PkgHelpers.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ufechner7/PkgHelpers.jl/actions/workflows/CI.yml?query=branch%3Amain)

## Introduction
This package provides the functions `freeze()` to freeze your Julia environment by adding the current versions of your package environment to the `[compat]` section of your project, and the function `lower_bound()` to set a lower bound of the versions of your packages.
If a `[compat]` section already exists it is overwritten without warning, so make a backup of your `Project.toml` file first.

### Background
For reproducible research it is important to document the version of all packages you used to
achieve a result that you published in a paper. This package makes it easy to do this. Compared to committing the `Manifest.toml` this approach has the following advantages:

- the project stays compatible with different Julia versions;
- changes in the git log are readable (I find the Manifest.toml file unreadable, YMMV).

Freezing your package versions has one more advantage: It can avoid unwanted package updates when adding new packages to your project.


## Installation

Add it to your global environment:  
```julia
using Pkg
Pkg.add("PkgHelpers") 
```
## Usage

Then change to the project you want to freeze or set a lower bound:
```bash
cd MyProject
julia --project
```
and on the Julia prompt type
```julia
using PkgHelpers, Pkg
freeze(Pkg)
```
or
```julia
using PkgHelpers, Pkg
lower_bound(Pkg)
```
This will overwrite your current `Project.toml`, so make sure you committed it to git before calling this function.

The following compat entries will be added for each of your direct dependencies:

| function                      | compat entry | range          | specifier  |
|-------------------------------|:------------:|:--------------:|:----------:|
| freeze(Pkg)                   | "=1.2.3"     | [1.2.3, 1.2.3] | equality   |
| freeze(Pkg; relax=true)       | "~1.2.3"     | [1.2.3, 1.3.0) | tilde      |
| lower_bound(Pkg)              | "^1.2.3"     | [1.2.3, 2.0.0) | caret      |
| lower_bound(Pkg; relax=true)  | "^1.2"       | [1.2.0, 2.0.0) | caret      |

Note that the care symbol (`^`) is not necessary in a version specifier.
Versions without a specifier are interpreted as a lower bound by default.
We include it only to be more explicit.

If you tested your project with the Julia versions 1.9 and 1.10, use the call
```julia
freeze(Pkg; julia="~1.9, ~1.10")
```
If you want to set as lower bound an older Julia version, you can also do that:
```julia
lower_bound(Pkg; julia="^1.6")
```
Optionally you can also call the function:
```
copy_manifest()
```
which creates a copy of the Manifest.toml file which includes the Julia version number
and operating system name and add and commit this file to git.

You can also use ranges, e.g.
```julia
freeze(Pkg; julia="1.6 - 1.11")
```
If you use a range there must be a space around the hyphen.

You can also call:
```julia
freeze(Pkg; relaxed=true)
```
This omits the patch version from the generated `compat` entry. The effect is that non-braking updates of the packages are allowed. While updates of the patch version SHOULD be non-braking, this is not always the case. Use this option with care.

More info about the version specifiers can be found [here](https://pkgdocs.julialang.org/v1/compatibility/).

### Keeping your existing compats
From version 0.3.0 onwards, there exists the `keep` keyword argument to both the `freeze` and `lower_bound` functions.
This argument when `true` (the default) will keep any existing compat entries from the Project.toml.
These compat _values_ are kept _exactly as is_ with all specifiers intact.
Their order may however be affected by the call to `freeze` or `lower_bound`.
Setting `keep` to `false` will result in the previous behaviour of the compat section being overwritten entirely.
