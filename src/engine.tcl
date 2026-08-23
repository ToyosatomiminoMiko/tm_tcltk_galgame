namespace eval galgame {
    namespace export -force *
}

oo::class create galgame::Engine {
    variable app
    variable state
    variable ui
    variable audio

    constructor {app_obj state_obj ui_obj audio_obj} {
        set app $app_obj
        set state $state_obj
        set ui $ui_obj
        set audio $audio_obj
    }

    method start {} {
        set story [$state story]
        if {$story eq ""} {
            error "No story has been loaded"
        }
        $state set_ip 0
        $state set_waiting 0
        $state set_pending_targets [list]
        my run_loop
    }

    method advance {} {
        if {[$state waiting]} {
            $state set_waiting 0
        }
        my run_loop
    }

    method choose {label} {
        set story [$state story]
        $state set_waiting 0
        $state set_pending_targets [list]
        $state set_ip [$story target_index $label]
        my run_loop
    }

    method resume_loaded {} {
        set story [$state story]
        if {$story eq ""} {
            $app return_title
            return
        }

        set pending [$state pending_targets]
        if {[llength $pending] > 0} {
            $ui show_choice $pending
            $state set_waiting 1
            return
        }

        if {[$state waiting]} {
            set cmd [$story command_at [$state ip]]
            set op [lindex $cmd 0]
            set args [lrange $cmd 1 end]
            if {$op eq "say" || $op eq "narrate"} {
                set name ""
                set text [lindex $args end]
                if {$op eq "say"} {
                    set name [lindex $args 0]
                    set text [lindex $args 1]
                }
                $ui show_line $name $text
                return
            }
        }

        $state set_waiting 0
        my run_loop
    }

    method resume_after_wait {} {
        $state set_waiting 0
        my run_loop
    }

    method run_loop {} {
        while {1} {
            set story [$state story]
            if {$story eq ""} {
                return
            }
            set ip [$state ip]
            if {$ip < 0 || $ip >= [$story line_count]} {
                $app return_title
                return
            }

            set cmd [$story command_at $ip]
            $state set_ip [expr {$ip + 1}]
            set op [lindex $cmd 0]
            set args [lrange $cmd 1 end]

            set continue_after [my dispatch $op {*}$args]
            if {!$continue_after} {
                return
            }
        }
    }

    method dispatch {op args} {
        switch -- $op {
            "label" {
                return 1
            }
            "say" {
                if {[llength $args] != 2} {
                    error "say requires <name> <text>"
                }
                my show_say [lindex $args 0] [lindex $args 1] 1
                return 0
            }
            "narrate" {
                if {[llength $args] != 1} {
                    error "narrate requires <text>"
                }
                my show_say "" [lindex $args 0] 1
                return 0
            }
            "bg" {
                if {[llength $args] != 1} {
                    error "bg requires <id>"
                }
                $state set_bg [lindex $args 0]
                $ui set_background [lindex $args 0]
                return 1
            }
            "cg" {
                if {[llength $args] != 1} {
                    error "cg requires <id>"
                }
                $state set_cg [lindex $args 0]
                $ui set_cg [lindex $args 0]
                return 1
            }
            "show" {
                if {[llength $args] < 2} {
                    error {show requires <character> <pose> [x]}
                }
                set name [lindex $args 0]
                set pose [lindex $args 1]
                set x "center"
                if {[llength $args] >= 3} {
                    set x [lindex $args 2]
                }
                $state set_character $name $pose $x
                $ui show_character $name $pose $x
                return 1
            }
            "hide" {
                if {[llength $args] != 1} {
                    error "hide requires <character>"
                }
                $state remove_character [lindex $args 0]
                $ui hide_character [lindex $args 0]
                return 1
            }
            "flag" {
                if {[llength $args] != 2} {
                    error "flag requires <name> <value>"
                }
                $state set_flag [lindex $args 0] [lindex $args 1]
                return 1
            }
            "clear" {
                if {[llength $args] != 1} {
                    error "clear requires <name>"
                }
                $state unset_flag [lindex $args 0]
                return 1
            }
            "add" {
                if {[llength $args] != 2} {
                    error "add requires <name> <amount>"
                }
                $state incr_flag [lindex $args 0] [lindex $args 1]
                return 1
            }
            "jump" {
                if {[llength $args] != 1} {
                    error "jump requires <label>"
                }
                set story [$state story]
                $state set_ip [$story target_index [lindex $args 0]]
                return 1
            }
            "if" {
                my execute_if 0 {*}$args
                return 1
            }
            "ifnot" {
                my execute_if 1 {*}$args
                return 1
            }
            "menu" {
                if {[llength $args] != 1} {
                    error "menu requires a choices list"
                }
                my show_menu [lindex $args 0]
                return 0
            }
            "music" {
                if {[llength $args] != 1} {
                    error "music requires <id>"
                }
                $audio play_music [lindex $args 0]
                return 1
            }
            "stopmusic" {
                $audio stop_music
                return 1
            }
            "sfx" {
                if {[llength $args] != 1} {
                    error "sfx requires <id>"
                }
                $audio play_sfx [lindex $args 0]
                return 1
            }
            "wait" {
                if {[llength $args] != 1} {
                    error "wait requires <milliseconds>"
                }
                $state set_waiting 1
                after [lindex $args 0] [list $app resume_wait]
                return 0
            }
            "end" {
                $app return_title
                return 0
            }
        }
        error "Unknown story command: $op"
    }

    method show_say {name text add_to_history} {
        if {$add_to_history} {
            $state add_history $name $text
        }
        $state set_waiting 1
        $ui show_line $name $text
    }

    method show_menu {targets} {
        if {![llength $targets]} {
            error "menu has no choices"
        }
        $state set_pending_targets $targets
        $state set_waiting 1
        $ui show_choice $targets
    }

    method execute_if {negate args} {
        set story [$state story]
        set arrow [lsearch -exact $args "->"]
        if {$arrow >= 0} {
            set label [lindex $args [expr {$arrow + 1}]]
            set cond [lrange $args 0 [expr {$arrow - 1}]]
        } else {
            set label [lindex $args end]
            set cond [lrange $args 0 end-1]
        }
        if {$label eq ""} {
            error "if requires a jump target"
        }

        set result 0
        if {[llength $cond] == 1} {
            set result [my truthy [$state get_flag [lindex $cond 0]]]
        } elseif {[llength $cond] == 3} {
            set result [my compare \
                [$state get_flag [lindex $cond 0]] \
                [lindex $cond 1] \
                [lindex $cond 2]]
        } else {
            error "Malformed if condition: $cond"
        }

        if {$negate} {
            set result [expr {!$result}]
        }
        if {$result} {
            $state set_ip [$story target_index $label]
        }
    }

    method truthy {value} {
        if {$value eq ""} { return 0 }
        if {[string is true -strict $value]} { return 1 }
        if {[string is false -strict $value]} { return 0 }
        if {[string is double -strict $value]} {
            return [expr {$value != 0}]
        }
        return 1
    }

    method compare {a op b} {
        set numeric 0
        if {[string is double -strict $a] && [string is double -strict $b]} {
            set numeric 1
        }
        switch -- $op {
            "==" {
                if {$numeric} { return [expr {$a == $b}] }
                return [expr {$a eq $b}]
            }
            "!=" {
                if {$numeric} { return [expr {$a != $b}] }
                return [expr {$a ne $b}]
            }
            "<" {
                if {$numeric} { return [expr {$a < $b}] }
                return [expr {[string compare $a $b] < 0}]
            }
            ">" {
                if {$numeric} { return [expr {$a > $b}] }
                return [expr {[string compare $a $b] > 0}]
            }
            "<=" {
                if {$numeric} { return [expr {$a <= $b}] }
                return [expr {[string compare $a $b] <= 0}]
            }
            ">=" {
                if {$numeric} { return [expr {$a >= $b}] }
                return [expr {[string compare $a $b] >= 0}]
            }
        }
        error "Unknown comparison operator: $op"
    }
}
