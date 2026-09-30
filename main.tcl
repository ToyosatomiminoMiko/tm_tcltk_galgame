#!/usr/bin/env wish
# 上述行指定使用 wish 解释器(Tk 的图形界面 shell), 用于启动 GUI 应用程序.
# Galgame 运行时入口.
# [职责边界] 本文件只做运行时该做的事: 定位自己, 加载 src/ 下的模块, 解析命令行,
# 找到内容包并启动. 任何具体作品的信息(标题/剧本/素材/地点名)都不在这里, 而是
# 在内容包目录的 game.tcl 清单里, 见 src/pack.tcl.
namespace eval galgame {}

# 运行时根目录: 基于本脚本自身位置计算, 因此可以从任意目录用绝对路径启动.
set ::galgame::ROOT [file normalize [file dirname [info script]]]
# 运行时源码目录.
set ::galgame::SRC [file join $::galgame::ROOT src]

# 用法说明, 同时作为 -h/--help 的输出.
# [为什么用花括号而不是双引号] 说明里的 [选项] 这类方括号在双引号里会被当成
# 命令替换; 花括号原样保留, 顺便让 $GALGAME_PACK 这类字样也保持字面.
proc galgame::usage {} {
    return {
用法: wish main.tcl [选项] [内容包目录]

选项:
  --game <目录>    指定内容包目录(与直接给出位置参数等价)
  --saves <目录>   指定存档根目录; 该内容包的存档在 <目录>/<内容包 id>/ 下
  --list-games     列出运行时 games/ 下的内容包
  --smoke          隐藏窗口加载全部模块, 约 1 秒后退出
  --smoke-story    隐藏窗口自动播一遍剧情开头, 约 2.2 秒后退出
  -h, --help       显示本说明

环境变量:
  GALGAME_PACK       未给 --game 时的内容包目录
  GALGAME_SAVE_DIR   未给 --saves 时的存档根目录(别名 GALGAME_DATA_DIR)
  XDG_DATA_HOME      两者都没给时的存档根目录前缀, 默认 ~/.local/share/galgame}
}

# 解析命令行参数, 返回 {mode <运行模式> game <内容包目录> saves <存档根目录>}.
# [为什么单独一个过程] 参数解析是入口最容易长歪的一段; 抽出来后 main.tcl 的
# 主流程只剩"加载模块 -> 定位内容包 -> 装配应用 -> 选模式"四步.
proc galgame::parse_args {argv} {
    set options [dict create mode run game "" saves ""]
    set n [llength $argv]
    for {set i 0} {$i < $n} {incr i} {
        set arg [lindex $argv $i]
        switch -- $arg {
            "--game" - "--saves" {
                incr i
                if {$i >= $n} {
                    error "选项 $arg 缺少参数"
                }
                dict set options [string trimleft $arg -] [lindex $argv $i]
            }
            "--smoke"       { dict set options mode smoke }
            "--smoke-story" { dict set options mode smoke_story }
            "--list-games"  { dict set options mode list_games }
            "-h" - "--help" { dict set options mode help }
            default {
                if {[string match "-*" $arg]} {
                    error "未知选项: $arg"
                }
                if {[dict get $options game] ne ""} {
                    error "只能指定一个内容包目录"
                }
                dict set options game $arg
            }
        }
    }
    return $options
}

# 按固定顺序加载模块, 顺序体现依赖关系: 内容包层最先, 应用装配最后.
foreach module {
    config.tcl
    pack.tcl
    state.tcl
    script.tcl
    audio.tcl
    visual.tcl
    save.tcl
    log.tcl
    dialogs.tcl
    ui.tcl
    engine.tcl
    application.tcl
} {
    source [file join $::galgame::SRC $module]
}

if {[catch {set options [galgame::parse_args $argv]} err]} {
    puts stderr "参数错误: $err"
    puts stderr [galgame::usage]
    exit 2
}

# 这两个模式只依赖运行时本身, 不需要内容包.
switch -- [dict get $options mode] {
    "help" {
        puts [galgame::usage]
        exit 0
    }
    "list_games" {
        set found [galgame::list_packs $::galgame::ROOT]
        if {[llength $found] == 0} {
            puts "games/ 下没有内容包."
            exit 0
        }
        # 单个内容包的清单写坏不该让整个列表失败: 就地打印问题并继续列下一个.
        foreach dir $found {
            if {[catch {set pack [galgame::load_pack $dir]} err]} {
                puts [format "%-12s <清单有问题: %s>  (%s)" [file tail $dir] $err $dir]
                continue
            }
            puts [$pack summary]
        }
        exit 0
    }
}

# 定位内容包并校验清单; 出错时给出可读提示而不是 Tcl 堆栈.
if {[catch {
    set pack_dir [galgame::find_pack $::galgame::ROOT [dict get $options game]]
    set pack [galgame::load_pack $pack_dir]
} err]} {
    puts stderr "内容包错误: $err"
    exit 2
}

# 存档目录是用户数据, 与运行时目录, 内容包目录都分开, 可整体搬走.
set ::galgame::SAVE_DIR [galgame::resolve_save_dir $pack [dict get $options saves]]
# [为什么要 catch] 默认位置在用户数据目录, 只读 HOME, 受限沙箱或权限不足的机器
# 上会创建失败; 这里要给出"换个目录"的可读提示, 而不是抛一段 Tcl 堆栈.
if {[catch {file mkdir $::galgame::SAVE_DIR} err]} {
    puts stderr "无法创建存档目录: $::galgame::SAVE_DIR"
    puts stderr "请用 --saves <目录> 或 GALGAME_SAVE_DIR 指定一个可写的目录."
    exit 2
}

# 创建 Application 实例并进入对应模式.
set ::galgame::app [galgame::Application new $pack $::galgame::SAVE_DIR]

switch -- [dict get $options mode] {
    "smoke"       { $::galgame::app smoke }
    "smoke_story" { $::galgame::app smoke_story }
    default       { $::galgame::app run }
}
