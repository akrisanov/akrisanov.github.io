+++
title = "Convert Flac to Apple Lossless With FFmpeg"
description = "How to use FFmpeg to convert FLAC files to Apple Lossless without losing the original quality and uploading them to Apple Music."
date = 2023-10-23
draft = false

[taxonomies]
tags = ["apple", "music", "ffmpeg"]

[extra]
keywords = "apple, music, ffmpeg, lossless, audio"
toc = false
+++

I'm a longtime Apple Music user. Most of my so-called music collection is on the streaming service.
However, I occasionally buy rare or remastered releases ripped from CDs. These releases are usually
in the FLAC format, which Apple Music doesn't support. But I've found an easy workaround that
allows me to organize and play albums on the go.

The centerpiece of the workaround is FFmpeg. So if you don't already have it installed,
it's worth installing now:

```bash
brew install ffmpeg
```

<span class="img-title">Homebrew Formula</span>

When the tool is ready to use, navigate to the folder containing the FLAC files and run the following script:

```bash
for file in *.flac; do ffmpeg -i "$file" -acodec alac -vcodec copy "`basename "$file" .flac`.m4a"; done; mkdir flac; mkdir alac; for file in *.flac; do mv "$file" "flac/"; done; for file in *.m4a; do mv "$file" "alac/"; done;
```

<span class="img-title">Silly One-liner Converting FLAC to ALAC</span>

![](/images/Screenshot-2023-10-22-at-18.26.25.png)
<span class="img-title">Susumu Hirasawa – Siren [Limited Edition]</span>

The bash script converts the audio to the Apple Lossless format (`*.m4a`) and moves the files to the `alac` directory:

![](/images/Screenshot-2023-10-22-at-18.27.10.png)

Finally, the `alac` directory can be dragged to Apple Music to import the album and upload its tracks to the cloud.

![](/images/Screenshot-2023-10-22-at-18.27.41.png)
<span class="img-title">The Uploaded Album</span>

---

👉 You probably wonder why this album has no Lossless icon in Apple Music. Well, it turns out the
audio quality of the FLAC files wasn't on pair with lossless. So, make sure releases you buy or
rip, have a proper audio codec and quality.
