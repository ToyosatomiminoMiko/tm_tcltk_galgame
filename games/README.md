# 内容包目录

这里放"内容",不放"运行时".每个子目录就是一个可以独立运行的游戏:

```text
games/<内容包>/
├── game.tcl          清单: 标题, 起始剧本, 素材目录, 地点名映射, 窗口尺寸
├── story/            剧本, 可以拆成多个 *.gal 用 include 拼接
└── assets/           素材, 约定见 assets/README.md
```

运行时(`../main.tcl` 与 `../src/`)不含任何具体作品的信息,只按清单取用,因此
`games/<内容包>/` 可以:

- 整体复制成另一份,改个目录名就是一个新游戏;
- 移到这个仓库外面,用 `wish main.tcl --game /path/to/内容包` 运行;
- 拆成独立仓库,运行时按路径引用它.

## 运行其中一个内容包

```bash
wish main.tcl --game games/sample   # 也可以直接写: wish main.tcl games/sample
wish main.tcl --list-games          # 列出这里的所有内容包
```

不指定 `--game` 时优先用 `games/sample`;若 `games/` 下有且只有一个内容包,
也会用它;有多个则必须显式指定.

## 新建一个内容包

最简单的方式是复制示例包再改:

```bash
cp -r games/sample games/my_game
$EDITOR games/my_game/game.tcl        # 至少改 id 与 title
$EDITOR games/my_game/story/main.gal  # 写自己的剧情
wish main.tcl --game games/my_game
```

清单支持的全部字段见 `sample/game.tcl` 顶部的说明.存档按清单里的 `id`
分目录保存,所以两个内容包即使标题相同也不会互相覆盖;换个 `id` 等于换一套存档.
