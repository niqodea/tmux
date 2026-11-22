#!/bin/sh

# A space in the last column of a wrapped line is part of the text: copy mode
# must not strip it as trailing whitespace.

PATH=/bin:/usr/bin
TERM=screen

[ -z "$TEST_TMUX" ] && TEST_TMUX=$(readlink -f ../tmux)
TMUX="$TEST_TMUX -Ltest -f/dev/null"
$TMUX kill-server 2>/dev/null

fail()
{
	echo "$1"
	$TMUX kill-server 2>/dev/null
	exit 1
}

check()
{
	actual=$($TMUX display-message -p "$1")
	[ "$actual" = "$2" ] || fail "$3: expected '$2', got '$actual'"
}

# At 20 columns the line wraps after "fox ", with the space in column 19.
$TMUX new-session -d -x20 -y8 \
    "printf 'the quick brown fox jumps over the lazy dog\n'; exec cat" ||
    fail "new-session failed"
$TMUX set-option -g window-size manual || fail "set size failed"
$TMUX set-window-option -g mode-keys vi || fail "set mode-keys failed"
sleep 1
$TMUX copy-mode || fail "copy-mode failed"

$TMUX send-keys -X history-top
$TMUX send-keys -X start-of-line
$TMUX send-keys -X -N4 next-word-end
check '#{copy_cursor_x},#{copy_cursor_y}' 18,0 "next-word-end to fox"
check '#{copy_cursor_word}' fox "word under cursor"
$TMUX send-keys -X next-word-end
check '#{copy_cursor_x},#{copy_cursor_y}' 4,1 "next-word-end over the space"

$TMUX send-keys -X start-of-line
$TMUX send-keys -X history-top
$TMUX send-keys -X -N19 cursor-right
check '#{copy_cursor_x},#{copy_cursor_y}' 19,0 "cursor-right to the space"

$TMUX kill-server 2>/dev/null
exit 0
