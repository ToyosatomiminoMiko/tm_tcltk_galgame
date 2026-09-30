# 示例内容包清单.
# ============================================================================
# 内容包 = 一个游戏的全部"内容": 清单 + 剧本(*.gal) + 素材(assets/).
# 运行时(src/ 与 main.tcl)不包含任何具体作品的信息, 只按本清单取用;
# 因此整个 games/sample/ 目录可以随时复制出去或换成另一个仓库, 运行时照跑.
#
# 本文件是普通 Tcl 脚本, 被 source 后的返回值就是清单字典.
# 注意: source 意味着清单可以执行任意 Tcl, 不要运行来源不可信的内容包.
#
# 可用字段(除 title/entry 外都有默认值):
#   id          内容包标识, 默认取目录名; 存档按它分目录, 换 id 等于换一套存档
#   title       窗口标题与标题屏主标题, 默认取 id
#   subtitle    标题屏副标题, 默认空(为空时不显示该行)
#   entry       起始剧本, 相对内容包目录, 默认 story/main.gal
#   assets      素材目录, 相对内容包目录, 默认 assets
#   defaults    素材缺失时的兜底图片, 相对 assets 目录:
#                 background  背景/CG 兜底图
#                 figure      立绘兜底图
#   locations   背景 id -> 顶栏显示的地点名; 未列出的 id 原样显示
#   geometry    主窗口初始尺寸, 默认 960x640
#   minsize     主窗口最小尺寸, 默认 {800 560}
# ============================================================================

return {
    id       sample
    title    "放课后的约定"
    subtitle "运行时与内容包分离的示例"

    entry  "story/main.gal"
    assets "assets"

    defaults {
        background "default_background-image.png"
        figure     "default_figure-image.png"
    }

    locations {
        classroom 教室
        library   图书馆
        rooftop   天台
        street    放学路上
        sunset    黄昏的河堤
        room      自己的房间
    }

    geometry "960x640"
    minsize  {800 560}
}
