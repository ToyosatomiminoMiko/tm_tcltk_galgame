# 状态模块: 集中保存一局游戏进行中的运行时数据.
# 包括剧情对象,指令指针,剧情标志,对话历史,背景/CG,角色站位以及等待状态.
namespace eval galgame {
    namespace export -force *
}

# GameState 类: 封装所有可变的游戏状态,并提供读写接口.
oo::class create galgame::GameState {
    # 当前加载的剧情对象.
    variable story
    # 当前指令指针,指向 story 中的下一条指令.
    variable ip
    # 剧情标志字典,用于记录分支条件.
    variable flags
    # 对话历史列表,每项为 [名字 文本].
    variable history
    # 当前背景编号.
    variable bg
    # 当前登场角色字典,键为角色名,值为 [pose x].
    variable characters
    # 当前 CG 编号.
    variable cg
    # 是否处于等待用户或定时器的暂停状态.
    variable waiting
    # 待展示的菜单选项列表,用于读档后恢复选项界面.
    variable pending_targets

    # 构造时重置所有状态.
    constructor {} {
        my reset
    }

    # 将所有状态恢复为初始值,用于开始新游戏与读档.
    # 会连对话日志一起清空,因为这是一局的开始,不继承上一局的记录.
    method reset {} {
        set history [list]
        my reset_run
        set bg "title"
    }

    # 清空"一局"的运行数据:剧本引用,指令指针,旗标与场景表现.
    # [为什么保留 history] history 是给"历史"窗口看的日志,属于功能数据
    # 而不是可由别处重建的缓存,所以整局结束后仍然保留,只在开始新游戏
    # 或读档时被替换.
    method reset_run {} {
        set story ""
        set ip 0
        set flags [dict create]
        my reset_scene
    }

    # 清空"一个场景"的表现数据,用于跳转到新 label 时丢弃上一个场景.
    # [为什么不在这里碰 flags] 旗标是跨场景的分支依据:示例剧本在 library
    # 里写 went_library,跳回 evening 后才读取它来决定结局.若在场景边界
    # 清掉旗标,所有分支都会失效.
    method reset_scene {} {
        set bg ""
        set cg ""
        set characters [dict create]
        set pending_targets [list]
        set waiting 0
    }

    # 以下为 story 的读取与设置.
    method story {} { return $story }
    method set_story {value} { set story $value }

    # 以下为指令指针 ip 的读取与设置.
    method ip {} { return $ip }
    method set_ip {value} { set ip $value }

    # 以下为剧情标志 flags 的相关操作.
    method flags {} { return $flags }
    method set_flag {name value} { dict set flags $name $value }
    method get_flag {name} {
        if {[dict exists $flags $name]} {
            return [dict get $flags $name]
        }
        return ""
    }
    method unset_flag {name} { dict unset flags $name }
    # 对数值型标志进行累加,非数字值按 0 处理.
    method incr_flag {name amount} {
        set current 0
        if {[dict exists $flags $name]} {
            set current [dict get $flags $name]
            if {![string is double -strict $current]} { set current 0 }
        }
        dict set flags $name [expr {$current + $amount}]
    }

    # 以下为对话历史 history 的相关操作.
    method history {} { return $history }
    method set_history {value} { set history $value }
    # 追加一条对话记录,并限制最多保留最近 300 条.
    method add_history {name text} {
        lappend history [list $name $text]
        if {[llength $history] > 300} {
            set history [lrange $history end-299 end]
        }
    }

    # 以下为背景 bg 与 CG 的相关操作,设置背景时同时清空 CG.
    method bg {} { return $bg }
    method set_bg {value} {
        set bg $value
        set cg ""
    }
    method cg {} { return $cg }
    method set_cg {value} {
        set cg $value
    }

    # 以下为登场角色 characters 的相关操作.
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

    # 以下为等待状态 waiting 的读取与设置.
    method waiting {} { return $waiting }
    method set_waiting {value} { set waiting $value }

    # 以下为待展示选项 pending_targets 的读取与设置.
    method pending_targets {} { return $pending_targets }
    method set_pending_targets {value} { set pending_targets $value }
}
