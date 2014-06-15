#!/bin/bash

# FIXME
gpgkey="BC0B0D65"
ppaname="cernekee/ppa"

builddir=tmp.debian
pkg=ocproxy

set -ex

function build_one
{
	arg="$1"

	rm -rf $builddir
	mkdir $builddir
	pushd $builddir

	cp ../$tarball "${pkg}_${ver}.orig.tar.gz"
	mkdir "$pkg-$ver"
	cd "$pkg-$ver"
	tar --strip 1 -zxf ../../$tarball
	cp -a ../../debian .
	if [ "$nosign" = "0" ]; then
		debuild "$arg"
	else
		debuild "$arg" -us -uc
	fi
	cd ..
	lintian -IE --pedantic *.changes | tee -a ../lintian.txt || true
	popd
}

#
# MAIN
#

tarball=$(ls -1 ${pkg}-*.tar.gz 2> /dev/null || true)
if [ -z "$tarball" -o ! -e "$tarball" ]; then
	echo "missing release tarball"
	exit 1
fi

ver=${tarball#*-}
ver=${ver%%.tar.gz}

if gpg --list-secret-keys $gpgkey >& /dev/null; then
	nosign=0
else
	nosign=1
fi

rm -f lintian.txt ${pkg}*.deb
touch lintian.txt

dist=$(lsb_release -si)
if [ "$dist" = "Ubuntu" ]; then
	git checkout -f debian/changelog
	codename=$(lsb_release -sc)

	today=$(date +%Y%m%d%H%M%S)
	ver="${ver}~${today}"
	uver="${ver}-1ubuntu1"

	dch --newversion "${uver}~${codename}" \
		--distribution $codename \
		--force-bad-version \
		"New PPA build."
fi

build_one ""
cp $builddir/*.deb .
echo "------------" >> lintian.txt
build_one "-S"

set +ex

echo "--------"
echo "lintian:"
echo "--------"
cat lintian.txt
echo "--------"

if [ -n "$uver" -a "$nosign" = "0" ]; then
	echo ""
	echo "UPLOAD COMMAND:"
	echo ""
	echo "    dput ppa:$ppaname tmp.debian/*_source.changes"
	echo ""
fi

exit 0
