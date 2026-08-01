+++
title = "Convert FLAC to Apple Lossless with FFmpeg"
description = "Convert FLAC to Apple Lossless (ALAC) with FFmpeg while preserving audio quality and metadata, then import the files into Apple Music."
date = 2023-10-23
draft = false

[taxonomies]
tags = ["ffmpeg", "apple-music", "audio", "flac", "alac"]

[extra]
keywords = "ffmpeg, apple-music, audio, flac, alac, lossless"
toc = false
static_thumbnail = "/images/social-convert-flac-to-apple-lossless-with-ffmpeg.png"

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

<p class="media-caption code-caption">Install FFmpeg with Homebrew</p>

When the tool is ready to use, navigate to the folder containing the FLAC files and run the following script:

```bash
for file in *.flac; do ffmpeg -i "$file" -acodec alac -vcodec copy "`basename "$file" .flac`.m4a"; done; mkdir flac; mkdir alac; for file in *.flac; do mv "$file" "flac/"; done; for file in *.m4a; do mv "$file" "alac/"; done;
```

<p class="media-caption code-caption">A one-liner that converts FLAC files to ALAC</p>

<figure class="article-figure">
  <img
    src="/images/Screenshot-2023-10-22-at-18.26.25.webp"
    alt="FLAC files for Susumu Hirasawa's album Siren in Finder"
    width="1160"
    height="900"
    loading="lazy"
    decoding="async"
  />
  <figcaption class="media-caption">Susumu Hirasawa – Siren [Limited Edition]</figcaption>
</figure>

The bash script converts the audio to the Apple Lossless format (`*.m4a`) and moves the files to the `alac` directory:

<figure class="article-figure">
  <img
    src="/images/Screenshot-2023-10-22-at-18.27.10.webp"
    alt="Converted M4A files in the ALAC directory in Finder"
    width="1160"
    height="1106"
    loading="lazy"
    decoding="async"
  />
</figure>

Finally, the `alac` directory can be dragged to Apple Music to import the album and upload its tracks to the cloud.

<figure class="article-figure">
  <img
    src="/images/Screenshot-2023-10-22-at-18.27.41.webp"
    alt="The imported Siren album in Apple Music"
    width="1600"
    height="946"
    loading="lazy"
    decoding="async"
  />
  <figcaption class="media-caption">The uploaded album</figcaption>
</figure>

<aside class="callout callout-warning" aria-label="Audio quality note">
  <p>
    You probably wonder why this album has no Lossless icon in Apple Music. Well, it turns out the
    audio quality of the FLAC files wasn't on par with lossless. So, make sure releases you buy or
    rip have a proper audio codec and quality.
  </p>
</aside>
