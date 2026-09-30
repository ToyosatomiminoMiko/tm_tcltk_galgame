# 剧本模块: 解析面向行的小型剧情 DSL,并封装为 Story 类.
# DSL 刻意保持精简,新命令可在 Engine 中继续扩展.
# 一个内容包的剧本可以拆成多份 *.gal,用 include 拼成同一条指令流.
namespace eval galgame {
    namespace export -force *
}

# 去掉一行中的注释部分,同时正确跳过引号与花括号内的 "#" 字符.
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

# 将一行剧本拆分为 token 列表,支持引号字符串与花括号分组.
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

# Story 类: 保存已解析的剧情指令序列与标签索引,供引擎执行.
oo::class create galgame::Story {
    # 入口剧本文件路径.
    variable path
    # 解析后的指令列表,每项是一个 [命令 参数...] 列表.
    variable lines
    # 标签名到指令索引的映射.
    variable labels
    # 剧本标题.
    variable title

    # 构造时立即加载并解析剧本文件.
    constructor {story_path} {
        my load $story_path
    }

    # 加载并解析入口剧本, 入口文件可以用 include 拼接更多 *.gal.
    method load {story_path} {
        set path [file normalize $story_path]
        if {![file exists $path]} {
            error "Story file not found: $path"
        }

        set lines [list]
        set labels [dict create]
        set title ""
        my load_file $path [list]

        if {$title eq ""} {
            set title "Galgame Sample"
        }
    }

    # 解析一个剧本文件, 把指令追加进 lines, 标签写进 labels.
    # stack 是正在解析的文件栈, 用来发现 include 成环.
    # [为什么 include 在解析期展开] 展开后所有文件共享同一条指令流与同一份标签
    # 表, 引擎看到的仍然只是一个线性指令数组: jump/if 的目标索引天然跨文件有效,
    # 引擎与存档格式都不需要知道剧本被拆成了几份.
    method load_file {file_path stack} {
        if {[lsearch -exact $stack $file_path] >= 0} {
            error "include 成环: $file_path (调用链: [join $stack { -> }])"
        }
        lappend stack $file_path

        set f [open $file_path r]
        set raw [split [read $f] "\n"]
        close $f

        # menu 块的状态每个文件各自独立: 一个 menu 块不允许跨文件.
        set in_menu 0
        set menu_choices [list]

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

            # 处于 menu 块内时,只接受 option 与 endmenu.
            if {$in_menu} {
                if {$op eq "option"} {
                    if {[llength $args] != 2} {
                        error "$file_path:$lineno: option requires <text> <label>"
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
                error "$file_path:$lineno: only option/endmenu allowed inside menu block"
            }

            switch -- $op {
                "menu" {
                    if {[llength $args] != 0} {
                        error "$file_path:$lineno: menu takes no arguments"
                    }
                    set in_menu 1
                    set menu_choices [list]
                }
                "label" {
                    if {[llength $args] != 1} {
                        error "$file_path:$lineno: label requires one name"
                    }
                    set name [lindex $args 0]
                    # [为什么要报重复标签] 剧本可以拆成多个文件, 重名标签在单文件
                    # 时代只是被悄悄覆盖, 拆开之后会变成极难定位的跳转错误.
                    if {[dict exists $labels $name]} {
                        error "$file_path:$lineno: label 重复定义: $name"
                    }
                    dict set labels $name [llength $lines]
                    lappend lines [list label $name]
                }
                "include" {
                    if {[llength $args] != 1} {
                        error "$file_path:$lineno: include requires one file"
                    }
                    # 相对当前文件所在目录解析, 这样整个剧本目录搬走仍然成立.
                    set inc [file normalize [file join [file dirname $file_path] [lindex $args 0]]]
                    if {![file exists $inc]} {
                        error "$file_path:$lineno: include 的文件不存在: $inc"
                    }
                    my load_file $inc $stack
                }
                "title" {
                    if {[llength $args] != 1} {
                        error "$file_path:$lineno: title requires one string"
                    }
                    # 窗口标题的唯一来源是内容包清单; 剧本里的 title 只作为
                    # Story 的元信息, 取第一个出现的值.
                    if {$title eq ""} {
                        set title [lindex $args 0]
                    }
                }
                default {
                    lappend lines [linsert $args 0 $op]
                }
            }
        }

        if {$in_menu} {
            error "$file_path: menu block is missing endmenu"
        }
    }

    # 以下为剧本元信息的只读访问方法.
    method path {} { return $path }
    method lines {} { return $lines }
    method line_count {} { return [llength $lines] }
    method title {} { return $title }

    # 返回指定索引处的指令,越界时报错.
    method command_at {index} {
        if {$index < 0 || $index >= [llength $lines]} {
            error "Story index out of range: $index"
        }
        return [lindex $lines $index]
    }

    # 根据标签名返回其对应的指令索引.
    method target_index {label} {
        if {![dict exists $labels $label]} {
            error "Unknown label: $label"
        }
        return [dict get $labels $label]
    }
}
