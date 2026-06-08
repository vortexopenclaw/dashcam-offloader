# NAS Dashcam Filename And Media Pattern Sampling

Private research pass from mounted NAS footage. Filenames below are sanitized to the original camera-looking token before any human description suffix.

## Viofo WM1

- Media files scanned: 20
- Pattern `YYYYMMDDHHMMSS_SEQ`: 17 file(s)
  - Examples: `20230302151958_000020.MP4`, `20230302184222_000093.MP4`, `20230302151458_000015.MP4`, `20230302211015_000117.MP4`
  - ffprobe `20230302151958_000020.MP4`: 2560x1440, h264, 28.1 Mbps, 60.0s
  - ffprobe `20230302184222_000093.MP4`: 2560x1440, h264, 27.7 Mbps, 60.0s
- Pattern `CYYYY`: 3 file(s)
  - Examples: `C0004.MP4`, `C0005.MP4`, `C0002.MP4`
  - ffprobe `C0004.MP4`: 3840x2160, h264, 55.1 Mbps, 126.1s
  - ffprobe `C0005.MP4`: 3840x2160, h264, 54.5 Mbps, 83.1s

## Viofo VS1

- Media files scanned: 50
- Pattern `YYYYMMDDHHMMSS_SEQ`: 37 file(s)
  - Examples: `20240411100943_002849.MP4`, `20240410172307_001841.MP4`, `20240410171907_001837.MP4`, `20240410171607_001834.MP4`
  - ffprobe `20240411100943_002849.MP4`: 2560x1440, h264, 25.4 Mbps, 60.0s
  - ffprobe `20240410172307_001841.MP4`: 2560x1440, h264, 25.4 Mbps, 60.0s
- Pattern `YYYYMMDDHHMMSS_SEQP`: 13 file(s)
  - Examples: `20240409191405_000506P.MP4`, `20240409165113_000362P.MP4`, `20240409165013_000361P.MP4`, `20240409113904_000045P.MP4`
  - ffprobe `20240409191405_000506P.MP4`: 2560x1440, h264, 6.6 Mbps, 60.0s
  - ffprobe `20240409165113_000362P.MP4`: 2560x1440, h264, 6.6 Mbps, 60.0s

## Viofo T130

- Media files scanned: 25
- Pattern `YYYY_MMDD_HHMMSS_I`: 13 file(s)
  - Examples: `2022_0303_095302_I.MP4`, `2022_0303_095402_I.MP4`, `2022_0228_102323_I.MP4`, `2022_0225_172804_I.MP4`
  - ffprobe `2022_0303_095302_I.MP4`: 1920x1080, h264, 9.0 Mbps, 60.0s
  - ffprobe `2022_0303_095402_I.MP4`: 1920x1080, h264, 9.0 Mbps, 31.2s
- Pattern `YYYY_MMDD_HHMMSS_F`: 7 file(s)
  - Examples: `2022_0303_095302_F.MP4`, `2022_0303_095402_F.MP4`, `2022_0228_102322_F.MP4`, `2022_0225_172802_F.MP4`
  - ffprobe `2022_0303_095302_F.MP4`: 2560x1440, h264, 27.7 Mbps, 60.0s
  - ffprobe `2022_0303_095402_F.MP4`: 2560x1440, h264, 27.7 Mbps, 31.4s
- Pattern `YYYY_MMDD_HHMMSS_R`: 3 file(s)
  - Examples: `2022_0303_095404_R.MP4`, `2022_0228_102323_R.MP4`, `2022_0303_095304_R.MP4`
  - ffprobe `2022_0303_095404_R.MP4`: 1920x1080, h264, 12.4 Mbps, 28.3s
  - ffprobe `2022_0228_102323_R.MP4`: 1920x1080, h264, 12.3 Mbps, 60.0s
- Pattern `IMG_YYYY`: 2 file(s)
  - Examples: `IMG_0153.MOV`, `IMG_0154.MOV`
  - ffprobe `IMG_0153.MOV`: 3840x2160, hevc, 22.4 Mbps, 11.0s
  - ffprobe `IMG_0154.MOV`: 3840x2160, hevc, 22.6 Mbps, 14.7s

## Viofo A129 Duo

- Media files scanned: 38
- Pattern `CYYYY`: 16 file(s)
  - Examples: `C0028.MP4`, `C0027.MP4`, `C0030.MP4`, `C0039.MP4`
  - ffprobe `C0028.MP4`: 3840x2160, h264, 56.8 Mbps, 30.0s
  - ffprobe `C0027.MP4`: 3840x2160, h264, 56.6 Mbps, 28.0s
- Pattern `YYYY_MMDD_HHMMSS_SEQF`: 11 file(s)
  - Examples: `2018_1129_095714_095F.MP4`, `2018_1129_095614_093F.MP4`, `2018_1129_095925_099F.MP4`, `2018_1129_100421_101F.MP4`
  - ffprobe `2018_1129_095714_095F.MP4`: 1920x1080, h264, 16.4 Mbps, 60.0s
  - ffprobe `2018_1129_095614_093F.MP4`: 1920x1080, h264, 16.4 Mbps, 60.0s
