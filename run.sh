#!/usr/bin/env bash
# 启动脚本: 默认运行运行时旁边的 games/sample, 其余参数原样转给 main.tcl.
# 例: sh run.sh --game /path/to/my_game   /   sh run.sh --list-games
# [为什么要先 cd] --game 的相对路径按当前目录理解; 切到脚本所在目录后,
# 无论从哪里调用, 相对路径的含义都一样.
set -euo pipefail
cd "$(dirname "$0")"

printf "game start...\n"
exec wish main.tcl "$@"
