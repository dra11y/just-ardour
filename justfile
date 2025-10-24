# Ardour Auto-Builder - making their "build system from hell $45 convenience fee" irrelevant
# Usage: just build

GIT_REPO := "https://github.com/Ardour/ardour.git"

# List all recipes
list:
    @just --list

# Main build recipe
build: compile
    echo '🚀 Ardour built successfully. That’ll be $0.00'

# Pull latest ardour from git
update: clean
    #!/usr/bin/env bash
    set -euo pipefail

    if [ ! -d "ardour/.git" ]; then
        echo "📥 Cloning repository..."
        git clone {{GIT_REPO}} ardour
    else
        echo "🔄 Pulling latest changes..."
        cd ardour && git checkout master && git pull
    fi

# Pull latest ardour from git and switch to the current stable version
[working-directory: "ardour"]
stable: update
    #!/usr/bin/env bash
    set -euo pipefail

    LATEST_STABLE=$(just versions | tail -1)
    git config advice.detachedHead false
    git checkout "$LATEST_STABLE"
    CURRENT=$(git describe)
    if [ "$CURRENT" != "$LATEST_STABLE" ]; then
        exit 1;
    fi

# Show or set the current checked out version tag
[working-directory: "ardour"]
version version="":
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "{{version}}" != "" ]; then
        git config advice.detachedHead false
        git checkout "{{version}}"
    else
        git branch
        git describe
    fi

[working-directory: "ardour"]
versions: update
    git tag -l | grep -E '^[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n

# Nuclear clean
[working-directory: "ardour"]
clean:
    rm -rf build/ .waf* .lock-waf* .DS_Store
    echo "🧹 Cleaned previous build"

# Install ALL the dependencies
deps:
    echo "📦 Installing dependencies..."
    brew update

    # Core audio/libs
    brew install boost glibmm gtkmm3 libsndfile libarchive liblo taglib \
        vamp-plugin-sdk rubberband libusb jack fftw aubio \
        libpng pango cairomm pangomm lv2 cppunit \
        libwebsockets lrdf serd sord sratom lilv

    # Build tools
    brew install pkg-config automake libtool wget

    echo "✅ Dependencies installed"

# Configure
[working-directory: "ardour"]
configure:
    #!/usr/bin/env bash

    set -euo pipefail

    echo "🔧 Setting up build environment..."

    BREW=$(brew --prefix)
    GCC=$(brew --prefix gcc)
    BOOST=$(brew --prefix boost)
    CELLAR=$(brew --cellar)
    LIBARCHIVE=$(brew --prefix libarchive)

    export CC=clang
    export CXX=clang++
    export CPPFLAGS="-DDISABLE_VISIBILITY -I$BREW/include -I$BOOST/include -I$LIBARCHIVE/include"
    export LDFLAGS="-L$BREW/lib -L$BOOST/lib"

    # Find directories matching the pattern and append them to PATH
    for dir in $(find "$CELLAR" -type d -name '*pkgconfig'); do
        PKG_CONFIG_PATH="${PKG_CONFIG_PATH:-}:$dir"
        echo $dir
    done

    export PKG_CONFIG_PATH=$(echo $PKG_CONFIG_PATH | sed 's/^://')

    env

    echo "⚙️  Configuring build..."

    ./waf configure --keepflags

    echo "✅ Configuration complete"

# Compile
[working-directory: "ardour"]
compile:
    #!/usr/bin/env bash
    set -euo pipefail

    if [ ! -f "build/gtk2_ardour/gtk2ardour-config.h" ]; then
        just configure
    fi

    echo "🔨 Compiling (this will take a while)..."
    ./waf -j$(sysctl -n hw.ncpu)
    echo "✅ Compilation complete"

# Run the development version
[working-directory: "ardour/gtk2_ardour"]
run: build
    ./ardev

# Package into a disk image on macOS
[working-directory: "ardour/tools/osx_packaging"]
package:
    ./osx_build --public
