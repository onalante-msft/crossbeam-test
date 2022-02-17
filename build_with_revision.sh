#! /usr/bin/env -S sh -eux

cleanup () {
	# rm -rf ${TMPDIR}
	# git checkout -- Cargo.toml Cargo.lock
	true
}

REVISION="${1:-e32c891f376332828852fa2eb5626a831b395e28}"
PROJECT_ROOT=$(cargo metadata --no-deps --format-version 1 \
	| jq -r '.workspace_root')
TMPDIR=$(mktemp -p /tmp -d crossbeam.XXXXX)
trap cleanup EXIT
cd "${TMPDIR}"

git init
git remote add origin https://github.com/crossbeam-rs/crossbeam.git
git fetch --depth 1 origin "${REVISION}"
git checkout FETCH_HEAD

if [ ! -t 0 ]
then
	git apply -
fi

VERSION=$(cargo metadata --no-deps --format-version 1 \
	| jq -r '.packages[] | select(.name == "crossbeam-utils") | .version')

cd "${PROJECT_ROOT}"
CROSSBEAM_UTILS="${TMPDIR}/crossbeam-utils"
PATCH_LINE=$({ grep -n '^\[patch\.crates-io\]$' Cargo.toml || printf "%d\n" -1; } \
	| sed 's/:.*//')

if [ "${PATCH_LINE}" -lt 0 ]
then
	ex Cargo.toml <<-EOF
		$
		a
		[patch.crates-io]
		crossbeam-utils = { path = "${CROSSBEAM_UTILS}" }
		.
		x
	EOF
else
	CROSSBEAM_PATCH=$(tail +$((${PATCH_LINE} + 1)) Cargo.toml \
		| { grep -n '^crossbeam-utils' || printf "%d\n" 0; } \
		| head -1 \
		| sed 's/:.*//')
	NEXT_TABLE=$(tail +$((${PATCH_LINE} + 1)) Cargo.toml \
		| { grep -n '^\[' || printf "%d\n" "${CROSSBEAM_PATCH}"; } \
		| head -1 \
		| sed 's/:.*//')

	if [ "${CROSSBEAM_PATCH}" -gt 0 -a "${CROSSBEAM_PATCH}" -le "${NEXT_TABLE}" ]
	then
		ex Cargo.toml <<-EOF
			$((${PATCH_LINE} + ${CROSSBEAM_PATCH}))c
			crossbeam-utils = { path = "${CROSSBEAM_UTILS}" }
			.
			x
		EOF
	else
		ex Cargo.toml <<-EOF
			${PATCH_LINE}a
			crossbeam-utils = { path = "${CROSSBEAM_UTILS}" }
			.
			x
		EOF
	fi
fi

cargo check
