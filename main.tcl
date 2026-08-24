#!/usr/bin/env wish
# 上述行指定使用 wish 解释器(Tk 的图形界面 shell),用于启动 GUI 应用程序.
# Galgame 框架入口点.
# 本脚本负责初始化整个游戏框架,加载所有模块,并根据命令行参数执行不同模式.
namespace eval galgame {}

# 创建名为 galgame 的命名空间,用于封装所有相关变量和过程,避免全局命名污染.
# 设置框架根目录的绝对路径,基于当前脚本所在位置
set ::galgame::ROOT [file normalize [file dirname [info script]]]
# 设置源码目录,即根目录下的 src 子目录
set ::galgame::SRC [file join $::galgame::ROOT src]

# 循环加载所有必需的模块文件,顺序固定以保证依赖关系
foreach module {
    config.tcl
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
    # 拼接完整路径并 source 加载
    source [file join $::galgame::SRC $module]
}

# 创建 Application 类的实例,传入根目录路径,并存入全局变量 app
set ::galgame::app [galgame::Application new $::galgame::ROOT]

# 处理命令行参数,决定运行模式
if {[llength $argv] > 0 && [lindex $argv 0] eq "--smoke"} {
    # 如果第一个参数是 --smoke,执行冒烟测试(基础功能快速验证)
    $::galgame::app smoke
} elseif {[llength $argv] > 0 && [lindex $argv 0] eq "--smoke-story"} {
    # 如果第一个参数是 --smoke-story,执行剧情脚本冒烟测试
    $::galgame::app smoke_story
} else {
    # 默认模式: 正常启动游戏主循环
    $::galgame::app run
}
