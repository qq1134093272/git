#!/bin/sh

test_description='branch --contains <commit>, --no-contains <commit> --merged, and --no-merged'

. ./test-lib.sh

test_expect_success setup '

	>file &&
	git add file &&
	test_tick &&
	git commit -m initial &&
	git branch side &&

	echo 1 >file &&
	test_tick &&
	git commit -a -m "second on master" &&

	git checkout side &&
	echo 1 >file &&
	test_tick &&
	git commit -a -m "second on side" &&

	git merge master

'

test_expect_success 'branch --contains=master' '

	git branch --contains=master >actual &&
	{
		echo "  master" && echo "* side"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --contains master' '

	git branch --contains master >actual &&
	{
		echo "  master" && echo "* side"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --no-contains=master' '

	git branch --no-contains=master >actual &&
	test_must_be_empty actual

'

test_expect_success 'branch --no-contains master' '

	git branch --no-contains master >actual &&
	test_must_be_empty actual

'

test_expect_success 'branch --contains=side' '

	git branch --contains=side >actual &&
	{
		echo "* side"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --no-contains=side' '

	git branch --no-contains=side >actual &&
	{
		echo "  master"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --contains with pattern implies --list' '

	git branch --contains=master master >actual &&
	{
		echo "  master"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --no-contains with pattern implies --list' '

	git branch --no-contains=master master >actual &&
	test_must_be_empty actual

'

test_expect_success 'side: branch --merged' '

	git branch --merged >actual &&
	{
		echo "  master" &&
		echo "* side"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --merged with pattern implies --list' '

	git branch --merged=side master >actual &&
	{
		echo "  master"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'side: branch --no-merged' '

	git branch --no-merged >actual &&
	test_must_be_empty actual

'

test_expect_success 'master: branch --merged' '

	git checkout master &&
	git branch --merged >actual &&
	{
		echo "* master"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'master: branch --no-merged' '

	git branch --no-merged >actual &&
	{
		echo "  side"
	} >expect &&
	test_cmp expect actual

'

test_expect_success 'branch --no-merged with pattern implies --list' '

	git branch --no-merged=master master >actual &&
	test_must_be_empty actual

'

test_expect_success 'implicit --list conflicts with modification options' '

	test_must_fail git branch --contains=master -d &&
	test_must_fail git branch --contains=master -m foo &&
	test_must_fail git branch --no-contains=master -d &&
	test_must_fail git branch --no-contains=master -m foo

'

test_expect_success 'Assert that --contains only works on commits, not trees & blobs' '
	test_must_fail git branch --contains master^{tree} &&
	blob=$(git hash-object -w --stdin <<-\EOF
	Some blob
	EOF
	) &&
	test_must_fail git branch --contains $blob &&
	test_must_fail git branch --no-contains $blob
'

# We want to set up a case where the walk for the tracking info
# of one branch crosses the tip of another branch (and make sure
# that the latter walk does not mess up our flag to see if it was
# merged).
#
# Here "topic" tracks "master" with one extra commit, and "zzz" points to the
# same tip as master The name "zzz" must come alphabetically after "topic"
# as we process them in that order.
test_expect_success 'branch --merged with --verbose' '
	git branch --track topic master &&
	git branch zzz topic &&
	git checkout topic &&
	test_commit foo &&
	git branch --merged topic >actual &&
	cat >expect <<-\EOF &&
	  master
	* topic
	  zzz
	EOF
	test_cmp expect actual &&
	git branch --verbose --merged topic >actual &&
	cat >expect <<-EOF &&
	  master $(git rev-parse --short master) second on master
	* topic  $(git rev-parse --short topic ) [ahead 1] foo
	  zzz    $(git rev-parse --short zzz   ) second on master
	EOF
	test_i18ncmp expect actual
'

# The next series of tests covers multiple filter combinations
test_expect_success 'set up repo for multiple filter combination tests' '
	git checkout master &&
	git branch | grep -v master | xargs git branch -D &&
	git checkout -b feature_a master &&
	>feature_a &&
	git add feature_a &&
	git commit -m "add feature a" &&
	git checkout -b feature_b master &&
	>feature_b &&
	git add feature_b &&
	git commit -m "add feature b"
'

test_expect_success 'multiple branch --contains' '
	git checkout -b next master &&
	git merge feature_a &&
	git branch --contains feature_a --contains feature_b >actual &&
	cat >expect <<-\EOF &&
	  feature_a
	  feature_b
	* next
	EOF
	test_cmp expect actual
'

test_expect_success 'multiple branch --merged' '
	git branch --merged next --merged master >actual &&
	cat >expect <<-\EOF &&
	  feature_a
	  master
	* next
	EOF
	test_cmp expect actual
'

test_expect_success 'multiple branch --no-contains' '
	git branch --no-contains feature_a --no-contains feature_b >actual &&
	cat >expect <<-\EOF &&
	  master
	EOF
	test_cmp expect actual
'

test_expect_success 'multiple branch --no-merged' '
	git branch --no-merged next --no-merged master >actual &&
	cat >expect <<-\EOF &&
	  feature_b
	EOF
	test_cmp expect actual
'

test_expect_success 'branch --contains combined with --no-contains' '
	git checkout master &&
	git merge feature_a &&
	git checkout next &&
	git merge feature_b &&
	git branch --contains feature_a --no-contains feature_b >actual &&
	cat >expect <<-\EOF &&
	  feature_a
	  master
	EOF
	test_cmp expect actual
'

test_expect_success 'branch --merged combined with --no-merged' '
	git branch --merged next --no-merged master >actual &&
	cat >expect <<-\EOF &&
	  feature_b
	* next
	EOF
	test_cmp expect actual
'

test_done
