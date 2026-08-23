namespace eval galgame {
    namespace export -force *
}

oo::class create galgame::GameState {
    variable story
    variable ip
    variable flags
    variable history
    variable bg
    variable characters
    variable cg
    variable waiting
    variable pending_targets

    constructor {} {
        my reset
    }

    method reset {} {
        set story ""
        set ip 0
        set flags [dict create]
        set history [list]
        set bg "title"
        set cg ""
        set characters [dict create]
        set waiting 0
        set pending_targets [list]
    }

    method story {} { return $story }
    method set_story {value} { set story $value }

    method ip {} { return $ip }
    method set_ip {value} { set ip $value }

    method flags {} { return $flags }
    method set_flag {name value} { dict set flags $name $value }
    method get_flag {name} {
        if {[dict exists $flags $name]} {
            return [dict get $flags $name]
        }
        return ""
    }
    method unset_flag {name} { dict unset flags $name }
    method incr_flag {name amount} {
        set current 0
        if {[dict exists $flags $name]} {
            set current [dict get $flags $name]
            if {![string is double -strict $current]} { set current 0 }
        }
        dict set flags $name [expr {$current + $amount}]
    }

    method history {} { return $history }
    method set_history {value} { set history $value }
    method add_history {name text} {
        lappend history [list $name $text]
        if {[llength $history] > 300} {
            set history [lrange $history end-299 end]
        }
    }

    method bg {} { return $bg }
    method set_bg {value} {
        set bg $value
        set cg ""
    }
    method cg {} { return $cg }
    method set_cg {value} {
        set cg $value
    }

    method characters {} { return $characters }
    method set_characters {value} { set characters $value }
    method set_character {name pose x} {
        dict set characters $name [list $pose $x]
    }
    method remove_character {name} {
        if {[dict exists $characters $name]} {
            dict unset characters $name
        }
    }
    method clear_characters {} { set characters [dict create] }

    method waiting {} { return $waiting }
    method set_waiting {value} { set waiting $value }

    method pending_targets {} { return $pending_targets }
    method set_pending_targets {value} { set pending_targets $value }
}
