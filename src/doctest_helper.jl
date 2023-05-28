using Pkg;

include("defaults.jl")

# checks the currently running julia version if it matches the
# version required for the doctests of a given package

function allow_doctests(pkg::Symbol, julia_version=VERSION)
   dep = first(filter(d->d.name == string(pkg), collect(values(Pkg.dependencies()))))

   if haskey(doctest_versions, pkg)
      for (pv, jvb) in doctest_versions[pkg]
         if dep.version >= pv
            return first(jvb) <= julia_version < last(jvb)
         end
      end
   end

   # fallback to LTS
   return v"1.6" <= julia_version < v"1.7"
end

function doctest_cmd(pkg::Symbol)
   mod = getproperty(@__MODULE__, pkg)
   setup = QuoteNode(isdefined(mod, :doctestsetup) ? mod.doctestsetup() : :(using $(pkg)))
   return quote
             DocMeta.setdocmeta!($pkg, :DocTestSetup, $setup; recursive = true); doctest($pkg)
          end
end

macro maybe_doctest(pkg::Symbol)
   if allow_doctests(pkg)
      return doctest_cmd(pkg)
   else
      msg = "Skipping doctest for $pkg due to julia version ($VERSION) mismatch."
      if haskey(ENV, "GITHUB_STEP_SUMMARY")
         open(ENV["GITHUB_STEP_SUMMARY"], "a") do io
            println(io, msg)
         end
      else
         println(msg)
      end
      return nothing
   end
end


