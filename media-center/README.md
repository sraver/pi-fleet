# Media Center Box

## Overview

A Pi 5 that downloads TV shows and movies by itself and streams them to any
device on the LAN. Everything runs in Docker, and everything that matters lives
on an external USB SSD, not on the SD card.

```
 Prowlarr ──(indexers)──> Sonarr / Radarr ──(grab)──> qBittorrent
                                │                          │
                                └────(hardlink import)──────┘
                                             │
                                        /mnt/data/media
                                             │
                                          Jellyfin ──> TV, phone, laptop
```

- **Prowlarr** — one place to configure trackers; it syncs them into Sonarr and
  Radarr automatically
- **Sonarr / Radarr** — track wanted series and films, pick releases, rename and
  file them
- **qBittorrent** — the download client
- **Jellyfin** — library and streaming frontend

## Requirements

- Raspberry Pi 5 (4GB is enough, 8GB comfortable), active cooler, official 27W PSU
- A **high-endurance** SD card for the OS
- An external USB 3.0 SSD, in a UASP-capable enclosure
- Wired ethernet to the router

A 3.5" spinning disk works too, but it must be in a **self-powered** enclosure —
the Pi cannot supply enough current over USB and will brown out.

## Disk layout

The SD card holds only the OS and Docker itself. Everything with a meaningful
write rate goes on the SSD, so the card stays read-mostly and does not wear out:

```
/mnt/data/                (external SSD, ext4, label "mediadata")
├── appdata/              container configs + SQLite databases
│   ├── prowlarr/ sonarr/ radarr/ qbittorrent/ jellyfin/ jellyfin-cache/
├── downloads/            qBittorrent writes here and keeps seeding
└── media/
    ├── tv/               Sonarr hardlinks into here
    └── movies/           Radarr hardlinks into here
```

Two things about this layout are load-bearing:

**Downloads and media are on one filesystem.** Imports become hardlinks — instant,
and the seeding file and the library file share the same bytes instead of costing
double. Split them across devices and every import silently becomes a full copy.

**Every container sees the SSD at the same path** (`/data`). The path qBittorrent
reports for a finished download is the exact path Sonarr resolves. Mismatched path
mappings are the single most common failure in these stacks, and they present as
"file not found" imports on files that are plainly there.

Because `appdata/` lives on the SSD, the SD card is disposable: if it dies,
reburn it, boot, and every container picks its config and library back up.

## Set up

Using the current last version of RaspiOS Lite, **64-bit (arm64)**.

It must be the 64-bit build. LinuxServer.io dropped all 32-bit ARM (armhf)
images in July 2023, so on an armhf base the stack simply has no images to pull.
The Pi 5 is a 64-bit Cortex-A76 anyway; armhf would only throw away performance.

