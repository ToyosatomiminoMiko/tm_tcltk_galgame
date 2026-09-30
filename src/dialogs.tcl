# 对话框模块: 提供设置窗口与存档槽位选择窗口.
# 两个窗口都通过回调把用户选择交回应用层处理.
namespace eval galgame {
    namespace export -force *
}

# 将窗口移动到父窗口的居中位置.
proc galgame::center_window {win parent} {
    update idletasks
    set pw [winfo rootx $parent]
    set py [winfo rooty $parent]
    set pw2 [winfo width $parent]
    set ph2 [winfo height $parent]
    set w [winfo reqwidth $win]
    set h [winfo reqheight $win]
    wm geometry $win "+[expr {$pw + ($pw2 - $w) / 2}]+[expr {$py + ($ph2 - $h) / 2}]"
}

# 根据模式返回存档/读档窗口的 Tk 子路径名.
# [为什么存档与读档要分开] 两者如果不共用窗口名,同时打开才互不干扰;
# 应用层需要用同一个函数算出路径,才能判断窗口是否已存在.
proc galgame::slot_window_name {mode} {
    if {$mode eq "save"} {
        return "slots_save"
    }
    return "slots_load"
}

# ConfigDialog 类: 让玩家调整文字速度,自动间隔,音效,音乐与全屏等设置.
oo::class create galgame::ConfigDialog {
    # 设置窗口路径.
    variable win
    # 配置对象,最终保存回它.
    variable config
    # 点击应用后执行的命令.
    variable apply_cmd
    # 各设置项的临时值,由控件绑定读写.
    variable text_delay
    variable auto_delay
    variable sfx_enabled
    variable music_enabled
    variable fullscreen

    # 构造设置窗口,并从配置对象载入当前值.
    constructor {parent config_obj apply_cmd_arg} {
        set config $config_obj
        set apply_cmd $apply_cmd_arg
        set text_delay [$config get text_delay_ms]
        set auto_delay [$config get auto_delay_ms]
        set sfx_enabled [$config get sfx_enabled]
        set music_enabled [$config get music_enabled]
        set fullscreen [$config get fullscreen]

        set win [toplevel [galgame::child_path $parent config]]
        wm title $win "设置"
        wm transient $win $parent
        wm resizable $win 0 0
        ttk::frame $win.body -padding 16
        pack $win.body -fill both -expand 1

        ttk::label $win.body.l1 -text "文字速度(每字间隔)"
        grid $win.body.l1 -row 0 -column 0 -sticky w
        ttk::scale $win.body.s1 -from 5 -to 100 -length 260 -command [list [self] set_text_delay]
        $win.body.s1 set $text_delay
        grid $win.body.s1 -row 0 -column 1 -pady 8
        ttk::label $win.body.v1 -textvariable [self namespace]::text_delay
        grid $win.body.v1 -row 0 -column 2 -padx 8

        ttk::label $win.body.l2 -text "自动播放间隔"
        grid $win.body.l2 -row 1 -column 0 -sticky w
        ttk::scale $win.body.s2 -from 500 -to 5000 -length 260 -command [list [self] set_auto_delay]
        $win.body.s2 set $auto_delay
        grid $win.body.s2 -row 1 -column 1 -pady 8
        ttk::label $win.body.v2 -textvariable [self namespace]::auto_delay
        grid $win.body.v2 -row 1 -column 2 -padx 8

        ttk::checkbutton $win.body.c1 -text "音效" -variable [self namespace]::sfx_enabled
        grid $win.body.c1 -row 2 -column 0 -columnspan 2 -sticky w -pady 4
        ttk::checkbutton $win.body.c2 -text "音乐" -variable [self namespace]::music_enabled
        grid $win.body.c2 -row 3 -column 0 -columnspan 2 -sticky w -pady 4
        ttk::checkbutton $win.body.c3 -text "全屏" -variable [self namespace]::fullscreen
        grid $win.body.c3 -row 4 -column 0 -columnspan 2 -sticky w -pady 4

        ttk::frame $win.body.actions
        grid $win.body.actions -row 5 -column 0 -columnspan 3 -pady 14
        ttk::button $win.body.actions.save -text "应用" -command [list [self] save]
        ttk::button $win.body.actions.cancel -text "取消" -command [list [self] close]
        pack $win.body.actions.save $win.body.actions.cancel -side left -padx 8

        wm protocol $win WM_DELETE_WINDOW [list [self] close]
        galgame::center_window $win $parent
        wm deiconify $win
        raise $win
    }

    # 关闭窗口并销毁本对象.
    # [为什么必须销毁对象] TclOO 对象不会随 Tk 窗口一起回收:只 destroy
    # 窗口,对象仍持有 config 与回调引用;反复开设置会不断堆积.
    method close {} {
        if {[winfo exists $win]} {
            destroy $win
        }
        after idle [list [self] destroy]
    }

    # 文字速度滑杆回调,保存为整数毫秒.
    method set_text_delay {value} {
        set text_delay [expr {int($value)}]
    }

    # 自动播放间隔滑杆回调,保存为整数毫秒.
    method set_auto_delay {value} {
        set auto_delay [expr {int($value)}]
    }

    # 将临时值写回配置对象,关闭窗口并执行应用回调,最后销毁本对象.
    method save {} {
        $config set text_delay_ms $text_delay
        $config set auto_delay_ms $auto_delay
        $config set sfx_enabled $sfx_enabled
        $config set music_enabled $music_enabled
        $config set fullscreen $fullscreen
        destroy $win
        eval $apply_cmd
        after idle [list [self] destroy]
    }
}

