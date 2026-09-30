# 视觉模块: 在 Canvas 上绘制背景/CG 与角色立绘.
# 优先使用 assets 目录下的默认图片,文件缺失时退化为色块占位.
namespace eval galgame {
    namespace export -force *
}

# Visual 类: 管理画布尺寸,并绘制背景/CG 与登场角色.
oo::class create galgame::Visual {
    # 关联的 Canvas 组件.
    variable canvas
    # 画布当前宽度.
    variable width
    # 画布当前高度.
    variable height
    # 当前背景编号.
    variable current_bg
    # 当前 CG 编号.
    variable current_cg
    # 当前登场角色字典,键为角色名,值为 [pose x].
    variable char_items
    # 原始图片对象: 默认背景与默认立绘.
    variable bg_image
    variable figure_image
    # 按画布尺寸缩放后的图片对象,以及生成它们时的画布尺寸.
    variable scaled_bg
    variable scaled_figure
    variable scaled_dims

    # 构造时加载默认图片并绑定画布尺寸变化事件.
    constructor {canvas_widget} {
        set canvas $canvas_widget
        set width 1
        set height 1
        set current_bg ""
        set current_cg ""
        set char_items [dict create]
        set bg_image ""
        set figure_image ""
        set scaled_bg ""
        set scaled_figure ""
        set scaled_dims [list -1 -1]

        set asset_dir [file join $::galgame::ROOT assets]
        # 占位背景图
        catch {
            set bg_image [image create photo -file [file join $asset_dir default_background-image.png]]
        }
        # 占位人物图
        catch {
            set figure_image [image create photo -file [file join $asset_dir default_figure-image.png]]
        }

        bind $canvas <Configure> [list [self] on_resize]
    }

    # 销毁时释放所有图片对象.
    destructor {
        my drop_scaled
        foreach img [list $bg_image $figure_image] {
            if {$img ne ""} {
                catch {image delete $img}
            }
        }
    }

    # 画布尺寸变化时更新宽高,并在尺寸有效时重绘.
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
        my ensure_scaled
        if {$current_cg ne ""} {
            my draw_placeholder $current_cg "CG" 1
        } else {
            if {$current_bg eq ""} { set current_bg "default" }
            my draw_placeholder $current_bg "场景" 0
        }
        foreach name [dict keys $char_items] {
            set info [dict get $char_items $name]
            my draw_character $name [lindex $info 0] [lindex $info 1]
        }
    }

    # 画布尺寸变化后重建缩放图片;尺寸未变时复用缓存.
    method ensure_scaled {} {
        if {$width < 3 || $height < 3} { return }
        if {$scaled_dims eq [list $width $height]} { return }
        my drop_scaled
        if {$bg_image ne ""} {
            set scaled_bg [my resize_photo $bg_image $width $height cover]
        }
        if {$figure_image ne ""} {
            set tw [expr {int($width * 0.38)}]
            set th [expr {int($height * 0.85)}]
            set scaled_figure [my resize_photo $figure_image $tw $th contain]
        }
        set scaled_dims [list $width $height]
    }

    # 删除当前缩放图片对象.
    method drop_scaled {} {
        foreach img [list $scaled_bg $scaled_figure] {
            if {$img ne ""} {
                catch {image delete $img}
            }
        }
        set scaled_bg ""
        set scaled_figure ""
    }

    # 用整数缩放/抽样的方式把图片调整到目标尺寸附近.
    # mode 为 cover 时结果不小于目标(用于背景铺满),
    # 为 contain 时结果不大于目标并保持宽高比(用于立绘).
    method resize_photo {src tw th mode} {
        set sw [image width $src]
        set sh [image height $src]
        if {$sw < 1 || $sh < 1} { return "" }

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
        $dst copy $src -zoom $best_z -subsample $best_s
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

    # 绘制背景或 CG: 优先显示默认背景图片,缺失时退化为色块.
    method draw_placeholder {id label is_cg} {
        if {$width < 10 || $height < 10} { return }
        if {$scaled_bg ne ""} {
            set iw [image width $scaled_bg]
            set ih [image height $scaled_bg]
            $canvas create image [expr {($width - $iw) / 2}] [expr {($height - $ih) / 2}] -image $scaled_bg -anchor nw
            return
        }
        set color [my color_for $id]
        $canvas create rectangle 0 0 $width $height -fill $color -outline {}
        set font [list TkDefaultFont [expr {$height / 18}] bold]
        $canvas create text [expr {$width / 2}] [expr {$height / 2}] -text $id -font $font -fill white
    }

    # 根据站位绘制一个角色: 显示默认立绘图片,名字显示在角色脚下.
    method draw_character {name pose x} {
        if {$width < 10 || $height < 10} { return }
        switch -- $x {
            "left" { set cx [expr {$width * 0.25}] }
            "right" { set cx [expr {$width * 0.75}] }
            default { set cx [expr {$width * 0.50}] }
        }

        set tag "char_$name"
        if {$scaled_figure ne ""} {
            $canvas create image $cx [expr {$height - 24}] -image $scaled_figure -anchor s -tags $tag
            $canvas create text $cx [expr {$height - 4}] -text $name -anchor s -font TkDefaultFont -fill white -tags $tag
            return
        }

        # 图片缺失时退化为简单色块.
        set outfit [my color_for "$name/$pose"]
        set body_w [expr {$height * 0.14}]
        set body_h [expr {$height * 0.28}]
        $canvas create rectangle [expr {$cx - $body_w}] [expr {$height - $body_h}] [expr {$cx + $body_w}] $height -fill $outfit -outline {} -tags $tag
        $canvas create text $cx [expr {$height - 6}] -text $name -anchor s -font TkDefaultFont -fill white -tags $tag
    }

    # 根据 id 生成一个稳定的颜色,用于占位色块.
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
