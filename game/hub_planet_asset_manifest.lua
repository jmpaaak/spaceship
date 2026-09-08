local M = {}

-- Lane D runtime allowlist for approved hub-only candidates. Keys match the
-- hub's galaxy star type; ordinary and shop planets never consume this map.
M.hubs = {
    bare = {
        id = "hub_pluto_nasa_pia19952",
        runtimePath = "assets/planet/studio/hub_pluto.png",
        masterPath = "docs/assets/masters/planet/hub_pluto_nasa_pia19952_master.png",
        width = 128,
        height = 128,
        sha256 = "257e083294aa7634e482024a935262ec854c17d0df1ef5d400797720ca711b72",
    },
    ice = {
        id = "hub_neptune_nasa_pia00046",
        runtimePath = "assets/planet/studio/hub_neptune.png",
        masterPath = "docs/assets/masters/planet/hub_neptune_nasa_pia00046_master.png",
        width = 128,
        height = 128,
        sha256 = "52e387259e424c323a4e1417e5670b60c4c375ac30b9d7be24c9386b8295a29a",
    },
}

return M
