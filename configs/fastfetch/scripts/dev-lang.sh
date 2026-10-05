#!/usr/bin/env bash
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ---- Tier 1: manifest files -------------------------------------------
if   [[ -f "$root/Cargo.toml" ]]; then
    echo "rust $(rustc --version 2>/dev/null | awk '{print $2}')"; exit
elif [[ -f "$root/go.mod" ]]; then
    echo "go $(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')"; exit
elif [[ -f "$root/package.json" ]]; then
    if [[ -f "$root/tsconfig.json" ]]; then
        echo "typescript $(tsc --version 2>/dev/null | awk '{print $2}')"
    else
        echo "node $(node --version 2>/dev/null | sed 's/v//')"
    fi
    exit
elif [[ -f "$root/pyproject.toml" || -f "$root/requirements.txt" || -f "$root/setup.py" || -f "$root/Pipfile" ]]; then
    echo "python $(python3 --version 2>&1 | awk '{print $2}')"; exit
elif [[ -f "$root/pom.xml" || -f "$root/build.gradle" || -f "$root/build.gradle.kts" ]]; then
    echo "java $(java --version 2>/dev/null | head -1 | awk '{print $2}')"; exit
elif [[ -f "$root/Gemfile" ]]; then
    echo "ruby $(ruby --version 2>/dev/null | awk '{print $2}')"; exit
elif [[ -f "$root/composer.json" ]]; then
    echo "php $(php --version 2>/dev/null | head -1 | awk '{print $2}')"; exit
elif [[ -f "$root/mix.exs" ]]; then
    echo "elixir $(elixir --version 2>/dev/null | tail -1 | awk '{print $2}')"; exit
elif [[ -f "$root/pubspec.yaml" ]]; then
    echo "dart $(dart --version 2>&1 | awk '{print $4}')"; exit
elif [[ -f "$root/CMakeLists.txt" ]]; then
    echo "c++ $(g++ --version 2>/dev/null | head -1 | awk '{print $NF}')"; exit
elif ls "$root"/*.csproj "$root"/*.sln >/dev/null 2>&1; then
    echo "c# $(dotnet --version 2>/dev/null)"; exit
elif [[ -f "$root/stack.yaml" ]] || ls "$root"/*.cabal >/dev/null 2>&1; then
    echo "haskell $(ghc --version 2>/dev/null | awk '{print $NF}')"; exit
fi

# ---- Tier 2: wildcard extension count ----------------------------------
# ext:label:version-command  (order = tiebreak priority, not detection priority)
declare -a table=(
    "py:python:python3 --version 2>&1 | awk '{print \$2}'"
    "rs:rust:rustc --version 2>/dev/null | awk '{print \$2}'"
    "go:go:go version 2>/dev/null | awk '{print \$3}' | sed 's/go//'"
    "ts:typescript:tsc --version 2>/dev/null | awk '{print \$2}'"
    "tsx:typescript:tsc --version 2>/dev/null | awk '{print \$2}'"
    "js:node:node --version 2>/dev/null | sed 's/v//'"
    "jsx:node:node --version 2>/dev/null | sed 's/v//'"
    "java:java:java --version 2>/dev/null | head -1 | awk '{print \$2}'"
    "kt:kotlin:kotlinc -version 2>&1 | awk '{print \$3}'"
    "rb:ruby:ruby --version 2>/dev/null | awk '{print \$2}'"
    "php:php:php --version 2>/dev/null | head -1 | awk '{print \$2}'"
    "ex:elixir:elixir --version 2>/dev/null | tail -1 | awk '{print \$2}'"
    "exs:elixir:elixir --version 2>/dev/null | tail -1 | awk '{print \$2}'"
    "dart:dart:dart --version 2>&1 | awk '{print \$4}'"
    "swift:swift:swift --version 2>/dev/null | head -1 | awk '{print \$4}'"
    "c:c:gcc --version 2>/dev/null | head -1 | awk '{print \$NF}'"
    "cpp:c++:g++ --version 2>/dev/null | head -1 | awk '{print \$NF}'"
    "cs:c#:dotnet --version 2>/dev/null"
    "hs:haskell:ghc --version 2>/dev/null | awk '{print \$NF}'"
    "scala:scala:scala -version 2>&1 | awk '{print \$NF}'"
    "r:r:R --version 2>/dev/null | head -1 | awk '{print \$3}'"
    "pl:perl:perl --version 2>/dev/null | sed -n '2p' | grep -oP 'v\\K[0-9.]+'"
    "lua:lua:lua -v 2>&1 | awk '{print \$2}'"
    "sh:bash:bash --version 2>/dev/null | head -1 | awk '{print \$4}'"
)

best_ext="" best_lang="" best_ver_cmd="" best_count=0
for entry in "${table[@]}"; do
    ext="${entry%%:*}"; rest="${entry#*:}"
    lang="${rest%%:*}"; ver_cmd="${rest#*:}"

    count=$(find "$root" -maxdepth 4 -type f -iname "*.${ext}" \
            -not -path '*/node_modules/*' -not -path '*/.git/*' \
            -not -path '*/target/*' -not -path '*/dist/*' \
            -not -path '*/build/*' -not -path '*/vendor/*' \
            2>/dev/null | wc -l)

    if (( count > best_count )); then
        best_count=$count
        best_ext=$ext
        best_lang=$lang
        best_ver_cmd=$ver_cmd
    fi
done

if (( best_count > 0 )); then
    echo "$best_lang $(eval "$best_ver_cmd")"
    exit
fi

# ---- Tier 3: repo-convention fallback -----------------------------------
if [[ -f "$root/bootstrap.sh" || -f "$root/install.sh" ]]; then
    echo "bash $(bash --version 2>/dev/null | head -1 | awk '{print $4}')"
else
    echo "n/a"
fi