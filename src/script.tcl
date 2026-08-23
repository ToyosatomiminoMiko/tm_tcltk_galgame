namespace eval galgame {
    namespace export -force *
}

# A tiny, line-oriented story DSL. Every non-empty line is one command.
# The DSL intentionally stays small so new commands can be added in Engine.

proc galgame::strip_comment {line} {
    set quote 0
    set brace 0
    set n [string length $line]
    for {set i 0} {$i < $n} {incr i} {
        set ch [string index $line $i]
        if {$quote} {
            if {$ch eq "\\"} {
                incr i
            } elseif {$ch eq "\""} {
                set quote 0
            }
            continue
        }
        if {$brace} {
            if {$ch eq "\\"} {
                incr i
            } elseif {$ch eq "\{"} {
                incr brace
            } elseif {$ch eq "\}"} {
                incr brace -1
            }
            continue
        }
        if {$ch eq "\""} {
            set quote 1
        } elseif {$ch eq "\{"} {
            set brace 1
        } elseif {$ch eq "#"} {
            return [string range $line 0 [expr {$i - 1}]]
        }
    }
    return $line
}

proc galgame::tokenize {line} {
    set tokens [list]
    set n [string length $line]
    set i 0
    while {$i < $n} {
        set ch [string index $line $i]
        if {[string is space -strict $ch]} {
            incr i
            continue
        }

        set token ""
        if {$ch eq "\""} {
            incr i
            while {$i < $n} {
                set c [string index $line $i]
                if {$c eq "\\"} {
                    incr i
                    if {$i < $n} {
                        append token [string index $line $i]
                    }
                    incr i
                    continue
                }
                if {$c eq "\""} {
                    incr i
                    break
                }
                append token $c
                incr i
            }
            lappend tokens $token
            continue
        }

        if {$ch eq "\{"} {
            incr i
            set depth 1
            while {$i < $n && $depth > 0} {
                set c [string index $line $i]
                if {$c eq "\\"} {
                    incr i
                    if {$i < $n} {
                        append token [string index $line $i]
                    }
                    incr i
                    continue
                }
                if {$c eq "\{"} {
                    incr depth
                    append token $c
                } elseif {$c eq "\}"} {
                    incr depth -1
                    if {$depth > 0} {
                        append token $c
                    }
                } else {
                    append token $c
                }
                incr i
            }
            lappend tokens $token
            continue
        }

        while {$i < $n} {
            set c [string index $line $i]
            if {[string is space -strict $c]} {
                break
            }
            if {$c eq "\\"} {
                incr i
                if {$i < $n} {
                    append token [string index $line $i]
                }
                incr i
                continue
            }
            append token $c
            incr i
        }
        lappend tokens $token
    }
    return $tokens
}

oo::class create galgame::Story {
    variable path
    variable lines
    variable labels
    variable title

    constructor {story_path} {
        my load $story_path
    }

    method load {story_path} {
        set path [file normalize $story_path]
        if {![file exists $path]} {
            error "Story file not found: $path"
        }

        set lines [list]
        set labels [dict create]
        set title ""
        set in_menu 0
        set menu_choices [list]

        set f [open $path r]
        set raw [split [read $f] "\n"]
        close $f

        set lineno 0
        foreach line $raw {
            incr lineno
            set line [galgame::strip_comment $line]
            set line [string trim $line]
            if {$line eq ""} continue

            set tokens [galgame::tokenize $line]
            if {![llength $tokens]} continue
            set op [lindex $tokens 0]
            set args [lrange $tokens 1 end]

            if {$in_menu} {
                if {$op eq "option"} {
                    if {[llength $args] != 2} {
                        error "$path:$lineno: option requires <text> <label>"
                    }
                    lappend menu_choices [list [lindex $args 0] [lindex $args 1]]
                    continue
                }
                if {$op eq "endmenu"} {
                    set in_menu 0
                    lappend lines [list menu $menu_choices]
                    set menu_choices [list]
                    continue
                }
                error "$path:$lineno: only option/endmenu allowed inside menu block"
            }

            switch -- $op {
                "menu" {
                    if {[llength $args] != 0} {
                        error "$path:$lineno: menu takes no arguments"
                    }
                    set in_menu 1
                    set menu_choices [list]
                }
                "label" {
                    if {[llength $args] != 1} {
                        error "$path:$lineno: label requires one name"
                    }
                    dict set labels [lindex $args 0] [llength $lines]
                    lappend lines [list label [lindex $args 0]]
                }
                "title" {
                    if {[llength $args] != 1} {
                        error "$path:$lineno: title requires one string"
                    }
                    set title [lindex $args 0]
                }
                default {
                    lappend lines [linsert $args 0 $op]
                }
            }
        }

        if {$in_menu} {
            error "$path: menu block is missing endmenu"
        }
        if {$title eq ""} {
            set title "Galgame Sample"
        }
    }

    method path {} { return $path }
    method lines {} { return $lines }
    method line_count {} { return [llength $lines] }
    method title {} { return $title }

    method command_at {index} {
        if {$index < 0 || $index >= [llength $lines]} {
            error "Story index out of range: $index"
        }
        return [lindex $lines $index]
    }

    method target_index {label} {
        if {![dict exists $labels $label]} {
            error "Unknown label: $label"
        }
        return [dict get $labels $label]
    }
}
