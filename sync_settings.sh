#!/bin/bash

TOML_FILE="settings.toml"
TEMPLATE_DIR="./settings"
SRC_DIR=""
DEST_DIR=""
GITHUB_SSH="git@github.com:vladimirjo"
REPOSITORY=""

function clean_quotes {
    local line="$1"

    if ! echo "$line" | grep -q "@@/CLEAN_QUOTES@@"; then
        echo "$line"
        return
    fi

    # Remove @@{JSON}@@ from the string
    line="${line//@@\/CLEAN_QUOTES@@/}"

    # Remove " from the string
    line="${line//\"/}"

    # Output the modified string
    echo "$line"
}

function clean_json {
    local line="$1"

    # Check if the pattern is found in the input string
    if ! echo "$line" | grep -q "@@/CLEAN_JSON@@"; then
        echo "$line"
        return
    fi

    # Remove @@/JSON@@ from the string
    line="${line//@@\/CLEAN_JSON@@/}"

    # Remove """ from the string
    line="${line//\"\"\"/}"

    # Output the modified string
    echo "$line"
}

function replace_templates {
    local templates
    templates=$(bash bashtoml.sh -f "$TOML_FILE" -t "$REPOSITORY")
    local template=""
    local template_value
    echo "Replacing template values in $REPOSITORY"

    while IFS= read -r template; do
        template_value=$(bash bashtoml.sh -f "$TOML_FILE" -t "$REPOSITORY" -k "$template")
        template_value=$(clean_json "$template_value")
        template_value=$(clean_quotes "$template_value")
        find "$SRC_DIR" -type f -exec sed -i "s|@@$template@@|$template_value|g" {} \;

        # Change @@/n@@ with new line characters
        find "$SRC_DIR" -type f -exec sed -i 's/@@\/n@@/\n/g' {} +
    done <<< "$templates"
}

function main {
    local repositories
    repositories=$(bash bashtoml.sh -f "$TOML_FILE")

    while IFS= read -r REPOSITORY; do
        SRC_DIR=$(mktemp -d "/tmp/src_XXXXXX")
        DEST_DIR=$(mktemp -d "/tmp/dest_XXXXXX")
        cp -r "$TEMPLATE_DIR"/. "$SRC_DIR"

        replace_templates

        git clone "$GITHUB_SSH/$REPOSITORY.git" "$DEST_DIR"
        git -C "$DEST_DIR" checkout -b sync_settings
        cp -rf "$SRC_DIR"/. "$DEST_DIR"
        git -C "$DEST_DIR" add .
        git -C "$DEST_DIR" commit -m "Automated: Developer settings updated."
        git -C "$DEST_DIR" push -u origin sync_settings

        echo "Removing temporary directories."
        rm -rf "$DEST_DIR"
        rm -rf "$SRC_DIR"
    done <<< "$repositories"

}

main