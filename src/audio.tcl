# 音频模块: 封装音乐与音效的播放接口.
# 当前优先使用 Snack 扩展,缺失时退化为系统提示音,保证功能可插拔.
namespace eval galgame {
    namespace export -force *
}

# Audio 类: 负责背景音乐,音效与点击提示音的控制.
oo::class create galgame::Audio {
    # 配置对象,用于判断音乐/音效是否启用.
    variable config
    # 是否成功加载了 Snack 扩展.
    variable snack_ok
    # 当前正在播放的音乐编号.
    variable current_music

    # 构造时保存配置并探测 Snack 扩展是否可用.
    constructor {config_obj} {
        set config $config_obj
        set current_music ""
        set snack_ok 0
        if {![catch {package require snack}]} {
            set snack_ok 1
        }
    }

    # 播放背景音乐(若配置允许),并记录当前音乐编号.
    method play_music {id} {
        if {![$config get music_enabled]} return
        set current_music $id
        if {$snack_ok} {
            catch {snack::sound stop}
            catch {snack::sound play -loop 1}
        }
        # 音乐播放刻意设计成可插拔: 在没有 Snack 的系统上,
        # 框架仍会记录音乐编号,供将来的音频后端使用.
    }

    # 停止背景音乐并清空当前音乐编号.
    method stop_music {} {
        set current_music ""
        if {$snack_ok} {
            catch {snack::sound stop}
        }
    }

    # 播放一次音效(若配置允许),Snack 不可用时退化为响铃.
    method play_sfx {id} {
        if {![$config get sfx_enabled]} return
        if {$snack_ok} {
            catch {snack::sound play}
        } else {
            catch {bell}
        }
    }

    # 播放一次点击提示音.
    method click {} {
        if {[$config get sfx_enabled]} {
            catch {bell}
        }
    }
}
