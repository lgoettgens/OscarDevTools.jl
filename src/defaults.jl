######
### defaults for julia-version, os and branches

const default_os = [ "ubuntu-latest" ]
const default_julia = [ "~1.6.0-0", "~1.8.0-0" ]
const default_branches = [ "<matching>", "release" ]

# for each package this contains an ordered list with
# pkg-version -> pair of lower and upper bound, more precisely:
# if pkgversion >= $version then check $lower <= julia_version < $upper
# newest entries should come first
# if no matching version is found the doctests will run with julia 1.6
const doctest_versions = Dict(
    :Oscar           => [v"0.12.1-DEV" => (v"1.8", v"1.11")],
    :Hecke           => [v"0.16.7"     => (v"1.8", v"1.9" )],
    :AbstractAlgebra => [v"0.29.5"     => (v"1.8", v"1.9" )],
    :Nemo            => [v"0.33.8"     => (v"1.8", v"1.9" )],
    :Singular        => [v"0.18.3"     => (v"1.8", v"1.9" )],
  )

### end defaults
######
