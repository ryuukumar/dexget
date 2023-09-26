# Installation Guide

DexGet has full support only for Windows 10 and 11.

The following operating systems can theoretically run DexGet but it is not fully tested on them:

- Ubuntu Linux 18.04 LTS and newer
- MacOS 10.13 and newer
- Anything that can run PowerShell 7

## Prerequisites

For now, you need to have available the following software on your device. You may follow the weblinks for each software and install the latest version.

### Windows

| Software | Installation Weblink |
|--|--|
| PowerShell 7 | https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.3 |
| ImageMagick | https://imagemagick.org/script/download.php |

### Linux (any distro)

| Software | Installation Weblink |
|--|--|
| PowerShell 7 | https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-linux?view=powershell-7.3 |
| ImageMagick | https://imagemagick.org/script/download.php |


### MacOS

| Software | Installation Weblink |
|--|--|
| PowerShell 7 | https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-macos?view=powershell-7.3 |
| ImageMagick | https://imagemagick.org/script/download.php |

## Install

#### Install via GitHub Web

Download the repository as a zip. This will be available under the code menu on the main page of the repository.

Extract the zip to your desired directory. Installation is done.

#### Install via Git CLI

You must have git command line installed for this.

Open Terminal on Windows and type:

```
git clone https://github.com/ryuukumar/dexget
cd dexget
```

Installation is done.

#### Running the in-dev beta or older versions

This is most easy with the git CLI. In the `dexget` folder, type:

```
git switch <branch>
```

Type the name of the branch with the required version. As of the time of writing, the latest (in-dev) version is v1.3, so I will type:

```
git switch v1.3
```

Then type:

```
git pull
```

And you can verify that it is indeed on v1.3 (or your desired version) by:

```
git status
```

You are now running on the latest in-dev version (or your desired older stable version). From time to time, there may be updates to the in-dev branch, so you may type `git pull` to receive updates.

It is suggested to run DexGet on `main` branch as it is guaranteed to be stable with the latest possible features (i.e. if v1.3 is in development, v1.2 is available). In-dev versions are *not guaranteed* to be stable.

## Configuration

You may read [SETTINGS.md](SETTINGS.md) for configuration and settings explanation.