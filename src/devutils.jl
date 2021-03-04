function create_tracking_branch(repo::LibGit2.GitRepo, remote::AbstractString, branch::AbstractString)
   hash = LibGit2.GitHash(repo,"refs/remotes/$remote/$branch")
   LibGit2.branch!(repo,branch,string(hash);track="$remote")
   # for some reason LibGit2.jl does not set the correct upstream branch...
   LibGit2.with(LibGit2.GitConfig, repo) do cfg
      LibGit2.set!(cfg, "branch.$branch.remote", remote)
   end
end

function update_project(pkg::AbstractString, devdir::AbstractString; branch::AbstractString, fork=nothing, url=nothing)
   @info "  updating '$pkg' in '$devdir':"
   # libgit2 is quite confusing...
   repo = LibGit2.GitRepo(devdir)
   LibGit2.fetch(repo; remote="origin")
   remote = LibGit2.lookup_remote(repo,isnothing(fork) ? "origin" : fork)
   # add fork remote if necessary
   if !isnothing(fork)
      if isnothing(remote)
         remote = LibGit2.GitRemote(repo,fork,url,"+refs/heads/*:refs/remotes/$fork/*")
         # TODO: test if we need that for pushing:
         #LibGit2.set_remote_push_url(repo,fork,repo_giturl(pkg,fork=fork))
      end
      LibGit2.fetch(repo; remote=fork)
   end
   remote = LibGit2.name(remote)
   # check for branch
   commit = LibGit2.lookup_branch(repo,"$branch")
   if commit != nothing
      @info "    switching to branch '$branch'"
      # switch branch and update
      LibGit2.branch!(repo,branch)
      upstream = LibGit2.upstream(commit)
      if isnothing(upstream)
         @warn "    branch '$branch' has no upstream"
      else
         @info "    updating '$branch'"
         upstream = LibGit2.GitAnnotated(repo,upstream)
         LibGit2.ffmerge!(repo,upstream)
      end
   else
      @info "    creating new branch '$branch' tracking from '$remote'"
      # create new tracking branch
      create_tracking_branch(repo,remote,branch)
   end
end

function clone_project(pkg::AbstractString, devdir::AbstractString; branch::AbstractString, fork=nothing, url=nothing)
   @info "  cloning '$pkg' in '$devdir':"
   if !isnothing(fork)
      # we create the main repo as well as the fork as upstream
      @info "    fetching main repo"
      repo = LibGit2.clone(repo_url(pkg;full=true), devdir)
      remote = LibGit2.GitRemote(repo,fork,url,"+refs/heads/*:refs/remotes/$fork/*")
      #LibGit2.set_remote_push_url(repo,fork,repo_giturl(pkg,fork=fork))
      @info "    fetching fork $fork"
      LibGit2.fetch(repo,remote=fork)
      @info "    creating new branch '$branch' tracking from '$fork'"
      create_tracking_branch(repo,fork,branch)
   else
      @info "    fetching and creating branch $branch"
      repo = LibGit2.clone(url, devdir, branch=branch)
      #LibGit2.set_remote_push_url(repo,"origin",repo_giturl(pkg))
   end
end

function checkout_project(pkg::AbstractString, dir::AbstractString; branch::AbstractString="", fork=nothing)
   (url,branch,fork) = find_branch(pkg, branch; fork=fork)
   @info "  developing '$pkg' using branch '$branch'\n          from $url"
   devdir = abspath(joinpath(dir,pkg))
   if isdir(devdir)
      update_project(pkg, devdir; branch=branch, fork=fork, url=url)
   else
      clone_project(pkg, devdir; branch=branch, fork=fork, url=url)
   end
   return devdir
end

function oscar_develop(pkgs::Dict{String,Any}; dir="oscar-dev", branch::AbstractString="", fork=nothing, active_repo=nothing)
   mkpath(dir)
   active_pkg = pkg_from_repo(active_repo)
   withenv("JULIA_PKG_DEVDIR"=>"$dir") do
      Pkg.activate(joinpath(dir,"project")) do
         @info "populating development directory '$dir':"
         if !isnothing(active_pkg)
            # during CI we always need to dev the active checkout
            @info "  reusing current dir for $active_pkg"
            Pkg.develop(path=".")
         end
         for (pkg,pkgbranch) in pkgs
            if pkg === active_pkg
               continue
            else
               if pkgbranch == "release"
                  # make sure we have that package added explicitly
                  Pkg.add(pkg)
               else
                  isnothing(pkgbranch) && (pkgbranch=branch)
                  devdir = checkout_project(pkg, dir; branch=pkgbranch, fork=fork)
                  Pkg.develop(path=devdir)
               end
            end
         end
      end
   end
   @info "Please start julia with:\njulia --project=$(abspath(joinpath(dir,"project")))"
end

function oscar_develop(pkgs::Array{String}; dir="oscar-dev", branch::AbstractString="", fork=nothing, active_repo=nothing)
   pkgdict = Dict{String,Any}()
   for pkg in pkgs
      pkgre = match(r"(\w+)(?:#(.*))?",pkg)
      push!(pkgdict, pkgre[1] => pkgre[2])
   end
   oscar_develop(pkgdict; dir=dir, branch, fork=fork, active_repo=active_repo)
end
