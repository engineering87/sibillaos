# Local speech-to-text

`sudo sibilla speech enable` puts a transcription endpoint on the same
gateway, behind the same keys, as everything else this machine serves.
The engine is whisper.cpp, repackaged from its pinned upstream release
exactly like llmfit (recorded sha256, no installer scripts), and the
Whisper model arrives like every other catalog artifact: verified
against the digest in the GPG-signed catalog, refused on mismatch,
with no override. Audio is transcribed on this machine and goes
nowhere else.

## Use

```console
$ sudo sibilla speech enable
speech model verified: sha256:60ed5b...
speech enabled at /v1/audio/transcriptions (same API keys as the API)
```

Then call the OpenAI transcription shape:

```console
$ curl http://YOUR_HOST:8080/v1/audio/transcriptions \
    -H "Authorization: Bearer YOUR_KEY" \
    -F file=@recording.wav \
    -F response_format=json
{"text": " ..."}
```

Any OpenAI SDK works the same way (`client.audio.transcriptions.create`),
pointed at this machine with `sibilla connect --env`.

`response_format` accepts the upstream server's formats (json, text,
srt, vtt, verbose_json), which covers subtitles directly.

## Formats and ffmpeg

Without ffmpeg installed the server accepts 16 kHz mono WAV only, and
`sibilla speech enable` says so. With ffmpeg (`sudo apt install
ffmpeg`, then enable again) most audio formats convert on the fly.
ffmpeg is a Recommends, not a hard dependency: the appliance stays
minimal by default.

## Configuration as code

`SPEECH=on|off` is a profile key like the other toggles: `sibilla
apply` converges it, `apply export` records it, `apply check` reports
its drift.

## Air-gapped delivery

Put the model file at /var/lib/llmd/models/whisper/ggml-base.bin by
any offline means; `sibilla speech enable` verifies the existing file
against the catalog digest and keeps it, downloading nothing. A file
that does not match is refused, exactly like a network download.

## Model

One model ships in the catalog: Whisper base (multilingual, ~148 MB,
MIT), a deliberate default that transcribes well on CPU. The catalog
can grow other sizes the day someone brings a use case that base does
not cover.
