# -*- shell-script -*-
#
# .bashrc.tmux - tmux-related functions and aliases for bash
#
# This is part of: http://blog.edsantiago.com/articles/tmux-session-preserve/
#

# we're not interactive, don't source me bro!
if [ -z "$PS1" ]; then
    return
fi
preexec () {
    echo "$1" > $HISTFILE.running
}
preexec_invoke_exec () {
    [ -n "$COMP_LINE" ] && return  # do nothing if completing
    local this_command=`history 1 | sed -e "s/^[ ]*[0-9]*[ ]*//g"`;
    preexec "$this_command"
}
#
# On LOGIN: enable a separate history file for this session
#
_tmux-init-history() {
    # Only interested in interactive shells running under tmux
    test -z "$PS1"  && return
    test -z "$TMUX" && return

    # Get our current tmux session id (eg devel.bz12345).
    # If empty, or if unnamed session (0, 1, 2, etc), do not save history.
    tmux_session=$(tmux-session mywindowid)
    test -z "$tmux_session" && return

    case "$tmux_session" in
        [0-9]*)   return ;;
    esac
    session_name=$( echo $tmux_session | perl -ne 's/\.\S*// && print' )
    window_name=$( echo $tmux_session | perl -ne 's/\S*?\.// && print' )

    if [ ! -d $HOME/.tmux-session.d ]; then
        mkdir --mode=0700 $HOME/.tmux-session.d
    fi
    if [ ! -d $HOME/.tmux-session.d/$session_name ]; then
        mkdir --mode=0700 $HOME/.tmux-session.d/$session_name
    fi
    histfile=$HOME/.tmux-session.d/$session_name/$window_name

    # Create the file on demand
    if [ ! -f $histfile ]; then
        touch $histfile
    fi
    chmod  0600 $histfile

    HISTFILE=$histfile
    HISTTIMEFORMAT='%F %T '
    HIST_DIRSTACK=$histfile.dirs
    # FIXME: on first pass through, restore dirs
    dirstack_reset=
    if [ -f $HIST_DIRSTACK ]; then
        while read d;do
            if [ -z "$dirstack_reset" ]; then
                builtin cd "$d"
                dirstack_reset=reset
            else
                builtin pushd "$d" >/dev/null
            fi
        done < <(tac $HIST_DIRSTACK)
    fi

    # Restore $OLDPWD, to allow cd -
    if [ -f $HIST_DIRSTACK- ]; then
        OLDPWD=$(< $HIST_DIRSTACK-)
    fi

    # Save history after every command.  This saves our bacon if we crash.
    # FIXME this could be improved, maybe with trap DEBUG or accept-line?
    if [ -n "$PROMPT_COMMAND" ]; then
        PROMPT_COMMAND="$PROMPT_COMMAND;history -w"
    else
        PROMPT_COMMAND="history -w"
    fi
}

#
# On LOGOUT: if tmux window has been renamed, FIXME
#
_tmux-fixme() {
    test -z "$tmux_session" && return

    new_tmux_session=$(tmux-session mywindowid)
    test -z "$new_tmux_session" && return

    # Unchanged.
    test "$new_tmux_session" = "$tmux_session" && return

    # Changed.
    # FIXME: rename histfile
}

#
# Directory-changing aliases.  Preserve current directory stack.
#

_tmux-save-dir-stack() {
    # Save both dirlist and $OLDPWD, so we can 'cd -' upon restore
    if [ -n "$HIST_DIRSTACK" ]; then
        builtin dirs -p -l >| $HIST_DIRSTACK
        echo $OLDPWD       >| $HIST_DIRSTACK-
    fi
}

pushd() { builtin pushd "$@"; _tmux-save-dir-stack; }
popd()  { builtin  popd "$@"; _tmux-save-dir-stack; }
cd()    { builtin    cd "$@"; _tmux-save-dir-stack; }

#
# For creating a new session.
#
tt()  { tmux-session new "$@"; }

# tmux-restore is useful when you <prefix>-c to create a new window,
# and immediately want to recover/restore from another session.
# It would be better to use tt, but sometimes we forget.
tmux-restore() {
    tmux rename-window "$@" && _tmux-init-history && history -r && _tmux-save-dir-stack
}

# tmux-rename is useful when you want to rename this session but keep
# your work.  (tmux-restore clobbers your history and directories).
tmux-rename() {
    tmux rename-window "$@"
    tmux_session=$(tmux-session mywindowid)
    HISTFILE=$HOME/.tmux-session.d/$tmux_session #FIXME this is broken with the new directory scheme
}

#do the initial setup
_tmux-init-history
trap 'preexec_invoke_exec' DEBUG
