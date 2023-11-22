# DexGet
Script to pull manga off of MangaDex.

To run, go to the folder which contains DexGet and type (in PowerShell Terminal):

```
./dexget.ps1 <manga-link>
```

Make sure that the manga link you paste contains the manga ID! This is a manga ID: `32d76d19-8a05-4db0-9fc2-e0b0648fe9d0`

Also available:

- `update.ps1`: Based on manga links you save in `notepad.txt`, it will simply download all the latest chapters after the currently saved ones.
- `clean.ps1`: When you have finished reading some manga but you want to download all new updates to the manga (with `update.ps1`) and delete everything you already read, use this to remove all chapters except the latest for ALL manga in the save directory.

## Installation

Read [INSTALL.md](INSTALL.md) for install instructions.

## Configuration and Settings

Read [SETTINGS.md](SETTINGS.md) for configuration instructions and a brief on settings.

## What's new?

### v1.4
v1.4 plans to implement some performance updates, chapter selection updates and smarter chapter selection methods.

A more detailed description of features can be found on PR [#3](https://github.com/ryuukumar/dexget/pull/3).

### v1.3
v1.3 gives you more control over your downloads, by implementing easier to change settings. It allows you to select page width in pixels, force grayscale and select quality levels - high, medium and low.

Further, large strides have been made in enabling cross-platform operation, so it is now possible to run DexGet on Windows, Linux and MacOS (note that other OSs may have questionable stability).

There are further stability updates which you may check on PR [#2](https://github.com/ryuukumar/dexget/pull/2).

### v1.2
v1.2 introduces batch downloading - where chapters are downloaded all together instead of separately. This approach has been noted (on personal tests) to cache manga on the local drive as a PDF upto 4x faster than v1.1.

Downloads of more than 20 chapters in a go may experience slower speeds as downloads are done in batches of 20 (above 20, it seems like you may get a 429 error from mangadex at any random point in time).

Additionally, a slight change in the processing of downloads may lead to PDFs upto 40% smaller in size (on personal tests) and more consistency in the PDFs (it is my personal observation that some PDFs have varying width even though I intend for them to all have the same width).

Finally, there are two utility scripts introduced:
- update.ps1: Based on a list of manga available in updates.txt, it will download all the latest chapters after the ones already downloaded.
- clean.ps1: Clears all the manga in the downloads folder (NOT in the cloud!), save for the last chapter.

### v1.1
v1.1 introduces a more intelligent chapter selection process, which can also look at previous download progress. The script has been patched up to look more aesthetically pleasing and colorful.
