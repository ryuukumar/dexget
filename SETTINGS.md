# Configuration and Settings

## Initial Configuration

When DexGet is run for the first time, it will automatically initialise some default settings. By default, it will disable cloud saving and download manga to the `Manga` directory inside the `dexget` directory at low quality. Parallel downloads are enabled (upto 25 at a time) but parallel compression and PDF generation is disabled.

## Configuring dexget.ps1

You may open `preferences.json` inside the `dexget` directory after first run, and it will show you some settings. Here are some handy settings you may want to change:

| Setting | Description |
|--|--|
| `manga-save-directory` | Directory where manga is saved. You can simply type the folder name and it will save it inside the `dexget` folder. Currently it is unstable to save to a directory outside `dexget`. |
| `enable-cloud-saving` and `cloud-save-directory` | Toggle `enable-cloud-saving` to enable cloud saving. You can set the save directory in `cloud-save-directory`. |
| `manga-language` | All manga will be downloaded in this language. "en" for English, "ru" for Russian, etc. Locale codes can be found online for other languages. |
| `quality` | Accepts `low`, `medium`, and `high`. Sets how much compression is applied to the image to reduce the size, obviously reducing the quality of the image. |

## Configuring update.ps1

The only configuration operation that this accepts is `manga-save-directory`.

Apart from this, for successful execution, you need to create a file `updates.txt` in the `dexget` folder and copy paste your MangaDex links in it, one link per line only.

## Configuring clean.ps1

The only configuration operation that this accepts is `manga-save-directory`.

## Advanced Settings

There are some other power user settings which you may want to change to improve your experience or to help with contributions to the code.

| Setting | Description |
|--|--|
| `maximum-simultaneous-*` | Maximum allowed simultaneous jobs for a certain process. It's not guaranteed that this many threads will run, it just caps the number of threads that run. Usually it will multithread to the specified limit but when your CPU is too busy it may run fewer threads. |
| `pdf-method` | Accepts `magick` and `pypdf`. These are different PDF generation methods, which respectively require ImageMagick and Python installed. `pypdf` seems to generate PDFs quicker and they're a little smaller, but it may take some time to initially set up. `magick` (the default) is good enough for normal use. |
| `debug-mode` | Setting this to true replaces the progress bars with verbose statements which give a lot of information about what is going on. It disables parallelisation between downloads and saving, and instead it is done as a 3-step process. |
| `update-on-launch` | Useful for when you are on rolling branch. This automatically tries to download the latest updates to the selected branch on every run. Unless your internet connection is extremely weak, you can leave this on and forget about it and it should be fine. |