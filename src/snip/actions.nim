import os
import posix
import strutils
import tables
import terminal

import ./compile
import ./gist
import ./globals
import ./key
import ./keymap
import ./ui
import ./undo

# CTRL-combo

proc ctrlfuncLeft(kfunc: proc(redraw: bool), rfunc: proc()) =
    if COL > 0 and BUFFER[LINE+COFFSET][COL-1] == ' ':
        while COL > 0 and BUFFER[LINE+COFFSET][COL-1] == ' ':
            kfunc(redraw=false)
    if COL > 0 and BUFFER[LINE+COFFSET][COL-1] != ' ':
        while COL > 0 and BUFFER[LINE+COFFSET][COL-1] != ' ':
            kfunc(redraw=false)
    else:
        kfunc(redraw=false)
    rfunc()

proc ctrlfuncRight(kfunc: proc(redraw: bool), rfunc: proc()) =
    if COL < BUFFER[LINE+COFFSET].len()-1 and BUFFER[LINE+COFFSET][COL+1] == ' ':
        while COL < BUFFER[LINE+COFFSET].len()-1 and BUFFER[LINE+COFFSET][COL+1] == ' ':
            kfunc(redraw=false)
        kfunc(redraw=false)
    if COL < BUFFER[LINE+COFFSET].len()-1 and BUFFER[LINE+COFFSET][COL+1] != ' ':
        while COL < BUFFER[LINE+COFFSET].len()-1 and BUFFER[LINE+COFFSET][COL+1] != ' ':
            kfunc(redraw=false)
        kfunc(redraw=false)
    else:
        kfunc(redraw=false)
    rfunc()

# Cursor movement

proc cursorLeftHelper(redraw=true) =
    if COL > 0:
        COL -= 1
        if redraw: lcol()
    else:
        if LINE > 0:
            LINE -= 1
            COL = BUFFER[LINE+COFFSET].len()
            if redraw: lcol()
        else:
            if COFFSET > 0:
                COFFSET -= 1
                COL = BUFFER[LINE+COFFSET].len()
                if redraw: redraw()

proc cursorLeft*() =
    cursorLeftHelper()

proc cursorLeftWord*() =
    ctrlfuncLeft(cursorLeftHelper, lcol)

proc cursorDownHelper(redraw=true) =
    if LINE+COFFSET < BUFFER.len()-1:
        if LINE < HEIGHT-WINDOW-1:
            LINE += 1
            if COL > BUFFER[LINE+COFFSET].len():
                COL = BUFFER[LINE+COFFSET].len()
            if redraw: lcol()
        else:
            COFFSET += 1
            if redraw: redraw()

proc cursorDown*() =
    cursorDownHelper()

proc cursorRightHelper(redraw=true) =
    if COL < WIDTH-MARGIN:
        if COL < BUFFER[LINE+COFFSET].len():
            COL += 1
            if redraw: lcol()
        else:
            if LINE+COFFSET < BUFFER.len()-1:
                if LINE < HEIGHT-WINDOW-1:
                    LINE += 1
                    COL = 0
                    if redraw: lcol()
                else:
                    COFFSET += 1
                    COL = 0
                    if redraw: redraw()

proc cursorRight*() =
    cursorRightHelper()

proc cursorRightWord*() =
    ctrlfuncRight(cursorRightHelper, lcol)

proc cursorUpHelper(redraw=true) =
    if LINE > 0:
        LINE -= 1
        if COL > BUFFER[LINE+COFFSET].len():
            COL = BUFFER[LINE+COFFSET].len()
        if redraw: lcol()
    else:
        if COFFSET > 0:
            COFFSET -= 1
            if redraw: redraw()

proc cursorUp*() =
    cursorUpHelper()

proc cursorTop*() =
    COL = 0
    LINE = 0
    COFFSET = 0
    redraw()

