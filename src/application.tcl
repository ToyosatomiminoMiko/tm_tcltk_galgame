# 应用模块: 组装各子系统,并对外提供启动,存档,读档,设置等高层操作.
# 它是 main.tcl 创建的唯一对象,也是各种界面回调的汇聚点.
namespace eval galgame {
    namespace export -force *
}

# Application 类: 整个游戏的应用总控.
oo::class create galgame::Application {
    # 主窗口路径.
    variable root
    # 配置对象.
    variable config
    # 游戏状态对象.
    variable state
    # 界面对象.
    variable ui
    # 音频对象.
    variable audio
    # 存档管理器.
    variable save_manager
    # 历史记录窗口.
    variable log
    # 引擎对象.
    variable engine
    # 当前模式: none, auto 或 skip.
    variable mode
    # 自动播放与快进的 after 任务编号.
    variable auto_job
    variable skip_job

    # 构造时创建并连接所有子系统.
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

    # 正常启动: 显示主窗口并进入事件循环.
    method run {} {
        wm deiconify $root
        $ui show_title
        vwait ::galgame::_forever
    }

    # 冒烟测试: 隐藏窗口,短暂运行后退出,用于验证模块可加载.
    method smoke {} {
        wm withdraw $root
        after 1000 {exit 0}
        vwait ::galgame::_forever
    }

    # 剧情冒烟测试: 自动开始新游戏,短暂运行后退出.
    method smoke_story {} {
        wm withdraw $root
        after 300 [list [self] start_new]
        after 2200 {exit 0}
        vwait ::galgame::_forever
    }

    # 返回默认剧情文件路径.
    method story_path {} {
        return [file join $::galgame::ROOT game story.gal]
    }

    # 开始新游戏: 载入剧本,重置状态并交给引擎执行.
    method start_new {} {
        my stop_modes
        set story [galgame::Story new [my story_path]]
        $state reset
        $state set_story $story
        $ui show_game
        $ui clear_line
        $engine start
    }

    # 继续游戏: 优先读最近存档,没有存档则开始新游戏.
    method continue_game {} {
        set slot [$save_manager most_recent]
        if {$slot < 1} {
            my start_new
        } else {
            my load_slot $slot
        }
    }

    # 将当前状态保存到指定槽位,没有进行中的游戏时给出提示.
    method save_slot {slot} {
        if {[$state story] eq ""} {
            tk_messageBox -parent $root -type ok -icon info -message "当前没有正在进行的游戏."
            return
        }
        $save_manager save $slot $state
    }

    # 从指定槽位读档,恢复所有状态并交给引擎继续执行.
    method load_slot {slot} {
        my stop_modes
        set data [$save_manager load $slot]
        set script_path [dict get $data script]
        if {![file exists $script_path]} {
            tk_messageBox -parent $root -type ok -icon error -message "存档对应的剧本不存在:\n$script_path"
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

    # 推进对话,转发给引擎.
    method advance {} {
        $engine advance
    }

    # 处理选项选择,先隐藏选项再交给引擎跳转.
    method choose {label} {
        $ui hide_choice
        $engine choose $label
    }

    # 定时等待结束后的续跑入口.
    method resume_wait {} {
        $engine resume_after_wait
    }

    # 返回标题屏: 停止模式,停止音乐并清理界面.
    method return_title {} {
        my stop_modes
        $audio stop_music
        $ui hide_choice
        $ui clear_line
        $ui show_title
    }

    # 显示对话历史窗口.
    method show_log {} {
        $log show [$state history]
    }

    # 显示设置窗口.
    method show_config {} {
        galgame::ConfigDialog new $root $config [list [self] apply_config]
    }

    # 显示存档槽位窗口.
    method show_save_dialog {} {
        galgame::SlotDialog new $root $save_manager "save" [list [self] save_slot]
    }

    # 显示读档槽位窗口.
    method show_load_dialog {} {
        galgame::SlotDialog new $root $save_manager "load" [list [self] load_slot]
    }

    # 应用设置后同步界面,并在音乐被关闭时停止音乐.
    method apply_config {} {
        $ui apply_config
        if {![$config get music_enabled]} {
            $audio stop_music
        }
    }

    # 切换自动播放模式.
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

    # 切换快进模式.
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

    # 启动自动播放并更新按钮文案.
    method start_auto {} {
        set mode "auto"
        $ui set_mode_button auto 1
        my schedule_auto
    }

    # 启动快进并更新按钮文案.
    method start_skip {} {
        set mode "skip"
        $ui set_mode_button skip 1
        my schedule_skip
    }

    # 停止自动播放并取消待执行任务.
    method stop_auto {} {
        if {$auto_job ne ""} {
            catch {after cancel $auto_job}
            set auto_job ""
        }
        if {$mode eq "auto"} { set mode "none" }
        $ui set_mode_button auto 0
    }

    # 停止快进并取消待执行任务.
    method stop_skip {} {
        if {$skip_job ne ""} {
            catch {after cancel $skip_job}
            set skip_job ""
        }
        if {$mode eq "skip"} { set mode "none" }
        $ui set_mode_button skip 0
    }

    # 同时停止自动播放与快进.
    method stop_modes {} {
        my stop_auto
        my stop_skip
    }

    # 按自动间隔调度下一次自动推进.
    method schedule_auto {} {
        set auto_job [after [$config get auto_delay_ms] [list [self] auto_tick]]
    }

    # 按快进间隔调度下一次快进推进.
    method schedule_skip {} {
        set skip_job [after [$config get skip_delay_ms] [list [self] skip_tick]]
    }

    # 自动播放的定时回调: 逐字中则先补全,否则推进对话.
    method auto_tick {} {
        if {$mode ne "auto"} return
        if {[$ui is_typing]} {
            $ui finish_typing
        } else {
            my advance
        }
        my schedule_auto
    }

    # 快进的定时回调: 逻辑与自动播放一致,仅间隔不同.
    method skip_tick {} {
        if {$mode ne "skip"} return
        if {[$ui is_typing]} {
            $ui finish_typing
        } else {
            my advance
        }
        my schedule_skip
    }

    # 退出应用: 停止所有模式并关闭音乐.
    method quit {} {
        my stop_modes
        $audio stop_music
        exit 0
    }
}
