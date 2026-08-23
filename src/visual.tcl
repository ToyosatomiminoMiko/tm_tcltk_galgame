namespace eval galgame {
    namespace export -force *
}

oo::class create galgame::Visual {
    variable canvas
    variable width
    variable height
    variable current_bg
    variable current_cg
    variable char_items

    constructor {canvas_widget} {
        set canvas $canvas_widget
        set width 1
        set height 1
        set current_bg ""
        set current_cg ""
        set char_items [dict create]
        bind $canvas <Configure> [list [self] on_resize]
    }

    method on_resize {} {
        set width [winfo width $canvas]
        set height [winfo height $canvas]
        if {$width > 2 && $height > 2} {
            my redraw
        }
    }

    method redraw {} {
        $canvas delete all
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

    method set_background {id} {
        set current_bg $id
        set current_cg ""
        my redraw
    }

    method set_cg {id} {
        set current_cg $id
        my redraw
    }

    method show_character {name pose x} {
        dict set char_items $name [list $pose $x]
        my redraw
    }

    method hide_character {name} {
        if {[dict exists $char_items $name]} {
            dict unset char_items $name
        }
        my redraw
    }

    method clear_characters {} {
        set char_items [dict create]
        my redraw
    }

    method set_characters {char_dict} {
        set char_items $char_dict
        my redraw
    }

    method draw_placeholder {id label is_cg} {
        if {$width < 10 || $height < 10} { return }
        set color [my color_for $id]
        $canvas create rectangle 0 0 $width $height -fill $color -outline {}

        if {$is_cg} {
            set font [list TkDefaultFont [expr {$height / 18}] bold]
            $canvas create text [expr {$width / 2}] [expr {$height / 2}] \
                -text $id -font $font -fill white
            $canvas create text [expr {$width / 2}] [expr {$height / 2 + 36}] \
                -text "（CG 资源占位，可替换 assets/cg）" -font TkDefaultFont -fill white
            return
        }

        set horizon [expr {$height * 0.58}]
        $canvas create rectangle 0 $horizon $width $height -fill [my darker $color] -outline {}
        set font [list TkDefaultFont [expr {$height / 18}] bold]
        $canvas create text 24 [expr {$height / 12}] -text $id -anchor w -font $font -fill white
        $canvas create text [expr {$width - 24}] [expr {$height - 34}] -anchor se \
            -text "背景资源占位：assets/bg/$id.png" -font TkDefaultFont -fill white
    }

    method draw_character {name pose x} {
        if {$width < 10 || $height < 10} { return }
        switch -- $x {
            "left" { set cx [expr {$width * 0.25}] }
            "right" { set cx [expr {$width * 0.75}] }
            default { set cx [expr {$width * 0.50}] }
        }

        set skin "#f2c39b"
        set hair [my color_for "$name/hair"]
        set outfit [my color_for "$name/$pose"]
        set body_top [expr {$height * 0.48}]
        set head_r [expr {$height * 0.075}]
        set body_w [expr {$head_r * 2.4}]
        set body_h [expr {$height * 0.28}]

        set tag "char_$name"
        $canvas create rectangle \
            [expr {$cx - $body_w}] $body_top \
            [expr {$cx + $body_w}] [expr {$body_top + $body_h}] \
            -fill $outfit -outline {} -tags $tag
        $canvas create oval \
            [expr {$cx - $head_r}] [expr {$body_top - $head_r * 1.9}] \
            [expr {$cx + $head_r}] [expr {$body_top - $head_r * 0.3}] \
            -fill $skin -outline {} -tags $tag
        $canvas create polygon \
            [expr {$cx - $head_r * 1.15}] [expr {$body_top - $head_r * 1.35}] \
            [expr {$cx - $head_r * 1.25}] [expr {$body_top - $head_r * 2.55}] \
            [expr {$cx + $head_r * 1.25}] [expr {$body_top - $head_r * 2.55}] \
            [expr {$cx + $head_r * 1.15}] [expr {$body_top - $head_r * 1.35}] \
            -fill $hair -outline {} -tags $tag
        $canvas create oval \
            [expr {$cx - $head_r * 0.42}] [expr {$body_top - $head_r * 1.45}] \
            [expr {$cx - $head_r * 0.16}] [expr {$body_top - $head_r * 1.12}] \
            -fill "#2a2a2a" -outline {} -tags $tag
        $canvas create oval \
            [expr {$cx + $head_r * 0.16}] [expr {$body_top - $head_r * 1.45}] \
            [expr {$cx + $head_r * 0.42}] [expr {$body_top - $head_r * 1.12}] \
            -fill "#2a2a2a" -outline {} -tags $tag

        set mouth_y [expr {$body_top - $head_r * 0.72}]
        switch -- $pose {
            "smile" {
                $canvas create arc \
                    [expr {$cx - $head_r * 0.25}] $mouth_y \
                    [expr {$cx + $head_r * 0.25}] [expr {$mouth_y + $head_r * 0.3}] \
                    -start 200 -extent 140 -style arc -outline "#4b2f2f" -width 2 -tags $tag
            }
            "blush" {
                $canvas create oval \
                    [expr {$cx - $head_r * 0.55}] [expr {$body_top - $head_r * 1.15}] \
                    [expr {$cx - $head_r * 0.22}] [expr {$body_top - $head_r * 0.86}] \
                    -fill "#e58d8d" -outline {} -tags $tag
                $canvas create oval \
                    [expr {$cx + $head_r * 0.22}] [expr {$body_top - $head_r * 1.15}] \
                    [expr {$cx + $head_r * 0.55}] [expr {$body_top - $head_r * 0.86}] \
                    -fill "#e58d8d" -outline {} -tags $tag
                $canvas create line \
                    [expr {$cx - $head_r * 0.22}] $mouth_y \
                    [expr {$cx + $head_r * 0.22}] $mouth_y \
                    -fill "#4b2f2f" -width 2 -tags $tag
            }
            "sad" {
                $canvas create arc \
                    [expr {$cx - $head_r * 0.25}] [expr {$mouth_y + $head_r * 0.18}] \
                    [expr {$cx + $head_r * 0.25}] [expr {$mouth_y + $head_r * 0.48}] \
                    -start 20 -extent 140 -style arc -outline "#4b2f2f" -width 2 -tags $tag
            }
            default {
                $canvas create line \
                    [expr {$cx - $head_r * 0.22}] $mouth_y \
                    [expr {$cx + $head_r * 0.22}] $mouth_y \
                    -fill "#4b2f2f" -width 2 -tags $tag
            }
        }

        $canvas create text $cx [expr {$body_top + $body_h + 14}] \
            -text $name -anchor n -font TkDefaultFont -fill white -tags $tag
    }

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

    method darker {color} {
        return $color
    }
}
