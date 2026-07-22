# Open WebUI manual validation

The web interface cannot be validated in CI (the container image is
too heavy and the flow needs a browser and a human), so this is a
manual checklist. It is a v1.0 criterion: execute it on a real
machine or VM, fill in the result record at the bottom, commit the
update.

## Prerequisites

- A machine or VM running SibillaOS (any image), or Ubuntu 24.04
  after `apt install llmd` + `sudo sibilla setup`.
- A served model (`sibilla status` shows it) and working inference:

  ```console
  $ KEY=$(sudo cat /etc/llmd/apikey); MODEL=$(sudo cat /etc/llmd/model)
  $ curl -s http://localhost:8080/v1/chat/completions \
      -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
      -d "{\"model\": \"$MODEL\", \"messages\": [{\"role\": \"user\", \"content\": \"hello\"}]}"
  ```

- Disk: the Open WebUI image is multi-gigabyte; check `df -h /` first.

## Checklist

Work through it in order; every step has an expected outcome.

1. Enable: `sudo sibilla webui enable`. Expected: the command returns,
   `systemctl status webui.service` shows the unit active (the first
   start pulls the image and can take several minutes on the pull;
   `journalctl -u webui -f` shows progress).
2. Reachability. On the image installs the firewall keeps port 3000
   closed on purpose: reach it from the machine itself, or open it
   deliberately (`sudo ufw allow 3000`), or tunnel
   (`ssh -L 3000:localhost:3000 user@machine`). Expected: a browser
   on `http://MACHINE:3000` (or the tunnel) shows the Open WebUI
   first-run page.
3. Account: create the first account. Expected: it becomes the
   administrator account and lands in the chat view. Record the
   version shown in the interface.
4. Model visibility. Expected: the model served by SibillaOS appears
   in the model selector (Open WebUI reads it from the loopback
   ollama; no manual configuration).
5. Chat: send "Reply with the single word: ok". Expected: an answer
   arrives and streams incrementally (tokens appear progressively,
   not one final blob).
6. A longer prompt: ask for a 5-line summary of any pasted paragraph.
   Expected: coherent output, no truncation, no container restart
   (`systemctl status webui.service` stays active, same PID).
7. Restart survival: `sudo systemctl restart webui.service`, reload
   the browser, log back in. Expected: account and chat history are
   still there (state lives in the container volume).
8. Disable: `sudo sibilla webui disable`. Expected: port 3000 stops
   answering; `sibilla status` unaffected; the API on 8080 untouched.
9. Re-enable: `sudo sibilla webui enable`. Expected: back up without
   re-pulling the image, account still present.

## Result record

| Date | SibillaOS | Open WebUI | Hardware | Steps passed | Notes |
|------|-----------|------------|----------|--------------|-------|
| (pending first execution) | | | | | |
