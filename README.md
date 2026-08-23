# Tcl/Tk Galgame Framework

一个用 Tcl/Tk 写的小型 Galgame 框架示例。它把“剧本、状态、表现层、输入控制、存档”拆开，
便于继续增加角色、演出命令、音视频后端和自定义 UI。

## 运行

```bash
wish main.tcl
```

如果只是想验证所有模块能加载，可以运行：

```bash
wish main.tcl --smoke
```

## 目录结构

```text
main.tcl                入口与模块加载
src/
  config.tcl            配置项
  state.tcl             游戏运行时状态
  script.tcl            剧本 DSL 解析器
  engine.tcl            命令执行与流程控制
  ui.tcl                主界面、文字框、选择框、标题屏
  visual.tcl            Canvas 背景/立绘占位绘制
  audio.tcl             音频后端接口
  save.tcl              存档/读档
  log.tcl               对话记录窗口
  dialogs.tcl           设置、存档选择对话框
  application.tcl       应用装配与自动/快进逻辑
game/
  story.gal             示例剧本
assets/                 后续放入真实图片
```

## 剧本语法

每行一条命令，`#` 开头为注释。双引号字符串可含中文和空格。

```text
label start
bg classroom
show alice normal center
say "艾莉丝" "今天也一起回家吗？"
narrate "夕阳把影子拉得很长。"
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

常用命令：

- `label <name>` 定义跳转点
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

- `src/visual.tcl` 的占位绘制替换为真实图片、立绘变换和转场。
- `src/audio.tcl` 接入 Snack、`vlc` 或其他后端。
- `src/script.tcl` 增加演出指令，并在 `src/engine.tcl` 的 `dispatch` 中处理。
- `src/save.tcl` 已经保存旗标、角色、背景、历史记录和当前指令位置，可按需加入变量、CG 收集和成就。