- Pattern `YYYY_MMDD_HHMMSS_SEQR`: 11 file(s)
  - Examples: `2018_1129_095714_096R.MP4`, `2018_1129_095614_094R.MP4`, `2018_1129_095925_100R.MP4`, `2018_1129_100421_102R.MP4`
  - ffprobe `2018_1129_095714_096R.MP4`: 1920x1080, h264, 16.4 Mbps, 60.0s
  - ffprobe `2018_1129_095614_094R.MP4`: 1920x1080, h264, 16.4 Mbps, 60.0s

## Viofo A129 Plus Duo

- Media files scanned: 17
- Pattern `YYYYMMDDHHMMSS_SEQF`: 7 file(s)
  - Examples: `20230215171321_202326F.MP4`, `20230215150617_000008F.MP4`, `20201015110013_000044F.MP4`, `20230216083635_202340F.MP4`
  - ffprobe `20230215171321_202326F.MP4`: 2560x1440, h264, 29.6 Mbps, 60.0s
  - ffprobe `20230215150617_000008F.MP4`: 2560x1440, h264, 11.6 Mbps, 28.3s
- Pattern `IMG_YYYY`: 3 file(s)
  - Examples: `IMG_0546.MOV`, `IMG_0548.MOV`, `IMG_0547.MOV`
  - ffprobe `IMG_0546.MOV`: 3840x2160, hevc, 22.6 Mbps, 20.4s
  - ffprobe `IMG_0548.MOV`: 3840x2160, hevc, 22.5 Mbps, 29.7s
- Pattern `YYYYMMDDHHMMSS_SEQPF`: 2 file(s)
  - Examples: `20230215151316_000014PF.MP4`, `20230215152053_000016PF.MP4`
  - ffprobe `20230215151316_000014PF.MP4`: 2560x1440, h264, 8.4 Mbps, 60.0s
  - ffprobe `20230215152053_000016PF.MP4`: 2560x1440, h264, 8.4 Mbps, 60.0s
- Pattern `YYYY_MMDD_HHMMSS_PF`: 2 file(s)
  - Examples: `2023_0215_152051_PF.MP4`, `2023_0215_151314_PF.MP4`
  - ffprobe `2023_0215_152051_PF.MP4`: 2560x1440, hevc, 9.8 Mbps, 45.0s
  - ffprobe `2023_0215_151314_PF.MP4`: 2560x1440, hevc, 9.8 Mbps, 45.0s
- Pattern `Dashcam`: 1 file(s)
  - Examples: `Dashcam.mp4`
  - ffprobe `Dashcam.mp4`: 3840x2160, h264, 45.3 Mbps, 576.8s
- Pattern `TikTok`: 1 file(s)
  - Examples: `TikTok.mp4`
  - ffprobe `TikTok.mp4`: 3840x2160, h264, 45.2 Mbps, 139.8s
- Pattern `YYYYMMDDHHMMSS_SEQR`: 1 file(s)
  - Examples: `20201015110013_000045R.MP4`
  - ffprobe `20201015110013_000045R.MP4`: 1920x1080, h264, 18.4 Mbps, 180.0s

## Viofo A129 Pro

- Media files scanned: 8
- Pattern `YYYYMMDD_HHMMSSF`: 2 file(s)
  - Examples: `20191126_093906F.MP4`, `20191120_154858F.MP4`
  - ffprobe `20191126_093906F.MP4`: 3840x2160, hevc, 51.2 Mbps, 60.0s
  - ffprobe `20191120_154858F.MP4`: 3840x2160, hevc, 51.2 Mbps, 60.0s
- Pattern `YYYYMMDD_HHMMSSPF`: 2 file(s)
  - Examples: `20191028_141003PF.MP4`, `20191110_165935PF.MP4`
  - ffprobe `20191028_141003PF.MP4`: 3840x2160, h264, 26.6 Mbps, 45.0s
  - ffprobe `20191110_165935PF.MP4`: 3840x2160, h264, 8.4 Mbps, 45.0s
- Pattern `YYYYMMDD_HHMMSSR`: 2 file(s)
  - Examples: `20191126_093906R.MP4`, `20191120_154858R.MP4`
  - ffprobe `20191126_093906R.MP4`: 1920x1080, hevc, 13.9 Mbps, 60.0s
  - ffprobe `20191120_154858R.MP4`: 1920x1080, hevc, 13.9 Mbps, 60.0s
- Pattern `YYYYMMDD_HHMMSS_SEQPF`: 1 file(s)
  - Examples: `20201022_115656_00285PF.MP4`
  - ffprobe `20201022_115656_00285PF.MP4`: 3840x2160, hevc, 8.4 Mbps, 45.0s
- Pattern `iPhone`: 1 file(s)
  - Examples: `iPhone.MP4`
  - ffprobe `iPhone.MP4`: 750x1334, h264, 1.5 Mbps, 295.1s

## Nextbase 622GW

- Media files scanned: 138
- Pattern `YYMMDD_HHMMSS_SEQ_FH`: 54 file(s)
  - Examples: `201125_075135_014_FH.MP4`, `201125_104859_085_FH.MP4`, `201125_105849_091_FH.MP4`, `201125_104505_080_FH.MP4`
  - ffprobe `201125_075135_014_FH.MP4`: 3840x2160, h264, 49.7 Mbps, 60.1s
  - ffprobe `201125_104859_085_FH.MP4`: 3840x2160, h264, 42.7 Mbps, 45.0s
