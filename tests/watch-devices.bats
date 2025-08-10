#!/usr/bin/env bats

setup() {
  mkdir -p tmp
  cat <<'EOF' > tmp/devices.csv
name,addr,type
Localhost,127.0.0.1,host
EOF
}

teardown() {
  rm -rf tmp
}

@test "localhost is up" {
  run bash -c "CONFIG=tmp/devices.csv LOG=tmp/watch.log $BATS_TEST_DIRNAME/../monitor/watch-devices.sh --timeout 1 --retries 1"
  [ "$status" -eq 0 ]
  grep -q "UP,Localhost,127.0.0.1" tmp/watch.log
}
