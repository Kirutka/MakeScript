#!/bin/bash
set -o pipefail 

echo "Добро пожаловать в MS!"

# ============================================================================
# УНИВЕРСАЛЬНАЯ ФУНКЦИЯ УСТАНОВКИ ПАКЕТОВ
# Обслуживает разделы: Базовые, Modern CLI, DevOps, GUI
# ============================================================================
install_package_category() {
    local category_name="$1"
    shift
    local items_list=("$@")

    local names=()
    local packages=()
    
    for item in "${items_list[@]}"; do
        names+=("${item%%:*}")
        packages+=("${item##*:}")
    done

    declare -A installed_map
    for pkg in "${packages[@]}"; do
        local check_pkg="${pkg%% *}"
        if dpkg-query -W -f='${Status}' "$check_pkg" 2>/dev/null | grep -q "installed"; then
            installed_map["$pkg"]=1
        fi
    done

    local page=0
    local page_size=15
    local total_pages=$(( (${#names[@]} + page_size - 1) / page_size ))
    declare -A user_selection

    show_page() {
        clear
        local start=$((page * page_size))
        local end=$((start + page_size - 1))
        (( end >= ${#names[@]} )) && end=$(( ${#names[@]} - 1 ))
        
        echo "=== $category_name (страница $((page+1))/$total_pages) ==="
        echo "  [✓] - выбрано / установлено, [ ] - пропустить"
        echo ""
        for (( i=start; i<=end; i++ )); do
            local name="${names[$i]}"
            local pkg="${packages[$i]}"
            local status_char="[ ]"
            
            if [[ -n "${installed_map[$pkg]}" ]]; then
                status_char="[✓]" 
            elif [[ -n "${user_selection[$pkg]}" ]]; then
                status_char="[✓]" 
            fi
            
            printf "%3d. %s %s\n" $((i+1)) "$status_char" "$name"
        done
        echo ""
        echo "Управление: <номер> - выбрать | a/d - страницы | i - установить | q - выход"
        echo -n "Ваш ввод: "
    }

    toggle_item() {
        local idx=$1
        if (( idx >= 1 && idx <= ${#packages[@]} )); then
            local pkg="${packages[$((idx-1))]}"
            if [[ -n "${installed_map[$pkg]}" ]]; then
                echo "Пакет/Утилита '$pkg' уже установлена."
                read -p "Нажмите Enter..."
            else
                if [[ -n "${user_selection[$pkg]}" ]]; then
                    unset 'user_selection[$pkg]'
                else
                    user_selection["$pkg"]=1
                fi
            fi
        else
            echo "Номер вне диапазона"
            read -p "Нажмите Enter..."
        fi
    }

    while true; do
        show_page
        read -r input
        case "$input" in
            q|Q) break ;;
            i|I)
                local to_install=()
                for pkg in "${packages[@]}"; do
                    if [[ -n "${user_selection[$pkg]}" ]] && [[ -z "${installed_map[$pkg]}" ]]; then
                        to_install+=("$pkg")
                    fi
                done
                
                if [[ ${#to_install[@]} -eq 0 ]]; then
                    echo "Нечего устанавливать. Отметьте пункты галочками."
                    read -p "Нажмите Enter..."
                else
                    echo "Будут установлены: ${to_install[*]}"
                    echo -n "Подтвердить? (y/n): "
                    read -r confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        sudo apt update
                        
                        for pkg in "${to_install[@]}"; do
                            if [[ "$pkg" == "extract-script" ]]; then
                                echo "Запуск установки Extract..."
                                curl -L -o install_extract.sh https://raw.githubusercontent.com/xvoland/Extract/master/install_extract.sh
                                if [ -f install_extract.sh ]; then
                                    bash install_extract.sh
                                    rm install_extract.sh
                                    echo "✓ Extract успешно установлен!"
                                else
                                    echo "✗ Ошибка скачивания скрипта Extract"
                                fi
                            
                            elif [[ "$pkg" == "docker.io" ]]; then
                                sudo apt install -y "$pkg"
                                echo "Добавляю пользователя в группу docker..."
                                sudo usermod -aG docker $USER
                                echo "✓ Готово! Перезайдите в систему для работы с docker без sudo."
                            
                            else
                                sudo apt install -y "$pkg"
                            fi
                        done
                        
                        for pkg in "${to_install[@]}"; do installed_map["$pkg"]=1; done
                        echo "✓ Все выбранные операции завершены!"
                        read -p "Нажмите Enter..."
                    fi
                fi
                ;;
            a|A) (( page > 0 )) && ((page--)) || { echo "Первая страница"; read -p "Enter..."; } ;;
            d|D) (( page < total_pages - 1 )) && ((page++)) || { echo "Последняя страница"; read -p "Enter..."; } ;;
            "") continue ;;
            *)
                if [[ "$input" =~ ^[0-9]+$ ]]; then toggle_item "$input"
                else echo "Используйте числа, a, d, i или q"; read -p "Enter..."; fi
                ;;
        esac
    done
}

# ============================================================================
# КАТЕГОРИИ УСТАНОВКИ
# ============================================================================

install_basic_utils() {
    install_package_category "Базовые утилиты" \
        "Git:git" \
        "Curl:curl" \
        "Wget:wget" \
        "Build-Essential (gcc/make):build-essential" \
        "Htop:htop" \
        "Btop:btop" \
        "Jq:jq" \
        "Vim:vim" \
        "Nano:nano"
}

install_modern_cli() {
    install_package_category "Modern CLI Tools" \
        "Bat (cat с подсветкой):bat" \
        "Eza (современный ls):eza" \
        "Ripgrep (быстрый grep):ripgrep" \
        "Fd (быстрый find):fd-find" \
        "Zoxide (умный cd):zoxide" \
        "Dust (анализ диска):dust" \
        "Procs (монитор процессов):procs" \
        "Sd (поиск/замена текста):sd" \
        "Extract (универсальный распаковщик):extract-script"
}

install_devops_tools() {
    install_package_category "DevOps & Monitoring" \
        "Docker:docke r.io" \
        "Docker Compose:docker-compose" \
        "Terraform:terraform" \
        "Ansible:ansible" \
        "Kubectl:kubectl" \
        "Helm:helm" \
        "Minikube:minikube" \
        "Prometheus:prometheus" \
        "Grafana:grafana" \
        "Loki:loki"
}

install_gui_apps() {
    install_package_category "Графические приложения" \
        "Firefox:firefox" \
        "VS Code:code" \
        "Telegram Desktop:telegram-desktop" \
        "MAX (уточните пакет):max"
}

# ============================================================================
# ZSH + OH MY ZSH
# ============================================================================

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
            echo "Устанавливаю curl..."
            sudo apt install -y curl
        fi
        if command -v curl &>/dev/null; then
            sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
            echo "Установка Oh My Zsh завершена!"
        fi
    fi
}

# ============================================================================
# УПРАВЛЕНИЕ ПЛАГИНАМИ OH MY ZSH
# ============================================================================

manage_zsh_plugins() {
    local zshrc="$HOME/.zshrc"
    local omz_dir="$HOME/.oh-my-zsh"

    if [[ ! -d "$omz_dir" ]]; then
        echo "Oh My Zsh не установлен. Сначала выполните пункт 6."
        read -p "Нажмите Enter..."
        return 1
    fi
    if [[ ! -f "$zshrc" ]]; then
        echo "Файл $zshrc не найден."
        read -p "Нажмите Enter..."
        return 1
    fi

    mapfile -t all_builtin_plugins < <(find "$omz_dir/plugins" -maxdepth 1 -type d -printf "%f\n" | grep -v '^plugins$' | grep -v '^\.' | sort)
    
    if [[ ${#all_builtin_plugins[@]} -eq 0 ]]; then
        echo "Нет встроенных плагинов."
        read -p "Нажмите Enter..."
        return 1
    fi

    local current_line
    current_line=$(grep -E '^plugins=\(.*\)' "$zshrc")
    if [[ -z "$current_line" ]]; then
        echo "В .zshrc нет строки plugins=(...). Добавьте её вручную."
        read -p "Нажмите Enter..."
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
        
        echo "=== Плагины Oh My Zsh (страница $((page+1))/$total_pages) ==="
        echo "  [✓] - включён, [ ] - выключен"
        for (( i=start; i<=end; i++ )); do
            local p="${all_builtin_plugins[i]}"
            if [[ -n "${selected_builtin_map[$p]}" ]]; then
                printf "%3d. [✓] %s\n" $((i+1)) "$p"
            else
                printf "%3d. [ ] %s\n" $((i+1)) "$p"
            fi
        done
        echo "--- Показано $((end-start+1)) из ${#all_builtin_plugins[@]} ---"
        echo ""
        echo "Управление: <номер> - вкл/выкл | a/d - страницы | q - сохранить и выйти"
        echo -n "Ваш ввод: "
    }

    toggle_plugin() {
        local idx=$1
        if (( idx >= 1 && idx <= ${#all_builtin_plugins[@]} )); then
            local p="${all_builtin_plugins[$((idx-1))]}"
            if [[ -n "${selected_builtin_map[$p]}" ]]; then
                unset 'selected_builtin_map[$p]'
            else
                selected_builtin_map["$p"]=1
            fi
        else
            echo "Номер вне диапазона"
            read -p "Нажмите Enter..."
        fi
    }

    while true; do
        show_page
        read -r input
        case "$input" in
            q|Q) break ;;
            a|A) (( page > 0 )) && ((page--)) || { echo "Первая страница"; read -p "Enter..."; } ;;
            d|D) (( page < total_pages - 1 )) && ((page++)) || { echo "Последняя страница"; read -p "Enter..."; } ;;
            "") continue ;;
            *)
                if [[ "$input" =~ ^[0-9]+$ ]]; then toggle_plugin "$input"
                else echo "Используйте числа, a, d или q"; read -p "Enter..."; fi
                ;;
        esac
    done

    local final_plugins=()
    for p in "${all_builtin_plugins[@]}"; do
        [[ -n "${selected_builtin_map[$p]}" ]] && final_plugins+=("$p")
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
    
    echo "✓ .zshrc обновлён. Резервная копия: $zshrc.bak"
    echo "Не забудьте: source ~/.zshrc"
}

# ============================================================================
# ОБНОВЛЕНИЕ СИСТЕМЫ
# ============================================================================

update_system() {
    echo "Полное обновление системы..."
    sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y
    echo "✓ Система обновлена"
}

# ============================================================================
# ГЛАВНОЕ МЕНЮ
# ============================================================================

options=(
    "1 - Полное обновление системы"
    "2 - Установка базовых утилит"
    "3 - Установка Modern CLI"
    "4 - Установка DevOps инструментов"
    "5 - Установка графических приложений"
    "6 - Установка Zsh + Oh My Zsh"
    "7 - Управление плагинами Oh My Zsh"
    "0 - Выход"
)

while true; do
    clear
    echo "=== МЕНЮ ==="
    PS3="Выберите номер действия: "

    select choice in "${options[@]}"; do
        case $REPLY in
            1) update_system; break ;;
            2) install_basic_utils; break ;;
            3) install_modern_cli; break ;;
            4) install_devops_tools; break ;;
            5) install_gui_apps; break ;;
            6) install_Zsh_OMZ_plugins; break ;;
            7) manage_zsh_plugins; break ;;
            0) echo "Выход"; exit 0 ;;
            *) echo "Неправильный ввод"; sleep 1; break ;;
        esac
    done
done