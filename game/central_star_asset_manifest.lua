local M = {}

-- Lane D runtime allowlist for approved central-star candidates. The home
-- galaxy uses the "earth" star type even though its central star is the Sun.
M.stars = {
    earth = {
        id = "star_sun_nasa_gsfc_20171208_archive_e002035",
        runtimePath = "assets/star/studio/star_sun.png",
        masterPath = "docs/assets/masters/star/star_sun_nasa_gsfc_20171208_archive_e002035_master.png",
        width = 128,
        height = 128,
        sha256 = "ab996356769c32c16a0967329f94612092a45f4d93307780ee88dc12bd939a5a",
    },
}

return M