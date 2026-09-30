# 示例内容包的素材目录

运行时按下面的约定在这里找图(约定实现在 `src/pack.tcl` 的 `GamePack`,
绘制在 `src/visual.tcl`):

```text
assets/
├── default_background-image.png   兜底背景图: 背景/CG 找不到对应文件时用它
├── default_figure-image.png       兜底立绘图: 立绘找不到对应文件时用它
├── bg/<id>.png                    背景,  例如 bg/classroom.png
├── cg/<id>.png                    CG,    例如 cg/memory.png
└── characters/<角色>_<表情>.png     立绘,  例如 characters/alice_normal.png
```

查找顺序:

- `bg <id>`:先 `bg/<id>.png`,再 `default_background-image.png`,都没有就
  画一个色块并在中间写上 id.
- `cg <id>`:先 `cg/<id>.png`,再 `default_background-image.png`,都没有就画色块.
- `show <角色> <表情>`:先 `characters/<角色>_<表情>.png`,再
  `default_figure-image.png`,都没有就画色块.

当前示例只有两张兜底图,所以所有背景与立绘都走兜底分支;往 `bg/`,`cg/`,
`characters/` 里放入同名图片即可自动生效,不需要改任何 Tcl 代码.

两点注意:

- 三个子目录里没有文件时不必建空目录,git 不会保留空目录.
- 图片按当前画布尺寸缩放后才缓存,原图不会被长期留在内存里;窗口尺寸变化时
  缓存会整批重建.
