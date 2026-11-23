#!/bin/sh

# OSC 2029 marks a line to wrap at spaces, when written and on resize, and copy
# mode moves, copies and searches across a row wrapped at a space. OSC 2029;?
# is answered with OSC 2029;1.

PATH=/bin:/usr/bin
TERM=screen

[ -z "$TEST_TMUX" ] && TEST_TMUX=$(readlink -f ../tmux)
TMUX="$TEST_TMUX -Ltest -f/dev/null"
$TMUX kill-server 2>/dev/null
TMP=$(mktemp)
trap "rm -f $TMP" 0 1 15

fail()
{
	echo "$1"
	$TMUX kill-server 2>/dev/null
	exit 1
}

check()
{
	[ "$2" = "$3" ] || fail "$1: expected '$2', got '$3'"
}

rows()
{
	$TMUX capture-pane -p -S- | grep . | head -3 | paste -sd'|' -
}

cursor()
{
	$TMUX display-message -p '#{copy_cursor_x},#{copy_cursor_y}'
}

# At 17 columns the line wraps at the space before "fox".
$TMUX new-session -d -x17 -y8 "
    printf '\033]2029\033\\\\the quick brown fox jumps over the lazy dog\n'
    stty raw -echo
    printf '\033]2029;?\033\\\\'
    dd bs=1 count=10 2>/dev/null >$TMP
    exec cat" || fail "new-session failed"
$TMUX set-option -g window-size manual || fail "set size failed"
$TMUX set-window-option -g mode-keys vi || fail "set mode-keys failed"
sleep 1
check written 'the quick brown|fox jumps over|the lazy dog' "$(rows)"
printf '\033]2029;1\033\\' | cmp -s - $TMP || fail "reply: expected ESC ]2029;1 ESC \\, got $(od -An -c $TMP)"

$TMUX resize-window -x12
sleep 1
check narrower 'the quick|brown fox|jumps over' "$(rows)"
$TMUX resize-window -x17
sleep 1
check back 'the quick brown|fox jumps over|the lazy dog' "$(rows)"

$TMUX copy-mode || fail "copy-mode failed"
$TMUX send-keys -X history-top
$TMUX send-keys -X start-of-line
$TMUX send-keys -X -N4 next-word-end
check next-word-end 2,1 "$(cursor)"
check word fox "$($TMUX display-message -p '#{copy_cursor_word}')"
$TMUX send-keys -X history-top
$TMUX send-keys -X start-of-line
$TMUX send-keys -X search-forward-text 'brown fox'
check search 10,0 "$(cursor)"
$TMUX send-keys -X history-top
$TMUX send-keys -X start-of-line
$TMUX send-keys -X begin-selection
$TMUX send-keys -X -N2 cursor-down
$TMUX send-keys -X end-of-line
$TMUX send-keys -X copy-selection
check copy 'the quick brown fox jumps over the lazy dog' "$($TMUX show-buffer)"

$TMUX kill-server 2>/dev/null
exit 0
