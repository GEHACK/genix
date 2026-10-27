# Substituted above: REPO, REF, CONTEST_DIR, DEPLOY_KEY, UPLOAD_TOKEN, RECIPIENTS,
# KNOWN_HOSTS, JOBS, REPORT_URL.

state=/var/lib/runtimes
work=$state/problemset
contest=$work/$CONTEST_DIR

banner() {
  printf '\n\033[1;36m==> %s\033[0m\n\n' "$*"
}

# One bt pass. A failing bt (unexpected verdicts, a submission that does not
# compile) still leaves useful timings, so its status is recorded, not fatal.
# -e: bt otherwise crops compiler errors and program output to 25 lines.
measure() {
  local label=$1
  banner "Measuring runtimes ($label CPU settings)"
  runtimes-report cpu-state >"$state/$label.cpu.json"
  set +e
  (cd "$contest" && bt time_limit -e -j "$JOBS") 2>&1 | tee "$state/$label.log"
  echo "${PIPESTATUS[0]}" >"$state/$label.status"
  set -e
}

printf '\033c'
banner "GEHACK runtime test: leave this computer alone until it says DONE"
lscpu | grep -E '^(Model name|CPU\(s\)|Thread\(s\) per core|Core\(s\) per socket):' || true

rm -rf "$state"
mkdir -p "$state"

# ssh refuses a world-readable key, and everything in the store is.
install -D -m 0600 "$DEPLOY_KEY" /run/runtimes/deploy_key
export GIT_SSH_COMMAND="ssh -i /run/runtimes/deploy_key -o IdentitiesOnly=yes \
  -o UserKnownHostsFile=$KNOWN_HOSTS -o StrictHostKeyChecking=yes \
  -o BatchMode=yes -o ConnectTimeout=20"

# Nothing can be measured without the problem set, so a missing cable stalls here
# until someone plugs one in.
banner "Downloading the problem set from $REPO"
attempt=1
until git clone --quiet --depth 1 ${REF:+--branch "$REF"} "$REPO" "$work"; do
  echo "Download attempt $attempt failed. Is a network cable plugged in? Retrying in 30 seconds."
  rm -rf "$work"
  attempt=$((attempt + 1))
  sleep 30
done
revision=$(git -C "$work" rev-parse HEAD)
echo "Problem set revision $revision, $JOBS job(s) at a time"

measure stock

banner "Locking the CPU like a judgehost: turbo off, SMT siblings and E-cores offline"
if runtimes-tune-cpu 2>&1 | tee "$state/tune.log"; then
  measure tuned
else
  echo "CPU tuning failed; skipping the tuned run." | tee -a "$state/tune.log"
fi

banner "Results"
runtimes-report build \
  --state "$state" \
  --contest "$contest" \
  --problemset-rev "$revision" \
  --jobs "$JOBS" \
  >"$state/report.json"
runtimes-report summary "$state/report.json"

# Encrypted end to end: the tunnel terminates TLS at Cloudflare, so only the jury's
# keys may be able to read the report, not the edge or the receiving server.
# Compressed first, since it carries the complete bt logs and age does not compress.
gzip -9 --stdout "$state/report.json" |
  age --encrypt --recipients-file "$RECIPIENTS" --output "$state/report.json.gz.age"

# A header file keeps the token out of curl's command line.
printf 'Authorization: Bearer %s\n' "$(<"$UPLOAD_TOKEN")" >/run/runtimes/auth-header
chmod 0600 /run/runtimes/auth-header

# --proto =https also covers redirects, so nothing ever goes out in the clear.
# An unsynced clock breaks certificate checks too; retrying covers NTP catching up.
banner "Uploading encrypted results to $REPORT_URL"
attempt=1
until curl --proto '=https' --tlsv1.2 --fail-with-body --silent --show-error \
  --connect-timeout 30 --max-time 1800 \
  --header @/run/runtimes/auth-header \
  --header 'Content-Type: application/octet-stream' \
  --data-binary "@$state/report.json.gz.age" \
  --output "$state/upload.response" \
  "$REPORT_URL"; do
  echo "Upload attempt $attempt failed. Is a network cable plugged in? Retrying in 30 seconds."
  attempt=$((attempt + 1))
  sleep 30
done

banner "DONE: results uploaded as $(cat "$state/upload.response"). Press the power button to switch off."
