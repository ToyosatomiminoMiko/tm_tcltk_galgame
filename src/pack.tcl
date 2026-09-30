# 内容包模块: 描述"一个游戏"的全部内容信息, 并提供路径与素材解析.
# [为什么单独一层] 运行时不认识任何具体作品: 标题, 副标题, 剧本位置, 素材位置,
# 地点名映射都是内容. 它们统一由内容包目录下的 game.tcl 清单声明, 运行时只按
# 清单取用, 于是 games/<包>/ 可以整体搬走或换成另一个包, src/ 一行都不用改.
namespace eval galgame {
    namespace export -force *
}

# 从清单字典里取字段, 字段缺失时返回默认值.
proc galgame::spec_get {spec key default} {
    if {[dict exists $spec $key]} {
        return [dict get $spec $key]
    }
    return $default
}

# 判断一个素材 id 能否安全地当作文件名使用.
# [为什么必须校验] 素材 id 来自剧本(bg/cg/show 的参数), 属于内容而不是代码.
# 一旦允许 ".." 或路径分隔符, 一个写错或恶意的内容包就能让运行时去读内容包
# 之外的任意文件; 这里只放行没有路径成分的名字, 越界一律当作"素材不存在".
proc galgame::safe_asset_id {id} {
    if {$id eq ""} { return 0 }
    if {[string first "/" $id] >= 0} { return 0 }
    if {[string first "\\" $id] >= 0} { return 0 }
    if {[string first ".." $id] >= 0} { return 0 }
    return 1
}

# 在基目录下按相对路径找文件: 找到返回绝对路径, 否则返回空字符串.
proc galgame::asset_file {base rel} {
    if {$base eq "" || $rel eq ""} { return "" }
    set path [file join $base $rel]
    if {[file isfile $path]} {
        return [file normalize $path]
    }
    return ""
}

# 把清单里的相对路径解析成绝对路径, 并保证它落在内容包目录内.
# [为什么强制相对路径] 内容包要能整体搬走: 清单里一旦出现绝对路径, 换机器或
# 换目录后就会指向不存在的位置, 存档里记录的剧本相对路径也会跟着失效.
proc galgame::pack_path {dir rel what} {
    if {$rel eq ""} {
        error "内容包清单的 $what 不能为空"
    }
    if {[file pathtype $rel] eq "absolute"} {
        error "内容包清单的 $what 必须是相对内容包目录的路径: $rel"
    }
    set base [file normalize $dir]
    set path [file normalize [file join $base $rel]]
    if {[string first $base $path] != 0} {
        error "内容包清单的 $what 不能指向内容包之外: $rel"
    }
    return $path
}

# 读取内容包清单: game.tcl 是普通 Tcl 脚本, source 的返回值就是清单字典.
# [注意] source 意味着清单可以执行任意 Tcl, 不要运行来源不可信的内容包.
proc galgame::read_manifest {path} {
    if {![file isfile $path]} {
        error "内容包缺少清单文件: $path"
    }
    set spec [source $path]
    if {[catch {set n [dict size $spec]}]} {
        error "内容包清单必须返回一个字典: $path"
    }
    if {$n == 0} {
        error "内容包清单是空的: $path"
    }
    return $spec
}

# 按目录加载内容包, 返回 GamePack 对象.
proc galgame::load_pack {dir} {
    set normalized [file normalize $dir]
    set spec [galgame::read_manifest [file join $normalized game.tcl]]
    return [galgame::GamePack new $normalized $spec]
}

# 找出运行时目录下 games/ 里所有内容包目录(含 game.tcl 的子目录).
proc galgame::list_packs {runtime_root} {
    set games [file join $runtime_root games]
    set found [list]
    if {![file isdirectory $games]} {
        return $found
    }
    foreach child [lsort [glob -nocomplain -directory $games -type d *]] {
        if {[file isfile [file join $child game.tcl]]} {
            lappend found [file normalize $child]
        }
    }
    return $found
}