- Pattern `YYMMDD_HHMMSS_SEQ_RH`: 27 file(s)
  - Examples: `201120_082835_077_RH.MP4`, `201124_164350_319_RH.MP4`, `201124_162817_307_RH.MP4`, `201124_162717_306_RH.MP4`
  - ffprobe `201120_082835_077_RH.MP4`: 1920x1080, h264, 12.0 Mbps, 45.0s
  - ffprobe `201124_164350_319_RH.MP4`: 1920x1080, h264, 12.0 Mbps, 60.1s
- Pattern `YYYYMMDD_HHMMSS_NF`: 14 file(s)
  - Examples: `20201125_085131_NF.mp4`, `20201122_154016_NF.mp4`, `20201122_153915_NF.mp4`, `20201121_190815_NF.mp4`
  - ffprobe `20201125_085131_NF.mp4`: 3840x2160, hevc, 25.1 Mbps, 60.0s
  - ffprobe `20201122_154016_NF.mp4`: 3840x2160, hevc, 24.1 Mbps, 61.0s
- Pattern `Nextbase`: 6 file(s)
  - Examples: `Nextbase.mp4`, `Nextbase.mp4`, `Nextbase.mp4`, `Nextbase.mp4`
  - ffprobe `Nextbase.mp4`: 3840x2160, h264, 30.2 Mbps, 11.9s
  - ffprobe `Nextbase.mp4`: 3840x2160, h264, 30.3 Mbps, 23.3s
- Pattern `GHAZYYYY`: 5 file(s)
  - Examples: `GHAZ0353.MP4`, `GHAZ0354.MP4`, `GHAZ0351.MP4`, `GHAZ0350.MP4`
  - ffprobe `GHAZ0353.MP4`: 3840x2160, h264, 55.3 Mbps, 60.1s
  - ffprobe `GHAZ0354.MP4`: 3840x2160, h264, 55.5 Mbps, 31.2s
- Pattern `GHAYYYYY`: 4 file(s)
  - Examples: `GHAY0347.MP4`, `GHAY0348.MP4`, `GHAY0346.MP4`, `GHAY0349.MP4`
  - ffprobe `GHAY0347.MP4`: 3840x2160, h264, 55.5 Mbps, 60.1s
  - ffprobe `GHAY0348.MP4`: 3840x2160, h264, 55.5 Mbps, 60.1s
- Pattern `IMG_YYYY`: 4 file(s)
  - Examples: `IMG_0649.MOV`, `IMG_0563.MOV`, `IMG_0660.MOV`, `IMG_7478.MOV`
  - ffprobe `IMG_0649.MOV`: 3840x2160, hevc, 39.5 Mbps, 32.2s
  - ffprobe `IMG_0563.MOV`: 3840x2160, hevc, 28.2 Mbps, 21.9s
- Pattern `YYYYMMDD_HHMMSS_EF`: 4 file(s)
  - Examples: `20201123_192230_EF.mp4`, `20201121_183225_EF.mp4`, `20201121_165946_EF.mp4`, `20201121_185923_EF.mp4`
  - ffprobe `20201123_192230_EF.mp4`: 3840x2160, hevc, 25.1 Mbps, 61.0s
  - ffprobe `20201121_183225_EF.mp4`: 3840x2160, hevc, 25.0 Mbps, 61.0s

## Nextbase iQ

- Media files scanned: 13
- Pattern `Nextbase`: 6 file(s)
  - Examples: `Nextbase.mp4`, `Nextbase.mov`, `Nextbase.mp4`, `Nextbase.mp4`
  - ffprobe `Nextbase.mp4`: 3840x2160, h264, 26.1 Mbps, 2183.8s
  - ffprobe `Nextbase.mov`: 2160x3840, h264, 62.0 Mbps, 51.5s
- Pattern `N)`: 5 file(s)
  - Examples: `4).mp4`, `2).mp4`, `3).mp4`, `5).mp4`
  - ffprobe `4).mp4`: 1920x1080, h264, 10.1 Mbps, 156.0s
  - ffprobe `2).mp4`: 3840x2160, h264, 66.6 Mbps, 71.4s
- Pattern `IMG_YYYY`: 2 file(s)
  - Examples: `IMG_7476.MOV`, `IMG_7477.MOV`
  - ffprobe `IMG_7476.MOV`: 3840x2160, hevc, 23.3 Mbps, 6.7s
  - ffprobe `IMG_7477.MOV`: 3840x2160, hevc, 22.7 Mbps, 9.9s

## Thinkware U1000

- Media files scanned: 224
- Pattern `IMG_YYYY`: 42 file(s)
  - Examples: `IMG_3109.MOV`, `IMG_3110.MOV`, `IMG_3703.MOV`, `IMG_3691.MOV`
  - ffprobe `IMG_3109.MOV`: 3840x2160, hevc, 22.1 Mbps, 29.3s
  - ffprobe `IMG_3110.MOV`: 3840x2160, hevc, 22.2 Mbps, 35.5s
