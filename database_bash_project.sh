#!/bin/bash

DATABASE_DIR="database"

function validate_name() {
    local name="$1"
    if [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        return 0
    else
        echo "Invalid name: $name. Names must start with a letter or underscore, and contain only alphanumeric characters or underscores."
        return 1
    fi
}

function list_directories() {
    ls -d */ 2>/dev/null | sed 's#/##'
}

function main_menu() {
    while true; do
        echo "Main Menu:"
        echo "1) Create Database"
        echo "2) List Databases"
        echo "3) Drop Database"
        echo "4) Connect to Database"
        echo "5) Exit"
        read -p "Enter your choice: " choice
        case $choice in
            1) create_database ;;
            2) list_databases ;;
            3) drop_database ;;
            4) connect_database ;;
            5) exit 0 ;;
            *) echo "Invalid choice. Please try again." ;;
        esac
    done
}

function create_database() {
    read -p "Enter database name: " db_name
    validate_name "$db_name" || return
    if [ -d "$DATABASE_DIR/$db_name" ]; then
        echo "Database $db_name already exists."
    else
        mkdir -p "$DATABASE_DIR/$db_name"
        echo "Database $db_name created."
    fi
}

function list_databases() {
    echo "Databases:"
    cd "$DATABASE_DIR" && list_directories || echo "No databases found."
}

function drop_database() {
    read -p "Enter database name: " db_name
    validate_name "$db_name" || return
    if [ -d "$DATABASE_DIR/$db_name" ]; then
        rm -rf "$DATABASE_DIR/$db_name"
        echo "Database $db_name dropped."
    else
        echo "Database $db_name does not exist."
    fi
}

function connect_database() {
    read -p "Enter database name: " db_name
    validate_name "$db_name" || return
    if [ -d "$DATABASE_DIR/$db_name" ]; then
        cd "$DATABASE_DIR/$db_name"
        database_menu
        cd - >/dev/null
    else
        echo "Database $db_name does not exist."
    fi
}

function database_menu() {
    while true; do
        echo "Database Menu:"
        echo "1) Create Table"
        echo "2) List Tables"
        echo "3) Drop Table"
        echo "4) Insert into Table"
        echo "5) Select from Table"
        echo "6) Delete from Table"
        echo "7) Update Table"
        echo "8) Back to Main Menu"
        read -p "Enter your choice: " choice
        case $choice in
            1) create_table ;;
            2) list_tables ;;
            3) drop_table ;;
            4) insert_into_table ;;
            5) select_from_table ;;
            6) delete_from_table ;;
            7) update_table ;;
            8) break ;;
            *) echo "Invalid choice. Please try again." ;;
        esac
    done
}

function create_table() {
    read -p "Enter table name: " table_name
    validate_name "$table_name" || return
    if [ -f "$table_name.meta" ]; then
        echo "Table $table_name already exists."
    else
        echo "Creating table $table_name..."
        read -p "Enter number of columns: " col_count
        columns=""
        primary_keys=""
        for ((i=1; i<=col_count; i++)); do
            read -p "Enter column $i name: " col_name
            validate_name "$col_name" || return
            read -p "Enter column $i type (string/number): " col_type
            columns+="$col_name:$col_type"
            if [ $i -lt $col_count ]; then
                columns+=","
            fi
            read -p "Is this column a primary key? (y/n): " is_pk
            if [ "$is_pk" == "y" ]; then
                primary_keys+="$col_name"
                if [ $i -lt $col_count ]; then
                    primary_keys+=":"
                fi
            fi
        done
        echo "columns=$columns" > "$table_name.meta"
        echo "primary_keys=$primary_keys" >> "$table_name.meta"
        touch "$table_name.data"
        echo "Table $table_name created."
    fi
}

function list_tables() {
    echo "Tables:"
    ls *.meta 2>/dev/null | sed 's/.meta//'
}

function drop_table() {
    read -p "Enter table name: " table_name
    validate_name "$table_name" || return
    if [ -f "$table_name.meta" ]; then
        rm "$table_name.meta" "$table_name.data"
        echo "Table $table_name dropped."
    else
        echo "Table $table_name does not exist."
    fi
}

function insert_into_table() {
    echo -n "Enter the table name to insert data: "
    read table_name
    if [[ ! -f "$table_name.data" ]] || [[ ! -f "$table_name.meta" ]]; then
        echo "Table '$table_name' does not exist."
        return
    fi
    column_names=($(awk -F':' '{print $1}' "$table_name.meta"))
    column_types=($(awk -F':' '{print $2}' "$table_name.meta"))
    primary_keys=($(awk -F':' '{if ($3 == "PK") print $1}' "$table_name.meta"))
    new_row=""
    for i in "${!column_names[@]}"; do
        echo -n "Enter value for ${column_names[i]} (${column_types[i]}): "
        read value
        if [[ "${column_types[i]}" == "number" && ! "$value" =~ ^[0-9]+$ ]]; then
            echo "Invalid value for ${column_names[i]} (must be a number)."
            return
        fi
        if [[ " ${primary_keys[*]} " =~ " ${column_names[i]} " ]]; then
            if grep -q "^.*:$value:.*$" "$table_name.data"; then
                echo "Duplicate value for primary key ${column_names[i]}."
                return
            fi
        fi
        new_row+="$value:"
    done
    echo "${new_row%:}" >> "$table_name.data"
    echo "Row inserted successfully!"
}

