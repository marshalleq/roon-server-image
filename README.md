# roon-server-image

A small Debian 13 container image for running [Roon Server](https://roon.app/) on Linux. It runs Roon as a user you choose, not as root, it is rebuilt every week so Debian's security fixes are always in it, and every build is tested and scanned before it is published.

Image: `ghcr.io/marshalleq/roon-server-image`

Tags: `latest` and `debian-13` (the newest build), a dated tag such as `20261123`, and `sha-<commit>`. Use a dated tag if you want to go back to an earlier build.

This is an independent project and is not affiliated with Roon Labs. The image does not contain Roon. Roon Server is downloaded from Roon's own servers the first time the container starts and is kept in the `/app` folder, where Roon updates itself as normal.

## Why I made this

I run Roon Server in Docker on a home server, and I open it to the internet so that Roon Arc works on my phone. That made me look properly at what was inside the container for the first time.

I had been using one of the community Roon images. It worked, but the image had not been rebuilt for about 16 months, so none of Debian's security fixes since then were in it. I scanned it with Trivy and it reported 29 critical and 178 high findings, and every one of them already had a fixed version available. Most of them were in libraries that Roon's own program probably never touches, such as ffmpeg and its graphics libraries, and I can't tell you which ones are reachable. But I did not want to argue about each one for a service that faces the internet. It is much easier to run an image with nothing outstanding.

It also ran Roon as root. The image had settings for a user and group, but nothing used them. I wanted Roon to run as an ordinary user, so that if something in it ever went wrong, it could not do as much damage.

So I built my own, and I made it look after itself:

- **Security.** The image is built on Debian 13, with the same package list that Roon uses in its own image, apart from `ffmpeg`, which comes from Debian so that it gets security updates too. Roon runs as the `PUID` and `PGID` you give it, and the container refuses to run as root. The same scan now reports no high or critical findings that have a fix available.
- **Speed.** After I moved to this image, Roon felt a lot faster to me. I should be honest that I haven't measured it, and I moved from a 16-month-old Debian 12 image to a fresh Debian 13 one while also restarting the server, so I can't tell you which of those made the difference. If you try it, I'd be interested to hear whether you notice it too.
- **Automatic updates.** Nobody has to remember to rebuild it. Every Sunday it is rebuilt from scratch, so the newest Debian fixes go in. Dependabot keeps the base image and the build tooling current, and merges the small updates itself once the tests pass.
- **Automatic testing.** A new image is not published unless it passes its checks. If a new critical security problem appears that already has a fix, the build fails and the last good image stays where it is.

Roon now publishes an official image of its own at `ghcr.io/roonlabs/roonserver`, and it is worth a look. I kept my own for three reasons. It runs as a user you choose. It is rebuilt on a schedule and scanned every time, and from what I could see in its repository, Roon's image is rebuilt when Roon tags a new version, not on a schedule. And it keeps the `/app` and `/data` folder layout that many existing installs already use, so moving from the older community images needs no restructuring. That is my reading of Roon's repository at the time I made this. Check it yourself, as it may change.

## Running it

```
docker run -d --name roon --restart=always --net=host -e TZ=Pacific/Auckland -e PUID=568 -e PGID=568 -v /path/to/roon/app:/app -v /path/to/roon/data:/data -v /path/to/music:/music ghcr.io/marshalleq/roon-server-image:latest
```

Roon needs host networking so that remote players on your network can find it. If you use Roon Arc, you also need to forward TCP port 55000 to the machine.

| Setting | Meaning |
|---|---|
| `PUID`, `PGID` | Required. The numeric user and group Roon runs as. There is no default, and 0 (root) is refused. |
| `/app` | Required. Roon Server is unpacked here and updates itself here. Must be writable by `PUID:PGID`. |
| `/data` | Required. Roon's database, settings and identity. Must be writable by `PUID:PGID`, and must be a different folder from `/app`. |
| `/music`, `/backup` | Optional mount points for your music and for Roon backups. |
| `ROON_SERVER_URL`, `ROON_SERVER_PKG` | Where Roon Server is downloaded from. Already set; change only if Roon moves it. |

If something is wrong the container stops at once and prints what to fix, for example the `chown` command to give a folder to `PUID:PGID`. The image never changes ownership of your files itself.

### Moving from an image that ran as root

Roon will have created some root-owned files in `/app` and `/data`, so the new user cannot open them. Stop the container and take a backup first. Then give both folders to the new user, for example `chown -R 568:568 /path/to/roon/app /path/to/roon/data`.

Also check the file modes. On my server about 14,600 entries in `/data` had mode 000, left over from an old permissions change on my NAS. Root ignores that, so it never mattered before, but a normal user cannot read them. `chmod -R u+rwX /path/to/roon/app /path/to/roon/data` fixes it. Roon worked normally afterwards, with its whole library loaded.

If you want to go back, the old image still works, because it runs as root and does not mind who owns the files.

## What is automatic

| What | How |
|---|---|
| Debian security fixes | A scheduled build every Sunday starts from nothing, so it picks up the newest packages. Nobody has to do anything. |
| Vulnerability scan | Every build is scanned with [Trivy](https://trivy.dev/). The build fails, and nothing is published, if any critical finding has a fix available. |
| Entrypoint tests | Every build checks that the container refuses bad settings and really runs as `PUID:PGID`. |
| Dependencies | Dependabot keeps the base image tag and the GitHub Actions up to date. Minor and patch updates merge themselves once the checks pass; major updates wait for a person. |
| Protection of `main` | Changes to `main` need the `ci / ci` check to pass. Force-pushes and deletion are blocked. |

Roon Server itself is closed-source software that is downloaded at start-up, so none of these checks cover it.

## Updating

Pull the new image and recreate the container: `docker pull ghcr.io/marshalleq/roon-server-image:latest`, then stop, remove and run it again with the same options. Nothing updates containers automatically, so a weekly rebuild does not restart your server by itself. Your library and settings stay in your `/app` and `/data` folders.

## Licence

MIT. See `LICENSE`.
