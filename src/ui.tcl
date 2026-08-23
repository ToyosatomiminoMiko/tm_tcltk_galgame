namespace eval galgame {
    namespace export -force *
}

oo::class create galgame::UI {
    variable root
    variable top
    variable app
    variable config
    variable visual
    variable location_label
    variable name_label
    variable dialogue_text
    variable title_frame
    variable choice_frame
    variable typing
    variable line_name
    variable line_text
    variable typed_len
    variable typing_job
    variable choice_active
    variable auto_btn
    variable skip_btn

    constructor {root_widget app_obj config_obj} {
        set top $root_widget
        set root ""
        set app $app_obj
        set config $config_obj
        set typing 0
        set line_name ""
        set line_text ""
        set typed_len 0
        set typing_job ""
        set choice_active 0

        wm title $top [$config get title]
        wm geometry $top 960x640
        wm minsize $top 800 560
        wm protocol $top WM_DELETE_WINDOW [list $app quit]

        my build
        my apply_config
        my show_title
    }

    method build {} {
        set root ""
        $top configure -background "#121417"
        grid columnconfigure $top 0 -weight 1
        grid rowconfigure $top 1 -weight 1

        ttk::frame $root.topbar -padding [list 12 5]
        grid $root.topbar -row 0 -column 0 -sticky ew
        grid columnconfigure $root.topbar 1 -weight 1

        ttk::label $root.topbar.title -text [$config get title] -font [list TkDefaultFont 10 bold]
        grid $root.topbar.title -row 0 -column 0 -padx 8

        set location_label [ttk::label $root.topbar.location -text "标题" -anchor center]
        grid $location_label -row 0 -column 1 -sticky ew

        ttk::frame $root.topbar.buttons
        grid $root.topbar.buttons -row 0 -column 2 -sticky e
        set auto_btn [ttk::button $root.topbar.buttons.auto -text "自动" -width 5 -command [list $app toggle_auto]]
        set skip_btn [ttk::button $root.topbar.buttons.skip -text "快进" -width 5 -command [list $app toggle_skip]]
        ttk::button $root.topbar.buttons.log -text "历史" -width 5 -command [list $app show_log]
        ttk::button $root.topbar.buttons.save -text "存档" -width 5 -command [list $app show_save_dialog]
        ttk::button $root.topbar.buttons.load -text "读档" -width 5 -command [list $app show_load_dialog]
        ttk::button $root.topbar.buttons.config -text "设置" -width 5 -command [list $app show_config]
        ttk::button $root.topbar.buttons.title -text "标题" -width 5 -command [list $app return_title]
        pack $auto_btn $skip_btn $root.topbar.buttons.log $root.topbar.buttons.save \
            $root.topbar.buttons.load $root.topbar.buttons.config $root.topbar.buttons.title \
            -side left -padx 3

        set canvas [canvas $root.canvas -background "#1d2228" -highlightthickness 0]
        grid $canvas -row 1 -column 0 -sticky nsew
        set visual [galgame::Visual new $canvas]

        ttk::frame $root.dialogue -padding [list 12 7]
        grid $root.dialogue -row 2 -column 0 -sticky ew
        grid columnconfigure $root.dialogue 1 -weight 1

        set name_label [ttk::label $root.dialogue.name -text "" -font [list TkDefaultFont 10 bold]]
        grid $name_label -row 0 -column 0 -sticky nw -padx [list 2 8]
        set dialogue_text [text $root.dialogue.text -height 4 -wrap word \
            -state disabled -relief flat -background "#f7f3ec" -foreground "#222222" \
            -padx 10 -pady 7 -highlightthickness 0]
        grid $dialogue_text -row 0 -column 1 -sticky ew
        my apply_text_font

        bind $canvas <Button-1> [list [self] on_click]
        bind $root.dialogue <Button-1> [list [self] on_click]
        bind $dialogue_text <Button-1> [list [self] on_click]
        bind $top <space> [list [self] on_key_click]
        bind $top <Return> [list [self] on_key_click]

        my build_title_screen
        my build_choice_frame
    }

    method build_title_screen {} {
        set title_frame [ttk::frame $root.title]
        ttk::label $title_frame.title -text [$config get title] -font [list TkDefaultFont 30 bold]
        ttk::label $title_frame.subtitle -text "一个用于演示 Tcl/Tk 架构的 Galgame 框架" -font TkDefaultFont
        pack $title_frame.title -pady [list 130 8]
        pack $title_frame.subtitle -pady 8
        ttk::frame $title_frame.buttons
        pack $title_frame.buttons -pady 30
        ttk::button $title_frame.buttons.new -text "开始游戏" -width 16 -command [list $app start_new]
        ttk::button $title_frame.buttons.continue -text "继续游戏" -width 16 -command [list $app continue_game]
        ttk::button $title_frame.buttons.load -text "读取存档" -width 16 -command [list $app show_load_dialog]
        ttk::button $title_frame.buttons.config -text "设置" -width 16 -command [list $app show_config]
        ttk::button $title_frame.buttons.quit -text "退出" -width 16 -command [list $app quit]
        pack $title_frame.buttons.new $title_frame.buttons.continue $title_frame.buttons.load \
            $title_frame.buttons.config $title_frame.buttons.quit -side top -pady 6
    }

    method build_choice_frame {} {
        set choice_frame [ttk::frame $root.choice -relief raised -padding 18]
        ttk::label $choice_frame.label -text "选择" -font [list TkDefaultFont 14 bold]
        pack $choice_frame.label -pady 6
        ttk::frame $choice_frame.buttons
        pack $choice_frame.buttons -pady 8
    }

    method show_title {} {
        my hide_choice
        my clear_line
        place $title_frame -x 0 -y 0 -relwidth 1 -relheight 1
        raise $title_frame
        $location_label configure -text "标题"
    }

    method show_game {} {
        place forget $title_frame
        raise $root.canvas
        my hide_choice
    }

    method set_location {text} {
        $location_label configure -text $text
    }

    method location_name {bg_id} {
        switch -- $bg_id {
            "classroom" { return "教室" }
            "library" { return "图书馆" }
            "rooftop" { return "天台" }
            "street" { return "放学路上" }
            "sunset" { return "黄昏的河堤" }
            "room" { return "自己的房间" }
            default { return $bg_id }
        }
    }

    method set_background {id} {
        $visual set_background $id
        my set_location [my location_name $id]
    }

    method set_cg {id} {
        $visual set_cg $id
        my set_location "回忆"
    }

    method show_character {name pose x} {
        $visual show_character $name $pose $x
    }

    method hide_character {name} {
        $visual hide_character $name
    }

    method set_characters {characters} {
        $visual set_characters $characters
    }

    method show_line {name text} {
        my cancel_typing_job
        set line_name $name
        set line_text $text
        set typed_len 0
        set typing 1
        $name_label configure -text $name
        $dialogue_text configure -state normal
        $dialogue_text delete 1.0 end
        $dialogue_text configure -state disabled
        my schedule_typing_tick
    }

    method schedule_typing_tick {} {
        if {!$typing} return
        set delay [$config get text_delay_ms]
        if {$delay < 1} { set delay 1 }
        set typing_job [after $delay [list [self] animate_tick]]
    }

    method animate_tick {} {
        if {!$typing} return
        incr typed_len
        if {$typed_len > [string length $line_text]} {
            set typed_len [string length $line_text]
        }
        set partial [string range $line_text 0 [expr {$typed_len - 1}]]
        $dialogue_text configure -state normal
        $dialogue_text delete 1.0 end
        $dialogue_text insert end $partial
        $dialogue_text configure -state disabled
        $dialogue_text see end
        if {$typed_len < [string length $line_text]} {
            my schedule_typing_tick
        } else {
            set typing 0
            set typing_job ""
        }
    }

    method finish_typing {} {
        my cancel_typing_job
        if {$line_text ne ""} {
            $dialogue_text configure -state normal
            $dialogue_text delete 1.0 end
            $dialogue_text insert end $line_text
            $dialogue_text configure -state disabled
            $dialogue_text see end
        }
        set typed_len [string length $line_text]
        set typing 0
    }

    method clear_line {} {
        my cancel_typing_job
        set typing 0
        set line_name ""
        set line_text ""
        set typed_len 0
        $name_label configure -text ""
        $dialogue_text configure -state normal
        $dialogue_text delete 1.0 end
        $dialogue_text configure -state disabled
    }

    method on_click {} {
        if {$choice_active} return
        if {[winfo ismapped $title_frame]} return
        if {$typing} {
            my finish_typing
        } else {
            $app advance
        }
    }

    method on_key_click {} {
        my on_click
    }

    method show_choice {targets} {
        set choice_active 1
        foreach child [winfo children $choice_frame.buttons] {
            destroy $child
        }
        set idx 0
        foreach pair $targets {
            set text [lindex $pair 0]
            set target [lindex $pair 1]
            set btn [format "%s.buttons.b%d" $choice_frame $idx]
            ttk::button $btn -text $text -width 28 -command [list $app choose $target]
            pack $btn -side top -pady 4
            incr idx
        }
        place $choice_frame -relx 0.5 -rely 0.5 -anchor center
        raise $choice_frame
    }

    method hide_choice {} {
        if {[winfo exists $choice_frame]} {
            place forget $choice_frame
        }
        set choice_active 0
    }

    method is_typing {} { return $typing }

    method cancel_typing_job {} {
        if {$typing_job ne ""} {
            catch {after cancel $typing_job}
            set typing_job ""
        }
    }

    method set_mode_button {mode active} {
        if {$mode eq "auto"} {
            $auto_btn configure -text [expr {$active ? "自动:开" : "自动"}]
        } elseif {$mode eq "skip"} {
            $skip_btn configure -text [expr {$active ? "快进:开" : "快进"}]
        }
    }

    method apply_text_font {} {
        if {[info exists dialogue_text] && $dialogue_text ne ""} {
            $dialogue_text configure -font [list TkDefaultFont [$config get text_size]]
        }
    }

    method apply_config {} {
        my apply_text_font
        wm attributes $top -fullscreen [$config get fullscreen]
    }
}
