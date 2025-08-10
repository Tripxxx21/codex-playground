# LAN Device Monitor

This repository provides a simple script to monitor devices on your local network.

## Configuration

Edit `monitor/devices.csv` with entries:

```
name,addr,type
Pixel6,192.168.1.71,host
# add more like: Name,IP,host
```
Lines starting with `#` and blank lines are ignored.

## Script

Run the watcher:

```bash
./monitor/watch-devices.sh
```

Options:

- `--loop` run continuously
- `--interval N` seconds between loops (default 10)
- `--timeout N` ping timeout seconds (default 1)
- `--retries N` probe retries with exponential backoff (default 3)
- `--json` output JSON lines

Environment variables:

- `CONFIG` path to CSV (default `monitor/devices.csv`)
- `LOG` log file (default `monitor/watch.log`)
- `WEBHOOK_URL` optional URL to POST JSON on state change

Log entries are CSV: `timestamp,state,name,addr,latency_ms`.

Exit status is 0 when all devices are UP, otherwise 1.

## Makefile

```bash
make deps   # install optional tools (fping, arp-scan, bats)
make test   # run bats tests
make run    # execute watcher
```

## Examples

Run once with JSON output:

```bash
CONFIG=monitor/devices.csv ./monitor/watch-devices.sh --json
```

Run continuously every 30 seconds:

```bash
./monitor/watch-devices.sh --loop --interval 30
```
