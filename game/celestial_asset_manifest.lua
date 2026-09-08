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
    gas = {
        id = "pp_gas_nasa_pia01518",
        runtimePath = "assets/planet/studio/pp_gas.png",
        masterPath = "docs/assets/masters/planet/pp_gas_nasa_pia01518_master.png",
        width = 128,
        height = 128,
        sha256 = "b03789fa874d42fe1c627ca0742883ffebbdc7a6fe89a5e0b85a036d5cadbd25",
    },
    dry = {
        id = "pp_dry_nasa_pia00407",
        runtimePath = "assets/planet/studio/pp_dry.png",
        masterPath = "docs/assets/masters/planet/pp_dry_nasa_pia00407_master.png",
        width = 128,
        height = 128,
        sha256 = "e05a74ddaadb122957e0a7e839aaa835f2af3cc2b5387eeb1c28f7d71b3fbebd",
    },
    ice = {
        id = "pp_ice_nasa_pia00353",
        runtimePath = "assets/planet/studio/pp_ice_nasa_pia00353.png",
        masterPath = "docs/assets/masters/planet/pp_ice_nasa_pia00353_master.png",
        width = 128,
        height = 128,
        sha256 = "8963191009096a3ccd9e16755f4aa55cca10059a08f316d73ce8f7254e83c537",
    },
}

return M