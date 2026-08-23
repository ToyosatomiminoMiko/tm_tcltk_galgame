namespace eval galgame {
    namespace export -force *
}

proc galgame::child_path {parent suffix} {
    if {$parent eq "." || $parent eq ""} {
        return ".$suffix"
    }
    return "$parent.$suffix"
}

oo::class create galgame::Config {
    variable data

    constructor {} {
        my defaults
    }

    method defaults {} {
        set data [dict create \
            title "放课后的约定" \
            text_delay_ms 28 \
            auto_delay_ms 1300 \
            skip_delay_ms 120 \
            text_size 12 \
            fullscreen 0 \
            sfx_enabled 1 \
            music_enabled 1]
    }

    method get {key} {
        if {[dict exists $data $key]} {
            return [dict get $data $key]
        }
        return ""
    }

    method set {key value} {
        dict set data $key $value
    }

    method toggle {key} {
        dict set data $key [expr {![dict get $data $key]}]
    }
}