# SlotDialog 类: 提供存档/读档的槽位选择列表.
oo::class create galgame::SlotDialog {
    # 窗口路径.
    variable win
    # 当前模式: save 或 load.
    variable mode
    # 选择完成后执行的回调,并附上槽位号.
    variable callback
    # 存档管理器对象.
    variable save_manager
    # 槽位列表组件.
    variable listbox
    # 当前选中的槽位号.
    variable current_slot

    # 构造槽位选择窗口,并按模式切换文案.
    constructor {parent save_mgr mode_arg callback_arg} {
        set save_manager $save_mgr
        set mode $mode_arg
        set callback $callback_arg
        set current_slot 1

        set win [toplevel [galgame::child_path $parent [galgame::slot_window_name $mode]]]
        wm title $win [expr {$mode eq "save" ? "存档" : "读档"}]
        wm transient $win $parent
        wm resizable $win 0 0
        ttk::frame $win.body -padding 12
        pack $win.body -fill both -expand 1

        set listbox [listbox $win.body.list -height 6 -width 46 -exportselection 0]
        pack $listbox -side top -fill both -expand 1
        bind $listbox <<ListboxSelect>> [list [self] select_slot]

        ttk::frame $win.body.actions
        pack $win.body.actions -side bottom -pady 10
        ttk::button $win.body.actions.ok -text [expr {$mode eq "save" ? "保存到此格" : "读取此格"}] -command [list [self] commit]
        ttk::button $win.body.actions.cancel -text "取消" -command [list [self] close]
        pack $win.body.actions.ok $win.body.actions.cancel -side left -padx 8

        wm protocol $win WM_DELETE_WINDOW [list [self] close]
        my refresh_list
        galgame::center_window $win $parent
        wm deiconify $win
        raise $win
    }

    # 关闭窗口并销毁本对象,避免选择窗口的对象在关闭后继续驻留.
    method close {} {
        if {[winfo exists $win]} {
            destroy $win
        }
        after idle [list [self] destroy]
    }

    # 重新读取 6 个槽位的摘要并刷新列表.
    method refresh_list {} {
        $listbox delete 0 end
        for {set slot 1} {$slot <= 6} {incr slot} {
            set summary [$save_manager slot_summary $slot]
            set label [format "存档 %d:%s" [lindex $summary 0] [lindex $summary 1]]
            $listbox insert end $label
        }
        $listbox selection set [expr {$current_slot - 1}]
    }

    # 列表选中变化时更新当前槽位号.
    method select_slot {} {
        set idx [$listbox curselection]
        if {[llength $idx]} {
            set current_slot [expr {[lindex $idx 0] + 1}]
        }
    }

    # 确认选择: 读档模式下空槽位会被拦截,其余情况执行回调.
    method commit {} {
        if {$mode eq "load"} {
            set summary [$save_manager slot_summary $current_slot]
            if {[lindex $summary 1] eq "空存档"} {
                tk_messageBox -parent $win -type ok -icon warning -message "该存档格为空."
                return
            }
        }
        set chosen $current_slot
        destroy $win
        eval [linsert $callback end $chosen]
        after idle [list [self] destroy]
    }
}
