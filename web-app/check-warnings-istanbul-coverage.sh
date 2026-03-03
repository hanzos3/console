#!/bin/bash

yell() { echo "$0: $*" >&2; }

die() {
  yell "$*"
  cat build.log
  exit 111
}

try() { "$@" &> build.log || die "cannot $*"; }

rm -f build.log
try pnpm buildistanbulcoverage

if cat build.log | grep "Compiled with warnings"; then
  echo "There are warnings in the code"
  exit 1
fi