- Pattern `REC_YYYY_MM_DD_HH_MM_SS_F`: 34 file(s)
  - Examples: `REC_2019_11_27_13_34_31_F.MP4`, `REC_2019_11_26_10_31_06_F.MP4`, `REC_2019_11_25_16_15_39_F.MP4`, `REC_2021_04_23_11_23_23_F.MP4`
  - ffprobe `REC_2019_11_27_13_34_31_F.MP4`: 3840x2160, hevc, 24.0 Mbps, 60.0s
  - ffprobe `REC_2019_11_26_10_31_06_F.MP4`: 3840x2160, hevc, 24.0 Mbps, 60.0s
- Pattern `PAK_YYYY_MM_DD_HH_MM_SS_F`: 23 file(s)
  - Examples: `PAK_2019_11_29_14_35_46_F.MP4`, `PAK_2020_10_08_13_45_40_F.MP4`, `PAK_2020_10_02_12_32_54_F.MP4`, `PAK_2020_10_08_19_38_39_F.MP4`
  - ffprobe `PAK_2019_11_29_14_35_46_F.MP4`: 3840x2160, hevc, 12.1 Mbps, 20.0s
  - ffprobe `PAK_2020_10_08_13_45_40_F.MP4`: 3840x2160, hevc, 12.0 Mbps, 20.0s
- Pattern `CYYYY`: 21 file(s)
  - Examples: `C0016.MP4`, `C0037.MP4`, `C0030.MP4`, `C0025.MP4`
  - ffprobe `C0016.MP4`: 3840x2160, h264, 55.1 Mbps, 56.6s
  - ffprobe `C0037.MP4`: 3840x2160, h264, 58.5 Mbps, 10.0s
- Pattern `RPReplay_FinalYYYYMMDDNN`: 20 file(s)
  - Examples: `RPReplay_Final1619529241.mp4`, `RPReplay_Final1619482084.mp4`, `RPReplay_Final1617138776.mp4`, `RPReplay_Final1617137830.MP4`
  - ffprobe `RPReplay_Final1619529241.mp4`: 888x1920, h264, 0.3 Mbps, 739.8s
  - ffprobe `RPReplay_Final1619482084.mp4`: 888x1920, h264, 2.2 Mbps, 261.6s
- Pattern `GXHHMMSS`: 18 file(s)
  - Examples: `GX014758.MP4`, `GX013837.MP4`, `GX014756.MP4`, `GX013833.MP4`
  - ffprobe `GX014758.MP4`: 5120x2880, hevc, 60.0 Mbps, 41.7s
  - ffprobe `GX013837.MP4`: 5120x2880, hevc, 60.0 Mbps, 55.9s
- Pattern `MAN_YYYY_MM_DD_HH_MM_SS_F`: 14 file(s)
  - Examples: `MAN_2021_03_28_14_13_03_F.MP4`, `MAN_2021_03_28_14_09_01_F.MP4`, `MAN_2021_03_28_13_38_17_F.MP4`, `MAN_2021_03_26_11_13_09_F.MP4`
  - ffprobe `MAN_2021_03_28_14_13_03_F.MP4`: 3840x2160, hevc, 24.0 Mbps, 60.0s
  - ffprobe `MAN_2021_03_28_14_09_01_F.MP4`: 3840x2160, hevc, 24.0 Mbps, 60.0s
- Pattern `MAN_YYYY_MM_DD_HH_MM_SS_R`: 13 file(s)
  - Examples: `MAN_2021_03_28_14_09_01_R.MP4`, `MAN_2021_03_28_13_38_17_R.MP4`, `MAN_2021_03_26_11_13_09_R.MP4`, `MAN_2021_03_26_11_08_27_R.MP4`
  - ffprobe `MAN_2021_03_28_14_09_01_R.MP4`: 2560x1440, hevc, 12.0 Mbps, 60.0s
  - ffprobe `MAN_2021_03_28_13_38_17_R.MP4`: 2560x1440, hevc, 12.0 Mbps, 60.0s

## Thinkware U1000 Plus

- Media files scanned: 303
- Pattern `MAN_YYYYMMDD_HHMMSS_F`: 69 file(s)
  - Examples: `MAN_20250407_204220_F.MP4`, `MAN_20250407_204052_F.MP4`, `MAN_20250407_203847_F.MP4`, `MAN_20250407_204339_F.MP4`
  - ffprobe `MAN_20250407_204220_F.MP4`: 3840x2160, hevc, 24.0 Mbps, 60.0s
  - ffprobe `MAN_20250407_204052_F.MP4`: 3840x2160, hevc, 24.0 Mbps, 60.0s
- Pattern `MAN_YYYYMMDD_HHMMSS_R`: 62 file(s)
  - Examples: `MAN_20250407_204052_R.MP4`, `MAN_20250407_203847_R.MP4`, `MAN_20250407_204220_R.MP4`, `MAN_20250407_204339_R.MP4`
  - ffprobe `MAN_20250407_204052_R.MP4`: 1920x1080, hevc, 6.0 Mbps, 60.0s
  - ffprobe `MAN_20250407_203847_R.MP4`: 1920x1080, hevc, 6.0 Mbps, 60.0s
