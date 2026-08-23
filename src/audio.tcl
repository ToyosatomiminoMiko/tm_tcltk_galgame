namespace eval galgame {
    namespace export -force *
}

oo::class create galgame::Audio {
    variable config
    variable snack_ok
    variable current_music

    constructor {config_obj} {
        set config $config_obj
        set current_music ""
        set snack_ok 0
        if {![catch {package require snack}]} {
            set snack_ok 1
        }
    }

    method play_music {id} {
        if {![$config get music_enabled]} return
        set current_music $id
        if {$snack_ok} {
            catch {snack::sound stop}
            catch {snack::sound play -loop 1}
        }
        # Music playback is intentionally pluggable. On systems without Snack,
        # the framework keeps the track id in state so a future backend can use it.
    }

    method stop_music {} {
        set current_music ""
        if {$snack_ok} {
            catch {snack::sound stop}
        }
    }

    method play_sfx {id} {
        if {![$config get sfx_enabled]} return
        if {$snack_ok} {
            catch {snack::sound play}
        } else {
            catch {bell}
        }
    }

    method click {} {
        if {[$config get sfx_enabled]} {
            catch {bell}
        }
    }
}
