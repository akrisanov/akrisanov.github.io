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

I use Apple Music for most of my music collection. I also buy rare or remastered CD releases that are sometimes
distributed as FLAC files, which Apple Music does not support. I convert them to Apple Lossless Audio Codec (ALAC)
before importing them into my library.

Install FFmpeg with Homebrew:

```bash
brew install ffmpeg
```

<p class="media-caption code-caption">Install FFmpeg with Homebrew</p>

Open the directory containing the FLAC files and run:

```bash
for file in *.flac; do
  ffmpeg -i "$file" -acodec alac -vcodec copy "$(basename "$file" .flac).m4a"
done

mkdir flac alac

for file in *.flac; do
  mv "$file" flac/
done

for file in *.m4a; do
  mv "$file" alac/
done
```

<p class="media-caption code-caption">Convert FLAC files to ALAC and organize the output</p>

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

The script converts each FLAC file to ALAC in an `.m4a` container. It moves the source files to `flac` and the
converted files to `alac`:

<figure class="article-figure">
  <img
    src="/images/Screenshot-2023-10-22-at-18.27.10.webp"
    alt="Converted M4A files in the ALAC directory in Finder"
    width="1160"
    height="1106"
    loading="lazy"
    decoding="async"
  />
  <figcaption class="media-caption">Converted ALAC files in Finder</figcaption>
</figure>

Drag the `alac` directory into Apple Music to import the album and upload its tracks to the cloud.

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
    The album shown above has no Lossless badge in Apple Music. Its FLAC files appeared to have been created from
    a lossy source. Converting a file to ALAC does not improve its source quality. Check the codec and quality of
    releases you buy or rip.
  </p>
</aside>