- Pattern `REC_YYYYMMDD_HHMMSS_R`: 41 file(s)
  - Examples: `REC_20250302_132205_R.MP4`, `REC_20250325_060108_R.MP4`, `REC_20250325_055908_R.MP4`, `REC_20250325_055808_R.MP4`
  - ffprobe `REC_20250302_132205_R.MP4`: 1920x1080, hevc, 6.0 Mbps, 60.0s
  - ffprobe `REC_20250325_060108_R.MP4`: 1920x1080, hevc, 6.0 Mbps, 60.0s
- Pattern `REC_YYYYMMDD_HHMMSS_F`: 39 file(s)
  - Examples: `REC_20250211_060853_F.MP4`, `REC_20250302_132205_F.MP4`, `REC_20250325_060108_F.MP4`, `REC_20250325_055908_F.MP4`
  - ffprobe `REC_20250211_060853_F.MP4`: 3840x2160, hevc, 24.0 Mbps, 60.0s
  - ffprobe `REC_20250302_132205_F.MP4`: 3840x2160, hevc, 24.0 Mbps, 60.0s
- Pattern `IMG_YYYY`: 25 file(s)
  - Examples: `IMG_0020.MOV`, `IMG_0019.MOV`, `IMG_0018.MOV`, `IMG_0016.MOV`
  - ffprobe `IMG_0020.MOV`: 3840x2160, hevc, 22.4 Mbps, 14.2s
  - ffprobe `IMG_0019.MOV`: 3840x2160, hevc, 22.5 Mbps, 12.8s
- Pattern `MOT_YYYYMMDD_HHMMSS_F`: 23 file(s)
  - Examples: `MOT_20250405_131725_F.MP4`, `MOT_20250327_071536_F.MP4`, `MOT_20250327_071518_F.MP4`, `MOT_20250327_065738_F.MP4`
  - ffprobe `MOT_20250405_131725_F.MP4`: 3840x2160, hevc, 12.0 Mbps, 20.0s
  - ffprobe `MOT_20250327_071536_F.MP4`: 3840x2160, hevc, 12.1 Mbps, 12.7s
- Pattern `MOT_YYYYMMDD_HHMMSS_R`: 10 file(s)
  - Examples: `MOT_20250405_131725_R.MP4`, `MOT_20250327_071536_R.MP4`, `MOT_20250327_071518_R.MP4`, `MOT_20250327_065738_R.MP4`
  - ffprobe `MOT_20250405_131725_R.MP4`: 1920x1080, hevc, 3.0 Mbps, 20.0s
  - ffprobe `MOT_20250327_071536_R.MP4`: 1920x1080, hevc, 3.0 Mbps, 12.5s
- Pattern `PAK_YYYYMMDD_HHMMSS_F`: 5 file(s)
  - Examples: `PAK_20250410_061643_F.MP4`, `PAK_20250130_131401_F.MP4`, `PAK_20250423_133359_F.MP4`, `PAK_20250423_131556_F.MP4`
  - ffprobe `PAK_20250410_061643_F.MP4`: 3840x2160, hevc, 10.0 Mbps, 10.0s
  - ffprobe `PAK_20250130_131401_F.MP4`: 3840x2160, hevc, 12.2 Mbps, 20.0s

## Vantrue N4

- Media files scanned: 62
- Pattern `IMG_YYYY`: 33 file(s)
  - Examples: `IMG_5332.MOV`, `IMG_5226.MOV`, `IMG_5333.MOV`, `IMG_5642.MOV`
  - ffprobe `IMG_5332.MOV`: 3840x2160, hevc, 22.9 Mbps, 3.8s
  - ffprobe `IMG_5226.MOV`: 3840x2160, hevc, 22.8 Mbps, 13.1s
- Pattern `YYYY_MM_DD_HHMMSS_N_A`: 6 file(s)
  - Examples: `2022_08_02_112327_N_A.MP4`, `2022_08_02_105952_N_A.MP4`, `2022_08_02_105852_N_A.MP4`, `2022_08_16_201026_N_A.MP4`
  - ffprobe `2022_08_02_112327_N_A.MP4`: 2560x1440, hevc, 14.3 Mbps, 60.0s
  - ffprobe `2022_08_02_105952_N_A.MP4`: 2560x1440, hevc, 14.9 Mbps, 60.0s
- Pattern `YYYY_MM_DD_HHMMSS_E_A`: 5 file(s)
  - Examples: `2022_08_02_111152_E_A.MP4`, `2022_08_05_103619_E_A.MP4`, `2022_08_05_130324_E_A.MP4`, `2022_08_05_130352_E_A.MP4`
  - ffprobe `2022_08_02_111152_E_A.MP4`: 2560x1440, hevc, 15.6 Mbps, 49.6s
  - ffprobe `2022_08_05_103619_E_A.MP4`: 2560x1440, hevc, 10.6 Mbps, 33.0s
- Pattern `YYYY_MM_DD_HHMMSS_E_B`: 5 file(s)
  - Examples: `2022_08_02_111152_E_B.MP4`, `2022_08_05_103619_E_B.MP4`, `2022_08_05_130352_E_B.MP4`, `2022_08_05_130324_E_B.MP4`
  - ffprobe `2022_08_02_111152_E_B.MP4`: 1920x1080, hevc, 8.1 Mbps, 49.7s
  - ffprobe `2022_08_05_103619_E_B.MP4`: 1920x1080, hevc, 5.7 Mbps, 33.0s
