# Freifunk feed for OpenWrt

## Description

This feeds contains the OpenWrt packages for Freifunk. In February 2019 this feed was created by moving these packages out of the OpenWrt "luci"-feed.

## Usage

To enable this feed add the following line to your feeds.conf:
```
src-git freifunk https://github.com/freifunk/openwrt-packages.git
```

To install all its package definitions, run:
```
./scripts/feeds update freifunk
./scripts/feeds install -a -p freifunk
```

## License

See [LICENSE](LICENSE) file.
 
## Package Guidelines

See [CONTRIBUTING.md](CONTRIBUTING.md) file.

## If you have commit access (in addition to the guidelines of OpenWrt):

* Do NOT use `git push --force`.
* Use Pull Requests if you are unsure and to suggest changes to other developers.
* Don't use merge commits if you accept a single commit PR, do a "rebase"-merge. This will keep the history more readable, as it's not flooded by "merge" logmessages
