namespace eval galgame {
    namespace export -force *
}

oo::class create galgame::LogWindow {
    variable win
    variable text

    constructor {parent history} {
        set win [toplevel [galgame::child_path $parent logwindow]]
        wm title $win "对话记录"
        wm transient $win $parent
        wm geometry $win 560x480
        wm withdraw $win
        wm protocol $win WM_DELETE_WINDOW [list wm withdraw $win]
        ttk::frame $win.body -padding 10
        pack $win.body -fill both -expand 1
        set text [text $win.body.text -wrap word -state disabled -font TkDefaultFont]
        pack $text -side top -fill both -expand 1
        ttk::button $win.body.close -text "关闭" -command [list wm withdraw $win]
        pack $win.body.close -side bottom -pady 8
        my refresh $history
    }

    method refresh {history} {
        $text configure -state normal
        $text delete 1.0 end
        foreach item $history {
            set name [lindex $item 0]
            set line [lindex $item 1]
            if {$name ne ""} {
                $text insert end "$name：\n" name
            }
            $text insert end "$line\n\n" body
        }
        $text tag configure name -font [list TkDefaultFont 10 bold] -foreground "#6b4f8f"
        $text tag configure body -font [list TkDefaultFont 10]
        $text configure -state disabled
        $text see end
    }

    method show {history} {
        my refresh $history
        wm deiconify $win
        raise $win
        focus $win
    }
}
