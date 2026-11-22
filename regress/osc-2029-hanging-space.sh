#!/bin/sh

# On a line marked by OSC 2029, a space that does not fit hangs past the edge,
# so a word that ends at the edge stays on its row and the next row starts with
# the next word, when written and on resize. Copy mode and capture-pane keep
# the hanging space.

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
	[ "$2" = "$3" ] || fail "$1: expected '$2', got '$3'"
}

rows()
{
	$TMUX capture-pane -p -S- | grep . | head -5 | paste -sd'|' -
}

cursor()
{
	$TMUX display-message -p '#{copy_cursor_x},#{copy_cursor_y}'
}

# At 15 columns, "brown" ends at the edge, and the third of the spaces after
# "three" does not fit.
$TMUX new-session -d -x15 -y8 "
    printf '\033]2029\033\\\\the quick brown fox jumps over the lazy dog\n'
    printf '\033]2029\033\\\\one two three   four\n'
    exec cat" || fail "new-session failed"
$TMUX set-option -g window-size manual || fail "set size failed"
$TMUX set-window-option -g mode-keys vi || fail "set mode-keys failed"
sleep 1
expected='the quick brown|fox jumps over|the lazy dog|one two three|four'
check written "$expected" "$(rows)"

$TMUX resize-window -x20
sleep 1
$TMUX resize-window -x15
sleep 1
check reflowed "$expected" "$(rows)"

check joined 'the quick brown fox jumps over the lazy dog|one two three   four' \
    "$($TMUX capture-pane -pJ -S- | grep . | paste -sd'|' -)"

$TMUX copy-mode || fail "copy-mode failed"
$TMUX send-keys -X history-top
$TMUX send-keys -X start-of-line
$TMUX send-keys -X -N3 next-word-end
check word brown "$($TMUX display-message -p '#{copy_cursor_word}')"
$TMUX send-keys -X next-word-end
check next-word-end 2,1 "$(cursor)"
$TMUX send-keys -X history-top
$TMUX send-keys -X start-of-line
$TMUX send-keys -X search-forward-text 'brown fox'
check search 10,0 "$(cursor)"
$TMUX send-keys -X history-top
$TMUX send-keys -X start-of-line
$TMUX send-keys -X search-forward 'brown fox j'
check search-regex 10,0 "$(cursor)"
$TMUX send-keys -X -N2 cursor-down
$TMUX send-keys -X search-backward 'brown fox j'
check search-regex-back 10,0 "$(cursor)"
$TMUX send-keys -X history-top
$TMUX send-keys -X start-of-line
$TMUX send-keys -X search-forward 'three   four'
check search-run 8,3 "$(cursor)"
$TMUX send-keys -X history-top
$TMUX send-keys -X start-of-line
$TMUX send-keys -X search-forward 'fox'
check search-regex-next-row 0,1 "$(cursor)"
$TMUX send-keys -X history-top
$TMUX send-keys -X start-of-line
$TMUX send-keys -X begin-selection
$TMUX send-keys -X -N4 cursor-down
$TMUX send-keys -X end-of-line
$TMUX send-keys -X copy-selection
check copy 'the quick brown fox jumps over the lazy dog
one two three   four' "$($TMUX show-buffer)"

# Erasing to the end of the line erases the space that hangs past the edge, so
# writing on puts a single space at the break.
$TMUX kill-server 2>/dev/null
$TMUX new-session -d -x15 -y8 "
    printf '\033]2029\033\\\\the quick brown \r\033[10C\033[Kbrown fox\n'
    exec cat" || fail "new-session failed"
sleep 1
check erased 'the quick brown fox' "$($TMUX capture-pane -pJ | grep .)"

$TMUX kill-server 2>/dev/null
exit 0
