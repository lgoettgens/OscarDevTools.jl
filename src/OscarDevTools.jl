module OscarDevTools

import GitHub
import JSON
import TOML
import Pkg
import LibGit2

export oscar_develop, oscar_update, oscar_branch, oscar_add_remotes

include("helpers.jl")
include("githubci.jl")
include("devutils.jl")

end # module
