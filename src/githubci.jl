global gh_auth = nothing

function github_auth(;token::AbstractString="")
   if !isempty(token)
      global gh_auth = GitHub.authenticate(token)
   elseif haskey(ENV,"GITHUB_TOKEN")
      global gh_auth = GitHub.authenticate(ENV["GITHUB_TOKEN"])
   else
      @info "Using anonymous github auth"
      global gh_auth = GitHub.AnonymousAuth()
   end
end

github_repo(pkg::AbstractString; fork=nothing) = 
      GitHub.repo(pkg_url(pkg; full=false, fork=fork); auth=gh_auth)

parse_meta(file::AbstractString) = TOML.parsefile(file)

# we try to find a matching branch in the main repo for that pkg
# or in a given fork, or via a full 'url#branch'
function find_branch(pkg::AbstractString, branch::AbstractString; fork=nothing)
   isnothing(gh_auth) && github_auth()
   if startswith(branch, "https://")
      urlmatch = match(r"https://github\.com/([-\w]+)/\w+\.jl#(.*)", branch)
      if isnothing(urlmatch)
         @error "could not parse org and branch from $branch"
      end
      if urlmatch[1] == pkg_org(pkg)
         return find_branch(pkg, urlmatch[2])
      else
         return find_branch(pkg, urlmatch[2]; fork=urlmatch[1])
      end
   end
   @info "locating branch '$branch' for '$pkg'" * (isnothing(fork) ? "" : " (in fork '$fork')")
   if !isnothing(fork)
      try
         GitHub.reference(github_repo(pkg; fork=fork),
                                 "heads/$branch"; 
                                 auth=gh_auth)
         @info "  -> found in fork: '$fork'"
         return (pkg_url(pkg; full=true, fork=fork), branch, fork)
      catch
         @info "  -- not found in fork: '$fork'"
      end
   end
   if branch != "master"
      try
         GitHub.reference(github_repo(pkg), "heads/$branch"; auth=gh_auth)
         @info "  -> found in main repo"
         return (pkg_url(pkg; full=true), branch, nothing)
      catch
         @info "  -- not found in main repo"
      end
   end
   # fallback to master branch in default repo
   @warn "  ** branch $branch not found, using default 'master' branch"
   return (pkg_url(pkg; full=true), "master", nothing)
end

# generate a dict describing branches, includes, os and julia versions 
# for use in github actions
function ci_matrix(meta::Dict{String,Any}; pr=0, fork=nothing, active_repo=nothing)
   isnothing(gh_auth) && github_auth()

   matrix = Dict{String,Any}(meta["env"])
   active_pkg = pkg_from_repo(active_repo)

   pr_branch = ""
   if pr > 0 && !isnothing(active_pkg) && isnothing(fork)
      @info "fetching $active_pkg PR #$pr."
      ghpr = GitHub.pull_request(github_repo(active_pkg), pr; auth=gh_auth)
      # check if this comes from a fork
      if ghpr.head.repo.full_name != pkg_url(active_pkg; full=false)
         fork = ghpr.head.user.login
         pr_branch = ghpr.head.ref
      end
      # TODO: we might even look into pr.body and parse the branch from there?
      # e.g.: look for such a line
      # SomePkg.jl: otherUser/SomePkg.jl#branchname
   end
   
   # for each package lookup branch with the same name in fork and main repo
   for (pkg,branches) in meta["pkgs"]
      # ignore currently active repo
      pkg == active_pkg && continue
      if !isempty(pr_branch) && pr_branch != "master"
         (url, branch, fork) = find_branch(pkg, pr_branch; fork=fork)
         push!(branches,
               isnothing(fork) ? 
                  branch : 
                  "$url#$branch")
      end
      if !isempty(branches)
         matrix[pkg] = [Dict("name" => "$pkg#$branch", "branch" => branch)
                           for branch in branches]
      end
   end
   
   # add includes for custom configurations
   matrix["include"] = []
   for (_,inc) in meta["include"]
      named_include = Dict()
      for (obj,val) in inc
         if obj in ("os","julia-version")
            named_include[obj] = val
         else
            named_include[obj] = Dict("name" => "$obj#$val", "branch" => val)
         end
      end
      push!(matrix["include"],named_include)
   end
   return matrix
end

function parse_job(job_json::AbstractString)
   job_dict = JSON.parse(job_json)
   pkgdict = Dict{String,Any}(pkg => val["branch"] 
                                  for (pkg,val) in
                                  filter(p->(!in(first(p), ("os","julia-version"))),
                                         job_dict))
   return pkgdict
end

# this allows setting a github output variable 'matrix'
# which we can then use as input for the matrix-strategy
github_json(github_matrix::Dict{String,Any}) =
   "::set-output name=matrix::" * JSON.json(github_matrix)