proc cursorBottom*() =
    if BUFFER.len()-1 < HEIGHT-WINDOW-1:
        LINE = BUFFER.len()-1
        COL = BUFFER[LINE+COFFSET].len()
        lcol()
    else:
        COFFSET = BUFFER.len()-1-HEIGHT+WINDOW+1
        LINE = HEIGHT-WINDOW-1
        COL = BUFFER[BUFFER.len()-1].len()
        redraw()

proc cursorEnd*() =
    COL = BUFFER[LINE+COFFSET].len()
    lcol()

proc cursorStart*() =
    COL = 0
    lcol()

proc cursorPageDown*() =
    for i in 1 .. (HEIGHT-WINDOW).shr(1):
        cursorDownHelper(false)
    redraw()

proc cursorPageUp*() =
    for i in 1 .. (HEIGHT-WINDOW).shr(1):
        cursorUpHelper(false)
    redraw()

# Output window

proc scrollWindowDown*() =
    WOFFSET -= 1
    if WOFFSET < 0:
        WOFFSET = 0
    redraw()

proc scrollWindowUp*() =
    WOFFSET += 1
    if WOFFSET > OUTLINES-WINDOW+2:
        WOFFSET = OUTLINES-WINDOW+2
    redraw()

# Actions

proc doQuit*() =
    clearScreen()
    cleanup()
    when not defined(windows):
        cleanExit()
    quit(0)

proc doRun*() =
    compile(foreground=true)
    redraw()

proc doRedraw*() =
    FORCE_REDRAW = true
    redraw()

proc doHelp*() =
    writeHelp(getKeyHelp())

proc doLoad*(src: string) =
    if fileExists(src):
        BUFFER = src.readFile().splitLines()
    elif src.len() > 4 and "http" == src[0..4]:
        BUFFER = getGist(src).splitLines()
    else:
        BUFFER = src.splitLines()
    doRedraw()

proc doClear*() =
    doLoad("")

proc doNextMode*() =
    setMode(true)
    lcol()

proc doPrevMode*() =
    setMode(false)
    lcol()

proc doToggleLineNo*() =
    if MARGIN != 0:
        MARGIN = 0
    else:
        MARGIN = D_MARGIN
    redraw()

# Removing chars

proc eraseLeftHelper(redraw=true) =
    let ln = BUFFER[LINE+COFFSET].len()
    if COL != 0:
        if COL == ln:
            BUFFER[LINE+COFFSET] = BUFFER[LINE+COFFSET].substr(0, ln-2)
        else:
            BUFFER[LINE+COFFSET] = BUFFER[LINE+COFFSET].substr(0, COL-2) & BUFFER[LINE+COFFSET].substr(COL)
        COL -= 1
        if redraw: redrawLine()
    else:
        if LINE > 0:
            COL = BUFFER[LINE+COFFSET-1].len()
            BUFFER[LINE+COFFSET-1] = BUFFER[LINE+COFFSET-1] & BUFFER[LINE+COFFSET]
            BUFFER.delete(LINE+COFFSET)
            LINE -= 1
            if redraw: redraw()

proc eraseLeft*() =
    eraseLeftHelper()

proc eraseLeftWord*() =
    ctrlfuncLeft(eraseLeftHelper, redraw)

proc eraseRightHelper(redraw=true) =
    if COL < BUFFER[LINE+COFFSET].len():
        BUFFER[LINE+COFFSET].delete(COL, COL)
        if redraw: redrawLine()
    else:
        if LINE < BUFFER.len()-1:
            BUFFER[LINE+COFFSET] = BUFFER[LINE+COFFSET] & BUFFER[LINE+COFFSET+1]
            BUFFER.delete(LINE+COFFSET+1)
            if redraw: redraw()

proc eraseRight*() =
    eraseRightHelper()

proc eraseRightWord*() =
    ctrlfuncRight(eraseRightHelper, redraw)

# Adding chars

