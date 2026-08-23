namespace eval galgame {
    namespace export -force *
}

oo::class create galgame::Application {
    variable root
    variable config
    variable state
    variable ui
    variable audio
    variable save_manager
    variable log
    variable engine
    variable mode
    variable auto_job
    variable skip_job

    constructor {project_root} {
        set root .
        set mode "none"
        set auto_job ""
        set skip_job ""

        set config [galgame::Config new]
        set state [galgame::GameState new]
        set audio [galgame::Audio new $config]
        set ui [galgame::UI new $root [self] $config]
        set save_manager [galgame::SaveManager new $project_root]
        set log [galgame::LogWindow new $root [$state history]]
        set engine [galgame::Engine new [self] $state $ui $audio]
    }

    method run {} {
        wm deiconify $root
        $ui show_title
        vwait ::galgame::_forever
    }

    method smoke {} {
        wm withdraw $root
        after 1000 {exit 0}
        vwait ::galgame::_forever
    }

    method smoke_story {} {
        wm withdraw $root
        after 300 [list [self] start_new]
        after 2200 {exit 0}
        vwait ::galgame::_forever
    }

    method story_path {} {
        return [file join $::galgame::ROOT game story.gal]
    }

    method start_new {} {
        my stop_modes
        set story [galgame::Story new [my story_path]]
        $state reset
        $state set_story $story
        $ui show_game
        $ui clear_line
        $engine start
    }

    method continue_game {} {
        set slot [$save_manager most_recent]
        if {$slot < 1} {
            my start_new
        } else {
            my load_slot $slot
        }
    }

    method save_slot {slot} {
        if {[$state story] eq ""} {
            tk_messageBox -parent $root -type ok -icon info \
                -message "当前没有正在进行的游戏。"
            return
        }
        $save_manager save $slot $state
    }

    method load_slot {slot} {
        my stop_modes
        set data [$save_manager load $slot]
        set script_path [dict get $data script]
        if {![file exists $script_path]} {
            tk_messageBox -parent $root -type ok -icon error \
                -message "存档对应的剧本不存在：\n$script_path"
            return
        }

        set story [galgame::Story new $script_path]
        $state reset
        $state set_story $story
        foreach {name value} [dict get $data flags] {
            $state set_flag $name $value
        }
        $state set_history [dict get $data history]
        $state set_bg [dict get $data bg]
        $state set_cg [dict get $data cg]
        $state set_characters [dict get $data characters]
        $state set_ip [dict get $data ip]
        $state set_waiting [dict get $data waiting]
        $state set_pending_targets [dict get $data pending]

        $ui show_game
        $ui clear_line
        if {[$state cg] ne ""} {
            $ui set_cg [$state cg]
        } else {
            $ui set_background [$state bg]
        }
        $ui set_characters [$state characters]
        $log refresh [$state history]
        $engine resume_loaded
    }

    method advance {} {
        $engine advance
    }

    method choose {label} {
        $ui hide_choice
        $engine choose $label
    }

    method resume_wait {} {
        $engine resume_after_wait
    }

    method return_title {} {
        my stop_modes
        $audio stop_music
        $ui hide_choice
        $ui clear_line
        $ui show_title
    }

    method show_log {} {
        $log show [$state history]
    }

    method show_config {} {
        galgame::ConfigDialog new $root $config [list [self] apply_config]
    }

    method show_save_dialog {} {
        galgame::SlotDialog new $root $save_manager "save" [list [self] save_slot]
    }

    method show_load_dialog {} {
        galgame::SlotDialog new $root $save_manager "load" [list [self] load_slot]
    }

    method apply_config {} {
        $ui apply_config
        if {![$config get music_enabled]} {
            $audio stop_music
        }
    }

    method toggle_auto {} {
        if {$mode eq "skip"} {
            my stop_skip
        }
        if {$mode eq "auto"} {
            my stop_auto
        } else {
            my start_auto
        }
    }

    method toggle_skip {} {
        if {$mode eq "auto"} {
            my stop_auto
        }
        if {$mode eq "skip"} {
            my stop_skip
        } else {
            my start_skip
        }
    }

    method start_auto {} {
        set mode "auto"
        $ui set_mode_button auto 1
        my schedule_auto
    }

    method start_skip {} {
        set mode "skip"
        $ui set_mode_button skip 1
        my schedule_skip
    }

    method stop_auto {} {
        if {$auto_job ne ""} {
            catch {after cancel $auto_job}
            set auto_job ""
        }
        if {$mode eq "auto"} { set mode "none" }
        $ui set_mode_button auto 0
    }

    method stop_skip {} {
        if {$skip_job ne ""} {
            catch {after cancel $skip_job}
            set skip_job ""
        }
        if {$mode eq "skip"} { set mode "none" }
        $ui set_mode_button skip 0
    }

    method stop_modes {} {
        my stop_auto
        my stop_skip
    }

    method schedule_auto {} {
        set auto_job [after [$config get auto_delay_ms] [list [self] auto_tick]]
    }

    method schedule_skip {} {
        set skip_job [after [$config get skip_delay_ms] [list [self] skip_tick]]
    }

    method auto_tick {} {
        if {$mode ne "auto"} return
        if {[$ui is_typing]} {
            $ui finish_typing
        } else {
            my advance
        }
        my schedule_auto
    }

    method skip_tick {} {
        if {$mode ne "skip"} return
        if {[$ui is_typing]} {
            $ui finish_typing
        } else {
            my advance
        }
        my schedule_skip
    }

    method quit {} {
        my stop_modes
        $audio stop_music
        exit 0
    }
}