- Pattern `YYYY_MM_DD_HHMMSS_N_B`: 4 file(s)
  - Examples: `2022_08_02_112327_N_B.MP4`, `2022_08_02_112427_N_B.MP4`, `2022_08_16_201821_N_B.MP4`, `2022_08_16_201921_N_B.MP4`
  - ffprobe `2022_08_02_112327_N_B.MP4`: 1920x1080, hevc, 8.0 Mbps, 60.0s
  - ffprobe `2022_08_02_112427_N_B.MP4`: 1920x1080, hevc, 3.2 Mbps, 5.5s
- Pattern `YYYY_MM_DD_HHMMSS_E_C`: 3 file(s)
  - Examples: `2022_08_05_103619_E_C.MP4`, `2022_08_05_130324_E_C.MP4`, `2022_08_05_130352_E_C.MP4`
  - ffprobe `2022_08_05_103619_E_C.MP4`: 1920x1080, hevc, 3.7 Mbps, 33.0s
  - ffprobe `2022_08_05_130324_E_C.MP4`: 1920x1080, hevc, 11.7 Mbps, 28.0s
- Pattern `YYYY_MM_DD_HHMMSS_P_A`: 3 file(s)
  - Examples: `2022_08_09_085539_P_A.MP4`, `2022_08_09_111538_P_A.MP4`, `2022_08_09_111338_P_A.MP4`
  - ffprobe `2022_08_09_085539_P_A.MP4`: 1280x720, hevc, 1.0 Mbps, 17.4s
  - ffprobe `2022_08_09_111538_P_A.MP4`: 1280x720, hevc, 1.3 Mbps, 60.0s
- Pattern `YYYY_MM_DD_HHMMSS_P_B`: 2 file(s)
  - Examples: `2022_08_09_085539_P_B.MP4`, `2022_08_09_111338_P_B.MP4`
  - ffprobe `2022_08_09_085539_P_B.MP4`: 1280x720, hevc, 0.7 Mbps, 17.5s
  - ffprobe `2022_08_09_111338_P_B.MP4`: 1280x720, hevc, 0.8 Mbps, 60.0s

## Vantrue N4 Pro

- Media files scanned: 8
- Pattern `CYYYY`: 7 file(s)
  - Examples: `C0058.MP4`, `C0057.MP4`, `C0059.MP4`, `C0054.MP4`
  - ffprobe `C0058.MP4`: 3840x2160, h264, 55.8 Mbps, 32.0s
  - ffprobe `C0057.MP4`: 3840x2160, h264, 55.9 Mbps, 56.6s
- Pattern `IMG_YYYY`: 1 file(s)
  - Examples: `IMG_2113.MOV`
  - ffprobe `IMG_2113.MOV`: 3840x2160, hevc, 22.4 Mbps, 11.6s

## Vantrue N5

- Media files scanned: 42
- Pattern `YYYYMMDD_HHMMSS_SEQ_N_C`: 12 file(s)
  - Examples: `20240614_125501_00080_N_C.MP4`, `20240614_111052_00060_N_C.MP4`, `20240614_094814_00008_N_C.MP4`, `20240614_145052_00127_N_C.MP4`
  - ffprobe `20240614_125501_00080_N_C.MP4`: 1920x1080, hevc, 9.8 Mbps, 60.0s
  - ffprobe `20240614_111052_00060_N_C.MP4`: 1920x1080, hevc, 9.8 Mbps, 60.0s
- Pattern `YYYYMMDD_HHMMSS_SEQ_N_A`: 10 file(s)
  - Examples: `20240614_125501_00080_N_A.MP4`, `20240614_111052_00060_N_A.MP4`, `20240614_094814_00008_N_A.MP4`, `20240614_150355_00130_N_A.MP4`
  - ffprobe `20240614_125501_00080_N_A.MP4`: 2592x1944, hevc, 16.0 Mbps, 60.0s
  - ffprobe `20240614_111052_00060_N_A.MP4`: 2560x1440, hevc, 14.3 Mbps, 60.0s
- Pattern `YYYYMMDD_HHMMSS_SEQ_N_B`: 10 file(s)
  - Examples: `20240614_125501_00080_N_B.MP4`, `20240614_111052_00060_N_B.MP4`, `20240614_094814_00008_N_B.MP4`, `20240614_150355_00130_N_B.MP4`
  - ffprobe `20240614_125501_00080_N_B.MP4`: 1920x1080, hevc, 9.8 Mbps, 60.0s
  - ffprobe `20240614_111052_00060_N_B.MP4`: 1920x1080, hevc, 9.8 Mbps, 60.0s
- Pattern `YYYYMMDD_HHMMSS_SEQ_N_D`: 10 file(s)
  - Examples: `20240614_111052_00060_N_D.MP4`, `20240614_125501_00080_N_D.MP4`, `20240614_094814_00008_N_D.MP4`, `20240614_100742_00023_N_D.MP4`
  - ffprobe `20240614_111052_00060_N_D.MP4`: 1920x1080, hevc, 9.8 Mbps, 60.0s
  - ffprobe `20240614_125501_00080_N_D.MP4`: 1920x1080, hevc, 9.8 Mbps, 60.0s

