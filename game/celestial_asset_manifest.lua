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
    lava = {
        id = "pp_lava_nasa_pia00703",
        runtimePath = "assets/planet/studio/pp_lava_nasa_pia00703.png",
        masterPath = "docs/assets/masters/planet/pp_lava_nasa_pia00703_master.png",
        width = 128,
        height = 128,
        sha256 = "e155a770f2586e79616e302b1e8d821097b7085a9d044c58dcd86c9d823e3f32",
    },
    earth = {
        id = "pp_earth_nasa_as17_148_22727",
        runtimePath = "assets/planet/studio/pp_earth.png",
        masterPath = "docs/assets/masters/planet/pp_earth_nasa_as17_148_22727_master.png",
        width = 128,
        height = 128,
        sha256 = "9f6d517594f696491165c4fe4a5af8ae137b496d5593a175155d4e6b67cffb8e",
    },
}

return M