function select_from_table() {
    echo -n "Enter the table name to select from: "
    read table_name

    if [[ ! -f "$table_name.data" ]] || [[ ! -f "$table_name.meta" ]]; then
        echo "Table '$table_name' does not exist."
        return
    fi

    echo "Select Options:"
    echo "1) Select all (SELECT *)"
    echo "2) Select specific columns with conditions"
    echo "3) Select specific columns data"
    echo -n "Choose an option: "
    read option

    column_names=($(awk -F':' '{print $1}' "$table_name.meta"))

    if [[ "$option" == "1" ]]; then
        echo "${column_names[*]}" | tr ' ' ':' 
        cat "$table_name.data"

    elif [[ "$option" == "2" ]]; then
        echo "Available columns: ${column_names[@]}"
        echo -n "Enter columns to select (comma-separated): "
        read selected_columns
        echo -n "Enter the condition"
        read condition

        selected_indices=()
        IFS=',' read -ra columns <<< "$selected_columns"
        for col in "${columns[@]}"; do
            index=$(awk -F':' -v col="$col" '$1==col {print NR-1}' "$table_name.meta")
            if [[ -z "$index" ]]; then
                echo "Invalid column: $col"
                return
            fi
            selected_indices+=("$index")
        done

        cond_col=$(echo "$condition" | cut -d'=' -f1)
        cond_val=$(echo "$condition" | cut -d'=' -f2)
        cond_col_index=$(awk -F':' -v col="$cond_col" '$1==col {print NR-1}' "$table_name.meta")
        if [[ -z "$cond_col_index" ]]; then
            echo "Invalid column in condition: $cond_col"
            return
        fi

        echo "${columns[*]}"
        awk -F':' -v idxs="${selected_indices[*]}" -v c_idx="$((cond_col_index+1))" -v c_val="$cond_val" '
            BEGIN { split(idxs, indices, " ") }
            $c_idx == c_val {
                row = ""
                for (i in indices) row = row $((indices[i]+1)) ":"
                print substr(row, 1, length(row)-1)
            }
        ' "$table_name.data"

    elif [[ "$option" == "3" ]]; then
        echo "Available columns: ${column_names[@]}"
        echo -n "Enter columns to select (comma-separated): "
        read selected_columns

        selected_indices=()
        IFS=',' read -ra columns <<< "$selected_columns"
        for col in "${columns[@]}"; do
            index=$(awk -F':' -v col="$col" '$1==col {print NR-1}' "$table_name.meta")
            if [[ -z "$index" ]]; then
                echo "Invalid column: $col"
                return
            fi
            selected_indices+=("$index")
        done

        echo "${columns[*]}"
        awk -F':' -v idxs="${selected_indices[*]}" '
            BEGIN { split(idxs, indices, " ") }
            {
                row = ""
                for (i in indices) row = row $((indices[i]+1)) ":"
                print substr(row, 1, length(row)-1)
            }
        ' "$table_name.data"
    else
        echo "Invalid option."
    fi
}

function delete_from_table() {
    echo -n "Enter the table name to delete from: "
    read table_name

    if [[ ! -f "$table_name.data" ]] || [[ ! -f "$table_name.meta" ]]; then
        echo "Table '$table_name' does not exist."
        return
    fi

    echo -n "Enter the column name for the condition: "
    read column_name
    echo -n "Enter the condition (e.g., =, >, <): "
    read condition
    echo -n "Enter the value: "
    read value

    column_index=$(awk -F':' -v col="$column_name" '$1==col {print NR-1}' "$table_name.meta")
    if [[ -z "$column_index" ]]; then
        echo "Column '$column_name' does not exist."
        return
    fi

    awk -F':' -v idx="$((column_index+1))" -v cond="$condition" -v val="$value" '
        {
            if (!($idx cond val)) print $0
        }
    ' "$table_name.data" > "$table_name.data.tmp" && mv "$table_name.data.tmp" "$table_name.data"

    echo "Rows deleted where $column_name $condition $value."
}

function update_table() {
    echo -n "Enter the table name to update: "
    read table_name

    if [[ ! -f "$table_name.data" ]] || [[ ! -f "$table_name.meta" ]]; then
        echo "Table '$table_name' does not exist."
        return
    fi

    echo -n "Enter the column name for the condition: "
    read column_name
    echo -n "Enter the condition (e.g., =, >, <): "
    read condition
    echo -n "Enter the value for the condition: "
    read value

    echo -n "Enter the column name to update: "
    read update_column
    echo -n "Enter the new value: "
    read new_value

    condition_index=$(awk -F':' -v col="$column_name" '$1==col {print NR-1}' "$table_name.meta")
    update_index=$(awk -F':' -v col="$update_column" '$1==col {print NR-1}' "$table_name.meta")

    if [[ -z "$condition_index" || -z "$update_index" ]]; then
        echo "Invalid column name(s)."
        return
    fi

    awk -F':' -v c_idx="$((condition_index+1))" -v u_idx="$((update_index+1))" -v cond="$condition" -v val="$value" -v new_val="$new_value" '
        {
            if ($c_idx cond val) $u_idx = new_val
            print $0
        }
    ' OFS=':' "$table_name.data" > "$table_name.data.tmp" && mv "$table_name.data.tmp" "$table_name.data"

    echo "Rows updated where $column_name $condition $value."
}


if [ ! -d "$DATABASE_DIR" ]; then
    mkdir "$DATABASE_DIR"
fi
cd "$DATABASE_DIR"
main_menu
