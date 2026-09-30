# 视觉模块: 在 Canvas 上绘制背景/CG 与角色立绘.
# [职责边界] 本模块不知道素材放在哪个目录, 也不知道某个背景叫什么名字: 具体
# 路径由内容包(src/pack.tcl 的 GamePack)按约定查好, 这里只负责解码, 缩放与
# 绘制, 素材缺失时退化为色块, 因此内容包没配图也能跑.
namespace eval galgame {
    namespace export -force *
}

# Visual 类: 管理画布尺寸, 按需加载并缩放素材, 绘制背景/CG 与登场角色.
oo::class create galgame::Visual {
    # 关联的 Canvas 组件.
    variable canvas
    # 内容包对象, 素材查找都通过它.
    variable pack
    # 画布当前宽度与高度.
    variable width
    variable height
    # 当前背景编号与当前 CG 编号.
    variable current_bg
    variable current_cg
    # 当前登场角色字典, 键为角色名, 值为 [pose x].
    variable char_items
    # 兜底背景图与兜底立绘图路径, 可能为空字符串.
    variable default_bg
    variable default_figure
    # 缩放后的图片缓存: "源路径|宽|高|模式" -> photo 名.
    variable photo_cache
    # 生成缓存时的画布尺寸; 尺寸变了就整批丢弃.
    variable cache_dims

    # 构造时记录内容包与兜底图片, 并绑定画布尺寸变化事件.
    constructor {canvas_widget pack_obj} {
        set canvas $canvas_widget
        set pack $pack_obj
        set width 1
        set height 1
        set current_bg ""
        set current_cg ""
        set char_items [dict create]
        set default_bg [$pack default_image background]
        set default_figure [$pack default_image figure]
        set photo_cache [dict create]
        set cache_dims [list -1 -1]

        bind $canvas <Configure> [list [self] on_resize]
        # 构造时先量一次尺寸: 如果画布在建好之后才拿到真实大小, Configure 事件
        # 已经过去了, 不主动量一次就要等到下一次窗口缩放才会有画面.
        my on_resize
    }

    # 销毁时释放所有缩放图片.
    destructor {
        my drop_photos
    }

    # 删除全部缓存图片.
    # [为什么只缓存缩放结果] 原图只用来生成当前画布尺寸的缩放图, 生成完就可以
    # 扔掉: 一张 4K 背景常驻内存没有意义, 屏幕上最多只显示到画布大小.
    method drop_photos {} {
        if {[dict size $photo_cache]} {
            foreach img [dict values $photo_cache] {
                catch {image delete $img}
            }
        }
        set photo_cache [dict create]
        set cache_dims [list -1 -1]
    }

    # 画布尺寸变化时更新宽高, 并在尺寸有效时重绘.
    method on_resize {} {
        set width [winfo width $canvas]
        set height [winfo height $canvas]
        if {$width > 2 && $height > 2} {
            my redraw
        }
    }

    # 清空画布后重绘当前背景/CG 与所有角色.
    method redraw {} {
        $canvas delete all
        if {$width < 3 || $height < 3} { return }
        my ensure_photos

        if {$current_cg ne ""} {
            my draw_picture [$pack cg_image $current_cg] $default_bg "CG"
        } else {
            set id $current_bg
            if {$id eq ""} { set id "default" }
            my draw_picture [$pack background_image $id] $default_bg $id
        }

        foreach name [dict keys $char_items] {
            set info [dict get $char_items $name]
            my draw_character $name [lindex $info 0] [lindex $info 1]
        }
    }

    # 画布尺寸变化后丢弃整批缩放缓存; 尺寸没变时什么都不做.
    method ensure_photos {} {
        if {$cache_dims eq [list $width $height]} { return }
        my drop_photos
        set cache_dims [list $width $height]
    }

    # 取得源图片在当前画布尺寸下缩放后的 photo 名; 源为空时返回空字符串.
    # mode 为 cover 时结果不小于目标(铺满背景), contain 时不大于目标(立绘).
    method photo_for {source mode} {
        if {$source eq ""} { return "" }
        if {$mode eq "cover"} {
            set tw $width
            set th $height
        } else {
            set tw [expr {int($width * 0.38)}]
            set th [expr {int($height * 0.85)}]
        }
        if {$tw < 1 || $th < 1} { return "" }

        set key "$source|$tw|$th|$mode"
        if {[dict exists $photo_cache $key]} {
            return [dict get $photo_cache $key]
        }
        set img [my load_scaled $source $tw $th $mode]
        if {$img ne ""} {
            dict set photo_cache $key $img
        }
        return $img
    }

    # 读入源图片, 用整数 zoom/subsample 缩放到目标尺寸附近后返回新 photo.
    # [为什么用 zoom/subsample] Tk 的 photo copy 只支持整数倍缩放, 但配合
    # subsample 能以很小的代价逼近任意目标尺寸: 先找出使结果最接近目标的组合,
    # 再复制一次. 这里不保留原图, 只留下缩放结果.
    method load_scaled {source tw th mode} {
        set src ""
        if {[catch {set src [image create photo -file $source]}]} {
            return ""
        }
        set sw [image width $src]
        set sh [image height $src]
        if {$sw < 1 || $sh < 1} {
            catch {image delete $src}
            return ""
        }

        set best_z 1
        set best_s 1
        set best_err ""
        for {set z 1} {$z <= 10} {incr z} {
            set wz [expr {$sw * $z}]
            set hz [expr {$sh * $z}]
            if {$mode eq "cover"} {
                set sx [expr {int(floor(double($wz) / $tw))}]
                set sy [expr {int(floor(double($hz) / $th))}]
                set s [expr {$sx < $sy ? $sx : $sy}]
                if {$s < 1} { set s 1 }
                set fw [expr {int(ceil(double($wz) / $s))}]
                set fh [expr {int(ceil(double($hz) / $s))}]
            } else {
                set sx [expr {int(ceil(double($wz) / $tw))}]
                set sy [expr {int(ceil(double($hz) / $th))}]
                set s [expr {$sx > $sy ? $sx : $sy}]
                if {$s < 1} { set s 1 }
                set fw [expr {int(floor(double($wz) / $s))}]
                set fh [expr {int(floor(double($hz) / $s))}]
            }
            if {$fw < 1 || $fh < 1} { continue }
            set err [expr {($fw - $tw) * ($fw - $tw) + ($fh - $th) * ($fh - $th)}]
            if {$best_err eq "" || $err < $best_err} {
                set best_err $err
                set best_z $z
                set best_s $s
            }
            if {$z > 1 && $wz >= $tw * 3 && $hz >= $th * 3} { break }
        }

        set dst [image create photo]
        if {[catch {$dst copy $src -zoom $best_z -subsample $best_s}]} {
            catch {image delete $dst}
            catch {image delete $src}
            return ""
        }
        catch {image delete $src}
        return $dst
    }

    # 切换背景并清空 CG.
    method set_background {id} {
        set current_bg $id
        set current_cg ""
        my redraw
    }

    # 切换 CG.
    method set_cg {id} {
        set current_cg $id
        my redraw
    }

    # 添加或更新一个登场角色并重绘.
    method show_character {name pose x} {
        dict set char_items $name [list $pose $x]
        my redraw
    }

    # 移除指定角色并重绘.
    method hide_character {name} {
        if {[dict exists $char_items $name]} {
            dict unset char_items $name
        }
        my redraw
    }

    # 清空画布与当前场景记录, 丢弃上一个场景的背景/CG/立绘.
    # [为什么保留缩放缓存] photo_cache 只跟源图与画布尺寸有关, 与场景无关;
    # 丢弃它会让下一次重绘重新解码整张图片, 属于纯粹的重复劳动.
    method clear {} {
        set current_bg ""
        set current_cg ""
        set char_items [dict create]
        $canvas delete all
    }

    # 清空全部角色并重绘.
    method clear_characters {} {
        set char_items [dict create]
        my redraw
    }

    # 用给定字典整体替换角色列表并重绘.
    method set_characters {char_dict} {
        set char_items $char_dict
        my redraw
    }

    # 绘制背景或 CG: 优先用内容包里的对应素材, 其次是兜底图, 都没有就画色块.
    method draw_picture {source fallback label} {
        set path $source
        if {$path eq ""} { set path $fallback }
        set img [my photo_for $path cover]
        if {$img ne ""} {
            set iw [image width $img]
            set ih [image height $img]
            $canvas create image [expr {($width - $iw) / 2}] [expr {($height - $ih) / 2}] \
                -image $img -anchor nw
            return
        }
        my draw_color_block $label
    }

    # 用稳定颜色的色块加文字充当缺失素材的占位.
    method draw_color_block {label} {
        $canvas create rectangle 0 0 $width $height -fill [my color_for $label] -outline {}
        set font [list TkDefaultFont [expr {$height / 18}] bold]
        $canvas create text [expr {$width / 2}] [expr {$height / 2}] -text $label -font $font -fill white
    }

    # 根据站位绘制一个角色: 优先用 characters/<角色>_<表情>.png, 否则用兜底立绘.
    method draw_character {name pose x} {
        if {$width < 10 || $height < 10} { return }
        switch -- $x {
            "left"  { set cx [expr {$width * 0.25}] }
            "right" { set cx [expr {$width * 0.75}] }
            default { set cx [expr {$width * 0.50}] }
        }

        set tag "char_$name"
        set img [my photo_for [$pack character_image $name $pose] contain]
        if {$img eq ""} {
            set img [my photo_for $default_figure contain]
        }
        if {$img ne ""} {
            $canvas create image $cx [expr {$height - 24}] -image $img -anchor s -tags $tag
            $canvas create text $cx [expr {$height - 4}] -text $name -anchor s -font TkDefaultFont -fill white -tags $tag
            return
        }

        # 图片缺失时退化为简单色块.
        my draw_character_block $name $pose $cx $tag
    }

    # 立绘缺失时的色块占位.
    method draw_character_block {name pose cx tag} {
        set outfit [my color_for "$name/$pose"]
        set body_w [expr {$height * 0.14}]
        set body_h [expr {$height * 0.28}]
        $canvas create rectangle [expr {$cx - $body_w}] [expr {$height - $body_h}] \
            [expr {$cx + $body_w}] $height -fill $outfit -outline {} -tags $tag
        $canvas create text $cx [expr {$height - 6}] -text $name -anchor s -font TkDefaultFont -fill white -tags $tag
    }

    # 根据 id 生成一个稳定的颜色, 用于占位色块.
    method color_for {id} {
        set h 0
        foreach ch [split $id {}] {
            scan $ch %c code
            set h [expr {($h * 31 + $code) % 997}]
        }
        set palette {
            "#4f6d7a" "#6b7f82" "#8b5f71" "#6e6a8f"
            "#5f7d6f" "#916b46" "#7a5c6b" "#4f7085"
        }
        return [lindex $palette [expr {$h % [llength $palette]}]]
    }
}
