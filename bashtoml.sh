#!/bin/bash

DIR_CHECKSUM=""

is_table(){
    local line="$1"
    if [[ "$line" =~ ^\[.*\]$ ]]; then
        return 0
    else
        return 1
    fi
}

check_table_or_key(){
    local name="$1"

    # Regex pattern to match allowed characters: letters, digits, underscores, and hyphens
    local pattern='^[a-zA-Z0-9_-]+$'

    # Check if the input string matches the pattern
    if [[ "$name" =~ $pattern ]]; then
        return 0
    else
        return 1
    fi
}

get_table(){
    local table_name="$1"
    # shellcheck disable=SC2001
    echo "$table_name" | sed -e 's/^\[\(.*\)\]$/\1/'
}

usage(){
    echo "Unrecognized usage $1"
}

cache_exists(){
    # Check if the folder exists
    if [ -d "$DIR_CHECKSUM" ]; then
        return 0
    else
        return 1
    fi
}

get_key() {
    # Accepting a string argument
    local line="$1"
    
    # Using parameter expansion to get the value before "="
    local value="${line%%=*}"

    # Removing leading and trailing whitespace from the value
    value="${value##[[:space:]]}"
    value="${value%%[[:space:]]}"

    # Checking if the value consists only of letters, digits, underscores, or hyphens
    echo "$value"
}

get_value() {
    local line="$1"

    # Using parameter expansion to get the value after the first "="
    local value="${line#*=}"
    
    # Removing leading and trailing whitespace from the value
    value="${value##[[:space:]]}"
    value="${value%%[[:space:]]}"

    echo "$value"
}

get_multil() {
    local value
    value="$1"

    if [[ "${value:0:1}" == "[" && "${value: -1}" != "]" ]]; then
        echo "["
    elif [[ "${value:0:1}" == "{" && "${value: -1}" != "}" ]]; then
        echo "{"
    elif [[ "${value:0:3}" == '"""'  && "${value: -3}" != '"""' ]]; then
        echo '"""'
    else
        echo ""
    fi
}

create_cache() {
    local toml_file="$1"
    local table_name=""
    local line
    local multil=""
    local trim_white_space=1
    local key=""
    local value=""

    # Read the file line by line
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Ignore empty lines and lines starting with #
        if [[ -z "$line" || "$line" == \#* ]]; then
            continue
        fi

        # If line has the table name, then set the table section 
        if is_table "$line"; then
            table_name=$(get_table "$line")
            if check_table_or_key "$table_name"; then
                mkdir -p "$DIR_CHECKSUM/$table_name"
            else
                table_name=""
            fi
            continue
        fi

        # Skip the line if it is not under the table section
        if [ -z "$table_name" ]; then
            continue
        fi

        # Check for the multi-line token
        if [ -z "$multil" ]; then
            key=$(get_key "$line")
            if ! check_table_or_key "$key"; then
                key=""
                continue
            fi
            value=$(get_value "$line")
            if [ "${value: -1}" == "\\" ]; then
                value="${value%?}"
                trim_white_space=0
            fi
            echo "$value" > "$DIR_CHECKSUM/$table_name/$key"
            multil=$(get_multil "$value")
        elif [ -n "$multil" ]; then
            local new_value=""
            new_value+="$value"
            if [ $trim_white_space -eq 0 ]; then
                # shellcheck disable=SC2001
                line=$(echo "$line" | sed 's/^[[:space:]]*//')
            elif [ $trim_white_space -ne 0 ]; then
                new_value+='@@/n@@'
            fi

            if [ "${line: -1}" == "\\" ]; then
                line="${line%?}"
                trim_white_space=0
            else
                trim_white_space=1
            fi
            new_value+="$line"
            value="$new_value"
            echo "$value" > "$DIR_CHECKSUM/$table_name/$key"
            if [ "$multil" == '[' ]; then
                if [ "${line: -1}" == "]" ]; then
                    multil=""
                fi
            elif [ "$multil" == '{' ]; then
                if [ "${line: -1}" == "}" ]; then
                    multil=""
                fi
            elif [ "$multil" == '"""' ]; then
                if [ "${line: -3}" == '"""' ]; then
                    multil=""
                fi
            fi
        fi

    done < "$toml_file"
}

parse_options() {
    local filename=""
    local table=""
    local key=""
    local clear_cache=1

    # Loop through all arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                shift
                filename="$1"
                ;;
            -t|--table)
                shift
                table="$1"
                ;;
            -k|--key)
                shift
                key="$1"
                ;;
            --clear-cache)
                clear_cache=0
                ;;
            
            *)
                usage "$@"
                return 1
                ;;
        esac
        shift
    done

    if [ $clear_cache -eq 0 ]; then
        rm -rf ".bashtoml"
        return 0
    fi

    if [[ ! -f "$filename" ]]; then
        echo "File not found: $filename"
        return 1
    fi
    
    checksum=$(sha256sum "$filename" | awk '{print $1}')
    DIR_CHECKSUM=".bashtoml/$checksum"


    if ! cache_exists; then
        mkdir -p "$DIR_CHECKSUM"
        create_cache "$filename"
    fi

    if [ -n "$table" ] && [ -n "$key" ]; then
        cat "$DIR_CHECKSUM/$table/$key"
        return 0
    fi

    if [ -n "$table" ] && [ -z "$key" ]; then
        find "$DIR_CHECKSUM/$table" -mindepth 1 -type f -printf "%f\n"
        return 0
    fi

    if [ -z "$table" ] && [ -z "$key" ]; then
        find "$DIR_CHECKSUM" -mindepth 1 -type d -printf "%f\n"
        return 0
    fi
}

parse_options "$@"