Download the `.img.xz` from
[raspberrypi.com/software](https://www.raspberrypi.com/software/operating-systems/)
([directory listing](https://downloads.raspberrypi.com/raspios_lite_arm64/images/)
if you want a specific release), verify it, and decompress it, since sdm
customizes a plain `.img`:

```
sha256sum -c 2026-09-15-raspios-trixie-arm64-lite.img.xz.sha256
xz -d 2026-09-15-raspios-trixie-arm64-lite.img.xz
```

Put your public key in `../assets/authorized_keys`, then adjust the variables at
the top of `ezsdm.sh` if you want a different hostname, user or timezone.

Then customize the image:

```
./ezsdm.sh 2026-09-15-raspios-trixie-arm64-lite.img
```

Then burn it into your SD:

```
sudo sdm --burn /dev/sdX 2026-09-15-raspios-trixie-arm64-lite.img
```

The image ships with Docker, the compose file at `/opt/media-center`, the fstab
entry, and a `media-center.service` unit already enabled.

## First boot

sdm FirstBoot runs, appends the fstab entry and reboots.

The stack is deliberately enabled with `service-enable-at-boot`, so it does not
try to start until *after* that reboot — by then the fstab entry is live. On a
brand new disk it will fail on purpose, because there is nothing labelled
`mediadata` to mount yet.

SSH in and prepare the disk. **This erases the target device:**

```
lsblk -f                          # find the SSD
sudo /opt/media-center/prepare-disk.sh /dev/sda
```

That partitions it, formats ext4 with label `mediadata`, and mounts it at
`/mnt/data`. Then start the stack:

```
sudo systemctl start media-center
journalctl -u media-center -f     # first run pulls ~2GB of images
```

From then on it comes up on every boot.

## Use

| Service | URL |
|---|---|
| Jellyfin | `http://mediabox.local:8096` |
| Prowlarr | `http://mediabox.local:9696` |
| Sonarr | `http://mediabox.local:8989` |
| Radarr | `http://mediabox.local:7878` |
| qBittorrent | `http://mediabox.local:8080` |

Wiring it together, once:

1. **qBittorrent** — get the temporary admin password with
   `docker logs qbittorrent`, log in, change it. Set the default save path to
   `/data/downloads`.
2. **Prowlarr** — add indexers, then Settings → Apps → add Sonarr and Radarr
   (`http://sonarr:8989`, `http://radarr:7878`; containers resolve each other by
   service name). Indexers now sync automatically.
3. **Sonarr** — Settings → Download Clients → qBittorrent at `http://qbittorrent:8080`.
   Root folder `/data/media/tv`.
4. **Radarr** — same, root folder `/data/media/movies`.
5. **Jellyfin** — add libraries pointing at `/data/media/tv` and `/data/media/movies`.

In Sonarr/Radarr, turn on Settings → Media Management → **Use Hardlinks instead
of Copy**. Verify it works: after an import, `ls -l` the file in `media/` and
check the link count is 2.

Set a DHCP reservation on the router so the Pi's address never moves.

## Transcoding: keep it at zero

The Pi 5 dropped the hardware video encoder the Pi 4 had. Its VideoCore VII does
HEVC *decode* only — there is no hardware encode at all. Every Jellyfin transcode
is therefore software x264 on four A76 cores: roughly one 1080p→720p stream, and
nothing at 4K.

Leave hardware acceleration **off** in the Jellyfin dashboard (the compose file
deliberately passes no `/dev/dri`) and aim for **direct play** instead, where the
Pi only serves bytes and the client decodes. On wired gigabit that is effortless
even for 4K remuxes.

To stay in direct play:

- Prefer 1080p H.264/H.265 releases with AAC or AC3 audio in the Sonarr/Radarr
  quality profiles
- Use the native Jellyfin apps, not a browser — Chrome and Firefox refuse HEVC
  and TrueHD and will force a transcode
- Prefer SRT subtitles; image subs (PGS) get burned in, which means a full
  video transcode
- Set a per-user max bitrate in Jellyfin so a phone cannot ask for a 40 Mbps file

Audio-only transcodes are cheap and fine. It is video transcoding that hurts.

## Remote access

Do **not** port-forward this. Use [Tailscale](https://tailscale.com): no open
ports, works through CGNAT, and Jellyfin sees remote devices as local.

```
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

If you forward a port anyway: forward **only** Jellyfin, behind a reverse proxy
with TLS. Never expose qBittorrent, Sonarr, Radarr or Prowlarr — they all run
scripts on completion, so reaching those web UIs is remote code execution on the
Pi. And note that upload bandwidth is the real ceiling: if your uplink is thinner
than the file's bitrate, Jellyfin must transcode down, which is exactly what this
hardware cannot do.

## Notes

- The disk is found by **filesystem label**, not UUID, so the image stays generic
  — any disk prepared with `prepare-disk.sh` will mount.
- Keep the disk **ext4**. exFAT has no hardlinks and no Unix permissions, and
  NTFS via FUSE burns a core on large copies; either one breaks the import model.
  Reach the files over the network instead of moving the drive between machines.
- `/var/lib/docker` stays on the SD card. Image layers are written once and then
  read, so the wear is modest; the write-heavy databases are all on the SSD.
- Jellyfin gets `media/` mounted read-only, since it is the service most likely to
  be exposed. Drop the `read_only: true` on that mount in `docker-compose.yml` if
  you want to delete from the Jellyfin UI.
- Bind mounts use `create_host_path: false`, so if the SSD is not mounted the
  containers refuse to start rather than silently recreating the library on the
  SD card. Docker's default would create the missing paths.
- `docker compose pull && docker compose up -d` in `/opt/media-center` to update.
