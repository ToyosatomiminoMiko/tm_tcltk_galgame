# 存档模块: 负责将游戏状态写入/读回磁盘文件.
# 存档内容使用 Base64 编码, 避免特殊字符破坏行式格式.
# [职责边界] 本模块不知道存档该放在哪里(目录由入口按内容包 id 解析后传进来),
# 也不认识具体作品: 它只记录内容包 id 与剧本的相对路径, 因此内容包整体搬走
# 之后, 老存档仍然能对上.
namespace eval galgame {
    namespace export -force *
}

# 存档格式版本.
# 1 是旧格式: 存的是剧本的绝对路径, 内容包一换目录就失效.
# 2 起改为"内容包 id + 相对内容包目录的剧本路径".
set galgame::SAVE_VERSION 2

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
    # 存档目录路径(绝对路径, 构造时创建).
    variable dir

    # 构造时记住存档目录并确保它存在.
    constructor {save_dir} {
        set dir [file normalize $save_dir]
        file mkdir $dir
    }

    # 返回存档目录, 便于界面或日志显示.
    method dir {} { return $dir }

    # 根据槽位号生成对应的存档文件路径.
    method slot_path {slot} {
        return [file join $dir [format "slot%02d.save" $slot]]
    }

    # 将状态对象序列化写入指定槽位.
    # pack 提供内容包 id 与剧本的相对路径, 它们让存档与具体目录解耦.
    method save {slot state pack} {
        set path [my slot_path $slot]
        set f [open $path w]
        fconfigure $f -encoding utf-8
        puts $f "galgame_save $::galgame::SAVE_VERSION"
        puts $f "saved_at [galgame::b64_encode [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]]"
        puts $f "pack [galgame::b64_encode [$pack id]]"
        puts $f "script [galgame::b64_encode [$pack entry_rel]]"
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

    # 从指定槽位读取并解析存档, 返回状态字典.
    # [为什么要校验内容包] 不同游戏的剧本与旗标互不通用: 拿 A 的存档去恢复 B
    # 只会得到一堆对不上的跳转, 所以宁可在这里直接报错.
    method load {slot pack} {
        set path [my slot_path $slot]
        if {![file exists $path]} {
            error "No save in slot $slot"
        }

        set f [open $path r]
        fconfigure $f -encoding utf-8
        set raw [split [read $f] "\n"]
        close $f

        set header [string trim [lindex $raw 0]]
        set expected "galgame_save $::galgame::SAVE_VERSION"
        if {$header ne $expected} {
            error "存档格式不受支持: $path (实际: $header, 期望: $expected)"
        }

        set data [dict create flags [dict create] history [list]]
        foreach line [lrange $raw 1 end] {
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
                "pack" - "script" - "ip" - "waiting" - "bg" - "cg" - "characters" - "pending" - "history" - "saved_at" {
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

        foreach required {pack script ip} {
            if {![dict exists $data $required]} {
                error "存档缺少必需字段 $required: $path"
            }
        }
        set saved_pack [dict get $data pack]
        if {$saved_pack ne [$pack id]} {
            error "存档属于内容包 $saved_pack, 当前运行的是 [$pack id]: $path"
        }
        return $data
    }

    # 读取某槽位的存档时间摘要, 用于在列表中展示.
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

    # 返回最近一次存档的槽位号, 没有存档时返回 -1.
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
