# OscarDevTools.jl

This is a utility package for the [OSCAR project](https://github.com/oscar-system/Oscar.jl).

It provides functions for managing julia project directories to facilitate developing OSCAR, e.g. by quickly checking out or creating matching branches in several OSCAR repositories at once.

In addition, it contains GitHub Actions code to run downstream tests, e.g. to check if a new PR in `Polymake.jl` would break the tests in `Oscar.jl`. The code will automatically look up matching branches from the different repositories which makes it possible to test larger refactoring efforts spanning across multiple repositories.

## DevUtils - OSCAR development utilities

The OSCAR development functions are based on a `oscar-dev` directory containing clones for some OSCAR packages and a corresponding julia project directory `oscar-dev/project`.

The most important (exported) functions are the following:

  - `oscar_branch([pkgs,] branchname)`: will create new local branches (`branchname`) for all given (or all already cloned) packages in the current development directory.
  - `oscar_develop(pkgs; branch="master")`: will clone all packages given in `pkgs`, check out a new tracking branch `branch`, and add the directories to the the julia project.
  - `oscar_update()`: will update all current checkouts (similar to running `git pull --ff-only` in each directory).
  - `oscar_add_remotes(forkname)`: will add a new git remote to all packages to allow pushing branches to a fork (which must be created on GitHub first).

All functions support a `dir::String="oscar-dev"` keyword argument to specify the development directory.
Please see the docstrings for these functions for more details on the possible arguments, e.g. via `?oscar_develop`.

To publish a branch created by these functions please go to the corresponding directory (e.g. `oscar-dev/Oscar`) and run `git push --set-upstream forkname` (or `origin` instead of `forkname` if you want to push to the main repository). After pushing all branches, you can create pull requests on GitHub and when `OscarCI` is set up (see below) it will run the corresponding tests automatically.

## OscarCI - GitHub Actions workflow for automated downstream testing

There is a workflow file in [`.github/workflows/oscar.yml`](https://github.com/oscar-system/OscarDevTools.jl/blob/master/.github/workflows/oscar.yml) that should work in any other repository as well and will run all the tests as specified in the [`OscarCI.toml`](https://github.com/oscar-system/OscarDevTools.jl/blob/master/OscarCI.toml) file which should be placed in the main directory of the repository. (Please do not use the other `oscar-something.yml` files as they are adjusted just for testing in this repository)

The general workflow is as follows: 
1. The `OscarCI.toml` metadata file lists the default test-environment, a list of OSCAR packages with the corresponding branches to use, and an optional list of extra test configurations.
2. If the tests are run for a pull request the code will determine the branchname for the pull request and try to look up identically named branches for all other packages that are listed in the TOML file and add these branches to the list.
3. GitHub Actions will expand these different branch-lists to a (large?) matrix and for each entry (plus the extra configurations) `oscar_develop` will be used to create a new project with the corresponding configuration.
4. For each such configuration tests will be run for `Oscar.jl`, other packages can also be tested by adding `test = true` in the corresponding `pkgs` entry.

An example of a more elaborate `OscarCI.toml` file:

```toml
title = "metadata for oscar CI run"

# keep it small to prevent job-explosion
[env]
os = [ "ubuntu-latest" ]
julia-version = [ "~1.6.0-0" ]

# packages not listed here will use the latest release
[pkgs]
  [pkgs.Oscar]
  branches = [ "master", "release" ]
  test = true

  [pkgs.Hecke]
  branches = [ "master", "release" ]
  test = true
  testoptions = [ "short" ]

[include]
  [include.macos]
  Oscar = "master"
  Hecke = "master"
  os = "macos-latest"
  julia-version = "~1.6.0-0"

  [include.julia]
  Oscar = "master"
  Hecke = "master"
  julia-version = "1.5"
  os = "ubuntu-latest"

  [include.singular]
  Oscar = "master"
  Singular = "master"
  os = "ubuntu-latest"
  julia-version = "~1.6.0-0"
```

This will test the currently active project (which might be `Nemo.jl` for example) in combination with `master`, latest release and (if it exists) the matching branch from the PR for both Oscar and Hecke. Tests will also run for `Hecke.jl` but with `test_args=["short"]`.
In addition, it will run these tests on julia 1.5, MacOS and together with the latest `Singular.jl` branch `master`.

Specifying extra tests to run in the `[include]` section is not supported (yet?).
