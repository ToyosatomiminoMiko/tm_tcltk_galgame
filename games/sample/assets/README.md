# 资源目录

默认占位图片(由 `src/visual.tcl` 自动加载):

- `default_background-image.png`:背景与 CG 的默认图片,绘制时铺满画面.
- `default_figure-image.png`:角色立绘的默认图片,当前所有角色共用同一张.

资源接入点预留如下:

- `bg/<id>.png`:背景,例如 `classroom.png`
- `cg/<id>.png`:CG,例如 `memory.png`
- `characters/<name>_<pose>.png`:立绘,例如 `alice_normal.png`

当前版本直接使用上面的两张默认图片.如果希望按场景/角色分别配图,可以在
`src/visual.tcl` 的 `draw_placeholder` / `draw_character` 中先检查上述文件
是否存在,存在时优先使用,否则回落到默认图片.
