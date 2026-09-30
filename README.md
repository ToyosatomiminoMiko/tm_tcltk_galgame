# Tcl/Tk Galgame 运行时

一个用 Tcl/Tk 写的小型 Galgame(视觉小说)运行时.它把两件事彻底分开:

- **运行时**:`main.tcl` 与 `src/`,只负责解析清单,执行剧本,绘制画面,存取档;
  里面没有任何具体作品的标题,地名,剧本或图片.
- **内容包**:`games/<名称>/`,一个游戏的全部内容:`game.tcl` 清单,`*.gal`
  剧本,`assets/` 素材.它可以整体复制,搬走,或拆成独立仓库.

运行时内部再按"剧本,状态,表现层,输入控制,存档"拆开,便于继续增加角色,
演出命令,音视频后端和自定义 UI.

## 运行

```bash
wish main.tcl                 # 运行 games/sample
wish main.tcl games/my_game   # 运行指定内容包
wish main.tcl --list-games    # 列出所有内容包
wish main.tcl --help          # 查看全部选项
```

`--saves <目录>` 可以把存档根目录挪到别处.验证模块能加载,内容包能跑:

```bash
wish main.tcl --smoke         # 只加载模块,约 1 秒后退出
wish main.tcl --smoke-story   # 自动播一遍剧情开头,约 2.2 秒后退出
```

## 目录结构

```text
main.tcl                 入口: 解析参数, 定位内容包, 装配应用
run.sh                   启动脚本(sh run.sh [选项])
src/                     运行时, 不含任何作品信息
  pack.tcl               内容包清单解析, 路径与素材解析, 存档目录解析
  config.tcl             运行时配置项
  state.tcl              游戏运行时状态
  script.tcl             剧本 DSL 解析器, 支持 include 拼接多份 *.gal
  engine.tcl             命令执行与流程控制
  ui.tcl                 主界面, 文字框, 选择框, 标题屏
  visual.tcl             Canvas 背景/立绘绘制与缩放缓存
  audio.tcl              音频后端接口
  save.tcl               存档/读档
  log.tcl                对话记录窗口
  dialogs.tcl            设置, 存档选择对话框
  application.tcl        应用装配与自动/快进逻辑
games/                   内容包
  README.md              内容包格式与新建方式
  sample/                示例内容包
    game.tcl             清单
    story/*.gal          剧本
    assets/              素材
doc/使用文档.md           完整使用文档
```

## 内容包清单

`game.tcl` 是一段普通 Tcl,`source` 的返回值就是清单字典:

```tcl
return {
    id       sample
    title    "放课后的约定"
    subtitle "运行时与内容包分离的示例"
    entry    "story/main.gal"
    assets   "assets"
    defaults {background "default_background-image.png" figure "default_figure-image.png"}
    locations {classroom 教室 library 图书馆}
    geometry "960x640"
    minsize  {800 560}
}
```

除 `title` 外都有默认值;每个字段的含义见 `games/sample/game.tcl` 顶部的注释.

## 存档

存档是用户数据,默认不放在仓库里:

- 根目录:`--saves <目录>`,否则 `$GALGAME_SAVE_DIR`(别名 `$GALGAME_DATA_DIR`),
  否则 `$XDG_DATA_HOME/galgame`,否则 `~/.local/share/galgame`;
- 每个内容包在根目录下占一层以清单 `id` 命名的子目录;
- 存档记录的是"内容包 id + 相对剧本路径",所以内容包搬走以后老存档仍然有效;
  拿别的内容包的存档来读档会被明确拒绝.

## 剧本语法

每行一条命令,`#` 开头(或行内未加引号处)为注释.双引号字符串可含中文和空格.

```text
include "endings.gal"        # 把另一份 *.gal 拼进同一条指令流

label start
bg classroom
show alice normal center
say "Alice" "今天也一起回家吗?"
narrate "夕阳把影子拉得很长."
menu
option "去图书馆" library
option "回家" home
endmenu

flag went_library 1
add affection 1
if went_library -> library_ending
ifnot met_alice -> start
jump start
end
```

常用命令:

- `include <文件>` 拼接另一份剧本,路径相对当前文件所在目录
- `label <name>` 定义跳转点,名称全局唯一,重名会报错
- `jump <label>` 无条件跳转
- `bg <id>` / `cg <id>` 切换背景或 CG
- `show <char> <pose> [left|center|right]` 显示立绘
- `hide <char>` 隐藏立绘
- `say "<name>" "<text>"` 显示一句对白
- `narrate "<text>"` 旁白
- `menu` + `option "<text>" <label>` + `endmenu` 选项分支
- `flag <name> <value>` / `clear <name>` 设置或清除旗标
- `add <name> <amount>` 增加数值旗标
- `if <flag> -> <label>` / `ifnot <flag> -> <label>`
- `if <flag> == <value> -> <label>` 以及 `!= < > <= >=`
- `music <id>` / `stopmusic` / `sfx <id>` 音频命令
- `wait <ms>` 等待后继续
- `end` 返回标题

## 扩展方向

- `src/visual.tcl`:按 id 找图的约定已经实现,把图片放进内容包的 `assets/bg`,
  `assets/cg`,`assets/characters` 即可生效;转场与立绘变换可在此基础上增加.
- `src/audio.tcl`:接入 Snack,`vlc` 或其他后端,并按内容包的素材目录解析音频.
- `src/script.tcl`:增加演出指令,再在 `src/engine.tcl` 的 `dispatch` 中处理.
- `src/save.tcl`:已经保存旗标,角色,背景,历史记录和当前指令位置,可按需加入
  变量,CG 收集和成就.
