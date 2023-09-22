# DexGet
Script to pull manga off of MangaDex

To run, go to the folder which contains DexGet and type:

```
./dexget.ps1 <manga-link>
```

Make sure that the manga link you paste contains the manga ID! This is a manga ID: 32d76d19-8a05-4db0-9fc2-e0b0648fe9d0

## What's new?

### v1.2
v1.2 introduces batch downloading - where chapters are downloaded all together instead of separately. This approach has been noted (on personal tests) to cache manga on the local drive as a PDF upto 4x faster than v1.1.

Downloads of more than 20 chapters in a go may experience slower speeds as downloads are done in batches of 20 (above 20, it seems like you may get a 429 error from mangadex at any random point in time).

Additionally, a slight change in the processing of downloads may lead to PDFs upto 40% smaller in size (on personal tests) and more consistency in the PDFs (it is my personal observation that some PDFs have varying width even though I intend for them to all have the same width).

Finally, there are two utility scripts introduced:
- update.ps1: Based on a list of manga available in updates.txt, it will download all the latest chapters after the ones already downloaded.
- clean.ps1: Clears all the manga in the downloads folder (NOT in the cloud!), save for the last chapter.

### v1.1
v1.1 introduces a more intelligent chapter selection process, which can also look at previous download progress. The script has been patched up to look more aesthetically pleasing and colorful.
