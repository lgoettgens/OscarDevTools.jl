const orgnames = Dict(
                     "AbstractAlgebra" => "Nemocas",
                     "Hecke" => "thofma",
                     "Nemo" => "Nemocas"
                )

const default_dev_dir = "oscar-dev"

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

function pkg_names(dir::AbstractString=default_dev_dir)
   return filter(x -> (isdir(joinpath(dir,x)) && x != "project"), readdir(dir))
end

function pkg_parsebranch(pkg::AbstractString, branch::AbstractString)
   fork = nothing
   if startswith(branch, "https://")
      urlmatch = match(r"https://github\.com/([-_\w]+)/[-_\w]+\.jl#(.*)", branch)
      isnothing(urlmatch) &&
         @error "could not parse org and branch from $branch"
      if urlmatch[1] != pkg_org(pkg)
         fork = urlmatch[1]
      end
      branch = urlmatch[2]
   end
   if isnothing(fork)
      return (nothing, branch, "$pkg#$branch")
   else
      return (fork, branch, "$pkg@$fork#$branch")
   end
end
