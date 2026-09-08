local M = {}

-- Lane D runtime allowlist. Candidates stay out of the game until they are
-- explicitly added here after their Asset Studio provenance is verified.
M.planets = {
    bare = {
        id = "pp_bare_nasa_pia00405",
        runtimePath = "assets/planet/studio/pp_bare.png",
        masterPath = "docs/assets/masters/planet/pp_bare_master.png",
        width = 128,
        height = 128,
        sha256 = "9f85b29f1b62325fea3da53ab092ff5fc6fae4654073079483af0c5fabdfcb24",
    },
}

return M