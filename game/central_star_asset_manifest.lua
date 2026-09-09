local M = {}

-- Lane D runtime allowlist for approved central-star candidates. The home
-- galaxy uses the "earth" star type even though its central star is the Sun.
M.stars = {
    earth = {
        id = "star_sun_nasa_gsfc_20171208_archive_e002035",
        runtimePath = "assets/star/studio/star_sun.png",
        runtimeSheetPath = "assets/star/studio/star_sun_sheet.png",
        masterPath = "docs/assets/masters/star/star_sun_nasa_gsfc_20171208_archive_e002035_master.png",
        width = 128,
        height = 128,
        sha256 = "ab996356769c32c16a0967329f94612092a45f4d93307780ee88dc12bd939a5a",
    },
    lava = {
        id = "star_filament_nasa_gsfc_20171208_archive_e002069",
        runtimePath = "assets/star/studio/star_filament.png",
        masterPath = "docs/assets/masters/star/star_filament_nasa_gsfc_20171208_archive_e002069_master.png",
        width = 128,
        height = 128,
        sha256 = "4925ef241b546e8bc6e371b51914d8fbcf90e7eda55f0dbe2002bd6f5d651ac5",
    },
    dry = {
        id = "star_cme_nasa_gsfc_20171208_archive_e001770",
        runtimePath = "assets/star/studio/star_cme.png",
        masterPath = "docs/assets/masters/star/star_cme_nasa_gsfc_20171208_archive_e001770_master.png",
        width = 128,
        height = 128,
        sha256 = "a75396e7083586f15f1e165917e11312a95e18dd956677de3ca7b4e333dca105",
    },
    gas = {
        id = "star_flare_nasa_gsfc_20171208_archive_e001058",
        runtimePath = "assets/star/studio/star_flare.png",
        masterPath = "docs/assets/masters/star/star_flare_nasa_gsfc_20171208_archive_e001058_master.png",
        width = 128,
        height = 128,
        sha256 = "e049d64e81561b3b66540972b0060016f6c57ea622d1a4d99bbb3349d5d34665",
    },
    bare = {
        id = "star_sdo_nasa_pia26681",
        runtimePath = "assets/star/studio/star_sdo.png",
        masterPath = "docs/assets/masters/star/star_sdo_nasa_pia26681_master.png",
        width = 128,
        height = 128,
        sha256 = "6774e2999a2bfc2cdd15d3a579db2b0312c8eb035417470aa38e87741a7b7d0f",
    },
}

return M