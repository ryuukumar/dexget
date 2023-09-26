# Configuration and Settings

## Initial Configuration

When DexGet is run for the first time, it will automatically initialise some default settings. By default, it will disable cloud saving and download manga to the `Manga` directory inside the `dexget` directory at low quality. Parallel downloads are enabled (upto 25 at a time) but parallel compression and PDF generation is disabled.

## Configuring dexget.ps1

You may open `preferences.json` inside the `dexget` directory after first run, and it will show you some settings. Here are some handy settings you may want to change:

| Setting | Description |
|--|--|
| `manga-save-directory` | Directory where manga is saved. You can simply type the folder name and it will save it inside the `dexget` folder. Currently it is unstable to save to a directory outside `dexget`. |
| `enable-cloud-saving` and `cloud-save-directory` | Toggle to enable cloud saving. Set the save directory in latter. |
| `maximum-simultaneous-*` | Maximum allowed simultaneous jobs for certain process. |
| `manga-language` | All manga will be downloaded in this language. "en" for English, "ru" for Russian, etc. Locale codes can be found online for other languages. |
| `quality` | To be implemented. Planned for quality control. |

## Configuring update.ps1

The only configuration operation that this accepts is `manga-save-directory`.

Apart from this, for successful execution, you need to create a file `updates.txt` in the `dexget` folder and copy paste your MangaDex links in it, one link per line only.

## Configuring clean.ps1

The only configuration operation that this accepts is `manga-save-directory`.