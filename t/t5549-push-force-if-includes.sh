test_description='Test push "--force-if-includes" forced update safety.'

. ./test-lib.sh

setup_src_dup_dst () {
	rm -fr src dup dst &&
	git init --bare dst &&
	git clone --no-local dst src &&
	git clone --no-local dst dup
	(
		cd src &&
		test_commit foo &&
		git push
	) &&
	(
		cd dup &&
		git fetch &&
		git merge origin/master &&
		test_commit bar &&
		git switch -c branch master~1 &&
		test_commit baz &&
		test_commit D &&
		git push --all
	) &&
	(
		cd src &&
		git switch master &&
		git fetch --all &&
		git branch branch --track origin/branch &&
		git rebase origin/master
	) &&
	(
		cd dup &&
		git switch master &&
		test_commit qux &&
		git switch branch &&
		test_commit quux &&
		git push origin --all
	)
}

test_expect_success 'reject push if remote changes are not integrated locally (protected, all refs)' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	git ls-remote dst refs/heads/master >expect.master &&
	git ls-remote dst refs/heads/master >expect.branch &&
	(
		cd src &&
		git switch branch &&
		test_commit wobble &&
		git switch master &&
		test_commit wubble &&
		git fetch --all &&
		test_must_fail git push --force-if-includes --all
	) &&
	git ls-remote dst refs/heads/master >actual.master &&
	git ls-remote dst refs/heads/master >actual.branch &&
	test_cmp expect.master actual.master &&
	test_cmp expect.branch actual.branch
'

test_expect_success 'reject push if remote changes are not integrated locally (protected, specific ref)' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	git ls-remote dst refs/heads/master >expect.master &&
	(
		cd src &&
		git switch branch &&
		test_commit wobble &&
		git switch master &&
		test_commit wubble &&
		git fetch --all &&
		test_must_fail git push --force-if-includes origin master
	) &&
	git ls-remote dst refs/heads/master >actual.master &&
	test_cmp expect.master actual.master
'

test_expect_success 'allow force push if "--force" is specified (forced, all refs)' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	(
		cd src &&
		git switch branch &&
		test_commit wobble &&
		git switch master &&
		test_commit wubble &&
		git fetch --all &&
		git push --force --force-if-includes origin --all 2>err &&
		grep "forced update" err
	)
'

test_expect_success 'allow force push if "--delete" is specified' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	(
		cd src &&
		git switch branch &&
		test_commit wobble &&
		git switch master &&
		test_commit wubble &&
		git fetch --all &&
		git push --delete --force-if-includes origin branch 2>err &&
		grep "deleted" err
	)
'

test_expect_success 'allow forced updates if specified with refspec (forced, specific ref)' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	(
		cd src &&
		git switch branch &&
		test_commit wobble &&
		git switch master &&
		test_commit wubble &&
		git fetch --all &&
		git push --force-if-includes origin +branch 2>err &&
		grep "forced update" err
	)
'

test_expect_success 'allow deletes if specified with refspec (delete, specific ref)' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	(
		cd src &&
		git switch branch &&
		test_commit wobble &&
		git switch master &&
		test_commit wubble &&
		git fetch --all &&
		git push --force-if-includes origin :branch 2>err &&
		grep "deleted" err
	)
'

test_expect_success 'must be disabled for --force-with-lease="<ref>:<expect>" (protected, specific ref)' '
	setup_src_dup_dst &&
	test_when_finished "rm -fr dst src dup" &&
	git ls-remote dst refs/heads/master >expect.master &&
	git ls-remote dst refs/heads/master >expect.branch &&
	(
		cd src &&
		git switch branch &&
		test_commit wobble &&
		git switch master &&
		test_commit wubble &&
		r_head="$(git rev-parse refs/remotes/origin/master)" &&
		git fetch --all &&
		test_must_fail git push --force-if-includes --force-with-lease="master:$r_head" 2>err &&
		grep "stale info" err
	) &&
	git ls-remote dst refs/heads/master >actual.master &&
	git ls-remote dst refs/heads/master >actual.branch &&
	test_cmp expect.master actual.master &&
	test_cmp expect.branch actual.branch
'

test_done
