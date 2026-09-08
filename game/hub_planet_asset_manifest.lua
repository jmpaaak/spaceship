local M = {}

-- Lane D runtime allowlist for approved hub-only candidates. Keys match the
-- hub's galaxy star type; ordinary and shop planets never consume this map.
M.hubs = {
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
