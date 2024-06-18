#!/bin/bash

MODULES=("docugenr8-core" "docugenr8-pdf" "docugenr8-shared" "docugenr8")

# Function to check if Python 3.10 is installed
check_python_version() {
    if command -v python3.10 &> /dev/null; then
        # Python 3.10 command is available, now check the version
        local python_version
        python_version=$(python3.10 --version 2>&1)
        if [[ $python_version == "Python 3.10"* ]]; then
            echo "Python 3.10 is installed: $python_version"
            return 0
        else
            echo "Python 3.10 command exists but the version is different: $python_version"
            return 1
        fi
    else
        echo "Python 3.10 is not installed."
        return 1
    fi
}

get_repository() {
    local repository="$1"
    echo "git@github.com:vladimirjo/$repository.git"
}

setup() {
    # Install Python 3.10
    if ! check_python_version; then
        sudo apt update
        sudo apt install -y python3.10 python3.10-venv
    fi

    # Update pip
    python3.10 -m pip install --upgrade pip

    # Print the current directory
    parent_dir=$(dirname "$(pwd)")
    echo "Parent directory is: $parent_dir"

    for module in "${MODULES[@]}"; do

        if [[ -d "$parent_dir/$module" ]]; then
            echo "Directory ${parent_dir}/${module} already exists, skipping ${module}."
            continue
        fi

        local repository
        repository=$(get_repository "$module")

        git clone "$repository" "$parent_dir/$module"

        python3.10 -m venv "$parent_dir/$module/.venv"

        echo "Activate virtual environment in $parent_dir/$module/.venv/bin/activate"
        # shellcheck source=/dev/null
        source "$parent_dir/$module/.venv/bin/activate"

        python3.10 -m pip install -e "${parent_dir}/${module}[dev]"

        if [[ "$module" == "docugenr8" ]]; then
            python3.10 -m pip install -e "$parent_dir/docugenr8-core"
            python3.10 -m pip install -e "$parent_dir/docugenr8-pdf"
            python3.10 -m pip install -e "$parent_dir/docugenr8-shared"
        fi

        echo "Deactivate virtual environment in $parent_dir/$module/.venv/bin/activate"
        deactivate

    done

}

setup
