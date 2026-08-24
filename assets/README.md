# 资源目录

资源接入点预留如下:

- `bg/<id>.png`:背景，例如 `classroom.png`
- `cg/<id>.png`:CG，例如 `memory.png`
- `characters/<name>_<pose>.png`:立绘，例如 `alice_normal.png`

当前示例没有附带二进制图片，所以视觉层会绘制占位图形。要在后续版本接入真实图片，
可在 `src/visual.tcl` 中把 `draw_placeholder` 替换为 `image create photo` + Canvas image item，
并优先检查上述文件是否存在。
