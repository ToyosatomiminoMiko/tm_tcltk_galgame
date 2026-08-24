# 存档模块: 负责将游戏状态写入/读回磁盘文件.
# 存档内容使用 Base64 编码,避免特殊字符破坏行式格式.
namespace eval galgame {
    namespace export -force *
}

# 将字符串编码为 Base64(UTF-8).
proc galgame::b64_encode {value} {
    return [binary encode base64 [encoding convertto utf-8 $value]]
}

# 将 Base64 解码回字符串(UTF-8).
proc galgame::b64_decode {value} {
    return [encoding convertfrom utf-8 [binary decode base64 $value]]
}

# SaveManager 类: 管理存档目录以及存档的读写与查询.
oo::class create galgame::SaveManager {
    # 存档目录路径.
    variable dir

    # 构造时确保存档目录存在.
    constructor {root} {
        set dir [file join $root saves]
        file mkdir $dir
    }

    # 根据槽位号生成对应的存档文件路径.
    method slot_path {slot} {
        return [file join $dir [format "slot%02d.save" $slot]]
    }

    # 将状态对象序列化写入指定槽位.
    method save {slot state} {
        set path [my slot_path $slot]
        set f [open $path w]
        fconfigure $f -encoding utf-8
        puts $f "galgame_save 1"
        puts $f "saved_at [galgame::b64_encode [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]]"
        puts $f "script [galgame::b64_encode [[$state story] path]]"
        puts $f "ip [galgame::b64_encode [$state ip]]"
        puts $f "waiting [galgame::b64_encode [$state waiting]]"
        puts $f "bg [galgame::b64_encode [$state bg]]"
        puts $f "cg [galgame::b64_encode [$state cg]]"
        puts $f "characters [galgame::b64_encode [$state characters]]"
        puts $f "pending [galgame::b64_encode [$state pending_targets]]"
        foreach {name value} [$state flags] {
            puts $f "flag [galgame::b64_encode $name] [galgame::b64_encode $value]"
        }
        set history [lrange [$state history] end-29 end]
        puts $f "history [galgame::b64_encode $history]"
        close $f
        return $path
    }

    # 从指定槽位读取并解析存档,返回状态字典.
    method load {slot} {
        set path [my slot_path $slot]
        if {![file exists $path]} {
            error "No save in slot $slot"
        }

        set f [open $path r]
        fconfigure $f -encoding utf-8
        set data [dict create flags [dict create] history [list]]
        set first [string trim [gets $f]]
        if {$first ne "galgame_save 1"} {
            close $f
            error "Invalid save file: $path"
        }
        while {[gets $f line] >= 0} {
            if {[string trim $line] eq ""} continue
            set key [string trimleft $line]
            set idx [string first " " $key]
            if {$idx < 0} {
                set field $key
                set rest ""
            } else {
                set field [string range $key 0 [expr {$idx - 1}]]
                set rest [string range $key [expr {$idx + 1}] end]
            }
            switch -- $field {
                "script" - "ip" - "waiting" - "bg" - "cg" - "characters" - "pending" - "history" - "saved_at" {
                    dict set data $field [galgame::b64_decode [string trim $rest]]
                }
                "flag" {
                    set vals [split [string trim $rest]]
                    if {[llength $vals] != 2} continue
                    set flag_name [galgame::b64_decode [lindex $vals 0]]
                    set flag_value [galgame::b64_decode [lindex $vals 1]]
                    dict set data flags $flag_name $flag_value
                }
            }
        }
        close $f
        return $data
    }

    # 读取某槽位的存档时间摘要,用于在列表中展示.
    method slot_summary {slot} {
        set path [my slot_path $slot]
        if {![file exists $path]} {
            return [list $slot "空存档"]
        }
        set info ""
        set f [open $path r]
        fconfigure $f -encoding utf-8
        gets $f
        while {[gets $f line] >= 0} {
            set key [string trimleft $line]
            set idx [string first " " $key]
            if {$idx < 0} continue
            set field [string range $key 0 [expr {$idx - 1}]]
            if {$field eq "saved_at"} {
                set rest [string range $key [expr {$idx + 1}] end]
                set info [galgame::b64_decode [string trim $rest]]
                break
            }
        }
        close $f
        if {$info eq ""} { set info "未知时间" }
        return [list $slot $info]
    }

    # 返回最近一次存档的槽位号,没有存档时返回 -1.
    method most_recent {} {
        set best -1
        set best_time 0
        for {set slot 1} {$slot <= 6} {incr slot} {
            set path [my slot_path $slot]
            if {![file exists $path]} continue
            set mtime [file mtime $path]
            if {$mtime > $best_time} {
                set best $slot
                set best_time $mtime
            }
        }
        return $best
    }
}
