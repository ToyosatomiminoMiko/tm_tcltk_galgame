# 配置模块: 提供全局配置项的读取,写入与开关切换.
# 本文件同时定义了一个用于拼接 Tk 子路径的工具函数.
namespace eval galgame {
    namespace export -force *
}

# 根据父路径与子名称拼出 Tk 组件的完整路径.
# 当父路径为空或为 "." 时, 子路径以 "." 开头, 符合 Tk 路径命名规则.
proc galgame::child_path {parent suffix} {
    if {$parent eq "." || $parent eq ""} {
        return ".$suffix"
    }
    return "$parent.$suffix"
}

# Config 类: 用字典保存游戏配置,并提供统一的访问接口.
oo::class create galgame::Config {
    # 内部字典,存放所有配置键值对.
    variable data

    # 构造时写入默认配置.
    constructor {} {
        my defaults
    }

    # 写入各项默认配置.
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

    # 读取指定配置项,不存在时返回空字符串.
    method get {key} {
        if {[dict exists $data $key]} {
            return [dict get $data $key]
        }
        return ""
    }

    # 写入或更新指定配置项.
    method set {key value} {
        dict set data $key $value
    }

    # 翻转布尔型配置项(在 0 与 1 之间切换).
    method toggle {key} {
        dict set data $key [expr {![dict get $data $key]}]
    }
}
