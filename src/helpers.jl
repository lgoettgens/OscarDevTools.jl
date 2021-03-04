const orgnames = Dict(
                     "AbstractAlgebra" => "Nemocas",
                     "Hecke" => "thofma",
                     "Nemo" => "Nemocas"
                )

pkg_org(pkg::AbstractString) = get(orgnames, pkg, "oscar-system")

pkg_from_repo(repo) = isnothing(repo) ? nothing : match(r"/(\w+).jl",repo)[1]

function pkg_url(pkg::AbstractString; full=true, fork=nothing)
   org = isnothing(fork) ? pkg_org(pkg) : fork
   return (full ? "https://github.com/" : "") * org * "/$pkg.jl"
end

function pkg_giturl(pkg::AbstractString; fork=nothing)
   org = isnothing(fork) ? pkg_org(pkg) : fork
   return "git@github.com:$org/$pkg.jl"
end
