module OscarDevTools

export oscar_develop, oscar_update, oscar_branch, oscar_add_remotes

include("Helpers.jl")
include("OscarCI.jl")
include("DevUtils.jl")

using .DevUtils

# for old CI yml files
import .OscarCI: parse_meta, ci_matrix, github_json, parse_job

end # module