## Vantrue E360

- Media files scanned: 13
- Pattern `YYYYMMDD_HHMMSS_SEQ_N_A`: 4 file(s)
  - Examples: `20250613_101202_00004_N_A.MP4`, `20250613_101302_00005_N_A.MP4`, `20250613_101502_00007_N_A.MP4`, `20250613_101402_00006_N_A.MP4`
  - ffprobe `20250613_101202_00004_N_A.MP4`: 5184x1944, h264, 28.7 Mbps, 60.0s
  - ffprobe `20250613_101302_00005_N_A.MP4`: 5184x1944, h264, 28.7 Mbps, 60.0s
- Pattern `CYYYY`: 2 file(s)
  - Examples: `C0147.MP4`, `C0148.MP4`
  - ffprobe `C0147.MP4`: 3840x2160, h264, 55.9 Mbps, 9.5s
  - ffprobe `C0148.MP4`: 3840x2160, h264, 55.8 Mbps, 12.5s
- Pattern `IMG_YYYY`: 2 file(s)
  - Examples: `IMG_4435.MOV`, `IMG_4436.MOV`
  - ffprobe `IMG_4435.MOV`: 3840x2160, hevc, 22.8 Mbps, 8.9s
  - ffprobe `IMG_4436.MOV`: 3840x2160, hevc, 22.9 Mbps, 8.9s
- Pattern `How`: 1 file(s)
  - Examples: `How.mov`
  - ffprobe `How.mov`: 3840x2160, h264, 40.0 Mbps, 77.0s
- Pattern `RPReplay_FinalYYYYMMDDNN`: 1 file(s)
  - Examples: `RPReplay_Final1749348388.MP4`
  - ffprobe `RPReplay_Final1749348388.MP4`: 886x1920, hevc, 5.3 Mbps, 157.8s
- Pattern `Vantrue`: 1 file(s)
  - Examples: `Vantrue.mov`
  - ffprobe `Vantrue.mov`: 4096x2304, h264, 50.2 Mbps, 466.0s
- Pattern `YYYYMMDD_HHMMSS_SEQ_E_A`: 1 file(s)
  - Examples: `20250430_091136_00009_E_A.MP4`
  - ffprobe `20250430_091136_00009_E_A.MP4`: 5184x1944, h264, 28.7 Mbps, 60.0s
- Pattern `YYYYMMDD_HHMMSS_SEQ_E_C`: 1 file(s)
  - Examples: `20250430_091136_00009_E_C.MP4`
  - ffprobe `20250430_091136_00009_E_C.MP4`: 2560x1440, h264, 14.4 Mbps, 60.0s

## 70mai T800

- Media files scanned: 2
- Pattern `How`: 1 file(s)
  - Examples: `How.mov`
  - ffprobe `How.mov`: 2160x3840, h264, 62.5 Mbps, 119.1s
- Pattern `NNmai`: 1 file(s)
  - Examples: `70mai.mov`
  - ffprobe `70mai.mov`: 3840x2160, h264, 40.7 Mbps, 189.8s

## 70mai M310

- Media files scanned: 77
- Pattern `NOYYYYMMDD-HHMMSS-SEQ`: 48 file(s)
  - Examples: `NO20260215-102943-001357.mp4`, `NO20260216-184203-001732.mp4`, `NO20260216-184103-001731.mp4`, `NO20260216-183402-001724.mp4`
  - ffprobe `NO20260215-102943-001357.mp4`: 2304x1296, hevc, 12.0 Mbps, 60.1s
  - ffprobe `NO20260216-184203-001732.mp4`: 2304x1296, hevc, 12.0 Mbps, 60.0s
- Pattern `IMG_YYYY`: 11 file(s)
  - Examples: `IMG_0013.MOV`, `IMG_0021.MOV`, `IMG_0017.MOV`, `IMG_0019.MOV`
  - ffprobe `IMG_0013.MOV`: 3840x2160, hevc, 22.2 Mbps, 9.3s
  - ffprobe `IMG_0021.MOV`: 3840x2160, hevc, 22.7 Mbps, 16.4s
- Pattern `LAYYYYMMDD-HHMMSS-SEQ`: 8 file(s)
  - Examples: `LA20260210-125940-000945.mp4`, `LA20260210-064052-000867.mp4`, `LA20260209-180337-000828.mp4`, `LA20260209-173336-000827.mp4`
  - ffprobe `LA20260210-125940-000945.mp4`: 2304x1296, hevc, 12.0 Mbps, 60.1s
  - ffprobe `LA20260210-064052-000867.mp4`: 2304x1296, hevc, 12.0 Mbps, 60.0s
- Pattern `YYYYMMDD_HHMMSS`: 3 file(s)
  - Examples: `20260217_115048.mp4`, `20260217_115449.mp4`, `20260217_115142.mp4`
  - ffprobe `20260217_115048.mp4`: 3840x2160, hevc, 94.6 Mbps, 27.3s
  - ffprobe `20260217_115449.mp4`: 3840x2160, hevc, 95.0 Mbps, 47.9s
