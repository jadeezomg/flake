#!/usr/bin/env nu
# Quick helper to preview print-header without rebuilding anything

use common.nu *

def main [
  title?: string = "Header Test",
  --icon (-i): string = "▲",
  --len (-l): int = 14,
  --all (-a)
] {
  if $all {
    let samples = [6 10 14 18 22 26 30 34]
    $samples | each { |n|
      print-header $"($title) [len=($n)]" $icon $n
    }
  } else {
    print-header $title $icon $len
  }
}


