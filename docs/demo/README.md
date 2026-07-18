# Recording the quick-start demo

The most convincing demo is a real terminal recording made on an
installed SibillaOS machine: authentic timing, authentic output. This
is the recipe to capture one and turn it into an animated SVG that
renders directly in the README with no external hosting.

## 1. Record the session

On the installed machine (or over SSH into it):

```console
$ sudo apt-get install -y asciinema   # or: pipx install asciinema
$ asciinema rec sibilla-quickstart.cast --idle-time-limit 2
```

Then run the quick-start flow, unhurried:

```console
$ sibilla status
$ KEY=$(sudo cat /etc/llmd/apikey)
$ MODEL=$(sudo cat /etc/llmd/model)
$ curl http://localhost:8080/v1/chat/completions \
    -H "Authorization: Bearer $KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"$MODEL\", \"messages\": [{\"role\": \"user\", \"content\": \"In one sentence, what are you?\"}]}"
```

Press Ctrl-D to stop. `--idle-time-limit 2` caps dead air so the model
generation pause does not drag; keep it if you want the real wait
visible, drop it otherwise.

## 2. Render to an animated SVG

`agg` (asciinema gif generator) and `svg-term` both work; svg-term
keeps the output as vector text, small and crisp on GitHub:

```console
$ npm install -g svg-term-cli
$ svg-term --in sibilla-quickstart.cast --out branding/demo-quickstart.svg \
    --window --no-cursor --term iterm2 --profile emerald
```

Or a GIF, if you prefer:

```console
$ agg --theme 0e2a1c,a8e063,... sibilla-quickstart.cast branding/demo-quickstart.gif
```

## 3. Wire it into the README

Put it right under the tagline, above the first prose line:

```markdown
<p align="center"><img src="branding/demo-quickstart.svg" alt="SibillaOS quick start" width="760"/></p>
```

Until a real recording exists, `branding/demo-quickstart.svg` in this
repo is a hand-built stopgap: correct commands, representative output.
Replace it with your capture as soon as you have a machine to record on.