proc addNewline*() =
    if LINE < HEIGHT-WINDOW-1:
        if COL <= BUFFER[LINE+COFFSET].len():
            let br = BUFFER[LINE+COFFSET].substr(COL)
            BUFFER[LINE+COFFSET] = BUFFER[LINE+COFFSET].substr(0, COL-1)
            if COL == BUFFER[LINE+COFFSET].len()-1:
                BUFFER.add("")
            else:
                BUFFER.insert(br, LINE+COFFSET+1)
            LINE += 1
            COL = 0
        compile()
        redraw()

proc addChar*() =
    if COL == BUFFER[LINE+COFFSET].len():
        BUFFER[LINE+COFFSET] &= LASTCHAR
    elif COL < BUFFER[LINE+COFFSET].len():
        let br = BUFFER[LINE+COFFSET].substr(COL)
        BUFFER[LINE+COFFSET] = BUFFER[LINE+COFFSET].substr(0, COL-1) & LASTCHAR & br
    COL += 1
    redrawLine()

proc addSpace() =
    LASTCHAR = ' '
    addChar()

proc add2Space() =
    for i in 0 .. 1: addSpace()

proc add4Space() =
    for i in 0 .. 3: addSpace()

proc add8Space() =
    for i in 0 .. 7: addSpace()
            
proc loadActions*() =
    ACTIONMAP[CURSOR_UP] = cursorUp
    ACTIONMAP[CURSOR_DOWN] = cursorDown
    ACTIONMAP[CURSOR_LEFT] = cursorLeft
    ACTIONMAP[CURSOR_RIGHT] = cursorRight
    ACTIONMAP[CURSOR_LEFT_WORD] = cursorLeftWord
    ACTIONMAP[CURSOR_RIGHT_WORD] = cursorRightWord
    ACTIONMAP[CURSOR_PAGEUP] = cursorPageUp
    ACTIONMAP[CURSOR_PAGEDOWN] = cursorPageDown
    ACTIONMAP[CURSOR_START] = cursorStart
    ACTIONMAP[CURSOR_END] = cursorEnd
    ACTIONMAP[CURSOR_TOP] = cursorTop
    ACTIONMAP[CURSOR_BOTTOM] = cursorBottom
    ACTIONMAP[WINDOW_DOWN] = scrollWindowDown
    ACTIONMAP[WINDOW_UP] = scrollWindowUp
    ACTIONMAP[ERASE_LEFT] = eraseLeft
    ACTIONMAP[ERASE_RIGHT] = eraseRight
    ACTIONMAP[ERASE_LEFT_WORD] = eraseLeftWord
    ACTIONMAP[ERASE_RIGHT_WORD] = eraseRightWord
    ACTIONMAP[NEWLINE] = addNewline
    ACTIONMAP[CLEAR] = doClear
    ACTIONMAP[HELP] = doHelp
    ACTIONMAP[PREV_MODE] = doPrevMode
    ACTIONMAP[NEXT_MODE] = doNextMode
    ACTIONMAP[QUIT] = doQuit
    ACTIONMAP[REDO] = doRedo
    ACTIONMAP[REDRAW] = doRedraw
    ACTIONMAP[RUN] = doRun
    ACTIONMAP[TO_2_SPACES] = add2Space
    ACTIONMAP[TO_4_SPACES] = add4Space
    ACTIONMAP[TO_8_SPACES] = add8Space
    ACTIONMAP[TOGGLE_LINES] = doToggleLineNo
    ACTIONMAP[UNDO] = doUndo
    ACTIONMAP[DEFAULT] = addChar

    when not defined(windows):
        if KEYACTION.hasKey(CTRL_C) and ACTIONMAP.hasKey(KEYACTION[CTRL_C]):
            onSignal(SIGINT):
                ACTIONMAP[KEYACTION[CTRL_C]]()
        
        if KEYACTION.hasKey(CTRL_Z) and ACTIONMAP.hasKey(KEYACTION[CTRL_Z]):
            onSignal(SIGTSTP):
                ACTIONMAP[KEYACTION[CTRL_Z]]()
                redraw()
        