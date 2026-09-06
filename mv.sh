#!/bin/bash
set -o pipefail 

echo "Добро пожаловать в MS!"

# ---- Функция обновления системы ----
update_system() {
    echo "Полное обновление системы"
    sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y
    echo "Система обновлена"
}

# ---- Функция установки Zsh + Oh My Zsh ----
install_Zsh_OMZ_plugins() {
    if ! command -v zsh &>/dev/null; then
        sudo apt update && sudo apt install -y zsh
        echo "Установка Zsh завершена!"
    else 
        echo "Zsh уже установлен"
    fi

    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "Oh My Zsh уже установлен"
    else 
        if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
            echo "Устанавливаю curl для установки Oh My Zsh"
            sudo apt install -y curl
        fi
        if command -v curl &>/dev/null; then
            sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
            echo "Установка Oh My Zsh завершена!"
        fi
    fi
}

# ---- Функция управления встроенными плагинами ----
manage_zsh_plugins() {
    local zshrc="$HOME/.zshrc"
    local omz_dir="$HOME/.oh-my-zsh"

    if [[ ! -d "$omz_dir" ]]; then
        echo "Oh My Zsh не установлен. Сначала выполните пункт 3."
        return 1
    fi
    if [[ ! -f "$zshrc" ]]; then
        echo "Файл $zshrc не найден."
        return 1
    fi

    mapfile -t all_plugins < <(find "$omz_dir/plugins" -maxdepth 1 -type d -printf "%f\n" | grep -v '^plugins$' | grep -v '^\.' | sort)
    if [[ ${#all_plugins[@]} -eq 0 ]]; then
        echo "Нет плагинов."
        return 1
    fi

    local current_line
    current_line=$(grep -E '^plugins=\(.*\)' "$zshrc")
    if [[ -z "$current_line" ]]; then
        echo "В .zshrc нет строки plugins=(...). Добавьте её вручную."
        return 1
    fi
    local plugins_str
    plugins_str=$(echo "$current_line" | sed -E 's/^plugins=\(//' | sed -E 's/\)$//' | tr -d '"' | tr -d "'")
    IFS=' ' read -r -a current_plugins <<< "$plugins_str"

    declare -A selected_map
    for p in "${current_plugins[@]}"; do
        selected_map["$p"]=1
    done

    local page=0
    local page_size=20
    local total_pages=$(( (${#all_plugins[@]} + page_size - 1) / page_size ))

    show_page() {
        clear
        local start=$((page * page_size))
        local end=$((start + page_size - 1))
        if (( end >= ${#all_plugins[@]} )); then
            end=$(( ${#all_plugins[@]} - 1 ))
        fi
        echo "=== Плагины Oh My Zsh (страница $((page+1))/$total_pages) ==="
        echo "  [x] - включён, [ ] - выключен"
        for (( i=start; i<=end; i++ )); do
            local p="${all_plugins[i]}"
            if [[ -n "${selected_map[$p]}" ]]; then
                printf "%3d. [x] %s\n" $((i+1)) "$p"
            else
                printf "%3d. [ ] %s\n" $((i+1)) "$p"
            fi
        done
        echo "--- Показано $((end-start+1)) из ${#all_plugins[@]} плагинов ---"
        echo ""
        echo "Управление:"
        echo "  5                 - вкл/выкл плагин"
        echo "  1-5    		      - вкл/выкл группу"
        echo "  a/d               - назад/вперёд"
        echo "  q                 - сохранить и выйти"
        echo ""
        echo -n "Ваш ввод: "
    }

    toggle_plugin_by_index() {
        local idx=$1
        if (( idx >= 1 && idx <= ${#all_plugins[@]} )); then
            local p="${all_plugins[$((idx-1))]}"
            if [[ -n "${selected_map[$p]}" ]]; then
                unset 'selected_map[$p]'
            else
                selected_map["$p"]=1
            fi
        else
            echo "Номер $idx вне диапазона (1-${#all_plugins[@]})"
            read -p "Нажмите Enter..."
        fi
    }

    while true; do
        show_page
        read -r input

        case "$input" in
            q|Q)
                break
                ;;
            a|A)
                if (( page > 0 )); then
                    page=$((page - 1))
                else
                    echo "Вы уже на первой странице."
                    read -p "Нажмите Enter..."
                fi
                ;;
            d|D)
                if (( page < total_pages - 1 )); then
                    page=$((page + 1))
                else
                    echo "Вы уже на последней странице."
                    read -p "Нажмите Enter..."
                fi
                ;;
            "")
                continue
                ;;
            *)
                input="${input//,/ }"
                read -r -a tokens <<< "$input"
                
                local has_error=0
                for token in "${tokens[@]}"; do
                    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                        local start_r="${BASH_REMATCH[1]}"
                        local end_r="${BASH_REMATCH[2]}"
                        if (( start_r <= end_r )); then
                            for (( k=start_r; k<=end_r; k++ )); do
                                toggle_plugin_by_index $k
                            done
                        else
                            echo "Неверный диапазон: $token"
                            has_error=1
                        fi
                    elif [[ "$token" =~ ^[0-9]+$ ]]; then
                        toggle_plugin_by_index "$token"
                    else
                        echo "Неизвестная команда или формат: '$token'. Используйте числа, диапазоны (1-5), a, d или q."
                        has_error=1
                    fi
                done
                
                if (( has_error == 1 )); then
                    read -p "Нажмите Enter..."
                fi
                ;;
        esac
    done

    local new_plugins=()
    for p in "${all_plugins[@]}"; do
        if [[ -n "${selected_map[$p]}" ]]; then
            new_plugins+=("$p")
        fi
    done
    for p in "${current_plugins[@]}"; do
        if [[ -z "${selected_map[$p]}" ]] && [[ ! " ${all_plugins[*]} " =~ " $p " ]]; then
            new_plugins+=("$p")
        fi
    done

    local new_line="plugins=(${new_plugins[*]})"
    cp "$zshrc" "$zshrc.bak"
    sed -i "s|^plugins=(.*)|$new_line|" "$zshrc"
    echo "$zshrc обновлён. Резервная копия: $zshrc.bak"
    echo "Не забудьте: source ~/.zshrc"
}

# ---- Функция управления сторонними плагинами ----
manage_external_plugins() {
    local custom_plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
    local zshrc="$HOME/.zshrc"

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        echo "Oh My Zsh не установлен. Сначала выполните пункт 3."
        return 1
    fi
    mkdir -p "$custom_plugins_dir"

    declare -A known_plugins=(
        ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
        ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
        ["zsh-history-substring-search"]="https://github.com/zsh-users/zsh-history-substring-search"
        ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
        ["fzf-tab"]="https://github.com/Aloxaf/fzf-tab"
    )

    local current_line
    current_line=$(grep -E '^plugins=\(.*\)' "$zshrc")
    if [[ -z "$current_line" ]]; then
        echo "В .zshrc нет строки plugins=(...). Добавьте её вручную или установите встроенные плагины."
        return 1
    fi
    local plugins_str
    plugins_str=$(echo "$current_line" | sed -E 's/^plugins=\(//' | sed -E 's/\)$//' | tr -d '"' | tr -d "'")
    IFS=' ' read -r -a current_zsh_plugins <<< "$plugins_str"

    local ext_names=()
    declare -A ext_urls
    
    for name in "${!known_plugins[@]}"; do
        ext_names+=("$name")
        ext_urls["$name"]="${known_plugins[$name]}"
    done
    IFS=$'\n' sorted_names=($(sort <<<"${ext_names[*]}")); unset IFS

    declare -A installed_map
    for name in "${sorted_names[@]}"; do
        if [[ -d "$custom_plugins_dir/$name" ]] && [[ " ${current_zsh_plugins[*]} " =~ " $name " ]]; then
            installed_map["$name"]=1
        fi
    done

    while true; do
        clear
        echo "=== Сторонние плагины ==="
        echo "  [x] - включен, [ ] - выключен"
        echo ""
        
        local idx=1
        for name in "${sorted_names[@]}"; do
            if [[ -n "${installed_map[$name]}" ]]; then
                printf "%3d. [x] %s\n" $idx "$name"
            else
                printf "%3d. [ ] %s\n" $idx "$name"
            fi
            idx=$((idx + 1))
        done
        
        echo ""
        echo "q. Выход"
        echo ""
        echo -n "Выберите номер для переключения: "
        read -r input

        case "$input" in
            q|Q)
                break
                ;;
            *)
                if [[ "$input" =~ ^[0-9]+$ ]]; then
                    local choice_idx=$((input))
                    if (( choice_idx >= 1 && choice_idx <= ${#sorted_names[@]} )); then
                        local selected_name="${sorted_names[$((choice_idx-1))]}"
                        local repo_url="${ext_urls[$selected_name]}"
                        local target_dir="$custom_plugins_dir/$selected_name"

                        if [[ -n "${installed_map[$selected_name]}" ]]; then
                            echo "Удаление плагина $selected_name..."
                            rm -rf "$target_dir"
                            sed -i "s/ $selected_name//g; s/$selected_name //g; s/$selected_name//g" "$zshrc"
                            sed -i "s/  */ /g" "$zshrc"
                            unset 'installed_map[$selected_name]'
                            echo "Плагин удален."
                        else
                            echo "Установка плагина $selected_name..."
                            if git clone "$repo_url" "$target_dir" 2>/dev/null; then
                                sed -i "s/^plugins=(\(.*\))/plugins=(\1 $selected_name)/" "$zshrc"
                                installed_map["$selected_name"]=1
                                echo "Плагин установлен и добавлен в конфиг."
                            else
                                echo "Ошибка клонирования."
                            fi
                        fi
                        read -p "Нажмите Enter..."
                    else
                        echo "Неверный номер."
                        read -p "Нажмите Enter..."
                    fi
                else
                    echo "Введите номер или q."
                    read -p "Нажмите Enter..."
                fi
                ;;
        esac
    done
    echo "Не забудьте перезагрузить терминал или выполнить: source ~/.zshrc"
}

# ---- Меню ----
options=(
    "1 - Полное обновление системы"
    "2 - Установка базовых утилит (нет)"
    "3 - Установка Zsh + Oh My Zsh"
    "4 - Управление встроенными плагинами Zsh"
    "5 - Управление сторонними плагинами"
    "0 - Выход"
)

while true; do
    echo "=== МЕНЮ ==="
    PS3="Выберите номер действия: "

    select choice in "${options[@]}"; do
        case $REPLY in
            1) update_system; break ;;
            3) install_Zsh_OMZ_plugins; break ;;
            4) manage_zsh_plugins; break ;;
            5) manage_external_plugins; break ;;
            0) echo "Выход"; exit 0 ;;
            *) echo "Неправильный ввод" ;;
        esac
    done

    echo ""
    read -p "Нажмите Enter, чтобы продолжить"
    echo ""
done