- Pattern `Amazon`: 2 file(s)
  - Examples: `Amazon.mov`, `Amazon.mov`
  - ffprobe `Amazon.mov`: 3840x2160, h264, 40.0 Mbps, 105.7s
  - ffprobe `Amazon.mov`: 3840x2160, h264, 40.1 Mbps, 120.3s
- Pattern `CYYYY`: 2 file(s)
  - Examples: `C0021.MP4`, `C0017.MP4`
  - ffprobe `C0021.MP4`: 3840x2160, h264, 56.7 Mbps, 91.1s
  - ffprobe `C0017.MP4`: 3840x2160, h264, 54.3 Mbps, 37.0s
- Pattern `Screencap`: 2 file(s)
  - Examples: `Screencap.MP4`, `Screencap.MP4`
  - ffprobe `Screencap.MP4`: 1180x2556, hevc, 0.9 Mbps, 17.6s
  - ffprobe `Screencap.MP4`: 1180x2556, hevc, 3.6 Mbps, 174.3s
- Pattern `NNmai`: 1 file(s)
  - Examples: `70mai.mov`
  - ffprobe `70mai.mov`: 3840x2160, h264, 40.0 Mbps, 1140.2s

## 70mai 4K Omni

- Media files scanned: 93
- Pattern `IMG_YYYY`: 32 file(s)
  - Examples: `IMG_3808.MOV`, `IMG_3785.MOV`, `IMG_3807.MOV`, `IMG_3806.MOV`
  - ffprobe `IMG_3808.MOV`: 3840x2160, hevc, 49.1 Mbps, 14.6s
  - ffprobe `IMG_3785.MOV`: 3840x2160, hevc, 22.7 Mbps, 42.7s
- Pattern `PAYYYYMMDD-HHMMSS-SEQF`: 21 file(s)
  - Examples: `PA20250516-090428-001934F.MP4`, `PA20250516-090509-001935F.MP4`, `PA20250517-125129-001979F.MP4`, `PA20250513-085532-000890F.MP4`
  - ffprobe `PA20250516-090428-001934F.MP4`: 3840x2160, hevc, 31.9 Mbps, 30.0s
  - ffprobe `PA20250516-090509-001935F.MP4`: 3840x2160, hevc, 32.4 Mbps, 6.0s
- Pattern `NOYYYYMMDD-HHMMSS-SEQF`: 15 file(s)
  - Examples: `NO20250527-201527-002194F.MP4`, `NO20250501-160315-000060F.MP4`, `NO20250516-092236-001949F.MP4`, `NO20250516-092136-001948F.MP4`
  - ffprobe `NO20250527-201527-002194F.MP4`: 3840x2160, hevc, 31.9 Mbps, 60.1s
  - ffprobe `NO20250501-160315-000060F.MP4`: 3840x2160, hevc, 60.3 Mbps, 60.0s
- Pattern `NOYYYYMMDD-HHMMSS-SEQR`: 5 file(s)
  - Examples: `NO20250527-201427-002193R.MP4`, `NO20250527-200116-002186R.MP4`, `NO20250527-232214-002224R.MP4`, `NO20250527-201527-002194R.MP4`
  - ffprobe `NO20250527-201427-002193R.MP4`: 1920x1080, hevc, 10.9 Mbps, 60.0s
  - ffprobe `NO20250527-200116-002186R.MP4`: 1920x1080, hevc, 10.9 Mbps, 57.4s
- Pattern `CYYYY`: 4 file(s)
  - Examples: `C0061.MP4`, `C0065.MP4`, `C0062.MP4`, `C0063.MP4`
  - ffprobe `C0061.MP4`: 3840x2160, h264, 58.5 Mbps, 13.0s
  - ffprobe `C0065.MP4`: 3840x2160, h264, 58.5 Mbps, 33.0s
- Pattern `YYYY_MMDD_HHMMSS_SEQPI`: 4 file(s)
  - Examples: `2025_0527_153759_167186PI.MP4`, `2025_0527_153659_167183PI.MP4`, `2025_0527_200330_167798PI.MP4`, `2025_0527_200230_167795PI.MP4`
  - ffprobe `2025_0527_153759_167186PI.MP4`: 1920x1080, h264, 3.9 Mbps, 22.0s
  - ffprobe `2025_0527_153659_167183PI.MP4`: 1920x1080, h264, 3.9 Mbps, 60.0s
- Pattern `YYYY_MMDD_HHMMSS_SEQPR`: 4 file(s)
  - Examples: `2025_0527_153659_167184PR.MP4`, `2025_0527_200330_167799PR.MP4`, `2025_0527_200230_167796PR.MP4`, `2025_0527_153759_167187PR.MP4`
  - ffprobe `2025_0527_153659_167184PR.MP4`: 2560x1440, h264, 4.1 Mbps, 60.0s
  - ffprobe `2025_0527_200330_167799PR.MP4`: 2560x1440, h264, 4.1 Mbps, 60.0s
- Pattern `NNmai`: 2 file(s)
  - Examples: `70mai.mov`, `70mai.MP4`
  - ffprobe `70mai.mov`: 3840x2160, h264, 40.0 Mbps, 1107.3s
  - ffprobe `70mai.MP4`: 886x1920, hevc, 4.2 Mbps, 208.2s
