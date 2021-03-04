function fetch_project(repo::LibGit2.GitRepo)
   for remote in LibGit2.remotes(repo)
      LibGit2.fetch(repo; remote=remote)
   end
end

function add_remote(repo::LibGit2.GitRepo; fork=nothing)
   pkg = basename(LibGit2.path(repo))
   remote = isnothing(fork) ? "origin" : fork
   isnothing(LibGit2.lookup_remote(repo, remote)) || return

   @info "$pkg: adding remote '$remote'"
   url = pkg_url(pkg, fork=fork)
   if !github_repo_exists(pkg,fork)
      @warn "$pkg: no such repository at org '$fork'"
      return
   end
   LibGit2.GitRemote(repo, remote, url,
                              "+refs/heads/*:refs/remotes/$remote/*")
   LibGit2.set_remote_push_url(repo, remote, pkg_giturl(pkg, fork=fork))
   LibGit2.fetch(repo; remote=remote)
end

add_remote(pkgdir::AbstractString; kwargs...) = 
   add_remote(LibGit2.GitRepo(pkgdir); kwargs...)

function create_tracking_branch(repo::LibGit2.GitRepo, branch::AbstractString; remote::AbstractString="origin")
   pkg = basename(LibGit2.path(repo))
   @info "$pkg: creating branch '$branch' tracking from '$remote'"
   hash = LibGit2.GitHash(repo, "refs/remotes/$remote/$branch")
   LibGit2.branch!(repo, branch, string(hash); track="$remote")
   # for some reason LibGit2.jl does not set the correct upstream branch...
   LibGit2.with(LibGit2.GitConfig, repo) do cfg
      LibGit2.set!(cfg, "branch.$branch.remote", remote)
   end
end

function create_branch(repo::LibGit2.GitRepo, branch::AbstractString; start="origin/master")
   pkg = basename(LibGit2.path(repo))
   @info "$pkg: creating branch '$branch' (based on '$start')"
   fetch_project(repo)
   commit = start == "HEAD" ?
      LibGit2.head(repo) :
      LibGit2.lookup_branch(repo,"$start")
   isnothing(commit) && (commit = LibGit2.lookup_branch(repo,"$start", true))
   if !isnothing(commit)
      LibGit2.branch!(repo, branch, string(LibGit2.GitHash(commit)))
   else
      @warn "$pkg: start point '$start' not found"
   end
end

create_branch(pkgdir::AbstractString, branch; kwargs...) = create_branch(LibGit2.GitRepo(pkgdir), branch; kwargs...)

function update_project(repo::LibGit2.GitRepo)
   pkg = basename(LibGit2.path(repo))
   head = LibGit2.head(repo)
   upstream = LibGit2.upstream(head)
   if !isnothing(upstream)
      @info "$pkg: updating from '$(LibGit2.shortname(upstream))'"
      upstream = LibGit2.GitAnnotated(repo, upstream)
      fetch_project(repo)
      LibGit2.ffmerge!(repo, upstream)
   else
      @warn "$pkg: branch '$(LibGit2.shortname(head))' has no upstream"
   end
end

update_project(pkgdir::AbstractString) = update_project(LibGit2.GitRepo(pkgdir))

function checkout_branch(pkg::AbstractString, devdir::AbstractString; branch::AbstractString, fork=nothing, url=nothing)
   @info "$pkg: checkout branch '$branch'"
   # libgit2 is quite confusing...
   repo = LibGit2.GitRepo(devdir)
   LibGit2.fetch(repo; remote="origin")
   remote = LibGit2.lookup_remote(repo, isnothing(fork) ? "origin" : fork)
   # add new remote for fork if necessary
   if !isnothing(fork)
      add_remote(repo; fork=fork)
   end
   remote = LibGit2.name(remote)
   # check for branch
   commit = LibGit2.lookup_branch(repo,"$branch")
   if commit != nothing
      # switch branch and update
      LibGit2.branch!(repo, branch)
      update_project(devdir)
   else
      # create new tracking branch
      create_tracking_branch(repo, branch; remote=remote)
   end
end

function clone_project(pkg::AbstractString, devdir::AbstractString; branch::AbstractString, fork=nothing, url=nothing)
   @info "$pkg: cloning to '$devdir' (branch '$branch'):"
   if !isnothing(fork)
      # we create the main repo as well as the fork as upstream
      repo = LibGit2.clone(pkg_url(pkg; full=true), devdir)
      add_remote(repo; fork=fork)
      create_tracking_branch(repo, fork, branch)
   else
      repo = LibGit2.clone(url, devdir, branch=branch)
   end
   LibGit2.set_remote_push_url(repo,"origin", pkg_giturl(pkg))
end

function checkout_project(pkg::AbstractString, dir::AbstractString; branch::AbstractString="master", fork=nothing)
   (url, branch, fork) = find_branch(pkg, branch; fork=fork)
   devdir = abspath(joinpath(dir, pkg))
   if isdir(devdir)
      checkout_branch(pkg, devdir; branch=branch, fork=fork, url=url)
   else
      clone_project(pkg, devdir; branch=branch, fork=fork, url=url)
   end
   return devdir
end

function pkg_array_to_dict(pkgs::Array{String})
   pkgdict = Dict{String,Any}()
   for pkg in pkgs
      pkgre = match(r"(\w+)(?:#(.*))?", pkg)
      push!(pkgdict, pkgre[1] => pkgre[2])
   end
   return pkgdict
end

function oscar_develop(pkgs::Dict{String,Any}; dir=default_dev_dir, branch::AbstractString="master", fork=nothing, active_repo=nothing)
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
         for (pkg, pkgbranch) in pkgs
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

oscar_develop(pkgs::Array{String}; kwargs...) = 
   oscar_develop(pkg_array_to_dict(pkgs); kwargs...)

function oscar_update(; dir=default_dev_dir)
   for pkgdir in joinpath.(dir, pkg_names(dir))
      if isdir(joinpath(pkgdir,".git"))
         update_project(pkgdir)
      end
   end
   # update project after switching branches
   Pkg.activate(joinpath(dir,"project")) do
      Pkg.update()
   end
end

function oscar_add_remotes(pkgs::Array{String}, fork::AbstractString; dir=default_dev_dir)
   for pkgdir in joinpath.(dir, pkgs)
      if isdir(joinpath(pkgdir, ".git"))
         add_remote(pkgdir; fork=fork)
      end
   end
end

oscar_add_remotes(fork::AbstractString; dir=default_dev_dir) =
   oscar_add_remotes(pkg_names(dir), fork; dir=dir)

function oscar_branch(pkgs::Array{String}, branch::AbstractString; dir=default_dev_dir, start="origin/master")
   for pkgdir in joinpath.(dir, pkgs)
      if isdir(joinpath(pkgdir, ".git"))
         create_branch(pkgdir, branch; start=start)
      end
   end
   # update project after switching branches
   Pkg.activate(joinpath(dir,"project")) do
      Pkg.update()
   end
end


oscar_branch(branch::AbstractString; dir=default_dev_dir, start="origin/master") =
   oscar_branch(pkg_names(dir), branch; dir=dir, start=start)

