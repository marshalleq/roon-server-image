# roon-server-image

A small Debian-based container image for running [Roon Server](https://roon.app/) on Linux. It is rebuilt every week so that Debian's security fixes are included, and it runs Roon as a user you choose, not as root.

This is an independent project and is not affiliated with Roon Labs. The image does not contain Roon. Roon Server is downloaded from Roon's own servers the first time the container starts and is kept in the `/app` folder, where Roon updates itself as normal.

Image: `ghcr.io/marshalleq/roon-server-image`

Tags: `latest` and `debian-12` (the newest build), a dated tag such as `20261123`, and `sha-<commit>`. Use a dated tag if you want to go back to an earlier build.

## Running it

```
docker run -d --name roon --restart=always --net=host -e TZ=Pacific/Auckland -e PUID=568 -e PGID=568 -v /path/to/roon/app:/app -v /path/to/roon/data:/data -v /path/to/music:/music ghcr.io/marshalleq/roon-server-image:latest
```

Roon needs host networking so that remote players on your network can find it.

| Setting | Meaning |
|---|---|
| `PUID`, `PGID` | Required. The numeric user and group Roon runs as. There is no default, and 0 (root) is refused. |
| `/app` | Required. Roon Server is unpacked here and updates itself here. Must be writable by `PUID:PGID`. |
| `/data` | Required. Roon's database, settings and identity. Must be writable by `PUID:PGID`, and must be a different folder from `/app`. |
| `/music`, `/backup` | Optional mount points for your music and for Roon backups. |
| `ROON_SERVER_URL`, `ROON_SERVER_PKG` | Where Roon Server is downloaded from. Already set; change only if Roon moves it. |

If something is wrong the container stops at once and prints what to fix, for example the `chown` command to give a folder to `PUID:PGID`. The image never changes ownership of your files itself.

### Moving from an image that ran as root

Roon will have created some root-owned files in `/app` and `/data`. Stop the container, take a backup or a snapshot, then give both folders to the new user, for example `chown -R 568:568 /path/to/roon/app /path/to/roon/data`.

## How it stays secure

| What | How |
|---|---|
| Debian security fixes | A scheduled build every Sunday starts from nothing, so it picks up the newest packages. Nobody has to do anything. |
| Vulnerability scan | Every build is scanned with Trivy. The build fails, and nothing is published, if any critical finding has a fix available. |
| Entrypoint tests | Every build checks that the container refuses bad settings and really runs as `PUID:PGID`. |
| Dependencies | Dependabot keeps the base image tag and the GitHub Actions up to date. Minor and patch updates merge themselves once the checks pass; major updates wait for a person. |

Roon Server itself is closed-source software that is downloaded at start-up, so these checks do not cover it.

## Updating

Pull the new image and recreate the container: `docker pull ghcr.io/marshalleq/roon-server-image:latest`, then stop, remove and run it again with the same options. Nothing updates containers automatically, so a weekly rebuild does not restart your server by itself.

## Licence

MIT. See `LICENSE`.
