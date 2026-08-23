#!/usr/bin/env wish

# Galgame framework entry point.
# Run with: wish main.tcl

namespace eval galgame {}

set ::galgame::ROOT [file normalize [file dirname [info script]]]
set ::galgame::SRC [file join $::galgame::ROOT src]

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
    source [file join $::galgame::SRC $module]
}

set ::galgame::app [galgame::Application new $::galgame::ROOT]

if {[llength $argv] > 0 && [lindex $argv 0] eq "--smoke"} {
    $::galgame::app smoke
} elseif {[llength $argv] > 0 && [lindex $argv 0] eq "--smoke-story"} {
    $::galgame::app smoke_story
} else {
    $::galgame::app run
}
