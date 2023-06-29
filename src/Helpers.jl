module Helpers

export default_dev_dir, pkg_org, pkg_from_repo, pkg_url, pkg_giturl,
       pkg_names, pkg_parsebranch, fork_from_repo

const orgnames = Dict(
                     "AbstractAlgebra" => "Nemocas",
                     "Hecke" => "thofma",
                     "Nemo" => "Nemocas"
                )

const non_jl_repo = [ "libpolymake-julia", "libsingular-julia" ]

const default_dev_dir = "oscar-dev"

pkg_org(pkg::AbstractString) = get(orgnames, pkg, "oscar-system")

pkg_repo(pkg::AbstractString) = pkg in non_jl_repo ? pkg : "$pkg.jl"

pkg_from_repo(repo) = isnothing(repo) ? nothing : match(r"/([-_\w]+)(?:\.jl)?$",repo)[1]

fork_from_repo(repo) = isnothing(repo) ? nothing : match(r"^([-_\w]+)/",repo)[1]

function pkg_url(pkg::AbstractString; full=true, fork=nothing)
   org = isnothing(fork) ? pkg_org(pkg) : fork
   return (full ? "https://github.com/" : "") * org * "/" * pkg_repo(pkg)
end

function pkg_giturl(pkg::AbstractString; fork=nothing)
   org = isnothing(fork) ? pkg_org(pkg) : fork
   return "git@github.com:$org/" * pkg_repo(pkg)
end

function pkg_names(dir::AbstractString=default_dev_dir)
   return filter(x -> (isdir(joinpath(dir,x)) && x != "project"), readdir(dir))
end

function pkg_parsebranch(pkg::AbstractString, branch::AbstractString)
   fork = nothing
   if startswith(branch, "https://")
      urlmatch = match(r"https://github\.com/([-_\w]+)/[-_\w]+(?:\.jl)?#(.*)", branch)
      isnothing(urlmatch) &&
         @error "could not parse org and branch from $branch"
      if urlmatch[1] != pkg_org(pkg)
         fork = urlmatch[1]
      end
      branch = urlmatch[2]
   end
   name = pkg
   isnothing(fork) || (name *= "@$fork")
   branch == "" || (name *= "#$branch")
   return (fork, branch, name)
end

end
