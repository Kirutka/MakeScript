#!/bin/bash

set -e          
set -o pipefail 

echo "Добро пожаловать в MS!"

update_system() {
	echo "Полное обновление системы"
	apt update && apt full-upgrade -y && apt autoremove -y && apt autoclean -y
	echo "Система обновлена"
}

install_Zsh_OMZ_plugins() {
	if ! command -v zsh &>/dev/null; then
		sudo apt update && sudo apt install -y zsh
		echo "Zsh установлен"
	else 
		echo "Zsh уже установлен"
	fi

	if [ -d "$HOME/.oh-my-zsh" ]; then
		echo "Oh My Zsh уже установлен"
	else 
		if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
		echo "Устанавливаю curl"
		sudo apt install -y curl
	fi
	if command -v curl &>/dev/null; then
            sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
			echo "Oh My Zsh установлен"
	fi
fi
}


options=(
	"1 - Полное обновление системы"
	"2 - Установка базовых утилит (нет)"
	"3 - Установка Zsh + Oh My Zsh"
	"0 - Выход"
	)

while true; do
	echo "===МЕНЮ==="
	PS3="Выберите номер действия: "

	select choice in "${options[@]}"; do
		case $REPLY in
			1)
				update_system
				break
				;;
			3) 
				install_Zsh_OMZ_plugins
				break
				;;

			0) 
				echo "Выход"
				exit 0
				;;
			*)
				echo "Неправильный ввод"
				;;
			esac
		done

		echo ""
		read -p "Нажмите Enter, чтобы продолжить"
		echo ""
	done