# 定位要运行的内容包目录.
# 顺序: 命令行/环境变量指定 -> games/sample -> games/ 下唯一的内容包.
# [为什么还要支持外部目录] 运行时与内容包是两个可以独立存放的东西: 内容包很
# 可能整个在另一个仓库里, 只认"运行时旁边的 games/"会把两者重新绑死.
proc galgame::find_pack {runtime_root requested} {
    set dir $requested
    if {$dir eq "" && [info exists ::env(GALGAME_PACK)]} {
        set dir $::env(GALGAME_PACK)
    }
    if {$dir ne ""} {
        if {![file isdirectory $dir]} {
            # 相对路径先按当前目录理解, 再按运行时目录理解, 两种调用都自然
            set alt [file join $runtime_root $dir]
            if {[file isdirectory $alt]} {
                set dir $alt
            }
        }
        if {![file isdirectory $dir]} {
            error "内容包目录不存在: $dir"
        }
        set dir [file normalize $dir]
        if {![file isfile [file join $dir game.tcl]]} {
            error "不是内容包(缺少 game.tcl): $dir"
        }
        return $dir
    }

    set packs [galgame::list_packs $runtime_root]
    set sample [file normalize [file join $runtime_root games sample]]
    if {[lsearch -exact $packs $sample] >= 0} {
        return $sample
    }
    if {[llength $packs] == 0} {
        error "没有找到内容包: 请用 --game <目录> 指定, 或在 [file join $runtime_root games] 下放一个带 game.tcl 的目录"
    }
    if {[llength $packs] > 1} {
        error "games/ 下有多个内容包, 请用 --game <目录> 指定其中一个:\n  [join $packs "\n  "]"
    }
    return [lindex $packs 0]
}

# 解析存档根目录.
# 优先级: --saves -> $GALGAME_SAVE_DIR / $GALGAME_DATA_DIR -> $XDG_DATA_HOME/galgame
#         -> $HOME/.local/share/galgame -> 当前目录下的 saves/.
# [为什么默认不放在项目根目录] 存档是用户数据, 既不属于运行时也不属于内容包:
# 内容包可能以只读方式分发, 运行时目录也可能不可写. 放到用户数据目录之后,
# 两者都能随便换位置, 存档仍然跟着内容包 id 走.
proc galgame::save_root {override} {
    if {$override ne ""} {
        return [file normalize $override]
    }
    foreach var {GALGAME_SAVE_DIR GALGAME_DATA_DIR} {
        if {[info exists ::env($var)] && $::env($var) ne ""} {
            return [file normalize $::env($var)]
        }
    }
    if {[info exists ::env(XDG_DATA_HOME)] && $::env(XDG_DATA_HOME) ne ""} {
        return [file join $::env(XDG_DATA_HOME) galgame]
    }
    if {[info exists ::env(HOME)] && $::env(HOME) ne ""} {
        return [file join $::env(HOME) .local share galgame]
    }
    return [file join [pwd] saves]
}

# 某个内容包的存档目录: 存档根目录下再按内容包 id 分一层, 不同游戏互不干扰.
proc galgame::resolve_save_dir {pack override} {
    return [file join [galgame::save_root $override] [$pack id]]
}

