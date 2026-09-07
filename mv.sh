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
    if command -v zsh &>/dev/null; then
        echo "Zsh уже установлен"
    else
        sudo apt update && sudo apt install -y zsh
        echo "Установка Zsh завершена!" 
        
    fi

    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "Oh My Zsh уже установлен"
    else 
        if ! command -v curl &>/dev/null; then
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

    mapfile -t all_builtin_plugins < <(find "$omz_dir/plugins" -maxdepth 1 -type d -printf "%f\n" | grep -v '^plugins$' | grep -v '^\.' | sort)
    
    if [[ ${#all_builtin_plugins[@]} -eq 0 ]]; then
        echo "Нет встроенных плагинов."
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
    IFS=' ' read -r -a current_all_plugins <<< "$plugins_str"

    declare -A selected_builtin_map
    for p in "${current_all_plugins[@]}"; do
        if [[ " ${all_builtin_plugins[*]} " =~ " $p " ]]; then
            selected_builtin_map["$p"]=1
        fi
    done

    local page=0
    local page_size=20
    local total_pages=$(( (${#all_builtin_plugins[@]} + page_size - 1) / page_size ))

    show_page() {
        clear
        local start=$((page * page_size))
        local end=$((start + page_size - 1))
        (( end >= ${#all_builtin_plugins[@]} )) && end=$(( ${#all_builtin_plugins[@]} - 1 ))
        
        echo "=== Встроенные плагины Oh My Zsh (страница $((page+1))/$total_pages) ==="
        echo "  [x] - включён, [ ] - выключен"
        for (( i=start; i<=end; i++ )); do
            local p="${all_builtin_plugins[i]}"
            if [[ -n "${selected_builtin_map[$p]}" ]]; then
                printf "%3d. [x] %s\n" $((i+1)) "$p"
            else
                printf "%3d. [ ] %s\n" $((i+1)) "$p"
            fi
        done
        echo "--- Показано $((end-start+1)) из ${#all_builtin_plugins[@]} плагинов ---"
        echo ""
        echo "Управление:"
        echo "  <номер>         - вкл/выкл"
        echo "  a/d             - назад/вперёд"
        echo "  q               - сохранить и выйти"
        echo ""
        echo -n "Ваш ввод: "
    }

    toggle_plugin_by_index() {
        local idx=$1
        if (( idx >= 1 && idx <= ${#all_builtin_plugins[@]} )); then
            local p="${all_builtin_plugins[$((idx-1))]}"
            if [[ -n "${selected_builtin_map[$p]}" ]]; then
                unset 'selected_builtin_map[$p]'
            else
                selected_builtin_map["$p"]=1
            fi
        else
            echo "Номер $idx вне диапазона"
            read -p "Нажмите Enter..."
        fi
    }

    while true; do
        show_page
        read -r input

        case "$input" in
            q|Q) break ;;
            a|A)
                if (( page > 0 )); then ((page--)); else echo "Первая страница"; read -p "Enter..."; fi ;;
            d|D)
                if (( page < total_pages - 1 )); then ((page++)); else echo "Последняя страница"; read -p "Enter..."; fi ;;
            "") continue ;;
            *)
                if [[ "$input" =~ ^[0-9]+$ ]]; then
                    toggle_plugin_by_index "$input"
                else
                    echo "Используйте числа или a/d/q"
                    read -p "Нажмите Enter..."
                fi
                ;;
        esac
    done

    local final_plugins=()
    
    for p in "${all_builtin_plugins[@]}"; do
        if [[ -n "${selected_builtin_map[$p]}" ]]; then
            final_plugins+=("$p")
        fi
    done

    for p in "${current_all_plugins[@]}"; do
        if [[ ! " ${all_builtin_plugins[*]} " =~ " $p " ]]; then
            final_plugins+=("$p")
        fi
    done

    local unique_plugins=()
    declare -A seen
    for p in "${final_plugins[@]}"; do
        if [[ -z "${seen[$p]}" ]]; then
            unique_plugins+=("$p")
            seen["$p"]=1
        fi
    done

    local new_line="plugins=(${unique_plugins[*]})"
    cp "$zshrc" "$zshrc.bak"
    sed -i "s|^plugins=(.*)|$new_line|" "$zshrc"
    
    echo "$zshrc обновлён."
    echo "Сохранено плагинов: ${#unique_plugins[@]}"
    echo "Не забудьте: source ~/.zshrc"
}

# ---- Функция управления темами Zsh ----
manage_zsh_theme() {
    local zshrc="$HOME/.zshrc"
    local omz_dir="$HOME/.oh-my-zsh"
    local themes_dir="$omz_dir/themes"

    if [[ ! -d "$omz_dir" ]]; then
        echo "Oh My Zsh не установлен. Сначала выполните пункт 3."
        return 1
    fi
    if [[ ! -f "$zshrc" ]]; then
        echo "Файл $zshrc не найден."
        return 1
    fi

    mapfile -t all_themes < <(find "$themes_dir" -maxdepth 1 -name "*.zsh-theme" -printf "%f\n" | sed 's/\.zsh-theme$//' | sort)
    if [[ ${#all_themes[@]} -eq 0 ]]; then
        echo "Темы не найдены в $themes_dir"
        return 1
    fi

    local current_theme="robbyrussell"
    local theme_line
    theme_line=$(grep -E '^ZSH_THEME=' "$zshrc")
    if [[ -n "$theme_line" ]]; then
        current_theme=$(echo "$theme_line" | sed -E 's/^ZSH_THEME=["'"'"']?([^"'"'"']+)["'"'"']?$/\1/')
    fi

    local selected_theme="$current_theme"
    local page=0
    local page_size=20
    local total_pages=$(( (${#all_themes[@]} + page_size - 1) / page_size ))

    show_page() {
        clear
        local start=$((page * page_size))
        local end=$((start + page_size - 1))
        (( end >= ${#all_themes[@]} )) && end=$(( ${#all_themes[@]} - 1 ))
        
        echo "=== Темы Oh My Zsh (страница $((page+1))/$total_pages) ==="
        echo "Текущая сохраненная тема: $current_theme"
        echo "  [*] - выбрана сейчас"
        echo ""
        for (( i=start; i<=end; i++ )); do
            local t="${all_themes[i]}"
            if [[ "$t" == "$selected_theme" ]]; then
                printf "%3d. [*] %s\n" $((i+1)) "$t"
            else
                printf "%3d. [ ] %s\n" $((i+1)) "$t"
            fi
        done
        echo "--- Показано $((end-start+1)) из ${#all_themes[@]} тем ---"
        echo ""
        echo "Управление:"
        echo "  5           - установить тему"
        echo "  a/d         - назад/вперёд"
        echo "  q           - сохранить и выйти"
        echo "  s           - выйти без сохранения"
        echo ""
        echo -n "Ваш ввод: "
    }

    select_theme_by_index() {
        local idx=$1
        if (( idx >= 1 && idx <= ${#all_themes[@]} )); then
            selected_theme="${all_themes[$((idx-1))]}"
        else
            echo "Номер $idx вне диапазона (1-${#all_themes[@]})"
            read -p "Нажмите Enter..."
        fi
    }

    while true; do
        show_page
        read -r input
        case "$input" in
            q|S) break ;;
            s|Q) echo "Изменения отменены."; return 0 ;;
            a|A) (( page > 0 )) && ((page--)) || { echo "Первая страница"; read -p "Enter..."; } ;;
            d|D) (( page < total_pages - 1 )) && ((page++)) || { echo "Последняя страница"; read -p "Enter..."; } ;;
            "") continue ;;
            *)
                if [[ "$input" =~ ^[0-9]+$ ]]; then
                    select_theme_by_index "$input"
                else
                    echo "Используйте числа, a, d, s или q."
                    read -p "Нажмите Enter..."
                fi
                ;;
        esac
    done

    if [[ "$selected_theme" == "$current_theme" ]]; then
        echo "Тема не была изменена."
        return 0
    fi

    cp "$zshrc" "$zshrc.bak"
    if grep -qE '^ZSH_THEME=' "$zshrc"; then
        sed -i "s|^ZSH_THEME=.*|ZSH_THEME=\"$selected_theme\"|" "$zshrc"
    else
        sed -i "1i ZSH_THEME=\"$selected_theme\"" "$zshrc"
    fi

    echo "Тема изменена на: $selected_theme"
    echo "Резервная копия: $zshrc.bak"
    echo "Выполните: source ~/.zshrc"
}

# ---- Функция управления сторонними плагинами ----
manage_external_plugins() {
    # ПРОВЕРКА GIT
    if ! command -v git &>/dev/null; then
        echo "ОШИБКА: Git не установлен!"
        echo "Установите его через пункт 1 или вручную: sudo apt install git"
        read -p "Нажмите Enter..."
        return 1
    fi

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
        echo "В .zshrc нет строки plugins=(...). Сначала настройте встроенные плагины (пункт 4)."
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
        if [[ -d "$custom_plugins_dir/$name" ]]; then
            installed_map["$name"]=1
            if [[ ! " ${current_zsh_plugins[*]} " =~ " $name " ]]; then
                sed -i "s/^plugins=(\(.*\))/plugins=(\1 $name)/" "$zshrc"
                current_zsh_plugins+=("$name")
            fi
        fi
    done

    while true; do
        clear
        echo "=== Сторонние плагины ==="
        echo "  [x] - установлен и включен"
        echo "  [ ] - не установлен"
        echo ""
        
        local idx=1
        for name in "${sorted_names[@]}"; do
            if [[ -n "${installed_map[$name]}" ]]; then
                printf "%3d. [x] %s\n" $idx "$name"
            else
                printf "%3d. [ ] %s\n" $idx "$name"
            fi
            ((idx++))
        done
        
        echo ""
        echo "q. Выход"
        echo -n "Выберите номер для переключения: "
        read -r input

        case "$input" in
            q|Q) break ;;
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
                            
                            if [[ -d "$target_dir" ]]; then
                                echo "Папка уже существует. Подключаю к конфигу..."
                            elif git clone "$repo_url" "$target_dir"; then
                                echo "Клонирование успешно."
                            else
                                echo "ОШИБКА КЛОНИРОВАНИЯ!"
                                echo "Проверьте интернет, доступность GitHub или права доступа."
                                read -p "Нажмите Enter..."
                                continue
                            fi
                            
                            sed -i "s/^plugins=(\(.*\))/plugins=(\1 $selected_name)/" "$zshrc"
                            installed_map["$selected_name"]=1
                            echo "Плагин установлен и добавлен в конфиг."
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
    echo "Не забудьте: source ~/.zshrc"
}

# ---- Меню ----
options=(
    "1 - Полное обновление системы"
    "2 - Установка базовых утилит (нет)"
    "3 - Установка Zsh + Oh My Zsh"
    "4 - Управление встроенными плагинами Zsh"
    "5 - Управление сторонними плагинами"
    "6 - Выбор темы Zsh"
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
            6) manage_zsh_theme; break ;;
            0) echo "Выход"; exit 0 ;;
            *) echo "Неправильный ввод" ;;
        esac
    done

    echo ""
    read -p "Нажмите Enter, чтобы продолжить"
    echo ""
done