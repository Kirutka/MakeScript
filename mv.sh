#!/bin/bash

set -e          
set -o pipefail 

echo "Добро пожаловать в MS!"

update_system() {
	echo "Полное обновление системы..."

	apt update && apt full-upgrade -y && apt autoremove -y && apt autoclean -y

	echo "Система обновлена"
}


options=(
	"1 - Полное обновление системы"
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