# GamePack 类: 一个内容包的只读视图, 把清单字段与素材约定变成方法.
oo::class create galgame::GamePack {
    # 内容包目录(绝对路径).
    variable dir
    # 内容包标识, 用于存档分目录与窗口识别.
    variable id
    # 窗口标题与标题屏主标题.
    variable title
    # 标题屏副标题, 可为空.
    variable subtitle
    # 起始剧本相对内容包目录的路径, 以及它的绝对路径.
    variable entry_rel
    variable entry_path
    # 素材目录绝对路径.
    variable assets_dir
    # 背景 id -> 地点显示名.
    variable locations
    # 兜底背景图与兜底立绘图, 可能为空字符串.
    variable default_background
    variable default_figure
    # 主窗口初始尺寸与最小尺寸.
    variable geometry
    variable min_size

    # 用内容包目录与已解析的清单字典构造, 并立即校验关键路径.
    # [为什么构造时就校验] 内容包写错应当在启动时报出来, 而不是等玩家点到
    # 某个背景或读档时才发现素材/剧本不存在.
    constructor {pack_dir spec} {
        set dir $pack_dir
        set id [galgame::spec_get $spec id [file tail $dir]]
        if {$id eq ""} {
            error "内容包 id 不能为空: $dir"
        }
        set title [galgame::spec_get $spec title $id]
        set subtitle [galgame::spec_get $spec subtitle ""]

        set entry_rel [galgame::spec_get $spec entry "story/main.gal"]
        set entry_path [galgame::pack_path $dir $entry_rel "entry"]
        if {![file isfile $entry_path]} {
            error "内容包清单里的 entry 不存在: $entry_rel (完整路径 $entry_path)"
        }

        set assets_rel [galgame::spec_get $spec assets "assets"]
        set assets_dir [galgame::pack_path $dir $assets_rel "assets"]
        if {![file isdirectory $assets_dir]} {
            error "内容包清单里的 assets 目录不存在: $assets_rel (完整路径 $assets_dir)"
        }

        # 兜底图片相对素材目录解析, 文件缺失不算错误: 视觉层会退化为色块.
        set defaults [galgame::spec_get $spec defaults [dict create]]
        set default_background [galgame::asset_file $assets_dir \
            [galgame::spec_get $defaults background "default_background-image.png"]]
        set default_figure [galgame::asset_file $assets_dir \
            [galgame::spec_get $defaults figure "default_figure-image.png"]]

        set locations [galgame::spec_get $spec locations [dict create]]
        set geometry [galgame::spec_get $spec geometry "960x640"]
        set min_size [galgame::spec_get $spec minsize {800 560}]
    }

    # 以下为清单字段的只读访问方法.
    method dir {} { return $dir }
    method id {} { return $id }
    method title {} { return $title }
    method subtitle {} { return $subtitle }
    method entry_rel {} { return $entry_rel }
    method entry_path {} { return $entry_path }
    method assets_dir {} { return $assets_dir }
    method geometry {} { return $geometry }
    method minsize {} { return $min_size }

    # 背景 id -> 顶栏显示的地点名, 清单里没写就原样返回 id.
    method location_name {bg_id} {
        if {[dict exists $locations $bg_id]} {
            return [dict get $locations $bg_id]
        }
        return $bg_id
    }

    # 兜底图片路径: kind 为 background 或 figure, 缺失时返回空字符串.
    method default_image {kind} {
        switch -- $kind {
            "background" { return $default_background }
            "figure"     { return $default_figure }
        }
        return ""
    }

    # 以下是素材查找约定, 找不到一律返回空字符串, 由视觉层决定怎么退化.
    # 约定路径都在内容包自己的 assets/ 下, 运行时只负责拼路径:
    #   bg/<id>.png                 背景
    #   cg/<id>.png                 CG
    #   characters/<角色>_<表情>.png  立绘
    method background_image {id} {
        if {![galgame::safe_asset_id $id]} { return "" }
        return [galgame::asset_file $assets_dir [file join bg "$id.png"]]
    }

    method cg_image {id} {
        if {![galgame::safe_asset_id $id]} { return "" }
        return [galgame::asset_file $assets_dir [file join cg "$id.png"]]
    }

    method character_image {name pose} {
        if {![galgame::safe_asset_id $name]} { return "" }
        if {![galgame::safe_asset_id $pose]} { return "" }
        return [galgame::asset_file $assets_dir [file join characters "${name}_${pose}.png"]]
    }

    # 供 --list-games 使用的一行摘要.
    method summary {} {
        return [format "%-12s %s  (%s)" $id $title $dir]
    }
}
